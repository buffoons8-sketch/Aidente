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
    case diagnostics = "Diagnostics"
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
        case .general: AidenteL10n.t("通用")
        case .dashboard: AidenteL10n.t("仪表盘")
        case .charging: AidenteL10n.t("充电管理")
        case .automation: AidenteL10n.t("计划与自动化")
        case .advanced: AidenteL10n.t("高级")
        case .diagnostics: AidenteL10n.t("诊断")
        case .about: AidenteL10n.t("关于")
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
        case .diagnostics:
            return "waveform.badge.magnifyingglass"
        case .about:
            return "heart.text.square.fill"
        }
    }

    var colors: [Color] {
        switch self {
        case .general: AidenteTheme.generalColors
        case .dashboard: AidenteTheme.dashboardColors
        case .charging: AidenteTheme.chargingColors
        case .automation: AidenteTheme.automationColors
        case .advanced: AidenteTheme.advancedColors
        case .diagnostics: AidenteTheme.dashboardColors
        case .about: AidenteTheme.aboutColors
        }
    }
}

struct SettingsView: View {
    @Default(.appLanguage) private var appLanguage
    @State private var selectedTab: SettingsTab

    private let capabilities: DeviceCapabilities
    private let chargeManager: ChargeManager
    private let diagnosticCenter: DiagnosticCenter

    init(
        capabilities: DeviceCapabilities,
        chargeManager: ChargeManager,
        diagnosticCenter: DiagnosticCenter,
        initialTab: SettingsTab = .general
    ) {
        self.capabilities = capabilities
        self.chargeManager = chargeManager
        self.diagnosticCenter = diagnosticCenter
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        ZStack {
            AidenteWindowBackdrop()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 11) {
                        AidenteIconBadge(
                            icon: selectedTab.icon,
                            colors: selectedTab.colors,
                            size: 34
                        )

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Aidente")
                                .font(.system(size: 17, weight: .bold))
                            Text(selectedTab.title)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(AidenteL10n.t("电池养护控制台"))
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Picker(AidenteL10n.t("设置页面"), selection: $selectedTab) {
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
                    AidenteChromeBar()
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
                    case .diagnostics:
                        DiagnosticsSettingsView(diagnosticCenter: diagnosticCenter)
                    case .about:
                        AboutSettingsView()
                    }
                }
            }
        }
        .tint(AidenteTheme.jade)
        .frame(minWidth: 960, minHeight: 640)
        .onAppear {
            updateWindowTitle()
        }
        .onChange(of: appLanguage) { _, _ in
            updateWindowTitle()
        }
    }

    private func updateWindowTitle() {
        DispatchQueue.main.async {
            NSApp.keyWindow?.title = AidenteL10n.t(
                "Aidente 设置",
                "Aidente Settings"
            )
        }
    }
}
