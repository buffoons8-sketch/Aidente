import AppKit
import Defaults
import SwiftUI

@MainActor
final class StatusBarManager: NSObject, NSPopoverDelegate, NSWindowDelegate {
    private let statusItem: NSStatusItem
    private let viewModel: MenuViewModel
    private let settingsWindowController: SettingsWindowController
    private let popover = NSPopover()
    private var displayObservation: Task<Void, Never>?
    private var powerWidthObservation: Task<Void, Never>?
    private var previewWindow: NSWindow?
    private var dashboardWindow: NSWindow?

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

        configurePopoverShell()
        setupPersistentHostingView()
        startDisplayObservation()
    }

    private func configurePopoverShell() {
        popover.contentSize = NSSize(width: 408, height: 720)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    private func preparePopoverContentIfNeeded() {
        guard popover.contentViewController == nil else { return }

        let rootView = makeDashboardRootView()
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
                self.dashboardWindow?.close()
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
            hosting.topAnchor.constraint(equalTo: button.topAnchor, constant: 1),
            hosting.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -1),
            hosting.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: BatteryIndicatorLayout.statusInset),
            hosting.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -BatteryIndicatorLayout.statusInset),
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
        powerWidthObservation = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                updateStatusItemLength()
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.viewModel.systemPower
                        _ = self.viewModel.displayPercentage
                    } onChange: {
                        Task { @MainActor in continuation.resume() }
                    }
                }
            }
        }
    }

    private func updateStatusItemLength() {
        let power = String(format: "%.2fW", abs(viewModel.systemPower))
        let powerWidth = ceil((power as NSString).size(withAttributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)
        ]).width) + 3
        let outerWidth = BatteryIndicatorLayout.statusInset * 2
        let iconWidth = BatteryIndicatorLayout.width(insidePercentage: false) + outerWidth
        let percentageIconWidth = BatteryIndicatorLayout.width(insidePercentage: true) + outerWidth
        switch Defaults[.menuBarReadoutStyle] {
        case .batteryPercentage:
            switch Defaults[.batteryPercentageDisplayLocation] {
            case .hidden:
                statusItem.length = iconWidth
            case .insideIcon:
                statusItem.length = percentageIconWidth
            case .nextToIcon:
                let textWidth = ceil(("\(viewModel.displayPercentage)%" as NSString).size(withAttributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
                ]).width)
                statusItem.length = textWidth + iconWidth + BatteryIndicatorLayout.outsideTextSpacing
            }
        case .systemPower:
            statusItem.length = iconWidth + powerWidth
        case .batteryAndPower:
            statusItem.length = percentageIconWidth + powerWidth
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        if let dashboardWindow, dashboardWindow.isVisible {
            dashboardWindow.close()
            Task { [weak self, weak sender] in
                await Task.yield()
                guard let self, let sender else { return }
                self.presentPopover(relativeTo: sender)
            }
            return
        }

        presentPopover(relativeTo: sender)
    }

    private func presentPopover(relativeTo sender: NSStatusBarButton) {
        preparePopoverContentIfNeeded()
        viewModel.menuWillOpen()
        popover.show(
            relativeTo: sender.bounds,
            of: sender,
            preferredEdge: .minY
        )
        popover.contentViewController?.view.window?.makeKey()
    }

    func showDashboardWindow() {
        if let dashboardWindow {
            NSApp.activate(ignoringOtherApps: true)
            dashboardWindow.makeKeyAndOrderFront(nil)
            dashboardWindow.orderFrontRegardless()
            return
        }

        if popover.isShown {
            popover.performClose(nil)
            Task { [weak self] in
                await Task.yield()
                self?.presentDashboardWindow()
            }
            return
        }

        presentDashboardWindow()
    }

    private func presentDashboardWindow() {
        guard dashboardWindow == nil else { return }

        let hostingController = NSHostingController(rootView: makeDashboardRootView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = AidenteL10n.t("Aidente 主菜单", "Aidente Dashboard")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 408, height: 720))
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        hostingController.view.wantsLayer = true
        hostingController.view.layer?.cornerRadius = 15
        hostingController.view.layer?.masksToBounds = true

        dashboardWindow = window
        viewModel.menuWillOpen()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func showPopoverForPreview() {
        guard let button = statusItem.button, !popover.isShown else { return }
        NSApp.activate(ignoringOtherApps: true)
        preparePopoverContentIfNeeded()
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
        let panel = AidentePreviewPanel(contentViewController: hostingController)
        panel.styleMask = [.borderless]
        panel.setContentSize(NSSize(width: 408, height: 720))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.isReleasedWhenClosed = false
        panel.delegate = self
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
        Task { [weak self] in
            await Task.yield()
            self?.popover.contentViewController = nil
        }
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            guard let closedWindow = notification.object as? NSWindow else { return }
            if closedWindow === dashboardWindow {
                dashboardWindow = nil
                viewModel.menuDidClose()
            } else if closedWindow === previewWindow {
                previewWindow = nil
                viewModel.menuDidClose()
            }
        }
    }

    deinit {
        displayObservation?.cancel()
        powerWidthObservation?.cancel()
    }
}

private final class AidentePreviewPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

struct StatusBarContentView: View {
    let viewModel: MenuViewModel
    @Default(.batteryPercentageDisplayLocation) var percentageDisplayLocation
    @Default(.menuBarReadoutStyle) var readoutStyle
    @Default(.showBatteryStateInStatusIcon) var showState

    var body: some View {
        HStack(spacing: 3) {
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
                Text(formattedPower)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .fixedSize()
        .lineLimit(1)
        .help(AidenteL10n.t(
            "电量 \(viewModel.displayPercentage)% · 系统功率 \(formattedPower)",
            "Battery \(viewModel.displayPercentage)% · System power \(formattedPower)"
        ))
    }

    private var batteryIndicatorLocation: PercentageDisplayLocation {
        switch readoutStyle {
        case .batteryPercentage: percentageDisplayLocation
        case .systemPower: .hidden
        case .batteryAndPower: .insideIcon
        }
    }

    private var formattedPower: String {
        String(format: "%.2fW", abs(viewModel.systemPower))
    }
}
