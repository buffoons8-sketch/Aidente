import AppKit
import SwiftUI
import smc_power

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let capabilities: DeviceCapabilities
    private let chargeManager: ChargeManager

    init(capabilities: DeviceCapabilities, chargeManager: ChargeManager) {
        self.capabilities = capabilities
        self.chargeManager = chargeManager
        super.init()
    }

    func showSettings(tab: SettingsTab = .general) {
        if let existingWindow = window {
            existingWindow.delegate = nil
            existingWindow.close()
            window = nil
        }

        let settingsView = SettingsView(
            capabilities: capabilities,
            chargeManager: chargeManager,
            initialTab: tab
        )
        let hostingController = NSHostingController(rootView: settingsView)

        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = AidenteL10n.t("Aidente 设置", "Aidente Settings")
        newWindow.styleMask = [
            .titled,
            .closable,
            .miniaturizable,
            .resizable,
            .fullSizeContentView,
        ]
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.isOpaque = false
        newWindow.backgroundColor = .clear
        newWindow.appearance = NSAppearance(named: .darkAqua)
        newWindow.contentView?.wantsLayer = true
        newWindow.contentView?.layer?.cornerRadius = 14
        newWindow.contentView?.layer?.masksToBounds = true
        newWindow.center()
        newWindow.setFrameAutosaveName("SettingsWindow")
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        self.window = newWindow
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            window = nil
        }
    }
}
