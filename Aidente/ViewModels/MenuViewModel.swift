import AppKit
import Defaults
import Foundation
import Observation

@MainActor
@Observable
class MenuViewModel {
    private let batteryService: BatteryService
    private let chargeManager: ChargeManager
    private let bootTimestamp: Date?

    var batteryPercentageText: String = "0%"
    var powerSourceText: String = AidenteL10n.t("电池")
    var timeRemainingText: String = AidenteL10n.t("正在估算…")
    var uptimeText: String = AidenteL10n.t("0 分钟", "0 min")
    var batteryModeText: String = AidenteL10n.t("未知")
    var batteryTemperatureText: String = "0°C"
    var externalInputText: String = "0V @ 0A"
    var internalInputText: String = "0V @ 0A"
    var cycleCountText: String = "0"
    var batteryHealthText: String = "100%"

    var displayPercentage: Int = 0
    var chargingMode: ChargingMode = .discharging
    var batteryPower: Double = 0
    var adapterPower: Double = 0
    var systemPower: Double = 0
    var powerSource: PowerSource = .battery
    var isCharging: Bool = false
    var isLowPowerModeEnabled: Bool = false
    var topEnergyApps: [AppEnergyUsageSnapshot] = []
    var hasEnergyUsageSample: Bool = false

    var chargeLimitOverrideActive: Bool { chargeManager.chargeLimitOverrideActive }
    var forceDischargeActive: Bool { chargeManager.forceDischargeActive }
    var manualPauseActive: Bool { chargeManager.manualPauseActive }
    var calibrationActive: Bool { chargeManager.calibrationStage != .idle }
    var operationStatusText: String { chargeManager.operationStatusTitle }
    var hasControlError: Bool { chargeManager.controlError != nil }
    var manageChargingEnabled: Bool { Defaults[.manageCharging] }
    var adapterConnected: Bool = false

    private var metricsObservation: Task<Void, Never>?
    private var settingsObservation: Task<Void, Never>?
    private var uptimeTask: Task<Void, Never>?
    private var powerModeObservation: Task<Void, Never>?
    private var energyUsageTask: Task<Void, Never>?

    init(batteryService: BatteryService, chargeManager: ChargeManager) {
        self.batteryService = batteryService
        self.chargeManager = chargeManager
        self.bootTimestamp = SystemService.bootTimestamp()
        startObservingMetrics()
        startObservingSettings()
        startObservingPowerMode()
    }

    private func startObservingMetrics() {
        metricsObservation = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.updateFormattedValues(
                    from: self.batteryService.metrics,
                    adapter: self.batteryService.adapterMetrics
                )
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.batteryService.metrics
                        _ = self.batteryService.adapterMetrics
                    } onChange: {
                        Task { @MainActor in
                            continuation.resume()
                        }
                    }
                }
            }
        }
    }

    private func startObservingSettings() {
        settingsObservation = Task { [weak self] in
            for await _ in Defaults.updates(
                [.useHardwarePercentage, .appLanguage],
                initial: false
            ) {
                guard let self else { return }
                self.updateFormattedValues(
                    from: self.batteryService.metrics,
                    adapter: self.batteryService.adapterMetrics
                )
            }
        }
    }

    private func startObservingPowerMode() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

        powerModeObservation = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: .NSProcessInfoPowerStateDidChange,
                object: ProcessInfo.processInfo
            )
            for await _ in notifications {
                self?.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
    }

    func toggleChargeLimitOverride() {
        chargeManager.toggleChargeLimitOverride()
    }

    func toggleForceDischarge() {
        chargeManager.toggleForceDischarge()
    }

    func toggleManualPause() {
        if manualPauseActive {
            chargeManager.resumeNormalManagement()
        } else {
            chargeManager.pauseCharging()
        }
    }

    func toggleCalibration() {
        if calibrationActive {
            chargeManager.cancelCalibration()
        } else {
            chargeManager.startCalibration()
        }
    }

    func refresh() {
        updateUptimeText()
        batteryService.scheduleSinglePoll(delay: .zero)
        refreshEnergyUsage()
    }

    private func updateFormattedValues(from metrics: BatteryMetrics, adapter: AdapterMetrics) {
        let useHardware = Defaults[.useHardwarePercentage]
        let percentage =
            useHardware
            ? metrics.hardwareBatteryPercentage : metrics.batteryPercentage
        displayPercentage = percentage
        batteryPercentageText = "\(percentage)%"

        let derivedPowerSource = derivePowerSource(battery: metrics, adapter: adapter)

        switch derivedPowerSource {
        case .battery:
            powerSourceText = AidenteL10n.t("电池")
        case .acAdapter:
            powerSourceText = AidenteL10n.t("电源适配器")
        case .both:
            powerSourceText = AidenteL10n.t("电池与电源适配器")
        }

        let formatted = formatTimeRemaining(minutes: metrics.timeRemaining)
        if !formatted.isEmpty {
            timeRemainingText = formatted
        } else if derivedPowerSource == .acAdapter && !metrics.isCharging {
            timeRemainingText = AidenteL10n.t("未在充电")
        } else {
            timeRemainingText = AidenteL10n.t("正在估算…")
        }

        updateUptimeText()

        if derivedPowerSource == .acAdapter {
            if metrics.isCharging {
                chargingMode = .charging
                batteryModeText = AidenteL10n.t("正在充电")
            } else {
                chargingMode = .pluggedIn
                batteryModeText = AidenteL10n.t("已接通电源（未充电）")
            }
        } else {
            chargingMode = .discharging
            batteryModeText = AidenteL10n.t("正在使用电池")
        }

        batteryTemperatureText =
            "\(metrics.batteryTemperature.formatted(.number.precision(.fractionLength(1))))°C"

        let voltageFormat = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2))
        let currentFormat = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2))

        externalInputText =
            "\(adapter.adapterVoltage.formatted(voltageFormat))V @ \(adapter.adapterCurrent.formatted(currentFormat))A"

        internalInputText =
            "\(metrics.batteryVoltage.formatted(voltageFormat))V @ \(metrics.batteryCurrent.formatted(currentFormat))A"

        batteryPower = metrics.batteryPower
        adapterPower = adapter.adapterPower
        systemPower = adapter.adapterPower - metrics.batteryPower
        powerSource = derivedPowerSource
        isCharging = metrics.isCharging
        adapterConnected = adapter.adapterConnected

        cycleCountText = "\(metrics.cycleCount)"
        batteryHealthText = "\(metrics.batteryHealth)%"
    }

    private func derivePowerSource(battery: BatteryMetrics, adapter: AdapterMetrics) -> PowerSource {
        guard adapter.adapterConnected else { return .battery }

        if adapter.adapterPower == 0 {
            return .battery
        } else if battery.batteryPower >= 0 {
            return .acAdapter
        } else {
            return .both
        }
    }

    private func updateUptimeText() {
        guard let bootTimestamp else {
            uptimeText = AidenteL10n.t("未知")
            return
        }

        let totalMinutes = max(0, Int(Date().timeIntervalSince(bootTimestamp) / 60))
        let days = totalMinutes / 1_440
        let hours = (totalMinutes % 1_440) / 60
        let minutes = totalMinutes % 60
        var components: [String] = []
        if days > 0 {
            components.append(AidenteL10n.t("\(days) 天", "\(days)d"))
        }
        if hours > 0 {
            components.append(AidenteL10n.t("\(hours) 小时", "\(hours)h"))
        }
        if minutes > 0 || components.isEmpty {
            components.append(AidenteL10n.t("\(minutes) 分钟", "\(minutes)m"))
        }
        uptimeText = components.prefix(2).joined(separator: " ")
    }

    private func startUptimeTimer() {
        guard uptimeTask == nil else { return }

        uptimeTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                self?.updateUptimeText()
            }
        }
    }

    private func stopUptimeTimer() {
        uptimeTask?.cancel()
        uptimeTask = nil
    }

    private func startEnergyUsageTimer() {
        guard energyUsageTask == nil else { return }

        energyUsageTask = Task { [weak self] in
            while !Task.isCancelled {
                let snapshots = await Task.detached(priority: .utility) {
                    AppEnergyUsageService.readTopApps()
                }.value

                guard !Task.isCancelled else { return }
                self?.topEnergyApps = snapshots
                self?.hasEnergyUsageSample = true

                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    private func stopEnergyUsageTimer() {
        energyUsageTask?.cancel()
        energyUsageTask = nil
    }

    private func refreshEnergyUsage() {
        Task { [weak self] in
            let snapshots = await Task.detached(priority: .utility) {
                AppEnergyUsageService.readTopApps()
            }.value
            guard !Task.isCancelled else { return }
            self?.topEnergyApps = snapshots
            self?.hasEnergyUsageSample = true
        }
    }

    func menuWillOpen() {
        updateUptimeText()
        startUptimeTimer()
        startEnergyUsageTimer()
        batteryService.enableFastPolling()
    }

    func menuDidClose() {
        stopUptimeTimer()
        stopEnergyUsageTimer()
        batteryService.disableFastPolling()
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func formatTimeRemaining(minutes: Int) -> String {
        if minutes < 0 {
            return ""
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 {
            return AidenteL10n.t("\(mins) 分钟", "\(mins) min")
        }
        return AidenteL10n.t(
            "\(hours) 小时 \(mins) 分钟",
            "\(hours) hr \(mins) min"
        )
    }

    deinit {
        MainActor.assumeIsolated {
            metricsObservation?.cancel()
            settingsObservation?.cancel()
            uptimeTask?.cancel()
            powerModeObservation?.cancel()
            energyUsageTask?.cancel()
        }
    }
}
