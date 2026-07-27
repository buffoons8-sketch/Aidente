import Defaults
import SwiftUI

struct DashboardSettingsView: View {
    @Default(.appLanguage) private var appLanguage

    @Default(.showPowerSource) var showPowerSource
    @Default(.showTimeTillDischarge) var showTimeTillDischarge
    @Default(.showUptime) var showUptime
    @Default(.showBatteryMode) var showBatteryMode
    @Default(.showBatteryTemperature) var showBatteryTemperature
    @Default(.showBatteryCycleCount) var showBatteryCycleCount
    @Default(.showBatteryHealth) var showBatteryHealth
    @Default(.showInternalPower) var showInternalPower
    @Default(.showExternalPower) var showExternalPower
    @Default(.showPowerDistribution) var showPowerDistribution

    var body: some View {
        IadenteSettingsPage {
            IadenteCard(
                "状态信息",
                subtitle: "选择菜单栏下拉面板中显示的系统与电池信息。",
                icon: "gauge.with.dots.needle.67percent",
                colors: IadenteTheme.dashboardColors
            ) {
                IadenteSettingToggle(
                    "电源来源",
                    icon: "powerplug.fill",
                    colors: [IadenteTheme.ocean, IadenteTheme.sky],
                    isOn: $showPowerSource
                )
                IadenteRowDivider()
                IadenteSettingToggle(
                    "剩余使用时间",
                    icon: "hourglass.bottomhalf.filled",
                    colors: IadenteTheme.automationColors,
                    isOn: $showTimeTillDischarge
                )
                IadenteRowDivider()
                IadenteSettingToggle(
                    "系统运行时间",
                    icon: "clock.fill",
                    colors: [IadenteTheme.violet, IadenteTheme.pink],
                    isOn: $showUptime
                )
                IadenteRowDivider()
                IadenteSettingToggle(
                    "电池工作模式",
                    icon: "bolt.horizontal.fill",
                    colors: IadenteTheme.chargingColors,
                    isOn: $showBatteryMode
                )
            }

            IadenteCard(
                "电池健康",
                subtitle: "查看电池老化、使用次数和当前温度。",
                icon: "heart.text.square.fill",
                colors: [IadenteTheme.coral, IadenteTheme.pink]
            ) {
                IadenteSettingToggle(
                    "循环次数",
                    icon: "arrow.triangle.2.circlepath.circle.fill",
                    colors: [IadenteTheme.violet, IadenteTheme.sky],
                    isOn: $showBatteryCycleCount
                )
                IadenteRowDivider()
                IadenteSettingToggle(
                    "电池健康度",
                    icon: "heart.fill",
                    colors: [IadenteTheme.coral, IadenteTheme.pink],
                    isOn: $showBatteryHealth
                )
                IadenteRowDivider()
                IadenteSettingToggle(
                    "电池温度",
                    icon: "thermometer.medium",
                    colors: [IadenteTheme.amber, IadenteTheme.coral],
                    isOn: $showBatteryTemperature
                )
            }

            IadenteCard(
                "实时功率",
                subtitle: "显示电池与电源适配器的电压、电流和功率。",
                icon: "waveform.path.ecg.rectangle.fill",
                colors: IadenteTheme.generalColors
            ) {
                IadenteSettingToggle(
                    "电池功率数据",
                    icon: "battery.50percent",
                    colors: IadenteTheme.chargingColors,
                    isOn: $showInternalPower
                )
                IadenteRowDivider()
                IadenteSettingToggle(
                    "适配器功率数据",
                    icon: "powerplug.fill",
                    colors: IadenteTheme.generalColors,
                    isOn: $showExternalPower
                )
            }

            IadenteCard(
                "彩色能量流",
                subtitle: "用立体流向图展示电源、电池和电脑之间的能量分配。",
                icon: "point.3.connected.trianglepath.dotted",
                colors: IadenteTheme.automationColors
            ) {
                IadenteSettingToggle(
                    "显示功率分配图",
                    icon: "chart.bar.fill",
                    colors: IadenteTheme.automationColors,
                    isOn: $showPowerDistribution
                )
            }
        }
    }
}
