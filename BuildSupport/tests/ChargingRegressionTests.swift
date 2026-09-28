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
        check(firmwareHold.upper(charging: false, ceiling: 60, percentage: 90) == 90, "Above-target hold must not force discharge to configured ceiling")
        check(firmwareHold.upper(charging: false, ceiling: 60, percentage: 55) == 90, "Polling must not chase declining capacity")
        check(firmwareHold.upper(charging: true, ceiling: 80, percentage: 50) == 80, "Resume restores target")
        check(firmwareHold.upper(charging: false, ceiling: 80, percentage: 50) == 50, "Manual pause captures current capacity")
        check(firmwareHold.upper(charging: false, ceiling: 80, percentage: 49) == 50, "Manual hold remains stable")
        firmwareHold.adapterDisconnected()
        check(firmwareHold.upper(charging: false, ceiling: 80, percentage: 45) == 45,
              "Reconnection captures current capacity instead of an obsolete pre-disconnect hold")
        var reached = FirmwareHoldPolicy()
        check(reached.upper(charging: true, ceiling: 60, percentage: 59) == 60, "Below limit still charges to configured limit")
        check(reached.upper(charging: false, ceiling: 60, percentage: 60) == 60, "Reaching limit must hold without raising target")
        check(reached.upper(charging: false, ceiling: 60, percentage: 59) == 60, "Hold must not ratchet down with discharge")
        check(reached.upper(charging: false, ceiling: 50, percentage: 60) == 60, "Lowering target must not discharge battery")
        check(reached.lower(rechargeBelow: 40, upper: 60) == 40, "Capture lower threshold with the hold")
        for target in [23, 60, 35, 50, 20] {
            check(reached.upper(charging: false, ceiling: target, percentage: 59) == 60,
                  "Dragging a paused target must not recapture a rounded-down battery level")
            check(reached.lower(rechargeBelow: max(0, target - 10), upper: 60) == 40,
                  "Dragging must not rewrite the lower endpoint either")
        }
        _ = reached.upper(charging: true, ceiling: 80, percentage: 59)
        check(reached.upper(charging: false, ceiling: 80, percentage: 80) == 80,
              "A new charge cycle captures a new upper threshold")
        check(reached.lower(rechargeBelow: 70, upper: 80) == 70,
              "A new charge cycle applies the latest lower threshold")
        var fractionalHold = FirmwareHoldPolicy()
        check(fractionalHold.upper(charging: false, ceiling: 60, percentage: 54.663355) == 55,
              "The observed 54.66% battery must not get a 54% discharge ceiling")
        check(fractionalHold.upper(charging: false, ceiling: 50, percentage: 54.32) == 55,
              "Rounded hold remains stable when changing the target or reading")
        fractionalHold.adapterDisconnected()
        check(fractionalHold.upper(charging: false, ceiling: 100, percentage: 99.99) == 100,
              "A near-full battery rounds safely to the maximum firmware percentage")
        for percentage in [0.0, 0.1, 20.01, 54.66, 59.999, 60.0, 73.5, 99.999, 100.0] {
            var captured = FirmwareHoldPolicy()
            let upper = captured.upper(charging: false, ceiling: 60, percentage: percentage)
            check(Double(upper) >= percentage && upper <= 100,
                  "A freshly captured hold never places the ceiling below fractional capacity")
        }
        var awake = ChargingPowerPolicy()
        awake.managed = true
        awake.charging = false
        awake.chargeCeiling = 60
        awake.rechargeBelow = 50
        awake.stopWhileSleeping = true
        var separated = FirmwarePowerPolicy()
        check(separated.target(policy: awake, percentage: 74.25, externalConnected: true)
                == .interval(lower: 50, upper: 75), "Capture an awake fractional hold")
        var sleepRequest = awake
        sleepRequest.sleeping = true
        check(separated.target(policy: sleepRequest, percentage: 54.66, externalConnected: true)
                == .interval(lower: 50, upper: 55), "Sleep captures an independent safe boundary")
        check(separated.target(policy: sleepRequest, percentage: 54.32, externalConnected: true)
                == .interval(lower: 50, upper: 55), "Dark-wake/watchdog does not lower the sleep boundary")
        check(separated.target(policy: awake, percentage: 54.32, externalConnected: true)
                == .interval(lower: 50, upper: 75), "Wake restores the saved awake interval, not sleep's lower boundary")
        check(separated.target(policy: sleepRequest, percentage: 53.5, externalConnected: true)
                == .interval(lower: 50, upper: 54), "The next sleep session captures fresh capacity")
        _ = separated.target(policy: awake, percentage: 52.5, externalConnected: false)
        check(separated.target(policy: awake, percentage: 52.5, externalConnected: true)
                == .interval(lower: 50, upper: 53), "Unplugging discards obsolete awake and sleep holds")
        var chargingRequest = awake
        chargingRequest.charging = true
        var sleepDuringCharging = FirmwarePowerPolicy()
        check(sleepDuringCharging.target(policy: chargingRequest, percentage: 54.66, externalConnected: true)
                == .interval(lower: 50, upper: 60), "Normal charging retains the configured 60% ceiling")
        var chargingSleep = chargingRequest
        chargingSleep.sleeping = true
        check(sleepDuringCharging.target(policy: chargingSleep, percentage: 54.66, externalConnected: true)
                == .interval(lower: 50, upper: 55), "Sleep while charging uses a fractional safe hold")
        check(sleepDuringCharging.target(policy: chargingRequest, percentage: 54.32, externalConnected: true)
                == .interval(lower: 50, upper: 60), "Fresh awake charge request restores configured limits")
        check(sleepDuringCharging.target(policy: chargingSleep, percentage: 57.2, externalConnected: true)
                == .interval(lower: 50, upper: 58), "Charging wake also resets the previous sleep snapshot")
        chargingRequest.chargeCeiling = 100
        chargingRequest.rechargeBelow = 98
        check(sleepDuringCharging.target(policy: chargingRequest, percentage: 54.66, externalConnected: true)
                == .unlimited, "Only an actual charge-to-full request permits unlimited charging")
        var pausedAtFull = chargingRequest
        pausedAtFull.charging = false
        check(sleepDuringCharging.target(policy: pausedAtFull, percentage: 54.66, externalConnected: true)
                == .interval(lower: 53, upper: 55), "A pause never disables the firmware limit")
        var flow = ChargeHoldVerification()
        check(flow.sample(batteryPower: -20) == .pending, "Single discharge sample may be transient")
        check(flow.sample(batteryPower: -18) == .pending, "Require sustained discharge")
        check(flow.sample(batteryPower: -19) == .discharging, "AC attached must not hide sustained discharge")
        check(flow.sample(batteryPower: 0.2) == .pending, "Recovery needs stable samples")
        check(flow.sample(batteryPower: -0.3) == .pending, "Small fluctuations are tolerated")
        check(flow.sample(batteryPower: 0) == .held, "Stable near-zero flow verifies hold")
        _ = flow.sample(batteryPower: 15)
        _ = flow.sample(batteryPower: 16)
        check(flow.sample(batteryPower: 14) == .charging, "Continuing to charge is not a successful hold")
        check(flow.sample(batteryPower: .nan) == .pending, "Invalid power readings reset verification")
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
        let holdRegisters = SimulatedFirmware()
        let holdController = FirmwareChargeLimitController(registers: holdRegisters)
        var aboveTargetHold = FirmwareHoldPolicy()
        let heldUpper = aboveTargetHold.upper(charging: false, ceiling: 60, percentage: 90)
        try holdController.set(lower: 50, upper: heldUpper)
        check(holdRegisters.state == FirmwareChargeLimitState(activation: 2, lower: 50, upper: 90),
              "Above-target hold keeps limit active at current capacity, never disables it or writes 60")
        holdRegisters.operations = []
        let repeatedUpper = aboveTargetHold.upper(charging: false, ceiling: 60, percentage: 89)
        try holdController.set(lower: 50, upper: repeatedUpper)
        check(holdRegisters.operations.isEmpty, "Declining capacity must not cause repeated threshold writes")
        let frozenLower = aboveTargetHold.lower(rechargeBelow: 50, upper: repeatedUpper)
        for target in [40, 23, 60] {
            let upper = aboveTargetHold.upper(charging: false, ceiling: target, percentage: 89)
            let lower = aboveTargetHold.lower(rechargeBelow: target - 10, upper: upper)
            try holdController.set(lower: lower, upper: upper)
            check(lower == frozenLower && holdRegisters.operations.isEmpty,
                  "Slider edits must produce zero firmware writes while paused")
        }
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
              "Low-level codec supports the minimum interval; production policy must not use it to force a hold")
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
