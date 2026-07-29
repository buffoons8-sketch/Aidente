import Defaults
import Foundation
import smc_power

enum AidenteRuntime {
    static let isUIPreview = CommandLine.arguments.contains("--ui-preview")
}

enum AidenteMigration {
    private static let legacyBundleIdentifier = "com.iadente.app"
    private static let migrationMarker = "didMigrateLegacyPreferencesV1"

    static func migrateLegacyPreferencesIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationMarker) else { return }

        let currentBundleIdentifier =
            Bundle.main.bundleIdentifier ?? "com.aidente.app"
        let currentValues =
            defaults.persistentDomain(forName: currentBundleIdentifier) ?? [:]

        if let legacyValues = defaults.persistentDomain(
            forName: legacyBundleIdentifier
        ) {
            for (key, value) in legacyValues where currentValues[key] == nil {
                defaults.set(value, forKey: key)
            }
        }

        defaults.set(true, forKey: migrationMarker)
    }
}

extension MagSafeLEDState: Defaults.Serializable {}

enum AppLanguage: String, Defaults.Serializable, CaseIterable, Identifiable {
    case system
    case simplifiedChinese
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: AidenteL10n.t("跟随系统", "System")
        case .simplifiedChinese: "中文"
        case .english: "English"
        }
    }
}

enum PercentageDisplayLocation: String, Defaults.Serializable, CaseIterable, Identifiable {
    case hidden
    case nextToIcon
    case insideIcon

    var id: String { rawValue }
}

enum MenuBarReadoutStyle: String, Defaults.Serializable, CaseIterable, Identifiable {
    case batteryPercentage
    case systemPower
    case batteryAndPower

    var id: String { rawValue }

    var title: String {
        switch self {
        case .batteryPercentage: AidenteL10n.t("实时电量")
        case .systemPower: AidenteL10n.t("实时功率")
        case .batteryAndPower: AidenteL10n.t("电量与功率")
        }
    }

    var icon: String {
        switch self {
        case .batteryPercentage: "battery.75percent"
        case .systemPower: "waveform.path.ecg"
        case .batteryAndPower: "gauge.with.dots.needle.67percent"
        }
    }
}

enum InterfaceMaterialStyle: String, Defaults.Serializable, CaseIterable, Identifiable {
    case solid
    case glass
    case frosted
    case liquidGlass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solid: AidenteL10n.t("清晰实体")
        case .glass: AidenteL10n.t("毛玻璃")
        case .frosted: AidenteL10n.t("高斯柔化")
        case .liquidGlass: AidenteL10n.t("液态玻璃")
        }
    }

    var subtitle: String {
        switch self {
        case .solid: AidenteL10n.t("最高文字对比度")
        case .glass: AidenteL10n.t("平衡透明度与清晰度")
        case .frosted: AidenteL10n.t("更明显的背景虚化")
        case .liquidGlass:
            AidenteL10n.t("适配 macOS 26/27，旧系统自动使用兼容效果")
        }
    }

    var icon: String {
        switch self {
        case .solid: "rectangle.fill"
        case .glass: "square.on.square"
        case .frosted: "aqi.medium"
        case .liquidGlass: "drop.circle.fill"
        }
    }
}

extension Defaults.Keys {
    // General
    static let appLanguage = Key<AppLanguage>("appLanguage", default: .system)
    static let launchAtLogin = Key<Bool>("launchAtLogin", default: false)
    static let interfaceMaterialStyle = Key<InterfaceMaterialStyle>(
        "interfaceMaterialStyle", default: .glass)

    // Status Icon
    static let batteryPercentageDisplayLocation = Key<PercentageDisplayLocation>(
        "batteryPercentageDisplayLocation", default: .nextToIcon)
    static let menuBarReadoutStyle = Key<MenuBarReadoutStyle>(
        "menuBarReadoutStyle", default: .batteryPercentage)
    static let showBatteryStateInStatusIcon = Key<Bool>(
        "showBatteryStateInStatusIcon", default: true)

    // Notifications
    static let disableNotifications = Key<Bool>("disableNotifications", default: false)
    static let showChargingStatusChangedNotification = Key<Bool>(
        "showChargingStatusChangedNotification", default: true)

    // Menu Dashboard
    static let showTimeTillDischarge = Key<Bool>("showTimeTillDischarge", default: true)
    static let showBatteryCycleCount = Key<Bool>("showBatteryCycleCount", default: true)
    static let showBatteryHealth = Key<Bool>("showBatteryHealth", default: true)
    static let showBatteryTemperature = Key<Bool>("showBatteryTemperature", default: false)
    static let showPowerSource = Key<Bool>("showPowerSource", default: false)
    static let showUptime = Key<Bool>("showUptime", default: true)
    static let showBatteryMode = Key<Bool>("showBatteryMode", default: true)
    static let showInternalPower = Key<Bool>("showInternalPower", default: true)
    static let showExternalPower = Key<Bool>("showExternalPower", default: true)
    static let showPowerDistribution = Key<Bool>("showPowerDistribution", default: false)

    // Charging
    static let manageCharging = Key<Bool>("manageCharging", default: false)
    static let chargeLimit = Key<Int>("chargeLimit", default: 80)
    static let sailingMode = Key<Bool>("sailingMode", default: true)
    static let sailingModeLimit = Key<Int>("sailingModeLimit", default: 5)
    static let automaticDischarge = Key<Bool>("automaticDischarge", default: true)
    static let disableSleepUntilChargeLimit = Key<Bool>("disableSleepUntilChargeLimit", default: false)

    // Charging - Heat Protection
    static let enableHeatProtectionMode = Key<Bool>(
        "enableHeatProtectionMode", default: true)
    static let heatProtectionLimit = Key<Int>("heatProtectionLimit", default: 40)

    // Charging - MagSafe LED Control
    static let manageMagSafeLED = Key<Bool>("manageMagSafeLED", default: true)
    static let heatProtectionMagSafeLEDState = Key<MagSafeLEDState>(
        "heatProtectionMagSafeLEDState", default: MagSafeLEDState.blinkOrangeSlow)

    // Charging - Advanced workflows
    static let stopChargingWhenAppClosed = Key<Bool>(
        "stopChargingWhenAppClosed", default: false)
    static let stopChargingWhileSleeping = Key<Bool>(
        "stopChargingWhileSleeping", default: true)
    static let topUpActive = Key<Bool>("topUpActive", default: false)
    static let manualPauseActive = Key<Bool>("manualPauseActive", default: false)
    static let forcedDischargeTarget = Key<Int>("forcedDischargeTarget", default: 80)
    static let calibrationStage = Key<String>("calibrationStage", default: "idle")
    static let calibrationOriginalLimit = Key<Int>(
        "calibrationOriginalLimit", default: 80)
    static let calibrationLowLevel = Key<Int>("calibrationLowLevel", default: 10)
    static let calibrationHoldMinutes = Key<Int>("calibrationHoldMinutes", default: 60)
    static let calibrationHoldUntil = Key<Double>("calibrationHoldUntil", default: 0)

    // Automation
    static let scheduleTasksData = Key<Data>("scheduleTasksData", default: Data())

    // Advanced
    static let useHardwarePercentage = Key<Bool>("useHardwarePercentage", default: false)
}
