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
        AidenteSettingsPage {
            AidenteCard(
                "状态信息",
                subtitle: "选择菜单栏下拉面板中显示的系统与电池信息。",
                icon: "gauge.with.dots.needle.67percent",
                colors: AidenteTheme.dashboardColors
            ) {
                AidenteSettingToggle(
                    "电源来源",
                    icon: "powerplug.fill",
                    colors: [AidenteTheme.ocean, AidenteTheme.sky],
                    isOn: $showPowerSource
                )
                AidenteRowDivider()
                AidenteSettingToggle(
                    "剩余使用时间",
                    icon: "hourglass.bottomhalf.filled",
                    colors: AidenteTheme.automationColors,
                    isOn: $showTimeTillDischarge
                )
                AidenteRowDivider()
                AidenteSettingToggle(
                    "系统运行时间",
                    icon: "clock.fill",
                    colors: [AidenteTheme.violet, AidenteTheme.pink],
                    isOn: $showUptime
                )
                AidenteRowDivider()
                AidenteSettingToggle(
                    "电池工作模式",
                    icon: "bolt.horizontal.fill",
                    colors: AidenteTheme.chargingColors,
                    isOn: $showBatteryMode
                )
            }

            AidenteCard(
                "电池健康",
                subtitle: "查看电池老化、使用次数和当前温度。",
                icon: "heart.text.square.fill",
                colors: [AidenteTheme.coral, AidenteTheme.pink]
            ) {
                AidenteSettingToggle(
                    "循环次数",
                    icon: "arrow.triangle.2.circlepath.circle.fill",
                    colors: [AidenteTheme.violet, AidenteTheme.sky],
                    isOn: $showBatteryCycleCount
                )
                AidenteRowDivider()
                AidenteSettingToggle(
                    "电池健康度",
                    icon: "heart.fill",
                    colors: [AidenteTheme.coral, AidenteTheme.pink],
                    isOn: $showBatteryHealth
                )
                AidenteRowDivider()
                AidenteSettingToggle(
                    "电池温度",
                    icon: "thermometer.medium",
                    colors: [AidenteTheme.amber, AidenteTheme.coral],
                    isOn: $showBatteryTemperature
                )
            }

            AidenteCard(
                "实时功率",
                subtitle: "显示电池与电源适配器的电压、电流和功率。",
                icon: "waveform.path.ecg.rectangle.fill",
                colors: AidenteTheme.generalColors
            ) {
                AidenteSettingToggle(
                    "电池功率数据",
                    icon: "battery.50percent",
                    colors: AidenteTheme.chargingColors,
                    isOn: $showInternalPower
                )
                AidenteRowDivider()
                AidenteSettingToggle(
                    "适配器功率数据",
                    icon: "powerplug.fill",
                    colors: AidenteTheme.generalColors,
                    isOn: $showExternalPower
                )
            }

            AidenteCard(
                "彩色能量流",
                subtitle: "用立体流向图展示电源、电池和电脑之间的能量分配。",
                icon: "point.3.connected.trianglepath.dotted",
                colors: AidenteTheme.automationColors
            ) {
                AidenteSettingToggle(
                    "显示功率分配图",
                    icon: "chart.bar.fill",
                    colors: AidenteTheme.automationColors,
                    isOn: $showPowerDistribution
                )
            }
        }
    }
}
