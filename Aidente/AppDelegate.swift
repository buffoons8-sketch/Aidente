import AppKit
import Defaults
import Darwin
import IOKit
import Observation
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarManager: StatusBarManager!
    private var batteryService: BatteryService!
    private var viewModel: MenuViewModel!
    private var chargeManager: ChargeManager!
    private var settingsWindowController: SettingsWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AidenteMigration.migrateLegacyPreferencesIfNeeded()

        if CommandLine.arguments.contains("--print-effective-defaults") {
            print("manageCharging=\(Defaults[.manageCharging])")
            print("manualPauseActive=\(Defaults[.manualPauseActive])")
            Darwin.exit(0)
        }

        if CommandLine.arguments.contains("--print-energy-apps") {
            for app in AppEnergyUsageService.readTopApps(limit: 10) {
                print(
                    "\(app.name)\t\(String(format: "%.2f", app.cpuUsage))%\t\(app.bundlePath)"
                )
            }
            Darwin.exit(0)
        }

        if CommandLine.arguments.contains("--unregister-helper") {
            try? ChargingHelperManager.shared.uninstall()
            Darwin.exit(0)
        }

        // Exit the app immediately if the device doesn't have a battery
        let batteryIOService = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard batteryIOService != 0 else {
            NSApplication.shared.terminate(nil)
            return
        }
        IOObjectRelease(batteryIOService)

        Task {
            ensureChargingHelperRegistration()
            await setupServices()
            if CommandLine.arguments.contains("--preview-window") {
                statusBarManager.showWindowForPreview()
            } else if CommandLine.arguments.contains("--show-popover") {
                statusBarManager.showPopoverForPreview()
            }
            observePowerEvents()
            requestNotificationPermissions()
            openSettingsFromCommandLineIfRequested()
        }
    }

    private func ensureChargingHelperRegistration() {
        guard !AidenteRuntime.isUIPreview else { return }
        guard Defaults[.manageCharging] else { return }
        do {
            try ChargingHelperManager.shared.ensureInstalled()
        } catch {
            // The settings page exposes the stored registration error and the
            // approval/repair actions. Read-only monitoring still starts.
        }
    }

    private func openSettingsFromCommandLineIfRequested() {
        guard let argument = CommandLine.arguments.first(where: {
            $0.hasPrefix("--settings-tab=")
        }) else {
            return
        }
        let value = String(argument.dropFirst("--settings-tab=".count))
        let tab = SettingsTab(urlValue: value) ?? .general
        settingsWindowController.showSettings(tab: tab)
    }

    private func setupServices() async {
        batteryService = BatteryService()
        await batteryService.loadCapabilities()
        chargeManager = ChargeManager(batteryService: batteryService)
        chargeManager.configureHelperDisconnectPolicy()
        chargeManager.checkControlService()
        viewModel = MenuViewModel(
            batteryService: batteryService,
            chargeManager: chargeManager
        )
        settingsWindowController = SettingsWindowController(
            capabilities: batteryService.deviceCapabilities,
            chargeManager: chargeManager
        )
        statusBarManager = StatusBarManager(
            viewModel: viewModel,
            settingsWindowController: settingsWindowController
        )
    }

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { _, _ in }
    }

    private func observePowerEvents() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemWillSleep(_:)),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemDidWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func handleSystemWillSleep(_ notification: Notification) {
        chargeManager.prepareForSleep()
    }

    @objc private func handleSystemDidWake(_ notification: Notification) {
        chargeManager.resumeFromSleep()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "aidente" {
            if url.host == "settings" {
                let tabValue = URLComponents(
                    url: url,
                    resolvingAgainstBaseURL: false
                )?.queryItems?.first(where: { $0.name == "tab" })?.value
                let tab = tabValue.flatMap(SettingsTab.init(urlValue:)) ?? .general
                settingsWindowController.showSettings(tab: tab)
            } else {
                chargeManager.handleAutomationURL(url)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        chargeManager.configureHelperDisconnectPolicy()
        chargeManager.stop()
        batteryService.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
