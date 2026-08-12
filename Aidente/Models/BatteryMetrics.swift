import Foundation

struct BatteryMetrics: Codable, Equatable, Sendable {
    var batteryPercentage: Int = 0
    var hardwareBatteryPercentage: Int = 0
    var isCharging: Bool = false
    var timeRemaining: Int = 0

    var batteryVoltage: Double = 0
    var batteryCurrent: Double = 0
    var batteryPower: Double = 0
    var batteryTemperature: Double = 0

    var batteryHealth: Double = 0
    var cycleCount: Int = 0

    var currentCapacityMilliampHours: Int = 0
    var estimatedFullChargeCapacityMilliampHours: Int = 0
    var designCapacityMilliampHours: Int = 0

    var externalConnected: Bool = false
}

struct AdapterMetrics: Equatable, Sendable {
    var adapterConnected: Bool = false
    var adapterVoltage: Double = 0
    var adapterCurrent: Double = 0
    var adapterPower: Double = 0
    var maximumSupportedPower: Double = 0
    var protocolName: String = ""
    var powerProfiles: [AdapterPowerProfile] = []
}

struct AdapterPowerProfile: Equatable, Identifiable, Sendable {
    let voltage: Double
    let current: Double
    let power: Double
    let isActive: Bool

    var id: String {
        "\(voltage)-\(current)-\(power)"
    }
}

struct BatteryControlState: Equatable, Sendable {
    var batteryPercentage: Int = 0
    var hardwareBatteryPercentage: Int = 0
    var adapterConnected: Bool = false
    var batteryTemperature: Double = 0
}
