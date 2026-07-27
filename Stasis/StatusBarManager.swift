import AppKit
import Defaults
import SwiftUI

@MainActor
final class StatusBarManager: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let viewModel: MenuViewModel
    private let settingsWindowController: SettingsWindowController
    private let popover = NSPopover()
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

        configurePopover()
        setupPersistentHostingView()
        startDisplayObservation()
    }

    private func configurePopover() {
        let rootView = makeDashboardRootView()

        popover.contentSize = NSSize(width: 408, height: 720)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: rootView)
        popover.contentViewController?.view.wantsLayer = true
        popover.contentViewController?.view.layer?.cornerRadius = 15
        popover.contentViewController?.view.layer?.masksToBounds = true
    }

    private func makeDashboardRootView() -> DashboardPopoverView {
        DashboardPopoverView(
            viewModel: viewModel,
            onOpenSettings: { [weak self] tab in
                guard let self else { return }
                self.popover.performClose(nil)
                self.previewWindow?.close()
                self.settingsWindowController.showSettings(tab: tab)
            },
            onQuit: { [weak self] in
                self?.viewModel.quit()
            }
        )
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
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        viewModel.menuWillOpen()
        popover.show(
            relativeTo: sender.bounds,
            of: sender,
            preferredEdge: .minY
        )
        popover.contentViewController?.view.window?.makeKey()
    }

    func showPopoverForPreview() {
        guard let button = statusItem.button, !popover.isShown else { return }
        NSApp.activate(ignoringOtherApps: true)
        viewModel.menuWillOpen()
        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )
        popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
    }

    func showWindowForPreview() {
        guard previewWindow == nil else { return }

        let hostingController = NSHostingController(rootView: makeDashboardRootView())
        let panel = IadentePreviewPanel(contentViewController: hostingController)
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

    func popoverDidClose(_ notification: Notification) {
        viewModel.menuDidClose()
    }

    deinit {
        displayObservation?.cancel()
    }
}

private final class IadentePreviewPanel: NSPanel {
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
