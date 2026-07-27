import Defaults
import SwiftUI

struct AdvancedSettingsView: View {
    @Default(.appLanguage) private var appLanguage

    @Default(.useHardwarePercentage) var useHardwarePercentage

    var body: some View {
        IadenteSettingsPage {
            IadenteCard(
                "电量读取方式",
                subtitle: "选择 iadente 用于充电上限、巡航和校准的电量数据。",
                icon: "sensor.fill",
                colors: IadenteTheme.advancedColors
            ) {
                IadenteSettingToggle(
                    "使用硬件电量百分比",
                    subtitle: "直接读取电池管理系统的原始数值，而不是 macOS 校准后的显示值",
                    icon: "cpu.fill",
                    colors: IadenteTheme.advancedColors,
                    isOn: $useHardwarePercentage
                )

                IadenteNotice(
                    text: "硬件电量通常会与菜单栏中的 macOS 电量相差几个百分点。切换后，所有充电策略都将使用所选读数。",
                    icon: "info.circle.fill",
                    colors: IadenteTheme.generalColors
                )
            }
        }
    }
}
