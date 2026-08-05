import Defaults
import Foundation
import IOKit.pwr_mgt
import Observation
import UserNotifications
import os.log
import smc_power

enum CalibrationStage: String {
    case idle
    case chargingToFull
    case dischargingToLow
    case rechargingToFull
    case holdingAtFull
    case restoringLimit

    var title: String {
        switch self {
        case .idle: AidenteL10n.t("空闲", "Idle")
        case .chargingToFull: AidenteL10n.t("校准：充电至 100%", "Calibration: Charging to 100%")
        case .dischargingToLow: AidenteL10n.t("校准：正在放电", "Calibration: Discharging")
        case .rechargingToFull: AidenteL10n.t("校准：重新充电至 100%", "Calibration: Recharging to 100%")
        case .holdingAtFull: AidenteL10n.t("校准：满电保持", "Calibration: Holding at Full")
        case .restoringLimit: AidenteL10n.t("校准：恢复充电上限", "Calibration: Restoring Charge Limit")
        }
    }
}

enum ChargeOperationStatus: Equatable {
    case monitoring
    case charging
    case paused
    case sailing
    case discharging(target: Int)
    case topUp
    case heatProtection
    case sleeping
    case calibration(CalibrationStage)

    var title: String {
        switch self {
        case .monitoring: AidenteL10n.t("只读监测")
        case .charging: AidenteL10n.t("正在充电")
        case .paused: AidenteL10n.t("充电已暂停")
        case .sailing: AidenteL10n.t("巡航中")
        case .discharging(let target):
            AidenteL10n.t("正在放电至 \(target)%", "Discharging to \(target)%")
        case .topUp: AidenteL10n.t("临时充至 100%")
        case .heatProtection: AidenteL10n.t("高温保护")
        case .sleeping: AidenteL10n.t("睡眠保护")
        case .calibration(let stage): stage.title
        }
    }
}

@MainActor
@Observable
class ChargeManager {
    private let batteryService: BatteryService

    private var metricsObservation: Task<Void, Never>?
    private var settingsObservation: Task<Void, Never>?
    private var scheduleObservation: Task<Void, Never>?

    private var lastAdapterConnected: Bool?
    private var lastManageChargingEnabled: Bool?
    private var hasReachedChargeLimit = false
    private var lastNotifiedChargingState: Bool?
    private var heatProtectionPaused = false
    private var heatProtectionReviewDate = Date.distantPast
    private var isSystemSleeping = false
    private var chargingCommandGeneration = 0

    private(set) var topUpActive = Defaults[.topUpActive]
    private(set) var forceDischargeActive = false
    private(set) var manualPauseActive = Defaults[.manualPauseActive]
    private(set) var calibrationStage =
        CalibrationStage(rawValue: Defaults[.calibrationStage]) ?? .idle
    private(set) var operationStatus: ChargeOperationStatus = .monitoring
    private var serviceControlError: String?
    private var chargingControlError: String?
    private var adapterControlError: String?

    var chargeLimitOverrideActive: Bool { topUpActive }
    var controlError: String? {
        guard let rawError =
            serviceControlError ?? chargingControlError ?? adapterControlError
        else {
            return nil
        }
        return AidenteL10n.controlError(rawError)
    }
    var operationStatusTitle: String {
        controlError == nil ? operationStatus.title : AidenteL10n.t("充电控制未生效")
    }
    private var sleepAssertionID: IOPMAssertionID = IOPMAssertionID(kIOPMNullAssertionID)

    private let logger = Logger(
        subsystem: "com.aidente.app",
        category: "ChargeManager"
    )

    init(batteryService: BatteryService) {
        self.batteryService = batteryService
        startObservingMetrics()
        startObservingSettings()
        startScheduleMonitoring()
    }

    private func startObservingMetrics() {
        metricsObservation = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.evaluate(controlState: self.batteryService.controlState)
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.batteryService.controlState
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
                [
                    .manageCharging, .sailingMode, .automaticDischarge,
                    .disableSleepUntilChargeLimit,
                    .enableHeatProtectionMode, .manageMagSafeLED, .useHardwarePercentage,
                    .chargeLimit, .sailingModeLimit, .heatProtectionLimit,
                    .heatProtectionMagSafeLEDState, .stopChargingWhenAppClosed,
                    .stopChargingWhileSleeping, .calibrationLowLevel,
                    .calibrationHoldMinutes,
                ],
                initial: false
            ) {
                guard let self else { return }
                self.configureHelperDisconnectPolicy()
                self.evaluate(controlState: self.batteryService.controlState)
            }
        }
    }

    private func startScheduleMonitoring() {
        scheduleObservation = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                for task in ScheduleStore.shared.takeDueTasks() {
                    self.executeScheduledTask(task)
                }
                self.evaluate(controlState: self.batteryService.controlState)
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    private func executeScheduledTask(_ task: ScheduleTask) {
        logger.info("Executing scheduled task: \(task.summary)")
        switch task.action {
        case .setChargeLimit:
            Defaults[.chargeLimit] = min(max(task.value, 20), 100)
            resumeNormalManagement()
        case .startCalibration:
            startCalibration()
        case .topUp:
            startTopUp()
        case .pauseCharging:
            pauseCharging()
        case .dischargeTo:
            startDischarge(to: task.value)
        }
    }

    private func evaluate(controlState: BatteryControlState) {
        guard !AidenteRuntime.isUIPreview else {
            operationStatus = .monitoring
            return
        }

        var stateWasCleared = false

        if controlState.adapterConnected != lastAdapterConnected {
            logger.info("Adapter connection changed: \(controlState.adapterConnected)")
            lastAdapterConnected = controlState.adapterConnected
            clearCachedState()
            stateWasCleared = true
        }

        guard Defaults[.manageCharging], controlState.adapterConnected else {
            if topUpActive, !controlState.adapterConnected {
                setTopUpActive(false)
            }
            if forceDischargeActive, !controlState.adapterConnected {
                forceDischargeActive = false
            }
            operationStatus = .monitoring
            clearControlErrors()
            resetToDefaults()
            return
        }

        guard !ChargingHelperManager.shared.isRunningFromDiskImage else {
            operationStatus = .monitoring
            serviceControlError =
                ChargingHelperManagerError.runningFromDiskImage.localizedDescription
            return
        }

        if lastManageChargingEnabled != true {
            lastManageChargingEnabled = true
            clearCachedState()
            stateWasCleared = true
        }

        let batteryPercentage =
            Defaults[.useHardwarePercentage]
            ? controlState.hardwareBatteryPercentage : controlState.batteryPercentage
        advanceCalibrationIfNeeded(batteryPercentage: batteryPercentage)

        var desiredCharging = false
        var desiredAdapter = true
        var desiredLED: MagSafeLEDState?
        var chargingStateReason: String?
        let chargeLimit = Defaults[.chargeLimit]

        if isSystemSleeping && Defaults[.stopChargingWhileSleeping] {
            desiredCharging = false
            desiredAdapter = true
            desiredLED = Defaults[.manageMagSafeLED] ? .green : nil
            chargingStateReason = AidenteL10n.t(
                "Mac 睡眠时已暂停充电",
                "Charging paused while the Mac is sleeping"
            )
            operationStatus = .sleeping
        } else if manualPauseActive {
            desiredCharging = false
            desiredAdapter = true
            desiredLED = Defaults[.manageMagSafeLED] ? .green : nil
            chargingStateReason = AidenteL10n.t(
                "已手动暂停充电",
                "Charging paused manually"
            )
            operationStatus = .paused
        } else if calibrationStage != .idle {
            applyCalibrationPolicy(
                batteryPercentage: batteryPercentage,
                desiredCharging: &desiredCharging,
                desiredAdapter: &desiredAdapter,
                desiredLED: &desiredLED,
                reason: &chargingStateReason
            )
            operationStatus = .calibration(calibrationStage)
        } else if topUpActive {
            desiredCharging = true
            desiredAdapter = true
            desiredLED = Defaults[.manageMagSafeLED] ? .orange : nil
            chargingStateReason = AidenteL10n.t(
                "正在临时将电池充至 100%",
                "Temporarily charging the battery to 100%"
            )
            operationStatus = .topUp
        } else if forceDischargeActive {
            let target = min(max(Defaults[.forcedDischargeTarget], 20), 100)
            desiredCharging = false
            if batteryPercentage > target {
                desiredAdapter = false
                operationStatus = .discharging(target: target)
                chargingStateReason = AidenteL10n.t(
                    "正在放电至 \(target)%",
                    "Discharging to \(target)%"
                )
            } else {
                forceDischargeActive = false
                manualPauseActive = true
                Defaults[.manualPauseActive] = true
                desiredAdapter = true
                operationStatus = .paused
                chargingStateReason = AidenteL10n.t(
                    "已达到 \(target)% 的放电目标",
                    "The \(target)% discharge target has been reached"
                )
            }
        } else {
            if stateWasCleared && Defaults[.sailingMode]
                && batteryPercentage >= chargeLimit - Defaults[.sailingModeLimit] {
                hasReachedChargeLimit = true
            }

            if batteryPercentage > chargeLimit {
                hasReachedChargeLimit = true
                desiredCharging = false
                desiredAdapter = !Defaults[.automaticDischarge]
                desiredLED = Defaults[.manageMagSafeLED] ? .green : nil
                chargingStateReason = AidenteL10n.t(
                    "电量高于 \(chargeLimit)% 的充电上限",
                    "Battery level is above the \(chargeLimit)% charge limit"
                )
                operationStatus = desiredAdapter ? .paused : .discharging(target: chargeLimit)
            } else if batteryPercentage == chargeLimit {
                hasReachedChargeLimit = true
                desiredCharging = false
                desiredAdapter = true
                desiredLED = Defaults[.manageMagSafeLED] ? .green : nil
                chargingStateReason = AidenteL10n.t(
                    "电池已达到 \(chargeLimit)% 的充电上限",
                    "Battery has reached the \(chargeLimit)% charge limit"
                )
                operationStatus = .paused
            } else if Defaults[.sailingMode] {
                let sailingThreshold = chargeLimit - Defaults[.sailingModeLimit]
                let inSailingRange = batteryPercentage >= sailingThreshold

                if inSailingRange && hasReachedChargeLimit {
                    desiredCharging = false
                    desiredAdapter = true
                    desiredLED = Defaults[.manageMagSafeLED] ? .green : nil
                    chargingStateReason = AidenteL10n.t(
                        "正在 \(sailingThreshold)%–\(chargeLimit)% 之间巡航",
                        "Sailing between \(sailingThreshold)% and \(chargeLimit)%"
                    )
                    operationStatus = .sailing
                } else {
                    hasReachedChargeLimit = false
                    desiredCharging = true
                    desiredAdapter = true
                    desiredLED = Defaults[.manageMagSafeLED] ? .orange : nil
                    chargingStateReason = AidenteL10n.t(
                        "正在充电至 \(chargeLimit)%",
                        "Charging to \(chargeLimit)%"
                    )
                    operationStatus = .charging
                }
            } else {
                desiredCharging = true
                desiredAdapter = true
                desiredLED = Defaults[.manageMagSafeLED] ? .orange : nil
                chargingStateReason = AidenteL10n.t(
                    "电量低于上限，正在充电至 \(chargeLimit)%",
                    "Battery is below the limit and charging to \(chargeLimit)%"
                )
                operationStatus = .charging
            }
        }

        if calibrationStage == .idle {
            applyHeatProtectionIfNeeded(
                temperature: controlState.batteryTemperature,
                desiredCharging: &desiredCharging,
                desiredLED: &desiredLED,
                reason: &chargingStateReason
            )
        } else {
            heatProtectionPaused = false
        }

        let capabilities = batteryService.deviceCapabilities

        if capabilities.chargingControl {
            setCharging(enabled: desiredCharging, reason: chargingStateReason)
        }
        if capabilities.adapterControl {
            setAdapter(enabled: desiredAdapter)
        }
        if let desiredLED, capabilities.hasMagSafe, capabilities.magsafeLEDControl {
            setLED(state: desiredLED)
        }

        let shouldPreventSleep = Defaults[.disableSleepUntilChargeLimit]
            && desiredCharging == true
        updateSleepAssertion(shouldPreventSleep: shouldPreventSleep)
    }

    private func advanceCalibrationIfNeeded(batteryPercentage: Int) {
        if topUpActive && batteryPercentage >= 100 {
            setTopUpActive(false)
            sendWorkflowNotification(
                title: AidenteL10n.t("临时补电完成", "Top-Up Complete"),
                body: AidenteL10n.t(
                    "电池已达到 100%，现已恢复原来的充电上限。",
                    "The battery reached 100% and the original charge limit has been restored."
                )
            )
        }

        switch calibrationStage {
        case .idle:
            return
        case .chargingToFull where batteryPercentage >= 100:
            setCalibrationStage(.dischargingToLow)
        case .dischargingToLow where batteryPercentage <= Defaults[.calibrationLowLevel]:
            setCalibrationStage(.rechargingToFull)
        case .rechargingToFull where batteryPercentage >= 100:
            Defaults[.calibrationHoldUntil] = Date()
                .addingTimeInterval(Double(Defaults[.calibrationHoldMinutes]) * 60)
                .timeIntervalSince1970
            setCalibrationStage(.holdingAtFull)
        case .holdingAtFull
            where Date().timeIntervalSince1970 >= Defaults[.calibrationHoldUntil]:
            setCalibrationStage(.restoringLimit)
        case .restoringLimit
            where batteryPercentage <= Defaults[.calibrationOriginalLimit]:
            setCalibrationStage(.idle)
            Defaults[.calibrationHoldUntil] = 0
            sendWorkflowNotification(
                title: AidenteL10n.t("电池校准完成", "Battery Calibration Complete"),
                body: AidenteL10n.t(
                    "电池已恢复至 \(Defaults[.calibrationOriginalLimit])% 的原充电上限。",
                    "The original \(Defaults[.calibrationOriginalLimit])% charge limit has been restored."
                )
            )
        default:
            return
        }
    }

    private func applyCalibrationPolicy(
        batteryPercentage: Int,
        desiredCharging: inout Bool,
        desiredAdapter: inout Bool,
        desiredLED: inout MagSafeLEDState?,
        reason: inout String?
    ) {
        switch calibrationStage {
        case .idle:
            return
        case .chargingToFull, .rechargingToFull:
            desiredCharging = true
            desiredAdapter = true
            desiredLED = Defaults[.manageMagSafeLED] ? .orange : nil
            reason = calibrationStage.title
        case .dischargingToLow:
            desiredCharging = false
            desiredAdapter = false
            desiredLED = Defaults[.manageMagSafeLED] ? .blinkOrangeSlow : nil
            reason = AidenteL10n.t(
                "\(calibrationStage.title)，目标 \(Defaults[.calibrationLowLevel])%",
                "\(calibrationStage.title), target \(Defaults[.calibrationLowLevel])%"
            )
        case .holdingAtFull:
            desiredCharging = false
            desiredAdapter = true
            desiredLED = Defaults[.manageMagSafeLED] ? .green : nil
            reason = calibrationStage.title
        case .restoringLimit:
            desiredCharging = false
            desiredAdapter = batteryPercentage <= Defaults[.calibrationOriginalLimit]
            desiredLED = Defaults[.manageMagSafeLED] ? .blinkOrangeSlow : nil
            reason = AidenteL10n.t(
                "\(calibrationStage.title)，目标 \(Defaults[.calibrationOriginalLimit])%",
                "\(calibrationStage.title), target \(Defaults[.calibrationOriginalLimit])%"
            )
        }
    }

    private func applyHeatProtectionIfNeeded(
        temperature: Double,
        desiredCharging: inout Bool,
        desiredLED: inout MagSafeLEDState?,
        reason: inout String?
    ) {
        guard Defaults[.enableHeatProtectionMode] else {
            heatProtectionPaused = false
            return
        }

        // Heat protection only overrides an active charge request. Manual pause,
        // discharge, and calibration hold states should keep their own status.
        guard desiredCharging || heatProtectionPaused else { return }

        let threshold = Double(Defaults[.heatProtectionLimit])
        let now = Date()

        if temperature > threshold && !heatProtectionPaused {
            heatProtectionPaused = true
            heatProtectionReviewDate = now.addingTimeInterval(300)
        } else if heatProtectionPaused && now >= heatProtectionReviewDate {
            if temperature > threshold - 1 {
                heatProtectionReviewDate = now.addingTimeInterval(300)
            } else {
                heatProtectionPaused = false
            }
        }

        guard heatProtectionPaused else { return }
        desiredCharging = false
        operationStatus = .heatProtection
        reason =
            AidenteL10n.t(
                "电池温度为 \(temperature.formatted(.number.precision(.fractionLength(1))))°C，已超过 \(Defaults[.heatProtectionLimit])°C 的设定上限",
                "Battery temperature is \(temperature.formatted(.number.precision(.fractionLength(1))))°C, above the \(Defaults[.heatProtectionLimit])°C limit"
            )
        if Defaults[.manageMagSafeLED] {
            desiredLED = Defaults[.heatProtectionMagSafeLEDState]
        }
    }

    private func setCalibrationStage(_ stage: CalibrationStage) {
        calibrationStage = stage
        Defaults[.calibrationStage] = stage.rawValue
        logger.info("Calibration stage changed to \(stage.rawValue)")
    }

    private func setTopUpActive(_ active: Bool) {
        topUpActive = active
        Defaults[.topUpActive] = active
    }

    private func clearCachedState() {
        lastNotifiedChargingState = nil
        hasReachedChargeLimit = false
    }

    private func resetToDefaults() {
        hasReachedChargeLimit = false
        lastManageChargingEnabled = false
        updateSleepAssertion(shouldPreventSleep: false)
        guard ChargingHelperManager.shared.isInstalled else { return }
        let capabilities = batteryService.deviceCapabilities
        if capabilities.chargingControl {
            // Restoring defaults after unplugging is not a charging-state
            // change the user should be notified about.
            setCharging(enabled: true, notify: false)
        }
        if capabilities.adapterControl {
            setAdapter(enabled: true)
        }
        if capabilities.hasMagSafe, capabilities.magsafeLEDControl {
            setLED(state: .reset)
        }
    }

    private func setCharging(enabled: Bool, reason: String? = nil, notify: Bool = true) {
        chargingCommandGeneration += 1
        let commandGeneration = chargingCommandGeneration
        logger.info("Setting charging: \(enabled)")
        Task {
            do {
                try await batteryService.manageBatteryCharging(enabled: enabled)
                guard commandGeneration == chargingCommandGeneration else { return }
                serviceControlError = nil
                chargingControlError = nil
                batteryService.scheduleSinglePoll()
                if notify {
                    sendChargingStateNotification(charging: enabled, reason: reason)
                }
                if !enabled {
                    try? await Task.sleep(for: .seconds(6))
                    guard commandGeneration == chargingCommandGeneration else { return }
                    if batteryService.adapterMetrics.adapterConnected
                        && batteryService.metrics.isCharging
                    {
                        chargingControlError =
                            AidenteL10n.t(
                                "SMC 已接受暂停设置，但系统仍报告电池正在充电。请点“修复控制服务”后重试。",
                                "SMC accepted the pause setting, but the system still reports charging. Click Repair Control Service and try again."
                            )
                        lastNotifiedChargingState = nil
                    }
                }
            } catch {
                guard commandGeneration == chargingCommandGeneration else { return }
                logger.error("Failed to set charging to \(enabled): \(error)")
                chargingControlError =
                    AidenteL10n.t(
                        "充电暂停命令未生效：\(error.localizedDescription)",
                        "The pause charging command did not take effect: \(error.localizedDescription)"
                    )
                lastNotifiedChargingState = nil
            }
        }
    }

    private func setAdapter(enabled: Bool) {
        logger.info("Setting adapter: \(enabled)")
        Task {
            do {
                try await batteryService.manageExternalPower(enabled: enabled)
                serviceControlError = nil
                adapterControlError = nil
                batteryService.scheduleSinglePoll()
            } catch {
                logger.error("Failed to set adapter to \(enabled): \(error)")
                adapterControlError = AidenteL10n.t(
                    "适配器控制未生效：\(error.localizedDescription)",
                    "Adapter control did not take effect: \(error.localizedDescription)"
                )
            }
        }
    }

    private func setLED(state: MagSafeLEDState) {
        logger.info("Setting MagSafe LED: \(String(describing: state))")
        Task {
            do {
                try await batteryService.manageMagsafeLED(target: state)
            } catch {
                logger.error("Failed to set LED to \(String(describing: state)): \(error)")
            }
        }
    }

    private func updateSleepAssertion(shouldPreventSleep: Bool) {
        let assertionActive = sleepAssertionID != IOPMAssertionID(kIOPMNullAssertionID)

        if shouldPreventSleep && !assertionActive {
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertPreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Aidente: charging toward the configured limit" as CFString,
                &sleepAssertionID
            )
            if result == kIOReturnSuccess {
                logger.info("Sleep assertion created")
            } else {
                logger.error("Failed to create sleep assertion: \(result)")
            }
        } else if !shouldPreventSleep && assertionActive {
            IOPMAssertionRelease(sleepAssertionID)
            sleepAssertionID = IOPMAssertionID(kIOPMNullAssertionID)
            logger.info("Sleep assertion released")
        }
    }

    private func sendChargingStateNotification(charging: Bool, reason: String?) {
        guard charging != lastNotifiedChargingState else { return }
        lastNotifiedChargingState = charging

        guard !Defaults[.disableNotifications],
            Defaults[.showChargingStatusChangedNotification]
        else { return }

        let content = UNMutableNotificationContent()
        content.title = AidenteL10n.t(
            charging ? "已恢复充电" : "已暂停充电",
            charging ? "Charging Resumed" : "Charging Paused"
        )
        if let reason {
            content.body = reason
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "chargingStateChanged",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { [logger] error in
            if let error {
                logger.error("Failed to deliver notification: \(error)")
            }
        }
    }

    private func sendWorkflowNotification(title: String, body: String) {
        guard !Defaults[.disableNotifications] else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "workflow-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func startTopUp() {
        cancelCalibration(reevaluate: false)
        forceDischargeActive = false
        manualPauseActive = false
        Defaults[.manualPauseActive] = false
        setTopUpActive(true)
        evaluate(controlState: batteryService.controlState)
    }

    func stopTopUp() {
        setTopUpActive(false)
        evaluate(controlState: batteryService.controlState)
    }

    func startCalibration() {
        Defaults[.calibrationOriginalLimit] = Defaults[.chargeLimit]
        Defaults[.calibrationHoldUntil] = 0
        setTopUpActive(false)
        forceDischargeActive = false
        manualPauseActive = false
        Defaults[.manualPauseActive] = false
        setCalibrationStage(.chargingToFull)
        evaluate(controlState: batteryService.controlState)
    }

    func cancelCalibration(reevaluate: Bool = true) {
        setCalibrationStage(.idle)
        Defaults[.calibrationHoldUntil] = 0
        if reevaluate {
            evaluate(controlState: batteryService.controlState)
        }
    }

    func pauseCharging() {
        setTopUpActive(false)
        forceDischargeActive = false
        cancelCalibration(reevaluate: false)
        manualPauseActive = true
        Defaults[.manualPauseActive] = true
        evaluate(controlState: batteryService.controlState)
    }

    func resumeNormalManagement() {
        setTopUpActive(false)
        forceDischargeActive = false
        cancelCalibration(reevaluate: false)
        manualPauseActive = false
        Defaults[.manualPauseActive] = false
        evaluate(controlState: batteryService.controlState)
    }

    func startDischarge(to target: Int) {
        setTopUpActive(false)
        cancelCalibration(reevaluate: false)
        manualPauseActive = false
        Defaults[.manualPauseActive] = false
        Defaults[.forcedDischargeTarget] = min(max(target, 20), 100)
        forceDischargeActive = true
        evaluate(controlState: batteryService.controlState)
    }

    func toggleChargeLimitOverride() {
        topUpActive ? stopTopUp() : startTopUp()
    }

    func toggleForceDischarge() {
        if forceDischargeActive {
            resumeNormalManagement()
        } else {
            startDischarge(to: Defaults[.chargeLimit])
        }
    }

    func prepareForSleep() async {
        isSystemSleeping = true
        evaluate(controlState: batteryService.controlState)
        guard Defaults[.manageCharging],
            Defaults[.stopChargingWhileSleeping],
            batteryService.controlState.adapterConnected,
            batteryService.deviceCapabilities.chargingControl
        else { return }
        // evaluate() applies the pause in a fire-and-forget task; await a direct
        // command so the write reaches the SMC before sleep is acknowledged.
        try? await batteryService.manageBatteryCharging(enabled: false)
    }

    func resumeFromSleep() {
        isSystemSleeping = false
        evaluate(controlState: batteryService.controlState)
    }

    func configureHelperDisconnectPolicy() {
        guard Defaults[.manageCharging] else { return }
        let resetOnDisconnect = !Defaults[.stopChargingWhenAppClosed]
        Task {
            do {
                try batteryService.setResetOnDisconnect(resetOnDisconnect)
            } catch {
                logger.warning(
                    "Could not update helper disconnect policy: \(error.localizedDescription)"
                )
            }
        }
    }

    func checkControlService() {
        guard Defaults[.manageCharging] else {
            clearControlErrors()
            return
        }
        guard !ChargingHelperManager.shared.isRunningFromDiskImage else {
            serviceControlError =
                ChargingHelperManagerError.runningFromDiskImage.localizedDescription
            return
        }

        Task {
            do {
                try await batteryService.checkChargingHelper()
                clearControlErrors()
                evaluate(controlState: batteryService.controlState)
            } catch {
                serviceControlError = AidenteL10n.t(
                    "后台控制服务未连接：\(error.localizedDescription)",
                    "Background control service is not connected: \(error.localizedDescription)"
                )
            }
        }
    }

    func retryControlAfterRepair() {
        clearControlErrors()
        clearCachedState()
        evaluate(controlState: batteryService.controlState)
        checkControlService()
    }

    private func clearControlErrors() {
        serviceControlError = nil
        chargingControlError = nil
        adapterControlError = nil
    }

    func handleAutomationURL(_ url: URL) {
        let action = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let value = components?.queryItems?
            .first(where: { $0.name == "value" })?
            .value
            .flatMap(Int.init)

        switch action {
        case "set-limit":
            if let value {
                Defaults[.chargeLimit] = min(max(value, 20), 100)
                resumeNormalManagement()
            }
        case "top-up":
            startTopUp()
        case "calibrate":
            startCalibration()
        case "pause":
            pauseCharging()
        case "discharge":
            startDischarge(to: value ?? Defaults[.chargeLimit])
        case "resume":
            resumeNormalManagement()
        default:
            logger.warning("Ignored unknown automation URL: \(url.absoluteString)")
        }
    }

    func stop() {
        metricsObservation?.cancel()
        metricsObservation = nil
        settingsObservation?.cancel()
        settingsObservation = nil
        scheduleObservation?.cancel()
        scheduleObservation = nil
        updateSleepAssertion(shouldPreventSleep: false)
    }
}
