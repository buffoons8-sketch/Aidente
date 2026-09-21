import Foundation
import SMCKit

public struct FirmwareChargeLimitState: Codable, Equatable, Sendable {
    public var activation: UInt8
    public var lower: UInt32
    public var upper: UInt32

    public init(activation: UInt8, lower: UInt32, upper: UInt32) {
        self.activation = activation
        self.lower = lower
        self.upper = upper
    }
}

public protocol FirmwareLimitRegisters {
    func readActivation() throws -> UInt8
    func readLower() throws -> UInt32
    func readUpper() throws -> UInt32
    func writeActivation(_ value: UInt8) throws
    func writeLower(_ value: UInt32) throws
    func writeUpper(_ value: UInt32) throws
}

public struct SMCFirmwareLimitRegisters: FirmwareLimitRegisters {
    public init() {}
    public func readActivation() throws -> UInt8 { try SMCKit.shared.read("bfF0") }
    // These firmware percentages are little-endian, matching SMCKit's native
    // UInt32 codec on Apple Silicon, rather than conventional big-endian SMC.
    public func readLower() throws -> UInt32 { try SMCKit.shared.read("bfE0") }
    public func readUpper() throws -> UInt32 { try SMCKit.shared.read("bfD0") }
    public func writeActivation(_ value: UInt8) throws { try SMCKit.shared.writeControlData("bfF0", Data([value])) }
    public func writeLower(_ value: UInt32) throws { try SMCKit.shared.write("bfE0", value) }
    public func writeUpper(_ value: UInt32) throws { try SMCKit.shared.write("bfD0", value) }
}

public struct FirmwareChargeLimitController<Registers: FirmwareLimitRegisters> {
    public let registers: Registers
    public init(registers: Registers) { self.registers = registers }

    public func read() throws -> FirmwareChargeLimitState {
        let state = FirmwareChargeLimitState(
            activation: try registers.readActivation(),
            lower: try registers.readLower(), upper: try registers.readUpper()
        )
        guard [0, 2].contains(state.activation), state.lower <= 100, state.upper <= 100,
              state.activation == 0 || state.lower < state.upper else {
            throw SMCBatteryError.unsupportedCapability
        }
        return state
    }

    public func set(lower: Int, upper: Int) throws {
        guard lower >= 0, upper <= 100, lower < upper else {
            throw SMCBatteryError.unsupportedCapability
        }
        try replace(with: FirmwareChargeLimitState(activation: 2, lower: UInt32(lower), upper: UInt32(upper)))
    }

    public func replace(with target: FirmwareChargeLimitState) throws {
        guard [0, 2].contains(target.activation), target.lower <= 100, target.upper <= 100,
              target.activation == 0 || target.lower < target.upper else {
            throw SMCBatteryError.unsupportedCapability
        }
        let previous = try read()
        guard previous != target else { return }
        var changed = false
        do {
            try registers.writeActivation(0)
            changed = true
            try registers.writeUpper(target.upper)
            try registers.writeLower(target.lower)
            try registers.writeActivation(target.activation)
            guard try read() == target else { throw SMCBatteryError.stateVerificationFailed }
        } catch {
            let originalError = error
            guard changed else { throw originalError }
            do {
                try write(previous)
                guard try read() == previous else { throw SMCBatteryError.stateVerificationFailed }
            } catch {
                throw SMCBatteryError.firmwareRestoreFailed
            }
            throw originalError
        }
    }

    private func write(_ state: FirmwareChargeLimitState) throws {
        // Updating a live interval can trigger charging against a half-updated
        // threshold. Disable it, write upper then lower, and activate last.
        try registers.writeActivation(0)
        try registers.writeUpper(state.upper)
        try registers.writeLower(state.lower)
        try registers.writeActivation(state.activation)
    }
}
