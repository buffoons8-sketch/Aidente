import AppKit
import Defaults
import SwiftUI

struct AboutSettingsView: View {
    @Default(.appLanguage) private var appLanguage

    var body: some View {
        IadenteSettingsPage {
            IadenteCard(
                "iadente",
                subtitle: "为 Apple 芯片 MacBook 打造的独立电池养护工具",
                icon: "bolt.heart.fill",
                colors: IadenteTheme.chargingColors
            ) {
                IadenteInsetPanel {
                    HStack(spacing: 16) {
                        IadenteIconBadge(
                            icon: "battery.100percent.bolt",
                            colors: [
                                IadenteTheme.jade,
                                IadenteTheme.mint,
                                IadenteTheme.gold,
                            ],
                            size: 64,
                            cornerRadius: 18
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("iadente")
                                .font(.title.bold())
                            Text(IadenteL10n.t("电池养护 · 充电管理 · 实时监测"))
                                .foregroundStyle(.secondary)
                            Text(IadenteL10n.t("版本 0.4.1", "Version 0.4.1"))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(IadenteTheme.jade)
                        }

                        Spacer()
                    }
                }
            }

            IadenteCard(
                "安全说明",
                subtitle: "底层控制始终以设备能力检测和明确授权为前提。",
                icon: "shield.checkered",
                colors: IadenteTheme.generalColors
            ) {
                Text(
                    IadenteL10n.t(
                        "iadente 会调整底层电池充电控制。设备不支持某项能力时，软件会自动退回只读监测模式。你可以随时关闭“管理充电”，恢复系统默认充电状态。"
                    )
                )
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            IadenteCard(
                "开放源代码",
                subtitle: "许可文本和第三方声明均随应用一同提供。",
                icon: "chevron.left.forwardslash.chevron.right",
                colors: IadenteTheme.advancedColors
            ) {
                Text(
                    IadenteL10n.t(
                        "iadente 是基于开源 Stasis 项目修改的 GPL-3.0 软件，并使用 SMCKit 与 Defaults 开源组件。"
                    )
                )
                .foregroundStyle(.secondary)

                Button {
                    guard let url = Bundle.main.url(
                        forResource: "LICENSE",
                        withExtension: "txt"
                    ) else { return }
                    NSWorkspace.shared.open(url)
                } label: {
                    Label(IadenteL10n.t("查看开源许可证"), systemImage: "doc.text.fill")
                }
                .buttonStyle(IadenteActionButtonStyle(colors: IadenteTheme.advancedColors))
            }

            IadenteCard(
                "商标声明",
                subtitle: "独立开发，不包含其他商业软件的代码或授权机制。",
                icon: "signature",
                colors: IadenteTheme.aboutColors
            ) {
                Text(
                    IadenteL10n.t(
                        "iadente 是独立项目，与 AppHouseKitchen 不存在隶属、授权或分发关系。AlDente 是其各自权利人的商标。"
                    )
                )
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
