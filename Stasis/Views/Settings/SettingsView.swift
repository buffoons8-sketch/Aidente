import AppKit
import Defaults
import SwiftUI
import smc_power

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case dashboard = "Dashboard"
    case charging = "Charging"
    case automation = "Automation"
    case advanced = "Advanced"
    case about = "About"

    var id: String { rawValue }

    init?(urlValue: String) {
        guard let tab = Self.allCases.first(where: {
            $0.rawValue.lowercased() == urlValue.lowercased()
        }) else {
            return nil
        }
        self = tab
    }
    
    var title: String {
        switch self {
        case .general: IadenteL10n.t("通用")
        case .dashboard: IadenteL10n.t("仪表盘")
        case .charging: IadenteL10n.t("充电管理")
        case .automation: IadenteL10n.t("计划与自动化")
        case .advanced: IadenteL10n.t("高级")
        case .about: IadenteL10n.t("关于")
        }
    }

    var icon: String {
        switch self {
        case .general:
            return "gearshape.fill"
        case .dashboard:
            return "gauge.with.dots.needle.67percent"
        case .charging:
            return "battery.100.bolt"
        case .automation:
            return "calendar.badge.clock"
        case .advanced:
            return "slider.horizontal.3"
        case .about:
            return "heart.text.square.fill"
        }
    }

    var colors: [Color] {
        switch self {
        case .general: IadenteTheme.generalColors
        case .dashboard: IadenteTheme.dashboardColors
        case .charging: IadenteTheme.chargingColors
        case .automation: IadenteTheme.automationColors
        case .advanced: IadenteTheme.advancedColors
        case .about: IadenteTheme.aboutColors
        }
    }
}

struct SettingsView: View {
    @Default(.appLanguage) private var appLanguage
    @State private var selectedTab: SettingsTab

    private let capabilities: DeviceCapabilities
    private let chargeManager: ChargeManager

    init(
        capabilities: DeviceCapabilities,
        chargeManager: ChargeManager,
        initialTab: SettingsTab = .general
    ) {
        self.capabilities = capabilities
        self.chargeManager = chargeManager
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        ZStack {
            IadenteWindowBackdrop()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 11) {
                        IadenteIconBadge(
                            icon: selectedTab.icon,
                            colors: selectedTab.colors,
                            size: 34
                        )

                        VStack(alignment: .leading, spacing: 1) {
                            Text("iadente")
                                .font(.system(size: 17, weight: .bold))
                            Text(selectedTab.title)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(IadenteL10n.t("电池养护控制台"))
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Picker(IadenteL10n.t("设置页面"), selection: $selectedTab) {
                        ForEach(SettingsTab.allCases) { tab in
                            Label(tab.title, systemImage: tab.icon)
                                .tag(tab)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .id(appLanguage)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 14)
                .background {
                    Color(
                        red: 0.095,
                        green: 0.09,
                        blue: 0.085
                    )
                    .opacity(0.98)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.white.opacity(0.14))
                        .frame(height: 1)
                }
                .shadow(color: .black.opacity(0.32), radius: 10, y: 5)
                .zIndex(1)

                Group {
                    switch selectedTab {
                    case .general:
                        GeneralSettingsView()
                    case .dashboard:
                        DashboardSettingsView()
                    case .charging:
                        ChargingSettingsView(
                            capabilities: capabilities,
                            chargeManager: chargeManager
                        )
                    case .automation:
                        AutomationSettingsView()
                    case .advanced:
                        AdvancedSettingsView()
                    case .about:
                        AboutSettingsView()
                    }
                }
            }
        }
        .tint(IadenteTheme.jade)
        .frame(minWidth: 860, minHeight: 600)
        .onAppear {
            updateWindowTitle()
        }
        .onChange(of: appLanguage) { _, _ in
            updateWindowTitle()
        }
    }

    private func updateWindowTitle() {
        DispatchQueue.main.async {
            NSApp.keyWindow?.title = IadenteL10n.t(
                "iadente 设置",
                "iadente Settings"
            )
        }
    }
}
