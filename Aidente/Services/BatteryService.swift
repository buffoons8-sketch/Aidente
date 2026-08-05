import Foundation
import AidenteShared
import Observation
import os.log
import smc_power

enum XPCError: LocalizedError {
    case helperUnavailable
    case timeout
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .helperUnavailable:
            AidenteL10n.t("充电控制服务不可用", "Charging control service is unavailable")
        case .timeout:
            AidenteL10n.t(
                "充电控制服务连接超时",
                "Charging control service connection timed out"
            )
        case .commandFailed(let message):
            AidenteL10n.t(
                "控制命令失败：\(message)",
                "Control command failed: \(message)"
            )
        }
    }
}

private final class XPCCommandReply: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?

    init(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func finish(_ result: Result<Void, Error>) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()
        continuation.resume(with: result)
    }
}

@MainActor
@Observable
class BatteryService {
    var metrics = BatteryMetrics()
    var adapterMetrics = AdapterMetrics()
    private(set) var controlState = BatteryControlState()
    private(set) var deviceCapabilities = DeviceCapabilities(
        chargingControl: false,
        adapterControl: false,
        hasMagSafe: false,
        magsafeLEDControl: false
    )

    private let xpcManager = SMCReaderConnection(
        serviceName: "com.aidente.app.reader"
    )
    private let ioKitService = IOKitService()

    private var ioKitMonitorTask: Task<Void, Never>?
    private var smcPollTask: Task<Void, Never>?
    private var delayedPollTask: Task<Void, Never>?

    private let logger = Logger(
        subsystem: "com.aidente.app",
        category: "BatteryService"
    )

    init() {
        logger.info("BatteryService initialized")
        xpcManager.connect()
        startIOKitMonitoring()
    }

    func loadCapabilities() async {
        let logger = self.logger
        guard
            let helper = xpcManager.getHelper(errorHandler: { error in
                logger.error(
                    "XPC error loading capabilities: \(error.localizedDescription)")
            })
        else {
            logger.warning("Helper unavailable for capability probe")
            return
        }

        let capabilities: DeviceCapabilities = await withCheckedContinuation { continuation in
            helper.getCapabilities { chargingControl, adapterControl, hasMagSafe, magsafeLEDControl in
                continuation.resume(
                    returning: DeviceCapabilities(
                        chargingControl: chargingControl,
                        adapterControl: adapterControl,
                        hasMagSafe: hasMagSafe,
                        magsafeLEDControl: magsafeLEDControl
                    )
                )
            }
        }

        self.deviceCapabilities = capabilities
        logger.info(
            "Capabilities loaded: charging=\(capabilities.chargingControl), adapter=\(capabilities.adapterControl), magSafe=\(capabilities.hasMagSafe)"
        )
    }

    private func startIOKitMonitoring() {
        logger.info("Starting IOKit monitoring in main app")
        ioKitMonitorTask = Task {
            for await (newBatteryMetrics, newAdapterMetrics) in self.ioKitService.metricsStream() {
                guard !Task.isCancelled else { break }
                self.handleIOKitUpdate(newBatteryMetrics, adapterUpdate: newAdapterMetrics)
            }
        }
    }

    func enableFastPolling() {
        guard smcPollTask == nil else {
            logger.warning("Fast polling already enabled")
            return
        }

        logger.info("Enabling fast SMC polling")

        smcPollTask = Task {
            await self.pollSMCOnce()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await self.pollSMCOnce()
            }
        }
    }

    func scheduleSinglePoll(delay: Duration = .seconds(3)) {
        delayedPollTask?.cancel()
        delayedPollTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self.pollSMCOnce()
        }
    }

    func disableFastPolling() {
        guard smcPollTask != nil else {
            logger.warning("Fast polling not enabled")
            return
        }

        logger.info("Disabling fast SMC polling")
        smcPollTask?.cancel()
        smcPollTask = nil
    }

    private func fetchSMCBatteryData() async -> SMCBatteryReading? {
        let logger = self.logger
        guard
            let helper = xpcManager.getHelper(errorHandler: { error in
                logger.error(
                    "XPC error during SMC battery poll: \(error.localizedDescription)"
                )
            })
        else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            helper.readBatteryMetrics { success, batteryVoltage, batteryCurrent, batteryPower in
                guard success else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(
                    returning: SMCBatteryReading(
                        batteryVoltage: batteryVoltage,
                        batteryCurrent: batteryCurrent,
                        batteryPower: batteryPower
                    )
                )
            }
        }
    }

    private func fetchSMCAdapterData() async -> SMCAdapterReading? {
        let logger = self.logger
        guard
            let helper = xpcManager.getHelper(errorHandler: { error in
                logger.error(
                    "XPC error during SMC adapter poll: \(error.localizedDescription)"
                )
            })
        else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            helper.readAdapterMetrics { success, adapterVoltage, adapterCurrent, adapterPower in
                guard success else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(
                    returning: SMCAdapterReading(
                        adapterVoltage: adapterVoltage,
                        adapterCurrent: adapterCurrent,
                        adapterPower: adapterPower
                    )
                )
            }
        }
    }

    private func pollSMCOnce() async {
        async let batteryData = fetchSMCBatteryData()
        async let adapterData = fetchSMCAdapterData()

        guard let batteryReading = await batteryData, let adapterReading = await adapterData else {
            logger.error("SMC poll failed; keeping last known metrics")
            return
        }

        var updatedBattery = metrics
        updatedBattery.batteryVoltage = batteryReading.batteryVoltage
        updatedBattery.batteryCurrent = batteryReading.batteryCurrent
        updatedBattery.batteryPower = batteryReading.batteryPower

        var updatedAdapter = adapterMetrics
        updatedAdapter.adapterVoltage = adapterReading.adapterVoltage
        updatedAdapter.adapterCurrent = adapterReading.adapterCurrent
        updatedAdapter.adapterPower = adapterReading.adapterPower

        // SMC reports faster than IOKit can update, so refine isCharging
        // using the actual power flow direction.
        if updatedAdapter.adapterConnected {
            updatedBattery.isCharging = batteryReading.batteryPower > 0
        }

        if updatedBattery != metrics {
            metrics = updatedBattery
        }
        if updatedAdapter != adapterMetrics {
            adapterMetrics = updatedAdapter
        }
        updateControlState(from: updatedBattery, adapter: updatedAdapter)
    }

    private func handleIOKitUpdate(_ newBatteryMetrics: BatteryMetrics, adapterUpdate: AdapterMetrics) {
        logger.debug("Received IOKit update")

        var updatedBattery = newBatteryMetrics
        updatedBattery.batteryVoltage = metrics.batteryVoltage
        updatedBattery.batteryCurrent = metrics.batteryCurrent
        updatedBattery.batteryPower = metrics.batteryPower

        if updatedBattery != metrics {
            metrics = updatedBattery
        }

        var updatedAdapter = adapterUpdate
        updatedAdapter.adapterVoltage = adapterMetrics.adapterVoltage
        updatedAdapter.adapterCurrent = adapterMetrics.adapterCurrent
        updatedAdapter.adapterPower = adapterMetrics.adapterPower

        if updatedAdapter != adapterMetrics {
            adapterMetrics = updatedAdapter
        }

        updateControlState(from: updatedBattery, adapter: updatedAdapter)
    }

    private func updateControlState(from metrics: BatteryMetrics, adapter: AdapterMetrics) {
        let newState = BatteryControlState(
            batteryPercentage: metrics.batteryPercentage,
            hardwareBatteryPercentage: metrics.hardwareBatteryPercentage,
            adapterConnected: adapter.adapterConnected,
            batteryTemperature: metrics.batteryTemperature
        )
        if newState != controlState {
            controlState = newState
        }
    }

    func manageBatteryCharging(enabled: Bool) async throws {
        try await performControlCommand { helper, reply in
            helper.manageBatteryCharging(enabled: enabled, reply: reply)
        }
    }

    func manageExternalPower(enabled: Bool) async throws {
        try await performControlCommand { helper, reply in
            helper.manageExternalPower(enabled: enabled, reply: reply)
        }
    }

    func manageMagsafeLED(target: MagSafeLEDState) async throws {
        try await performControlCommand { helper, reply in
            helper.manageMagsafeLED(target: target.rawValue, reply: reply)
        }
    }

    func checkChargingHelper() async throws {
        try await performControlCommand { helper, reply in
            helper.ping(reply: reply)
        }
    }

    private func performControlCommand(
        _ command: @escaping @Sendable (
            AidenteControlProtocol,
            @escaping @Sendable (Bool, String?) -> Void
        ) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let commandReply = XPCCommandReply(continuation)
            guard
                let helper = ChargingHelperManager.shared.getHelper(errorHandler: { error in
                    commandReply.finish(.failure(error))
                })
            else {
                commandReply.finish(.failure(XPCError.helperUnavailable))
                return
            }

            // Generous enough to cover launchd cold-starting the helper daemon.
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 10) {
                commandReply.finish(.failure(XPCError.timeout))
            }

            command(helper) { success, errorMessage in
                if success {
                    commandReply.finish(.success(()))
                } else {
                    commandReply.finish(
                        .failure(
                            XPCError.commandFailed(
                                errorMessage ?? AidenteL10n.t("未知错误", "Unknown error")
                            )
                        )
                    )
                }
            }
        }
    }

    func setResetOnDisconnect(_ enabled: Bool) throws {
        let helper = try getChargingHelper()
        helper.setResetOnDisconnect(enabled)
    }

    private func getChargingHelper() throws -> AidenteControlProtocol {
        let logger = self.logger
        guard
            let helper = ChargingHelperManager.shared.getHelper(errorHandler: { error in
                logger.error("Charging helper XPC error: \(error.localizedDescription)")
            })
        else {
            throw XPCError.helperUnavailable
        }
        return helper
    }

    func stop() {
        logger.info("BatteryService stopping")
        ioKitMonitorTask?.cancel()
        ioKitMonitorTask = nil
        smcPollTask?.cancel()
        smcPollTask = nil
        delayedPollTask?.cancel()
        delayedPollTask = nil
        xpcManager.disconnect()
    }
}
