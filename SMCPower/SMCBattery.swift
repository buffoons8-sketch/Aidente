import Foundation
import SMCKit
import IOKit

public enum SMCBatteryError: LocalizedError, Sendable {
    case unsupportedCapability
    case stateVerificationFailed
    case firmwareRestoreFailed
    public var errorDescription: String? {
        switch self {
        case .unsupportedCapability: "Unsupported charging-control registers on this firmware"
        case .stateVerificationFailed: "SMC power-state readback did not match the requested state"
        case .firmwareRestoreFailed: "Firmware charge-limit write failed and the previous limits could not be restored"
        }
    }
}

public struct BatteryCapabilities: Codable, Sendable {
    public let inhibitChargeControl: Bool
    public let forceDischargeControl: Bool
    public init(inhibitChargeControl: Bool, forceDischargeControl: Bool) {
        self.inhibitChargeControl = inhibitChargeControl
        self.forceDischargeControl = forceDischargeControl
    }
}

public protocol BatteryPowerControlling {
    var capabilities: BatteryCapabilities { get }
    func getChargingInhibited() throws -> Bool
    func setChargingInhibited(_ inhibited: Bool) throws
    func chargingInhibitMatches(_ inhibited: Bool) throws -> Bool
    func getForceDischarging() throws -> Bool
    func setForceDischarging(_ enabled: Bool) throws
}

/*
 * Based on:
 * https://github.com/AsahiLinux/linux/blob/79a307df1e18f144610742ac9ee60080c3983875/drivers/power/supply/macsmc-power.c
 * https://github.com/mhaeuser/Battery-Toolkit/blob/ed3adf103abfdad53223ce6f0a764ae7163c385b/Libraries/SMCComm%2BPower.swift
 * https://github.com/acidanthera/VirtualSMC/blob/55b89a23f51beda82581dbab795615838a3e6e56/Docs/SMCSensorKeys.txt
 */
public struct SMCBattery: Sendable, BatteryPowerControlling {
    public let capabilities: BatteryCapabilities

    private let hasCH0C: Bool
    private let hasCH0B: Bool
    private let hasCHTE: Bool
    private let hasCH0I: Bool
    private let hasCHIE: Bool
    public let usesFirmwareChargeLimit: Bool

    public var chargingControlKey: String {
        usesFirmwareChargeLimit ? "bfF0/bfD0/bfE0" : hasCHTE ? "CHTE" : hasCH0C ? (hasCH0B ? "CH0B/CH0C" : "CH0C") : "unsupported"
    }
    public var dischargeControlKey: String { hasCHIE ? "CHIE" : hasCH0I ? "CH0I" : "unsupported" }

    public static func probe() throws -> SMCBattery {
        func supported(_ key: FourCharCode, size: UInt32) throws -> Bool {
            do {
                let info = try SMCKit.shared.getKeyInformation(key)
                let knownTypes: [FourCharCode] = size == 4 ? ["ui32"] : ["hex_", "ui8 "]
                return info.size == size && knownTypes.contains(info.type)
            } catch SMCError.keyNotFound { return false }
              catch SMCError.notPrivileged { return false }
        }
        let hasCH0C = try supported("CH0C", size: 1)
        let hasCH0B = try supported("CH0B", size: 1)
        let hasCHTE = try supported("CHTE", size: 4)
        let hasCH0I = try supported("CH0I", size: 1)
        let hasCHIE = try supported("CHIE", size: 1)
        let hasFirmwareLimit = try supported("bfF0", size: 1)
            && supported("bfD0", size: 4) && supported("bfE0", size: 4)

        let capabilities = BatteryCapabilities(
            inhibitChargeControl: hasFirmwareLimit || hasCH0C || hasCHTE,
            forceDischargeControl: hasCH0I || hasCHIE
        )

        return SMCBattery(
            capabilities: capabilities,
            hasCH0C: hasCH0C,
            hasCH0B: hasCH0B,
            hasCHTE: hasCHTE,
            hasCH0I: hasCH0I,
            hasCHIE: hasCHIE,
            usesFirmwareChargeLimit: hasFirmwareLimit
        )
    }
    
    private init(capabilities: BatteryCapabilities, hasCH0C: Bool, hasCH0B: Bool, hasCHTE: Bool, hasCH0I: Bool, hasCHIE: Bool, usesFirmwareChargeLimit: Bool) {
        self.capabilities = capabilities
        self.hasCH0C = hasCH0C
        self.hasCH0B = hasCH0B
        self.hasCHTE = hasCHTE
        self.hasCH0I = hasCH0I
        self.hasCHIE = hasCHIE
        self.usesFirmwareChargeLimit = usesFirmwareChargeLimit
    }

    public static func getVoltage() throws -> Double {
        Double(try SMCKit.shared.read("B0AV") as UInt16) / 1000.0
    }

    public static func getCurrent() throws -> Double {
        Double(try SMCKit.shared.read("B0AC") as Int16) / 1000.0
    }

    public static func firmwarePercentage() throws -> Int {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { throw SMCBatteryError.unsupportedCapability }
        defer { IOObjectRelease(service) }
        func number(_ key: String) -> Double? {
            (IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber)?.doubleValue
        }
        guard let current = number("AppleRawCurrentCapacity"), let full = number("AppleRawMaxCapacity"),
              full > 0, current >= 0 else { throw SMCBatteryError.unsupportedCapability }
        return max(1, min(100, Int((current / full * 100).rounded(.down))))
    }

    public func getChargingInhibited() throws -> Bool {
        guard capabilities.inhibitChargeControl else { throw SMCBatteryError.unsupportedCapability }

        if usesFirmwareChargeLimit {
            let state = try FirmwareChargeLimitController(registers: SMCFirmwareLimitRegisters()).read()
            guard state.activation == 2 else { return false }
            return try Self.firmwarePercentage() >= Int(state.upper)
        }

        if hasCHTE {
            let value: UInt32 = try SMCKit.shared.read("CHTE")
            return value != 0
        } else {
            let value: UInt8 = try SMCKit.shared.read("CH0C")
            if hasCH0B {
                let companion: UInt8 = try SMCKit.shared.read("CH0B")
                return value != 0 || companion != 0
            }
            return value != 0
        }
    }

    public func chargingInhibitMatches(_ inhibited: Bool) throws -> Bool {
        if !usesFirmwareChargeLimit && !hasCHTE && hasCH0B && hasCH0C {
            let companion: UInt8 = try SMCKit.shared.read("CH0B")
            let primary: UInt8 = try SMCKit.shared.read("CH0C")
            let expected: UInt8 = inhibited ? 2 : 0
            return companion == expected && primary == expected
        }
        return try getChargingInhibited() == inhibited
    }

    public func setChargingInhibited(_ inhibited: Bool) throws {
        guard capabilities.inhibitChargeControl else { throw SMCBatteryError.unsupportedCapability }

        if usesFirmwareChargeLimit {
            let controller = FirmwareChargeLimitController(registers: SMCFirmwareLimitRegisters())
            if inhibited {
                let upper = try Self.firmwarePercentage()
                try controller.set(lower: max(0, upper - 2), upper: upper)
            } else {
                var state = try controller.read()
                state.activation = 0
                try controller.replace(with: state)
            }
            return
        }

        if hasCHTE {
            if !inhibited && hasCH0I {
                try SMCKit.shared.write("CH0I", UInt8(0))
            }
            let value: UInt32 = inhibited ? 1 : 0
            try SMCKit.shared.write("CHTE", value)
        } else {
            if !inhibited && hasCH0I {
                try SMCKit.shared.write("CH0I", UInt8(0))
            }
            let value: UInt8 = inhibited ? (hasCH0B ? 2 : 1) : 0
            if hasCH0B { try SMCKit.shared.writeControlData("CH0B", Data([value])) }
            try SMCKit.shared.writeControlData("CH0C", Data([value]))
        }
    }

    public func getForceDischarging() throws -> Bool {
        guard capabilities.forceDischargeControl else {
            throw SMCBatteryError.unsupportedCapability
        }

        if hasCHIE {
            let data = try SMCKit.shared.readData("CHIE")
            return data.first == 0x08
        } else {
            let value: UInt8 = try SMCKit.shared.read("CH0I")
            return value != 0
        }
    }

    public func setForceDischarging(_ enabled: Bool) throws {
        guard capabilities.forceDischargeControl else {
            throw SMCBatteryError.unsupportedCapability
        }

        if enabled {
            // Clear charging inhibit before enabling force discharge
            if hasCHTE {
                try SMCKit.shared.write("CHTE", UInt32(0))
            } else if hasCH0C {
                if hasCH0B { try SMCKit.shared.writeControlData("CH0B", Data([0])) }
                try SMCKit.shared.write("CH0C", UInt8(0))
            }

            if hasCHIE {
                try SMCKit.shared.writeControlData("CHIE", Data([0x08]))
            } else {
                try SMCKit.shared.write("CH0I", UInt8(1))
            }
        } else {
            if hasCHIE {
                try SMCKit.shared.writeControlData("CHIE", Data([0x00]))
            } else {
                try SMCKit.shared.write("CH0I", UInt8(0))
            }
        }
    }

}

extension BatteryPowerControlling {
    public func chargingInhibitMatches(_ inhibited: Bool) throws -> Bool {
        try getChargingInhibited() == inhibited
    }
    /// One ordered transaction. Enabling discharge clears the charge-inhibit
    /// register on this hardware, so it must never race a separate pause write.
    public func applyPowerState(charging: Bool, adapter: Bool) throws {
        guard capabilities.inhibitChargeControl else {
            throw SMCBatteryError.unsupportedCapability
        }
        if adapter {
            if capabilities.forceDischargeControl, try getForceDischarging() {
                try setForceDischarging(false)
            }
            if try !chargingInhibitMatches(!charging) {
                try setChargingInhibited(!charging)
            }
            guard try chargingInhibitMatches(!charging) else {
                throw SMCBatteryError.stateVerificationFailed
            }
            if capabilities.forceDischargeControl, try getForceDischarging() {
                throw SMCBatteryError.stateVerificationFailed
            }
        } else {
            guard capabilities.forceDischargeControl else {
                throw SMCBatteryError.unsupportedCapability
            }
            if try !getForceDischarging() { try setForceDischarging(true) }
            guard try getForceDischarging() else {
                throw SMCBatteryError.stateVerificationFailed
            }
        }
    }
}
