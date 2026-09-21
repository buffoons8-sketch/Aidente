import Foundation

/// Firmware limits may discharge down to the ceiling. Never emulate a pause
/// with a 1% limit. Capture once, so polling cannot chase a falling battery.
public struct FirmwareHoldPolicy {
    private var heldCeiling: Int?
    private var configuredCeiling: Int?
    public init() {}
    public mutating func upper(charging: Bool, ceiling: Int, percentage: Int) -> Int {
        if charging { heldCeiling = nil; configuredCeiling = ceiling; return ceiling }
        if heldCeiling == nil || configuredCeiling != ceiling {
            heldCeiling = max(1, min(ceiling, percentage))
            configuredCeiling = ceiling
        }
        return heldCeiling!
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
