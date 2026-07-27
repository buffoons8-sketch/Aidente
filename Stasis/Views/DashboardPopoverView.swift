import AppKit
import Defaults
import SwiftUI

struct DashboardPopoverView: View {
    let viewModel: MenuViewModel
    let onOpenSettings: (SettingsTab) -> Void
    let onQuit: () -> Void

    @Default(.chargeLimit) private var chargeLimit
    @Default(.manageCharging) private var manageCharging
    @Default(.showBatteryTemperature) private var showBatteryTemperature
    @Default(.enableHeatProtectionMode) private var heatProtectionEnabled
    @Default(.stopChargingWhileSleeping) private var sleepPauseEnabled
    @Default(.sailingMode) private var sailingModeEnabled
    @Default(.appLanguage) private var appLanguage

    @State private var chargeLimitDraft: Double = 80
    @State private var isAdjustingChargeLimit = false

    var body: some View {
        ZStack {
            IadenteWindowBackdrop()

            VStack(spacing: 0) {
                header

                Rectangle()
                    .fill(.primary.opacity(0.11))
                    .frame(height: 1)
                    .padding(.horizontal, 14)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        statusHero
                        batterySummary
                        powerSummary
                        energyAppRanking
                        careActions
                        automaticProtection
                        settingsLinks
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                }
                .scrollIndicators(.never)

                footer
            }
        }
        .frame(width: 408, height: 720)
        .preferredColorScheme(.dark)
        .tint(IadenteTheme.jade)
        .onAppear {
            chargeLimitDraft = Double(chargeLimit)
        }
        .onChange(of: chargeLimit) { _, newValue in
            guard !isAdjustingChargeLimit else { return }
            chargeLimitDraft = Double(newValue)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    viewModel.adapterConnected
                        ? IadenteL10n.t("电源已连接")
                        : IadenteL10n.t("正在使用电池")
                )
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                Text(viewModel.batteryModeText)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if showBatteryTemperature {
                Label(viewModel.batteryTemperatureText, systemImage: "thermometer.medium")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(IadenteTheme.jade)
            }

            Rectangle()
                .fill(.primary.opacity(0.16))
                .frame(width: 1, height: 25)

            Text(viewModel.batteryPercentageText)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var statusHero: some View {
        VStack(spacing: 13) {
            HStack(spacing: 12) {
                Image(
                    systemName: viewModel.adapterConnected
                        ? (viewModel.isCharging ? "bolt.fill" : "powerplug.fill")
                        : "battery.75percent"
                )
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 39, height: 39)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(statusTint.opacity(0.17))
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.operationStatusText)
                        .font(.system(size: 15, weight: .bold))
                    Text(
                        viewModel.adapterConnected
                            ? IadenteL10n.t(
                                "适配器 \(viewModel.externalInputText)",
                                "Adapter \(viewModel.externalInputText)"
                            )
                            : IadenteL10n.t(
                                "电池 \(viewModel.internalInputText)",
                                "Battery \(viewModel.internalInputText)"
                            )
                    )
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer()
            }

            BatteryChargeLimitControl(
                batteryLevel: viewModel.displayPercentage,
                chargeLimitDraft: $chargeLimitDraft,
                tint: statusTint
            ) { editing in
                isAdjustingChargeLimit = editing
                if !editing {
                    chargeLimit = displayedChargeLimit
                }
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(manageCharging ? IadenteTheme.jade : IadenteTheme.amber)
                    .frame(width: 6, height: 6)
                    .shadow(
                        color: manageCharging ? IadenteTheme.jade : IadenteTheme.amber,
                        radius: 4
                    )
                Text(
                    manageCharging
                        ? IadenteL10n.t(
                            "达到 \(displayedChargeLimit)% 后自动暂停充电",
                            "Charging pauses automatically at \(displayedChargeLimit)%"
                        )
                        : IadenteL10n.t(
                            "只读监测 · 上限会在启用充电管理后生效",
                            "Read-only monitoring · Enable charging control to apply the limit"
                        )
                )
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.115, green: 0.145, blue: 0.18).opacity(0.95),
                            Color(red: 0.065, green: 0.075, blue: 0.09).opacity(0.92),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(statusTint)
                .frame(width: 2)
                .shadow(color: statusTint, radius: 8)
                .padding(.vertical, 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: statusTint.opacity(0.12), radius: 10, y: 4)
    }

    private var batterySummary: some View {
        PopoverCompactCard {
            HStack(spacing: 0) {
                CompactMetric(
                    title: "电池健康",
                    value: viewModel.batteryHealthText,
                    tint: IadenteTheme.jade
                )
                CompactDivider()
                CompactMetric(
                    title: "循环次数",
                    value: viewModel.cycleCountText,
                    tint: IadenteTheme.violet
                )
                CompactDivider()
                CompactMetric(
                    title: "剩余时间",
                    value: viewModel.timeRemainingText,
                    tint: IadenteTheme.amber,
                    compact: true
                )
            }
        }
    }

    private var powerSummary: some View {
        PopoverCompactCard {
            VStack(spacing: 8) {
                HStack {
                    Label(
                        IadenteL10n.t("实时功率分流"),
                        systemImage: "point.3.connected.trianglepath.dotted"
                    )
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(viewModel.powerSourceText)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                CompactPowerFlowDiagram(
                    powerSource: viewModel.powerSource,
                    isCharging: viewModel.isCharging,
                    adapterPower: viewModel.adapterPower,
                    systemPower: viewModel.systemPower,
                    batteryPower: viewModel.batteryPower
                )
            }
        }
    }

    private var energyAppRanking: some View {
        PopoverCompactCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Label(
                        IadenteL10n.t("当前耗电 App"),
                        systemImage: "bolt.horizontal.circle.fill"
                    )
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(IadenteL10n.t("按处理器活动实时估算"))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                if !viewModel.hasEnergyUsageSample {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(IadenteL10n.t("正在采样当前应用活动…"))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                } else if viewModel.topEnergyApps.isEmpty {
                    Text(IadenteL10n.t("当前没有检测到明显耗电的前台应用"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    let maximum = max(
                        viewModel.topEnergyApps.map(\.cpuUsage).max() ?? 1,
                        1
                    )
                    ForEach(
                        Array(viewModel.topEnergyApps.prefix(3).enumerated()),
                        id: \.element.id
                    ) { item in
                        EnergyAppRow(
                            rank: item.offset + 1,
                            app: item.element,
                            maximumCPUUsage: maximum,
                            tint: energyTint(for: item.offset)
                        )
                    }
                }
            }
        }
    }

    private var careActions: some View {
        PopoverCompactCard {
            VStack(spacing: 10) {
                HStack {
                    Label(IadenteL10n.t("快捷养护"), systemImage: "leaf.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(viewModel.operationStatusText)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(statusTint)
                }

                CompactActionRow(
                    title: "暂停充电",
                    subtitle: viewModel.manualPauseActive
                        ? "当前已暂停，点击恢复管理"
                        : "保持适配器供电，停止电池充入",
                    icon: viewModel.manualPauseActive ? "pause.fill" : "pause.circle",
                    tint: IadenteTheme.coral,
                    isOn: viewModel.manualPauseActive,
                    action: viewModel.toggleManualPause
                )

                CompactActionRow(
                    title: "临时充至 100%",
                    subtitle: IadenteL10n.t(
                        "完成后恢复 \(displayedChargeLimit)% 充电上限",
                        "Restore the \(displayedChargeLimit)% charge limit when complete"
                    ),
                    icon: "bolt.fill",
                    tint: IadenteTheme.amber,
                    isOn: viewModel.chargeLimitOverrideActive,
                    action: viewModel.toggleChargeLimitOverride
                )

                CompactActionRow(
                    title: "放电至充电上限",
                    subtitle: IadenteL10n.t(
                        "使用电池降低至 \(displayedChargeLimit)%",
                        "Use the battery until it reaches \(displayedChargeLimit)%"
                    ),
                    icon: "arrow.down.circle.fill",
                    tint: IadenteTheme.ocean,
                    isOn: viewModel.forceDischargeActive,
                    action: viewModel.toggleForceDischarge
                )

                CompactActionRow(
                    title: "电池校准",
                    subtitle: "执行完整充放电校准流程",
                    icon: "arrow.triangle.2.circlepath",
                    tint: IadenteTheme.violet,
                    isOn: viewModel.calibrationActive,
                    action: viewModel.toggleCalibration
                )
            }
        }
    }

    private var automaticProtection: some View {
        PopoverCompactCard {
            VStack(alignment: .leading, spacing: 9) {
                Label(IadenteL10n.t("自动保护"), systemImage: "shield.lefthalf.filled")
                    .font(.system(size: 13, weight: .semibold))

                HStack(spacing: 7) {
                    ProtectionPill(
                        title: "高温",
                        isEnabled: heatProtectionEnabled
                    )
                    ProtectionPill(
                        title: "睡眠暂停",
                        isEnabled: sleepPauseEnabled
                    )
                    ProtectionPill(
                        title: "巡航",
                        isEnabled: sailingModeEnabled
                    )
                }
            }
        }
    }

    private var settingsLinks: some View {
        HStack(spacing: 9) {
            DashboardLinkButton(
                title: "电池详情",
                icon: "info.circle"
            ) {
                onOpenSettings(.dashboard)
            }
            DashboardLinkButton(
                title: "充电设置",
                icon: "slider.horizontal.3"
            ) {
                onOpenSettings(.charging)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 9) {
            Text("iadente")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            IadenteTheme.violet,
                            IadenteTheme.jade,
                            IadenteTheme.pink,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text(IadenteL10n.t("实时电池养护"))
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            FooterButton(icon: "arrow.clockwise") {
                viewModel.refresh()
            }
            FooterButton(icon: "gearshape.fill") {
                onOpenSettings(.general)
            }
            FooterButton(icon: "power") {
                onQuit()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.11))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.primary.opacity(0.11))
                .frame(height: 1)
        }
    }

    private var displayedChargeLimit: Int {
        min(max(Int(chargeLimitDraft.rounded()), 20), 100)
    }

    private var statusTint: Color {
        if viewModel.hasControlError { return IadenteTheme.coral }
        if viewModel.isCharging { return IadenteTheme.amber }
        return IadenteTheme.jade
    }

    private func energyTint(for index: Int) -> Color {
        switch index {
        case 0: IadenteTheme.amber
        case 1: IadenteTheme.ocean
        default: IadenteTheme.violet
        }
    }
}

private struct BatteryChargeLimitControl: View {
    @Default(.appLanguage) private var appLanguage

    let batteryLevel: Int
    @Binding var chargeLimitDraft: Double
    let tint: Color
    let onEditingChanged: (Bool) -> Void

    private var chargeLimit: Int {
        min(max(Int(chargeLimitDraft.rounded()), 20), 100)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text("\(batteryLevel)%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                    Text(IadenteL10n.t("实时电量"))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text(IadenteL10n.t("上限"))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("\(chargeLimit)%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(IadenteTheme.jade)
                }
            }

            GeometryReader { geometry in
                let width = geometry.size.width
                let safeBattery = min(max(batteryLevel, 0), 100)
                let batteryWidth = width * CGFloat(safeBattery) / 100
                let limitX = width * CGFloat(chargeLimit) / 100

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.085))
                        .frame(height: 10)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [IadenteTheme.ocean, tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(5, batteryWidth), height: 10)
                        .shadow(color: tint.opacity(0.35), radius: 5)

                    ForEach(1..<10, id: \.self) { tick in
                        Rectangle()
                            .fill(.white.opacity(tick % 2 == 0 ? 0.24 : 0.13))
                            .frame(width: 1, height: tick % 2 == 0 ? 7 : 5)
                            .offset(x: width * CGFloat(tick) / 10)
                    }

                    ZStack {
                        Capsule()
                            .fill(.white.opacity(0.96))
                            .frame(width: 3, height: 20)
                            .shadow(color: .black.opacity(0.70), radius: 2)

                        Circle()
                            .fill(.white)
                            .frame(width: 13, height: 13)
                            .overlay {
                                Circle()
                                    .strokeBorder(IadenteTheme.jade.opacity(0.75), lineWidth: 2)
                            }
                            .shadow(color: IadenteTheme.jade.opacity(0.45), radius: 5)
                    }
                    .frame(width: 18, height: 24)
                    .offset(x: min(max(limitX - 9, 0), width - 18))
                }
                .frame(height: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            onEditingChanged(true)
                            updateLimit(at: value.location.x, width: width)
                        }
                        .onEnded { value in
                            updateLimit(at: value.location.x, width: width)
                            onEditingChanged(false)
                        }
                )
            }
            .frame(height: 24)

            HStack {
                Text("0%")
                Spacer()
                Text(IadenteL10n.t("拖动白色标记调整上限"))
                Spacer()
                Text("100%")
            }
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            IadenteL10n.t("电池电量与充电上限", "Battery Level and Charge Limit")
        )
        .accessibilityValue(
            IadenteL10n.t(
                "实时电量 \(batteryLevel)%，充电上限 \(chargeLimit)%",
                "Battery level \(batteryLevel)%, charge limit \(chargeLimit)%"
            )
        )
        .accessibilityHint(
            IadenteL10n.t(
                "拖动或调整数值来修改充电上限",
                "Drag or adjust the value to change the charge limit"
            )
        )
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                chargeLimitDraft = min(100, chargeLimitDraft + 1)
            case .decrement:
                chargeLimitDraft = max(20, chargeLimitDraft - 1)
            @unknown default:
                return
            }
            onEditingChanged(false)
        }
    }

    private func updateLimit(at x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        let percentage = (x / width * 100).rounded()
        chargeLimitDraft = min(max(Double(percentage), 20), 100)
    }
}

private struct CompactPowerFlowDiagram: View {
    @Default(.appLanguage) private var appLanguage

    let powerSource: PowerSource
    let isCharging: Bool
    let adapterPower: Double
    let systemPower: Double
    let batteryPower: Double

    private let nodeWidth: CGFloat = 108
    private let nodeHeight: CGFloat = 46

    private var diagramHeight: CGFloat {
        switch diagramMode {
        case .adapterSplit, .sourcesMerge:
            120
        case .adapterOnly, .batteryOnly:
            64
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let leftX = nodeWidth / 2
            let rightX = geometry.size.width - nodeWidth / 2
            let topY: CGFloat = nodeHeight / 2
            let middleY = diagramHeight / 2
            let bottomY = diagramHeight - nodeHeight / 2

            ZStack {
                Canvas { context, _ in
                    drawFlows(
                        context: context,
                        leftX: leftX + nodeWidth / 2 - 5,
                        rightX: rightX - nodeWidth / 2 + 5,
                        topY: topY,
                        middleY: middleY,
                        bottomY: bottomY
                    )
                }

                switch diagramMode {
                case .adapterSplit:
                    PowerFlowNode(
                        title: "适配器",
                        icon: "powerplug.fill",
                        power: adapterPower,
                        tint: IadenteTheme.amber
                    )
                    .position(x: leftX, y: middleY)

                    PowerFlowNode(
                        title: "电池充入",
                        icon: isCharging ? "battery.100.bolt" : "battery.100",
                        power: batteryPower,
                        tint: IadenteTheme.jade
                    )
                    .position(x: rightX, y: topY)

                    PowerFlowNode(
                        title: "系统使用",
                        icon: "laptopcomputer",
                        power: systemPower,
                        tint: IadenteTheme.ocean
                    )
                    .position(x: rightX, y: bottomY)

                case .sourcesMerge:
                    PowerFlowNode(
                        title: "电池输出",
                        icon: "battery.100",
                        power: batteryPower,
                        tint: IadenteTheme.jade
                    )
                    .position(x: leftX, y: topY)

                    PowerFlowNode(
                        title: "适配器",
                        icon: "powerplug.fill",
                        power: adapterPower,
                        tint: IadenteTheme.amber
                    )
                    .position(x: leftX, y: bottomY)

                    PowerFlowNode(
                        title: "系统使用",
                        icon: "laptopcomputer",
                        power: systemPower,
                        tint: IadenteTheme.ocean
                    )
                    .position(x: rightX, y: middleY)

                case .adapterOnly:
                    PowerFlowNode(
                        title: "适配器",
                        icon: "powerplug.fill",
                        power: adapterPower,
                        tint: IadenteTheme.amber
                    )
                    .position(x: leftX, y: middleY)

                    PowerFlowNode(
                        title: "系统使用",
                        icon: "laptopcomputer",
                        power: systemPower,
                        tint: IadenteTheme.ocean
                    )
                    .position(x: rightX, y: middleY)

                case .batteryOnly:
                    PowerFlowNode(
                        title: "电池输出",
                        icon: "battery.100",
                        power: batteryPower,
                        tint: IadenteTheme.jade
                    )
                    .position(x: leftX, y: middleY)

                    PowerFlowNode(
                        title: "系统使用",
                        icon: "laptopcomputer",
                        power: systemPower,
                        tint: IadenteTheme.ocean
                    )
                    .position(x: rightX, y: middleY)
                }
            }
        }
        .frame(height: diagramHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(IadenteL10n.t("实时功率分流图", "Live Power Flow Diagram"))
        .accessibilityValue(
            IadenteL10n.t(
                "适配器 \(formatted(adapterPower))，系统 \(formatted(systemPower))，电池 \(formatted(batteryPower))",
                "Adapter \(formatted(adapterPower)), system \(formatted(systemPower)), battery \(formatted(batteryPower))"
            )
        )
    }

    private enum DiagramMode {
        case adapterSplit
        case sourcesMerge
        case adapterOnly
        case batteryOnly
    }

    private var diagramMode: DiagramMode {
        switch powerSource {
        case .acAdapter:
            batteryPower > 0.05 ? .adapterSplit : .adapterOnly
        case .both:
            .sourcesMerge
        case .battery:
            .batteryOnly
        }
    }

    private func drawFlows(
        context: GraphicsContext,
        leftX: CGFloat,
        rightX: CGFloat,
        topY: CGFloat,
        middleY: CGFloat,
        bottomY: CGFloat
    ) {
        switch diagramMode {
        case .adapterSplit:
            drawFlow(
                context: context,
                from: CGPoint(x: leftX, y: middleY),
                to: CGPoint(x: rightX, y: topY),
                power: batteryPower,
                startColor: IadenteTheme.amber,
                endColor: IadenteTheme.jade
            )
            drawFlow(
                context: context,
                from: CGPoint(x: leftX, y: middleY),
                to: CGPoint(x: rightX, y: bottomY),
                power: systemPower,
                startColor: IadenteTheme.amber,
                endColor: IadenteTheme.ocean
            )

        case .sourcesMerge:
            drawFlow(
                context: context,
                from: CGPoint(x: leftX, y: topY),
                to: CGPoint(x: rightX, y: middleY),
                power: batteryPower,
                startColor: IadenteTheme.jade,
                endColor: IadenteTheme.ocean
            )
            drawFlow(
                context: context,
                from: CGPoint(x: leftX, y: bottomY),
                to: CGPoint(x: rightX, y: middleY),
                power: adapterPower,
                startColor: IadenteTheme.amber,
                endColor: IadenteTheme.ocean
            )

        case .adapterOnly:
            drawFlow(
                context: context,
                from: CGPoint(x: leftX, y: middleY),
                to: CGPoint(x: rightX, y: middleY),
                power: adapterPower,
                startColor: IadenteTheme.amber,
                endColor: IadenteTheme.ocean
            )

        case .batteryOnly:
            drawFlow(
                context: context,
                from: CGPoint(x: leftX, y: middleY),
                to: CGPoint(x: rightX, y: middleY),
                power: systemPower,
                startColor: IadenteTheme.jade,
                endColor: IadenteTheme.ocean
            )
        }
    }

    private func drawFlow(
        context: GraphicsContext,
        from start: CGPoint,
        to end: CGPoint,
        power: Double,
        startColor: Color,
        endColor: Color
    ) {
        let controlX = start.x + (end.x - start.x) * 0.50
        let path = Path { path in
            path.move(to: start)
            path.addCurve(
                to: end,
                control1: CGPoint(x: controlX, y: start.y),
                control2: CGPoint(x: controlX, y: end.y)
            )
        }
        let width = min(max(CGFloat(sqrt(abs(power))) * 1.15, 3), 8)

        context.stroke(
            path,
            with: .color(.black.opacity(0.24)),
            style: StrokeStyle(lineWidth: width + 3, lineCap: .round)
        )
        context.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [
                    startColor.opacity(0.82),
                    endColor.opacity(0.88),
                ]),
                startPoint: start,
                endPoint: end
            ),
            style: StrokeStyle(lineWidth: width, lineCap: .round)
        )

        var arrow = Path()
        arrow.move(to: CGPoint(x: end.x - 1, y: end.y))
        arrow.addLine(to: CGPoint(x: end.x - 8, y: end.y - 5))
        arrow.addLine(to: CGPoint(x: end.x - 8, y: end.y + 5))
        arrow.closeSubpath()
        context.fill(arrow, with: .color(endColor.opacity(0.95)))
    }

    private func formatted(_ power: Double) -> String {
        String(format: "%.2f W", abs(power))
    }
}

private struct PowerFlowNode: View {
    @Default(.appLanguage) private var appLanguage

    let title: String
    let icon: String
    let power: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 23, height: 23)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(IadenteL10n.t(title))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(String(format: "%.2f W", abs(power)))
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(width: 108, height: 46)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.black.opacity(0.19))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(tint.opacity(0.30), lineWidth: 1)
                }
        }
        .shadow(color: tint.opacity(0.12), radius: 5, y: 2)
    }
}

private struct PopoverCompactCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(13)
            .background {
                PopoverCardBackground()
            }
    }
}

private struct PopoverCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.045))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            }
    }
}

private struct CompactDivider: View {
    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.11))
            .frame(width: 1, height: 34)
    }
}

private struct CompactMetric: View {
    @Default(.appLanguage) private var appLanguage

    let title: String
    let value: String
    let tint: Color
    var compact = false

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(
                    .system(
                        size: compact ? 12 : 16,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.70)
            Text(IadenteL10n.t(title))
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CompactActionRow: View {
    @Default(.appLanguage) private var appLanguage

    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(tint.opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(IadenteL10n.t(title))
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(IadenteL10n.t(subtitle))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(IadenteL10n.t(isOn ? "开启" : "关闭"))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(isOn ? tint : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill((isOn ? tint : Color.secondary).opacity(0.12))
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct EnergyAppRow: View {
    let rank: Int
    let app: AppEnergyUsageSnapshot
    let maximumCPUUsage: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 9) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundlePath))
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(rank)")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(tint)
                        .frame(width: 13)
                    Text(app.name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(String(format: "%.1f%%", app.cpuUsage))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.07))
                        Capsule()
                            .fill(tint)
                            .frame(
                                width: max(
                                    3,
                                    geometry.size.width
                                        * min(app.cpuUsage / maximumCPUUsage, 1)
                                )
                            )
                    }
                }
                .frame(height: 3)
            }
        }
    }
}

private struct ProtectionPill: View {
    @Default(.appLanguage) private var appLanguage

    let title: String
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isEnabled ? IadenteTheme.jade : Color.secondary)
                .frame(width: 6, height: 6)
            Text(IadenteL10n.t(title))
                .font(.system(size: 10.5, weight: .medium))
            Text(IadenteL10n.t(isEnabled ? "开" : "关"))
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(isEnabled ? IadenteTheme.jade : .secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.04))
        )
    }
}

private struct DashboardLinkButton: View {
    @Default(.appLanguage) private var appLanguage

    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(IadenteL10n.t(title), systemImage: icon)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background {
            PopoverCardBackground()
        }
    }
}

private struct FooterButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11.5, weight: .semibold))
                .frame(width: 25, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.white.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
    }
}
