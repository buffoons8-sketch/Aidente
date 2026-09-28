import Foundation

/// Firmware limits may discharge down to the ceiling. Never emulate a pause
/// with a lower configured limit when already above it. Capture the current
/// level once: neither charge up to a higher target nor discharge to a lower one.
/// Polling must not chase a falling battery. Hardware power flow still needs verification.
public struct FirmwareHoldPolicy {
    private var heldCeiling: Int?
    private var heldLower: Int?
    public init() {}
    public mutating func adapterDisconnected() {
        heldCeiling = nil
        heldLower = nil
    }
    public mutating func upper(charging: Bool, ceiling: Int, percentage: Double) -> Int {
        if charging { heldCeiling = nil; heldLower = nil; return ceiling }
        if heldCeiling == nil {
            // Firmware accepts whole percentages. Rounding down a live 54.6%
            // reading to 54% can select battery power even though AC is attached.
            // Capture once at the next whole boundary, never follow later drops.
            heldCeiling = max(1, min(100, Int(percentage.rounded(.up))))
        }
        return heldCeiling!
    }
    // Moving the target while holding must not toggle firmware activation by
    // changing either endpoint. Apply new thresholds on the next charge cycle.
    public mutating func lower(rechargeBelow: Int, upper: Int) -> Int {
        if heldLower == nil { heldLower = min(rechargeBelow, max(0, upper - 2)) }
        return heldLower!
    }
}

/// Resolves the same firmware interval for requests, watchdog and sleep events.
/// A temporary sleep hold must not replace the saved awake interval.
public struct FirmwarePowerPolicy {
    public enum Target: Equatable {
        case interval(lower: Int, upper: Int)
        case unlimited
    }
    private var awakeHold = FirmwareHoldPolicy()
    private var sleepHold = FirmwareHoldPolicy()
    public init() {}

    public mutating func reset() {
        awakeHold.adapterDisconnected()
        sleepHold.adapterDisconnected()
    }

    public mutating func target(policy: ChargingPowerPolicy, percentage: Double,
                                externalConnected: Bool) -> Target {
        if !externalConnected { reset() }
        if !policy.sleeping { sleepHold.adapterDisconnected() }
        let power = policy.effective
        if !power.adapter {
            reset()
            return .interval(lower: policy.rechargeBelow, upper: policy.chargeCeiling)
        }
        if power.charging && percentage < Double(policy.chargeCeiling) {
            if policy.sleeping {
                _ = sleepHold.upper(charging: true, ceiling: policy.chargeCeiling, percentage: percentage)
            } else {
                _ = awakeHold.upper(charging: true, ceiling: policy.chargeCeiling, percentage: percentage)
            }
            return policy.chargeCeiling == 100 ? .unlimited
                : .interval(lower: policy.rechargeBelow, upper: policy.chargeCeiling)
        }
        let upper: Int
        let lower: Int
        if policy.sleeping {
            upper = sleepHold.upper(charging: false, ceiling: policy.chargeCeiling, percentage: percentage)
            lower = sleepHold.lower(rechargeBelow: policy.rechargeBelow, upper: upper)
        } else {
            upper = awakeHold.upper(charging: false, ceiling: policy.chargeCeiling, percentage: percentage)
            lower = awakeHold.lower(rechargeBelow: policy.rechargeBelow, upper: upper)
        }
        return .interval(lower: lower, upper: upper)
    }
}

/// Pure policy shared by the app and regression tests. A normal hold never
/// disconnects the adapter; discharge is a separate, explicitly enabled action.
public struct ChargeLimitPolicy {
    public var reachedLimit = false
    public var automaticDischargeActive = false

    public init() {}

    public mutating func evaluate(
        percentage: Int, limit: Int, sailing: Bool, sailingRange: Int,
        automaticDischarge: Bool, initialize: Bool
    ) -> (charging: Bool, adapter: Bool) {
        let limit = min(100, max(20, limit))
        let lower = max(0, limit - (sailing ? max(2, sailingRange) : 2))
        if initialize {
            reachedLimit = percentage >= (sailing ? lower : limit)
            automaticDischargeActive = automaticDischarge && percentage > limit + 1
        }
        if !automaticDischarge || percentage <= limit {
            automaticDischargeActive = false
        }
        if automaticDischargeActive {
            reachedLimit = true
            return (false, false)
        }
        if percentage >= limit { reachedLimit = true }
        if sailing ? percentage < lower : percentage <= lower { reachedLimit = false }
        return (!reachedLimit, true)
    }
}

/// The daemon retains the awake request while applying a sleep override.
public struct ChargingPowerPolicy {
    public var charging = true
    public var adapter = true
    public var managed = false
    public var stopWhileSleeping = false
    public var sleeping = false
    public var chargeCeiling = 100
    public var rechargeBelow = 98

    public init() {}

    public var effective: (charging: Bool, adapter: Bool) {
        // Always reconnect AC before sleeping, including explicit discharge.
        if sleeping && managed {
            return (stopWhileSleeping ? false : charging && adapter, true)
        }
        return (charging && adapter, adapter)
    }
}

/// Requires consecutive fresh samples; caller owns freshness and AC checks.
/// Ignore small sensor fluctuations, but never call register acceptance a hold.
public struct ChargeHoldVerification {
    public enum Result: Equatable { case pending, held, charging, discharging }
    private var last: Result = .pending
    private var count = 0
    public init() {}
    public mutating func sample(batteryPower: Double) -> Result {
        guard batteryPower.isFinite else { self = Self(); return .pending }
        let state: Result = batteryPower > 1 ? .charging : batteryPower < -1 ? .discharging : .held
        count = state == last ? count + 1 : 1
        last = state
        return count >= 3 ? state : .pending
    }
}
