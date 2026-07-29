import Foundation

@objc public protocol AidenteReaderProtocol {
    func readBatteryMetrics(
        reply: @escaping @Sendable (Double, Double, Double) -> Void
    )
    func readAdapterMetrics(
        reply: @escaping @Sendable (Double, Double, Double) -> Void
    )
    func getCapabilities(
        reply: @escaping @Sendable (Bool, Bool, Bool, Bool) -> Void
    )
}

@objc public protocol AidenteControlProtocol {
    func ping(
        reply: @escaping @Sendable (Bool, String?) -> Void
    )
    func manageBatteryCharging(
        enabled: Bool,
        reply: @escaping @Sendable (Bool, String?) -> Void
    )
    func manageExternalPower(
        enabled: Bool,
        reply: @escaping @Sendable (Bool, String?) -> Void
    )
    func manageMagsafeLED(
        target: UInt8,
        reply: @escaping @Sendable (Bool, String?) -> Void
    )
    func setResetOnDisconnect(_ enabled: Bool)
    func resetToDefaults()
}
