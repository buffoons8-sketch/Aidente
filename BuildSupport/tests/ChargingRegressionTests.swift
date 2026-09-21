import Foundation
import AidenteShared
import smc_power
import SMCKit

final class SimulatedFirmware: FirmwareLimitRegisters {
    var state = FirmwareChargeLimitState(activation: 0, lower: 0, upper: 0)
    var operations: [String] = []
    var failNextLowerWrite = false
    var ignoreActivation = false
    var denyWrites = false
    func readActivation() throws -> UInt8 { state.activation }
    func readLower() throws -> UInt32 { state.lower }
    func readUpper() throws -> UInt32 { state.upper }
    func writeActivation(_ value: UInt8) throws {
        if denyWrites { throw SMCError.notPrivileged }
        operations.append("active=\(value)")
        if !ignoreActivation { state.activation = value }
    }
    func writeLower(_ value: UInt32) throws {
        operations.append("lower=\(value)")
        if failNextLowerWrite {
            failNextLowerWrite = false
            throw SMCBatteryError.stateVerificationFailed
        }
        state.lower = value
    }
    func writeUpper(_ value: UInt32) throws {
        operations.append("upper=\(value)")
        state.upper = value
    }
}

final class SimulatedBattery: BatteryPowerControlling {
    let capabilities = BatteryCapabilities(inhibitChargeControl: true, forceDischargeControl: true)
    var inhibited = false
    var discharging = false
    var ignoreWrites = false
    var writes: [String] = []
    func getChargingInhibited() throws -> Bool { inhibited }
    func getForceDischarging() throws -> Bool { discharging }
    func setChargingInhibited(_ value: Bool) throws {
        writes.append("inhibit=\(value)")
        if !ignoreWrites { inhibited = value }
    }
    func setForceDischarging(_ value: Bool) throws {
        writes.append("discharge=\(value)")
        if !ignoreWrites {
            discharging = value
            if value { inhibited = false } // Actual SMC coupling.
        }
    }
}

@main struct ChargingRegressionTests {
    static func main() throws {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            precondition(condition(), name)
            checks += 1
        }
        var normal = ChargeLimitPolicy()
        var firmwareHold = FirmwareHoldPolicy()
        check(firmwareHold.upper(charging: false, ceiling: 60, percentage: 90) == 60, "Hold uses real limit, never 1 percent")
        check(firmwareHold.upper(charging: false, ceiling: 60, percentage: 55) == 60, "Polling must not chase declining capacity")
        check(firmwareHold.upper(charging: true, ceiling: 80, percentage: 50) == 80, "Resume restores target")
        check(firmwareHold.upper(charging: false, ceiling: 80, percentage: 50) == 50, "Manual pause captures current capacity")
        check(firmwareHold.upper(charging: false, ceiling: 80, percentage: 49) == 50, "Manual hold remains stable")
        check(!ControlServiceRefreshPolicy.needsRefresh(previous: nil, current: "os:hash"),
              "First registration must not be torn down immediately")
        check(!ControlServiceRefreshPolicy.needsRefresh(previous: "os:hash", current: "os:hash"),
              "Same verified build does not require re-registration")
        check(ControlServiceRefreshPolicy.needsRefresh(previous: "os:old", current: "os:new"),
              "Changed helper requires migration")
        check(ControlServiceRefreshPolicy.needsRefresh(previous: "old:hash", current: "new:hash"),
              "Changed OS requires migration")
        for (index, level) in [79, 80, 81, 80, 79, 78, 79, 77, 78, 80].enumerated() {
            let state = normal.evaluate(percentage: level, limit: 80, sailing: false,
                                        sailingRange: 5, automaticDischarge: true, initialize: index == 0)
            check(state.adapter, "Normal charge overshoot must never force battery power")
            check(state.charging == [true, false, false, false, false, true, true, true, true, false][index],
                  "Hold must survive one/two point fluctuations")
        }
        var explicit = ChargeLimitPolicy()
        for (i, level) in [90, 85, 81, 80, 81, 79].enumerated() {
            let state = explicit.evaluate(percentage: level, limit: 80, sailing: false,
                                          sailingRange: 5, automaticDischarge: true, initialize: i == 0)
            check(state.adapter == (i >= 3), "Explicit automatic discharge stops once and stays stopped")
            check(!state.charging, "Automatic discharge must not charge")
        }
        var disabled = ChargeLimitPolicy()
        check(disabled.evaluate(percentage: 95, limit: 80, sailing: false, sailingRange: 5,
                                automaticDischarge: false, initialize: true).adapter,
              "Disabled auto-discharge always retains adapter power")
        var sailing = ChargeLimitPolicy()
        for (i, level) in [78, 76, 75, 74, 79, 80].enumerated() {
            let state = sailing.evaluate(percentage: level, limit: 80, sailing: true, sailingRange: 5,
                                         automaticDischarge: false, initialize: i == 0)
            check(state.adapter, "Sailing must not force discharge")
            check(state.charging == [false, false, false, true, true, false][i], "Sailing hysteresis")
        }
        for charge in [false, true] {
            for adapter in [false, true] {
                var sleep = ChargingPowerPolicy()
                sleep.managed = true
                sleep.charging = charge
                sleep.adapter = adapter
                sleep.stopWhileSleeping = true
                sleep.sleeping = true
                check(!sleep.effective.charging && sleep.effective.adapter,
                      "Sleep pauses charging and restores AC, even if unplugged before sleep")
                sleep.sleeping = false
                check(sleep.effective.charging == (charge && adapter) && sleep.effective.adapter == adapter,
                      "Fresh awake request restores policy")
            }
        }
        var noSleepOverride = ChargingPowerPolicy()
        noSleepOverride.managed = true
        noSleepOverride.charging = false
        noSleepOverride.sleeping = true
        check(!noSleepOverride.effective.charging, "Manual pause survives sleep with sleep option disabled")

        let hardware = SimulatedBattery()
        hardware.discharging = true
        try hardware.applyPowerState(charging: false, adapter: true)
        check(hardware.writes == ["discharge=false", "inhibit=true"], "Restore adapter BEFORE pausing")
        hardware.writes = []
        try hardware.applyPowerState(charging: false, adapter: true)
        check(hardware.writes.isEmpty, "Stable state must avoid redundant SMC writes")
        try hardware.applyPowerState(charging: false, adapter: false)
        check(hardware.discharging && !hardware.inhibited, "Discharge honors coupled registers")
        hardware.writes = []
        try hardware.applyPowerState(charging: true, adapter: true)
        check(!hardware.discharging && !hardware.inhibited, "Resume leaves adapter connected")
        hardware.ignoreWrites = true
        do {
            try hardware.applyPowerState(charging: false, adapter: true)
            preconditionFailure("Readback must reject ignored firmware writes")
        } catch SMCBatteryError.stateVerificationFailed { checks += 1 }
        let firmware = SimulatedFirmware()
        let firmwareControl = FirmwareChargeLimitController(registers: firmware)
        try firmwareControl.set(lower: 75, upper: 80)
        check(firmware.operations == ["active=0", "upper=80", "lower=75", "active=2"],
              "Firmware activation must follow the complete interval")
        firmware.operations = []
        try firmwareControl.set(lower: 75, upper: 80)
        check(firmware.operations.isEmpty, "Stable firmware interval requires no writes")
        let baseline = firmware.state
        firmware.failNextLowerWrite = true
        do {
            try firmwareControl.set(lower: 40, upper: 50)
            preconditionFailure("Partial firmware failure must propagate")
        } catch { checks += 1 }
        check(firmware.state == baseline, "Partial firmware write restores the original interval")
        try firmwareControl.set(lower: 0, upper: 1)
        check(firmware.state.upper == 1 && firmware.state.activation == 2,
              "Sleep/manual hold uses the firmware limit, not adapter cut")
        try firmwareControl.replace(with: baseline)
        check(firmware.state == baseline, "Original system settings restore exactly")
        firmware.denyWrites = true
        do {
            try firmwareControl.set(lower: 20, upper: 30)
            preconditionFailure("Private entitlement denial must not report success")
        } catch SMCError.notPrivileged { checks += 1 }
        check(firmware.state == baseline, "Denied writes leave the original state intact")
        firmware.denyWrites = false
        firmware.state = FirmwareChargeLimitState(activation: 0, lower: 0, upper: 0)
        firmware.ignoreActivation = true
        do {
            try firmwareControl.set(lower: 50, upper: 60)
            preconditionFailure("Ignored firmware activation must fail readback")
        } catch SMCBatteryError.stateVerificationFailed { checks += 1 }
        check(firmware.state == FirmwareChargeLimitState(activation: 0, lower: 0, upper: 0),
              "Ignored activation restores the disabled state")
        for interval in [(-1, 80), (80, 80), (81, 80), (80, 101)] {
            do {
                try firmwareControl.set(lower: interval.0, upper: interval.1)
                preconditionFailure("Invalid firmware interval accepted")
            } catch SMCBatteryError.unsupportedCapability { checks += 1 }
        }
        let encoded = try UInt32(80).encode()
        check(withUnsafeBytes(of: encoded) { Array($0.prefix(4)) } == [80, 0, 0, 0],
              "Firmware percentage codec must be little endian")
        print("PASS: \(checks) charging, sleep, firmware, rollback and readback checks")
    }
}
