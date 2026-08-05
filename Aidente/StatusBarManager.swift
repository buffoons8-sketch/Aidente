import AppKit
import Defaults
import SwiftUI

@MainActor
final class StatusBarManager: NSObject {
    private let statusItem: NSStatusItem
    private let viewModel: MenuViewModel
    private let settingsWindowController: SettingsWindowController
    private var dashboardPanel: NSPanel?
    private var dismissMonitors: [Any] = []
    private var displayObservation: Task<Void, Never>?
    private var previewWindow: NSWindow?

    init(
        viewModel: MenuViewModel,
        settingsWindowController: SettingsWindowController
    ) {
        self.viewModel = viewModel
        self.settingsWindowController = settingsWindowController
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        super.init()

        setupPersistentHostingView()
        startDisplayObservation()
    }

    // A fixed-position panel instead of an NSPopover: popovers track their
    // anchor, so menu bar managers like Ice that relocate status items to
    // hide them would drag the open popover along (breaking an in-progress
    // charge-limit drag) or dismiss it outright.
    private func makeDashboardPanel() -> NSPanel {
        let hostingController = NSHostingController(rootView: makeDashboardRootView())
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.cornerRadius = 15
        hostingController.view.layer?.masksToBounds = true

        let panel = AidenteFloatingPanel(contentViewController: hostingController)
        panel.styleMask = [.borderless, .nonactivatingPanel]
        panel.setContentSize(NSSize(width: 408, height: 720))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        return panel
    }

    private func makeDashboardRootView() -> DashboardPopoverView {
        DashboardPopoverView(
            viewModel: viewModel,
            onOpenSettings: { [weak self] tab in
                guard let self else { return }
                self.closeDashboard()
                self.previewWindow?.close()
                self.settingsWindowController.showSettings(tab: tab)
            },
            onQuit: { [weak self] in
                self?.viewModel.quit()
            }
        )
    }

    private func showDashboard() {
        guard let button = statusItem.button else { return }
        let panel = dashboardPanel ?? makeDashboardPanel()
        dashboardPanel = panel

        let size = panel.frame.size
        if let buttonWindow = button.window {
            let buttonFrame = buttonWindow.convertToScreen(
                button.convert(button.bounds, to: nil)
            )
            let screenFrame =
                (buttonWindow.screen ?? NSScreen.main)?.visibleFrame
                ?? buttonFrame
            let x = min(
                max(buttonFrame.midX - size.width / 2, screenFrame.minX + 8),
                screenFrame.maxX - size.width - 8
            )
            let y = max(buttonFrame.minY - size.height - 6, screenFrame.minY)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        viewModel.menuWillOpen()
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        installDismissMonitors()
    }

    private func closeDashboard() {
        removeDismissMonitors()
        guard let panel = dashboardPanel, panel.isVisible else { return }
        panel.orderOut(nil)
        viewModel.menuDidClose()
    }

    private func installDismissMonitors() {
        guard dismissMonitors.isEmpty else { return }

        let globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { _ in
            Task { @MainActor [weak self] in
                self?.closeDashboard()
            }
        }

        let localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { event in
            let consumeEvent = MainActor.assumeIsolated { [weak self] () -> Bool in
                guard let self else { return false }
                if event.type == .keyDown {
                    guard event.keyCode == 53 else { return false }
                    self.closeDashboard()
                    return true
                }
                // Clicks on the status item itself are left to the button's
                // toggle action so they don't close-then-reopen the panel.
                if event.window == self.dashboardPanel
                    || event.window == self.statusItem.button?.window
                {
                    return false
                }
                self.closeDashboard()
                return false
            }
            return consumeEvent ? nil : event
        }

        dismissMonitors = [globalMonitor, localMonitor].compactMap { $0 }
    }

    private func removeDismissMonitors() {
        dismissMonitors.forEach { NSEvent.removeMonitor($0) }
        dismissMonitors.removeAll()
    }

    private func setupPersistentHostingView() {
        guard let button = statusItem.button else { return }

        let rootView = StatusBarContentView(viewModel: viewModel)
            .allowsHitTesting(false)
        let hosting = NSHostingView(rootView: rootView)

        button.subviews.forEach { $0.removeFromSuperview() }
        button.title = ""
        button.image = nil
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        hosting.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: button.topAnchor, constant: 4),
            hosting.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -4),
            hosting.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 7),
            hosting.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -7),
        ])
    }

    private func startDisplayObservation() {
        displayObservation = Task { [weak self] in
            for await _ in Defaults.updates(
                [.menuBarReadoutStyle, .batteryPercentageDisplayLocation],
                initial: true
            ) {
                self?.updateStatusItemLength()
            }
        }
    }

    private func updateStatusItemLength() {
        switch Defaults[.menuBarReadoutStyle] {
        case .batteryPercentage:
            switch Defaults[.batteryPercentageDisplayLocation] {
            case .hidden:
                statusItem.length = 38
            case .insideIcon:
                statusItem.length = 44
            case .nextToIcon:
                statusItem.length = 64
            }
        case .systemPower:
            statusItem.length = 88
        case .batteryAndPower:
            statusItem.length = 126
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if let panel = dashboardPanel, panel.isVisible {
            closeDashboard()
        } else {
            showDashboard()
        }
    }

    func showPopoverForPreview() {
        guard dashboardPanel?.isVisible != true else { return }
        NSApp.activate(ignoringOtherApps: true)
        showDashboard()
    }

    func showWindowForPreview() {
        guard previewWindow == nil else { return }

        let hostingController = NSHostingController(rootView: makeDashboardRootView())
        let panel = AidenteFloatingPanel(contentViewController: hostingController)
        panel.styleMask = [.borderless]
        panel.setContentSize(NSSize(width: 408, height: 720))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.isReleasedWhenClosed = false
        if let screen = NSScreen.screens.first {
            let visibleFrame = screen.visibleFrame
            panel.setFrameOrigin(
                NSPoint(
                    x: visibleFrame.midX - 204,
                    y: visibleFrame.midY - 360
                )
            )
        } else {
            panel.center()
        }

        hostingController.view.wantsLayer = true
        hostingController.view.layer?.cornerRadius = 15
        hostingController.view.layer?.masksToBounds = true

        previewWindow = panel
        viewModel.menuWillOpen()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    deinit {
        displayObservation?.cancel()
    }
}

private final class AidenteFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

struct StatusBarContentView: View {
    let viewModel: MenuViewModel
    @Default(.batteryPercentageDisplayLocation) var percentageDisplayLocation
    @Default(.menuBarReadoutStyle) var readoutStyle
    @Default(.showBatteryStateInStatusIcon) var showState

    var body: some View {
        HStack(spacing: 5) {
            BatteryIndicatorView(
                batteryLevel: viewModel.displayPercentage,
                chargingMode: viewModel.chargingMode,
                isLowPowerModeEnabled: viewModel.isLowPowerModeEnabled,
                percentageDisplayLocation: batteryIndicatorLocation,
                showState: showState
            )

            switch readoutStyle {
            case .batteryPercentage:
                EmptyView()
            case .systemPower:
                Text(formattedPower)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            case .batteryAndPower:
                Text("\(viewModel.displayPercentage)% · \(formattedPower)")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .fixedSize()
    }

    private var batteryIndicatorLocation: PercentageDisplayLocation {
        readoutStyle == .batteryPercentage ? percentageDisplayLocation : .hidden
    }

    private var formattedPower: String {
        String(format: "%.2fW", abs(viewModel.systemPower))
    }
}
