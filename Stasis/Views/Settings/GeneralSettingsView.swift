import Defaults
import SwiftUI

struct GeneralSettingsView: View {
    @Default(.appLanguage) var appLanguage
    @Default(.launchAtLogin) var launchAtLogin
    @Default(.batteryPercentageDisplayLocation) var batteryPercentageDisplayLocation
    @Default(.menuBarReadoutStyle) var menuBarReadoutStyle
    @Default(.showBatteryStateInStatusIcon) var showBatteryStateInStatusIcon
    @Default(.disableNotifications) var disableNotifications
    @Default(.showChargingStatusChangedNotification) var showChargingStatusChangedNotification
    @Default(.interfaceMaterialStyle) var interfaceMaterialStyle

    var body: some View {
        IadenteSettingsPage {
            IadenteCard(
                "语言",
                subtitle: "切换菜单栏和设置界面的显示语言。",
                icon: "character.bubble.fill",
                colors: IadenteTheme.generalColors
            ) {
                Picker(IadenteL10n.t("语言"), selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title)
                            .tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .id(appLanguage)
            }

            IadenteCard(
                "界面材质",
                subtitle: "选择菜单浮层和设置窗口的透明与虚化程度。",
                icon: "square.on.square",
                colors: IadenteTheme.dashboardColors
            ) {
                Picker(IadenteL10n.t("界面材质"), selection: $interfaceMaterialStyle) {
                    ForEach(InterfaceMaterialStyle.allCases) { style in
                        Label(style.title, systemImage: style.icon)
                            .tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .id(appLanguage)

                HStack(spacing: 8) {
                    Image(systemName: interfaceMaterialStyle.icon)
                        .foregroundStyle(IadenteTheme.violet)
                    Text(interfaceMaterialStyle.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            IadenteCard(
                "启动",
                subtitle: "让电池保护在登录后自动开始工作。",
                icon: "power.circle.fill",
                colors: IadenteTheme.generalColors
            ) {
                IadenteSettingToggle(
                    "登录时启动 iadente",
                    subtitle: "登录当前账户后自动显示菜单栏图标",
                    icon: "arrow.up.forward.app.fill",
                    colors: IadenteTheme.generalColors,
                    isOn: $launchAtLogin
                )
            }

            IadenteCard(
                "菜单栏实时读数",
                subtitle: "在电量、当前系统功率或两者同时显示之间切换。",
                icon: "gauge.with.dots.needle.67percent",
                colors: IadenteTheme.chargingColors
            ) {
                Picker(IadenteL10n.t("菜单栏显示内容"), selection: $menuBarReadoutStyle) {
                    ForEach(MenuBarReadoutStyle.allCases) { style in
                        Label(style.title, systemImage: style.icon)
                            .tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .id(appLanguage)

                if menuBarReadoutStyle == .batteryPercentage {
                    IadenteRowDivider()

                    IadenteControlRow(
                        "电量数字位置",
                        icon: "percent",
                        colors: IadenteTheme.chargingColors
                    ) {
                        Picker("", selection: $batteryPercentageDisplayLocation) {
                            Text(IadenteL10n.t("不显示")).tag(PercentageDisplayLocation.hidden)
                            Text(IadenteL10n.t("图标旁")).tag(PercentageDisplayLocation.nextToIcon)
                            Text(IadenteL10n.t("图标内")).tag(PercentageDisplayLocation.insideIcon)
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                }

                IadenteRowDivider()

                IadenteSettingToggle(
                    "用颜色显示电池状态",
                    subtitle: "充电、接通电源、低电量使用不同颜色",
                    icon: "paintpalette.fill",
                    colors: IadenteTheme.dashboardColors,
                    isOn: $showBatteryStateInStatusIcon
                )
            }

            IadenteCard(
                "通知",
                subtitle: "控制 iadente 何时向你报告充电状态。",
                icon: "bell.badge.fill",
                colors: IadenteTheme.automationColors
            ) {
                IadenteSettingToggle(
                    "关闭全部通知",
                    icon: "bell.slash.fill",
                    colors: [IadenteTheme.coral, IadenteTheme.amber],
                    isOn: $disableNotifications
                )

                IadenteRowDivider()

                IadenteSettingToggle(
                    "充电状态变化时通知",
                    subtitle: "暂停或恢复充电时发送系统通知",
                    icon: "bolt.badge.clock.fill",
                    colors: IadenteTheme.automationColors,
                    isOn: $showChargingStatusChangedNotification
                )
                    .disabled(disableNotifications)
                    .opacity(disableNotifications ? 0.48 : 1)
            }
        }
        .onChange(of: launchAtLogin) { _, newValue in
            LaunchAtLoginService.shared.setLaunchAtLogin(newValue)
        }
    }
}
