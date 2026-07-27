import AppKit
import Defaults
import SwiftUI

@MainActor
class MenuBuilder {
    private let viewModel: MenuViewModel
    private let settingsWindowController: SettingsWindowController

    init(
        viewModel: MenuViewModel,
        settingsWindowController: SettingsWindowController
    ) {
        self.viewModel = viewModel
        self.settingsWindowController = settingsWindowController
    }

    func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "iadente")
        populateMenu(menu)
        return menu
    }

    func populateMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let mainInfoItem = createMenuItem(
            view: BatteryMainInfoView(viewModel: viewModel)
        )
        menu.addItem(mainInfoItem)

        let sections: [[NSMenuItem]] = [
            buildInfoSection(),
            buildPowerMetricsSection(),
            buildVisualizationSection(),
            buildHardwareSection(),
        ]

        for section in sections where !section.isEmpty {
            menu.addItem(NSMenuItem.separator())
            for item in section {
                menu.addItem(item)
            }
        }

        if viewModel.manageChargingEnabled && viewModel.adapterConnected {
            menu.addItem(NSMenuItem.separator())
            menu.addItem(createMenuItem(view: ChargeLimitOverrideToggleView(viewModel: viewModel)))
            menu.addItem(createMenuItem(view: ForceDischargeToggleView(viewModel: viewModel)))
            menu.addItem(createMenuItem(view: ManualPauseToggleView(viewModel: viewModel)))
            menu.addItem(createMenuItem(view: CalibrationToggleView(viewModel: viewModel)))
        }

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: IadenteL10n.t("设置…"),
            action: #selector(handleSettings),
            keyEquivalent: ","
        )
        settingsItem.image = menuSymbol(
            "gearshape.fill",
            colors: [.systemBlue, .systemTeal]
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: IadenteL10n.t("退出 iadente"),
            action: #selector(handleQuit),
            keyEquivalent: "q"
        )
        quitItem.image = menuSymbol(
            "power.circle.fill",
            colors: [.systemRed, .systemOrange]
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func buildInfoSection() -> [NSMenuItem] {
        var items: [NSMenuItem] = []

        if viewModel.manageChargingEnabled {
            items.append(
                createInfoItem(
                    label: "iadente 状态",
                    keyPath: \.operationStatusText,
                    icon: "sparkles",
                    colors: IadenteTheme.chargingColors
                )
            )
        }

        if Defaults[.showPowerSource] {
            items.append(
                createInfoItem(
                    label: "电源来源",
                    keyPath: \.powerSourceText,
                    icon: "powerplug.fill",
                    colors: IadenteTheme.generalColors
                )
            )
        }
        if Defaults[.showTimeTillDischarge] {
            items.append(
                createInfoItem(
                    label: "剩余时间",
                    keyPath: \.timeRemainingText,
                    icon: "hourglass.bottomhalf.filled",
                    colors: IadenteTheme.automationColors
                )
            )
        }
        if Defaults[.showUptime] {
            items.append(
                createInfoItem(
                    label: "系统运行时间",
                    keyPath: \.uptimeText,
                    icon: "clock.fill",
                    colors: IadenteTheme.dashboardColors
                )
            )
        }
        if Defaults[.showBatteryMode] {
            items.append(
                createInfoItem(
                    label: "电池模式",
                    keyPath: \.batteryModeText,
                    icon: "bolt.horizontal.fill",
                    colors: IadenteTheme.chargingColors
                )
            )
        }
        if Defaults[.showBatteryTemperature] {
            items.append(
                createInfoItem(
                    label: "电池温度",
                    keyPath: \.batteryTemperatureText,
                    icon: "thermometer.medium",
                    colors: [IadenteTheme.amber, IadenteTheme.coral]
                )
            )
        }

        return items
    }

    private func buildPowerMetricsSection() -> [NSMenuItem] {
        var items: [NSMenuItem] = []

        if Defaults[.showInternalPower] {
            items.append(
                createInfoItem(
                    label: "电池功率",
                    keyPath: \.internalInputText,
                    icon: "battery.50percent",
                    colors: IadenteTheme.chargingColors
                )
            )
        }
        if Defaults[.showExternalPower] {
            items.append(
                createInfoItem(
                    label: "适配器功率",
                    keyPath: \.externalInputText,
                    icon: "powerplug.fill",
                    colors: IadenteTheme.generalColors
                )
            )
        }

        return items
    }

    private func buildVisualizationSection() -> [NSMenuItem] {
        var items: [NSMenuItem] = []

        if Defaults[.showPowerDistribution] {
            items.append(
                createMenuItem(
                    view: PowerSankeyViewWrapper(viewModel: viewModel)
                )
            )
        }

        return items
    }

    private func buildHardwareSection() -> [NSMenuItem] {
        var items: [NSMenuItem] = []

        if Defaults[.showBatteryCycleCount] {
            items.append(createInfoItem(
                label: "循环次数",
                keyPath: \.cycleCountText,
                icon: "arrow.triangle.2.circlepath",
                colors: IadenteTheme.dashboardColors
            ))
        }
        if Defaults[.showBatteryHealth] {
            items.append(
                createInfoItem(
                    label: "电池健康度",
                    keyPath: \.batteryHealthText,
                    icon: "heart.fill",
                    colors: [IadenteTheme.coral, IadenteTheme.pink]
                )
            )
        }

        return items
    }

    private func createInfoItem(
        label: String,
        keyPath: KeyPath<MenuViewModel, String>,
        icon: String,
        colors: [Color]
    ) -> NSMenuItem {
        createMenuItem(
            view: BatteryAdditionalInfoObserverView(
                label: label,
                viewModel: viewModel,
                keyPath: keyPath,
                icon: icon,
                colors: colors
            )
        )
    }

    private static let menuWidth: CGFloat = 330

    private func createMenuItem<V: View>(view: V) -> NSMenuItem {
        let hostingView = NSHostingView(rootView: view)
        let height = hostingView.fittingSize.height
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: Self.menuWidth,
            height: height
        )

        let menuItem = NSMenuItem()
        menuItem.view = hostingView

        return menuItem
    }

    private func menuSymbol(_ name: String, colors: [NSColor]) -> NSImage? {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            return nil
        }
        return image.withSymbolConfiguration(
            NSImage.SymbolConfiguration(paletteColors: colors)
        )
    }

    @objc private func handleSettings() {
        settingsWindowController.showSettings()
    }

    @objc private func handleQuit() {
        viewModel.quit()
    }
}

struct BatteryMainInfoView: View {
    let viewModel: MenuViewModel

    var body: some View {
        BatteryMainInfo(
            label: IadenteL10n.t("电池仪表盘", "Battery Dashboard"),
            value: viewModel.batteryPercentageText,
            status: viewModel.batteryModeText
        )
    }
}

struct BatteryAdditionalInfoObserverView: View {
    let label: String
    let viewModel: MenuViewModel
    let keyPath: KeyPath<MenuViewModel, String>
    let icon: String
    let colors: [Color]

    var body: some View {
        BatteryAdditionalInfo(
            label: label,
            value: viewModel[keyPath: keyPath],
            icon: icon,
            colors: colors
        )
    }
}

struct PowerSankeyViewWrapper: View {
    let viewModel: MenuViewModel

    var body: some View {
        PowerSankeyView(
            powerSource: viewModel.powerSource,
            isCharging: viewModel.isCharging,
            batteryPower: viewModel.batteryPower,
            adapterPower: viewModel.adapterPower,
            systemPower: viewModel.systemPower
        )
    }
}

struct ChargeLimitOverrideToggleView: View {
    let viewModel: MenuViewModel

    var body: some View {
        HStack {
            IadenteIconBadge(
                icon: "bolt.fill",
                colors: IadenteTheme.automationColors,
                size: 25
            )
            Text(IadenteL10n.t("临时充至 100%"))
            Spacer(minLength: 20)
            Toggle(
                IadenteL10n.t("临时充至 100%"),
                isOn: Binding(
                    get: { viewModel.chargeLimitOverrideActive },
                    set: { _ in viewModel.toggleChargeLimitOverride() }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
            .disabled(viewModel.forceDischargeActive)
        }
        .foregroundColor(.secondary)
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }
}

struct ForceDischargeToggleView: View {
    let viewModel: MenuViewModel

    var body: some View {
        HStack {
            IadenteIconBadge(
                icon: "arrow.down.circle.fill",
                colors: IadenteTheme.generalColors,
                size: 25
            )
            Text(IadenteL10n.t("放电至充电上限"))
            Spacer(minLength: 20)
            Toggle(
                IadenteL10n.t("放电至充电上限"),
                isOn: Binding(
                    get: { viewModel.forceDischargeActive },
                    set: { _ in viewModel.toggleForceDischarge() }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
            .disabled(viewModel.chargeLimitOverrideActive)
        }
        .foregroundColor(.secondary)
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }
}

struct ManualPauseToggleView: View {
    let viewModel: MenuViewModel

    var body: some View {
        HStack {
            IadenteIconBadge(
                icon: "pause.fill",
                colors: [IadenteTheme.coral, IadenteTheme.amber],
                size: 25
            )
            Text(IadenteL10n.t("暂停充电"))
            Spacer(minLength: 20)
            Toggle(
                IadenteL10n.t("暂停充电"),
                isOn: Binding(
                    get: { viewModel.manualPauseActive },
                    set: { _ in viewModel.toggleManualPause() }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .foregroundColor(.secondary)
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }
}

struct CalibrationToggleView: View {
    let viewModel: MenuViewModel

    var body: some View {
        HStack {
            IadenteIconBadge(
                icon: "arrow.triangle.2.circlepath",
                colors: IadenteTheme.dashboardColors,
                size: 25
            )
            Text(IadenteL10n.t("电池校准"))
            Spacer(minLength: 20)
            Toggle(
                IadenteL10n.t("电池校准"),
                isOn: Binding(
                    get: { viewModel.calibrationActive },
                    set: { _ in viewModel.toggleCalibration() }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .foregroundColor(.secondary)
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }
}
