import Defaults
import SwiftUI
import os.log
import smc_power

struct ChargingSettingsView: View {
    @Default(.appLanguage) private var appLanguage

    @Default(.manageCharging) var manageCharging
    @Default(.chargeLimit) var chargeLimit
    @Default(.sailingMode) var sailingMode
    @Default(.sailingModeLimit) var sailingModeLimit
    @Default(.automaticDischarge) var automaticDischarge
    @Default(.disableSleepUntilChargeLimit) var disableSleepUntilChargeLimit
    @Default(.enableHeatProtectionMode) var enableHeatProtectionMode
    @Default(.heatProtectionLimit) var heatProtectionLimit
    @Default(.manageMagSafeLED) var manageMagSafeLED
    @Default(.heatProtectionMagSafeLEDState) var heatProtectionMagSafeLEDState
    @Default(.stopChargingWhenAppClosed) var stopChargingWhenAppClosed
    @Default(.stopChargingWhileSleeping) var stopChargingWhileSleeping
    @Default(.calibrationLowLevel) var calibrationLowLevel
    @Default(.calibrationHoldMinutes) var calibrationHoldMinutes
    @State private var helperManager = ChargingHelperManager.shared
    @State private var installError: String?

    private let capabilities: DeviceCapabilities
    private let chargeManager: ChargeManager

    private let logger = Logger(
        subsystem: "com.aidente.app",
        category: "ChargingSettingsView"
    )

    init(capabilities: DeviceCapabilities, chargeManager: ChargeManager) {
        self.capabilities = capabilities
        self.chargeManager = chargeManager
    }

    private var hasChargingControl: Bool {
        capabilities.chargingControl
    }

    private var hasAdapterControl: Bool {
        capabilities.adapterControl
    }

    private var hasMagSafe: Bool {
        capabilities.hasMagSafe
    }

    private var hasAnyControl: Bool {
        hasChargingControl || hasAdapterControl
    }

    private var sailingResumePercentage: Int {
        chargeLimit - sailingModeLimit
    }

    var body: some View {
        AidenteSettingsPage {
            AidenteCard(
                "充电管理",
                subtitle: "限制最高充电量，减少电池长期处于满电状态的时间。",
                icon: "battery.75percent",
                colors: AidenteTheme.chargingColors
            ) {
                AidenteSettingToggle(
                    "管理充电",
                    subtitle: "需要在系统设置中批准 Aidente 后台控制服务",
                    icon: "switch.2",
                    colors: AidenteTheme.chargingColors,
                    isOn: Binding(
                        get: { manageCharging },
                        set: { toggleManageCharging($0) }
                    )
                )
                .disabled(!hasAnyControl || helperManager.helperStatus == .requiresApproval)
                .opacity(
                    (!hasAnyControl || helperManager.helperStatus == .requiresApproval)
                        ? 0.50 : 1
                )

                if helperManager.helperStatus == .requiresApproval {
                    AidenteNotice(
                        text: "请前往“系统设置 → 通用 → 登录项与扩展”批准 Aidente，然后返回这里重新检查。",
                        icon: "person.badge.shield.checkmark.fill",
                        colors: AidenteTheme.automationColors
                    )

                    Button {
                        checkApprovalStatus()
                    } label: {
                        Label(
                            AidenteL10n.t("重新检查授权"),
                            systemImage: "arrow.clockwise.circle.fill"
                        )
                    }
                    .buttonStyle(AidenteActionButtonStyle(colors: AidenteTheme.generalColors))
                }

                if helperManager.isRunningFromDiskImage {
                    AidenteNotice(
                        text: "当前正从安装磁盘映像运行，后台控制服务无法可靠启动。请退出 Aidente，将应用拖入“应用程序”文件夹后重新打开。",
                        icon: "externaldrive.badge.exclamationmark",
                        colors: [AidenteTheme.coral, AidenteTheme.amber]
                    )
                }

                if let registrationError = helperManager.registrationError {
                    AidenteNotice(
                        text: AidenteL10n.t(
                            "后台控制服务登记失败：\(registrationError)",
                            "Background control service registration failed: \(registrationError)"
                        ),
                        icon: "person.badge.shield.exclamationmark.fill",
                        colors: [AidenteTheme.coral, AidenteTheme.amber]
                    )
                }

                if !hasAnyControl {
                    AidenteNotice(
                        text: "当前设备不支持充电管理；Aidente 将继续提供只读电池监测。",
                        icon: "laptopcomputer.trianglebadge.exclamationmark",
                        colors: [AidenteTheme.coral, AidenteTheme.amber]
                    )
                }

                if manageCharging {
                    AidenteRowDivider()
                    AidenteControlRow(
                        "充电上限",
                        subtitle: "达到上限后暂停充电",
                        icon: "target",
                        colors: AidenteTheme.chargingColors
                    ) {
                        HStack(spacing: 9) {
                            Slider(
                                value: Binding(
                                    get: { Double(chargeLimit) },
                                    set: { chargeLimit = Int($0) }
                                ),
                                in: 50...100,
                                step: 5
                            )
                            .frame(width: 190)

                            Text("\(chargeLimit)%")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(AidenteTheme.jade)
                                .frame(width: 48, alignment: .trailing)
                        }
                    }
                }
            }

            if manageCharging {
                AidenteCard(
                    "快捷操作",
                    subtitle: "执行一次性操作，不会改动你保存的充电上限。",
                    icon: "bolt.circle.fill",
                    colors: AidenteTheme.automationColors
                ) {
                    AidenteInsetPanel {
                        HStack {
                            Text(AidenteL10n.t("当前状态"))
                                .foregroundStyle(.secondary)
                            Spacer()
                            HStack(spacing: 7) {
                                Circle()
                                    .fill(
                                        chargeManager.controlError == nil
                                            ? AidenteTheme.jade : AidenteTheme.coral
                                    )
                                    .frame(width: 8, height: 8)
                                    .shadow(
                                        color: (
                                            chargeManager.controlError == nil
                                                ? AidenteTheme.jade : AidenteTheme.coral
                                        ).opacity(0.7),
                                        radius: 3
                                    )
                                Text(chargeManager.operationStatusTitle)
                                    .font(.headline)
                            }
                        }
                    }

                    if let controlError = chargeManager.controlError {
                        AidenteNotice(
                            text: controlError,
                            icon: "exclamationmark.shield.fill",
                            colors: [AidenteTheme.coral, AidenteTheme.amber]
                        )

                        Button {
                            repairControlService()
                        } label: {
                            Label(
                                AidenteL10n.t("修复控制服务"),
                                systemImage: "wrench.and.screwdriver.fill"
                            )
                        }
                        .buttonStyle(
                            AidenteActionButtonStyle(colors: AidenteTheme.automationColors)
                        )
                        .disabled(helperManager.isRunningFromDiskImage)
                    }

                    HStack(spacing: 10) {
                        Button {
                            if chargeManager.topUpActive {
                                chargeManager.stopTopUp()
                            } else {
                                chargeManager.startTopUp()
                            }
                        } label: {
                            Label(
                                AidenteL10n.t(
                                    chargeManager.topUpActive ? "停止补电" : "临时充至 100%"
                                ),
                                systemImage: "bolt.fill"
                            )
                        }
                        .buttonStyle(AidenteActionButtonStyle(colors: AidenteTheme.automationColors))

                        Button {
                            if chargeManager.calibrationStage == .idle {
                                chargeManager.startCalibration()
                            } else {
                                chargeManager.cancelCalibration()
                            }
                        } label: {
                            Label(
                                AidenteL10n.t(
                                    chargeManager.calibrationStage == .idle
                                        ? "开始校准" : "取消校准"
                                ),
                                systemImage: "arrow.triangle.2.circlepath"
                            )
                        }
                        .buttonStyle(AidenteActionButtonStyle(colors: AidenteTheme.dashboardColors))

                        Button {
                            if chargeManager.manualPauseActive {
                                chargeManager.resumeNormalManagement()
                            } else {
                                chargeManager.pauseCharging()
                            }
                        } label: {
                            Label(
                                AidenteL10n.t(
                                    chargeManager.manualPauseActive ? "恢复充电" : "暂停充电"
                                ),
                                systemImage: chargeManager.manualPauseActive
                                    ? "play.fill" : "pause.fill"
                            )
                        }
                        .buttonStyle(
                            AidenteActionButtonStyle(
                                colors: [AidenteTheme.coral, AidenteTheme.amber]
                            )
                        )
                    }
                }

                AidenteCard(
                    "自动放电",
                    subtitle: "接通电源且电量高于目标时，自动放电至充电上限。",
                    icon: "arrow.down.circle.fill",
                    colors: AidenteTheme.generalColors
                ) {
                    AidenteSettingToggle(
                        "启用自动放电",
                        subtitle: "到达目标后自动恢复适配器供电",
                        icon: "battery.25percent",
                        colors: AidenteTheme.generalColors,
                        isOn: $automaticDischarge
                    )
                    .disabled(!hasAdapterControl)
                    .opacity(hasAdapterControl ? 1 : 0.5)

                    if !hasAdapterControl {
                        AidenteNotice(text: "当前设备不支持适配器控制。")
                    }
                }

                AidenteCard(
                    "睡眠与退出行为",
                    subtitle: "决定 Mac 睡眠以及 Aidente 未运行时如何保持充电状态。",
                    icon: "moon.stars.fill",
                    colors: AidenteTheme.advancedColors
                ) {
                    AidenteSettingToggle(
                        "达到上限前阻止睡眠",
                        icon: "moon.zzz.fill",
                        colors: AidenteTheme.advancedColors,
                        isOn: $disableSleepUntilChargeLimit
                    )
                    AidenteRowDivider()
                    AidenteSettingToggle(
                        "睡眠时暂停充电",
                        icon: "bed.double.fill",
                        colors: [AidenteTheme.ocean, AidenteTheme.violet],
                        isOn: $stopChargingWhileSleeping
                    )
                    AidenteRowDivider()
                    AidenteSettingToggle(
                        "退出 Aidente 后保持暂停",
                        subtitle: "适合快速用户切换或临时退出应用",
                        icon: "door.left.hand.closed",
                        colors: [AidenteTheme.coral, AidenteTheme.amber],
                        isOn: $stopChargingWhenAppClosed
                    )
                }

                AidenteCard(
                    "电池校准",
                    subtitle: "充至 100% → 放电 → 再充满 → 满电保持 → 恢复原上限。",
                    icon: "arrow.triangle.2.circlepath.circle.fill",
                    colors: AidenteTheme.dashboardColors
                ) {
                    AidenteControlRow(
                        "放电目标",
                        icon: "arrow.down.to.line.compact",
                        colors: AidenteTheme.dashboardColors
                    ) {
                        HStack(spacing: 9) {
                            Slider(
                                value: Binding(
                                    get: { Double(calibrationLowLevel) },
                                    set: { calibrationLowLevel = Int($0) }
                                ),
                                in: 5...20,
                                step: 1
                            )
                            .frame(width: 170)
                            Text("\(calibrationLowLevel)%")
                                .monospacedDigit()
                                .frame(width: 45, alignment: .trailing)
                        }
                    }

                    AidenteRowDivider()

                    AidenteControlRow(
                        "满电保持时间",
                        icon: "timer",
                        colors: AidenteTheme.automationColors
                    ) {
                        Stepper(
                            AidenteL10n.t(
                                "\(calibrationHoldMinutes) 分钟",
                                "\(calibrationHoldMinutes) min"
                            ),
                            value: $calibrationHoldMinutes,
                            in: 15...120,
                            step: 15
                        )
                    }
                }

                AidenteCard(
                    "巡航模式",
                    subtitle: "允许电量在上限附近自然浮动，减少频繁微量补电。",
                    icon: "sailboat.fill",
                    colors: AidenteTheme.generalColors
                ) {
                    AidenteSettingToggle(
                        "启用巡航模式",
                        icon: "water.waves",
                        colors: AidenteTheme.generalColors,
                        isOn: $sailingMode
                    )
                    .disabled(!hasChargingControl)
                    .opacity(hasChargingControl ? 1 : 0.5)

                    if sailingMode {
                        AidenteRowDivider()
                        AidenteControlRow(
                            "低于上限多少时恢复充电",
                            icon: "arrow.down.right",
                            colors: AidenteTheme.generalColors
                        ) {
                            HStack(spacing: 9) {
                                Slider(
                                    value: Binding(
                                        get: { Double(sailingModeLimit) },
                                        set: { sailingModeLimit = Int($0) }
                                    ),
                                    in: 1...20,
                                    step: 1
                                )
                                .frame(width: 150)
                                Text("\(sailingModeLimit)%")
                                    .monospacedDigit()
                                    .frame(width: 44, alignment: .trailing)
                            }
                        }

                        AidenteControlRow(
                            "恢复充电电量",
                            icon: "play.circle.fill",
                            colors: AidenteTheme.chargingColors
                        ) {
                            Text("\(sailingResumePercentage)%")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(AidenteTheme.jade)
                        }
                    }
                }

                AidenteCard(
                    "高温保护",
                    subtitle: "温度超过阈值时暂停充电，并通过五分钟迟滞避免频繁切换。",
                    icon: "thermometer.high",
                    colors: [AidenteTheme.amber, AidenteTheme.coral]
                ) {
                    AidenteSettingToggle(
                        "启用高温保护",
                        icon: "flame.fill",
                        colors: [AidenteTheme.amber, AidenteTheme.coral],
                        isOn: $enableHeatProtectionMode
                    )
                    .disabled(!hasChargingControl)
                    .opacity(hasChargingControl ? 1 : 0.5)

                    if enableHeatProtectionMode {
                        AidenteRowDivider()
                        AidenteControlRow(
                            "温度上限",
                            icon: "thermometer.medium",
                            colors: [AidenteTheme.amber, AidenteTheme.coral]
                        ) {
                            HStack(spacing: 9) {
                                Slider(
                                    value: Binding(
                                        get: { Double(heatProtectionLimit) },
                                        set: { heatProtectionLimit = Int($0) }
                                    ),
                                    in: 30...50,
                                    step: 1
                                )
                                .frame(width: 160)
                                Text("\(heatProtectionLimit)°C")
                                    .monospacedDigit()
                                    .frame(width: 50, alignment: .trailing)
                            }
                        }
                    }
                }

                if hasMagSafe {
                    AidenteCard(
                        "MagSafe 指示灯",
                        subtitle: "在受支持机型上用颜色显示充电、暂停和保护状态。",
                        icon: "lightbulb.led.fill",
                        colors: AidenteTheme.automationColors
                    ) {
                        AidenteSettingToggle(
                            "由 Aidente 控制指示灯",
                            icon: "lightbulb.fill",
                            colors: AidenteTheme.automationColors,
                            isOn: $manageMagSafeLED
                        )
                        .disabled(!capabilities.magsafeLEDControl)
                        .opacity(capabilities.magsafeLEDControl ? 1 : 0.5)

                        if manageMagSafeLED && enableHeatProtectionMode {
                            AidenteRowDivider()
                            AidenteControlRow(
                                "高温保护时的灯光",
                                icon: "lightspectrum.horizontal",
                                colors: AidenteTheme.automationColors
                            ) {
                                Picker("", selection: $heatProtectionMagSafeLEDState) {
                                    Text(AidenteL10n.t("关闭")).tag(MagSafeLEDState.off)
                                    Text(AidenteL10n.t("绿色")).tag(MagSafeLEDState.green)
                                    Text(AidenteL10n.t("橙色")).tag(MagSafeLEDState.orange)
                                    Text(AidenteL10n.t("橙色慢闪"))
                                        .tag(MagSafeLEDState.blinkOrangeSlow)
                                    Text(AidenteL10n.t("橙色快闪"))
                                        .tag(MagSafeLEDState.blinkOrangeFast)
                                }
                                .labelsHidden()
                                .frame(width: 140)
                            }
                        }

                        if !capabilities.magsafeLEDControl {
                            AidenteNotice(text: "当前设备不支持 MagSafe 指示灯控制。")
                        }
                    }
                }
            }
        }
        .animation(.default, value: manageCharging)
        .animation(.default, value: sailingMode)
        .animation(.default, value: enableHeatProtectionMode)
        .animation(.default, value: manageMagSafeLED)
        .animation(.default, value: helperManager.helperStatus)
        .alert(
            AidenteL10n.t("无法启用充电控制服务"),
            isPresented: Binding(
                get: { installError != nil },
                set: { if !$0 { installError = nil } }
            )
        ) {
            Button(AidenteL10n.t("好")) { installError = nil }
        } message: {
            if let installError {
                Text(installError)
            }
        }
    }

    private func toggleManageCharging(_ enabled: Bool) {
        do {
            if enabled {
                try helperManager.install()
                if helperManager.helperStatus == .installed {
                    manageCharging = true
                }
            } else {
                try helperManager.uninstall()
                manageCharging = false
            }
        } catch {
            logger.error("Failed to \(enabled ? "install" : "uninstall") charging helper: \(error)")
            installError = error.localizedDescription
        }
    }

    private func checkApprovalStatus() {
        helperManager.refreshStatus()
        if helperManager.helperStatus == .installed {
            manageCharging = true
            chargeManager.checkControlService()
        }
    }

    private func repairControlService() {
        Task {
            do {
                try await helperManager.repair()
                if helperManager.helperStatus == .installed {
                    manageCharging = true
                    chargeManager.retryControlAfterRepair()
                }
            } catch {
                logger.error("Failed to repair charging helper: \(error)")
                installError = error.localizedDescription
            }
        }
    }
}
