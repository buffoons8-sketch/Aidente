import SwiftUI

/// Shared geometry keeps the menu-bar allocation aligned with the rendered icon.
enum BatteryIndicatorLayout {
    static let bodyWidth: CGFloat = 16
    static let bodyHeight: CGFloat = 10
    static let insideBodyWidth: CGFloat = 22
    static let insideBodyHeight: CGFloat = 12
    static let terminalWidth: CGFloat = 1.5
    static let terminalHeight: CGFloat = 4
    static let terminalSpacing: CGFloat = 0.5
    static let outsideTextSpacing: CGFloat = 2
    static let statusInset: CGFloat = 1

    static func width(insidePercentage: Bool) -> CGFloat {
        (insidePercentage ? insideBodyWidth : bodyWidth) + terminalSpacing + terminalWidth
    }
}

struct BatteryIndicatorView: View {
    let batteryLevel: Int
    let chargingMode: ChargingMode
    var isLowPowerModeEnabled: Bool = false
    var percentageDisplayLocation: PercentageDisplayLocation = .hidden
    var showState: Bool = false

    private var shouldShowInsidePercentage: Bool {
        percentageDisplayLocation == .insideIcon
    }

    private var shouldShowOutsidePercentage: Bool {
        percentageDisplayLocation == .nextToIcon
    }

    private var isCritical: Bool {
        showState && batteryLevel <= 20
    }

    private var fillColor: Color {
        if isCritical { return Color(red: 0.99, green: 0.62, blue: 0.66) }
        if isLowPowerModeEnabled { return AidenteTheme.gold }
        if chargingMode == .charging { return AidenteTheme.mint }
        if showState && chargingMode == .pluggedIn { return AidenteTheme.sky }
        if showState { return AidenteTheme.jade }
        return Color(red: 0.62, green: 0.70, blue: 0.78)
    }

    private enum Layout {
        static let cornerRadius: CGFloat = 2
        static let strokeWidth: CGFloat = 0.75
        static let outlineOpacity: CGFloat = 0.5
        static let trackColor = Color(red: 0.84, green: 0.88, blue: 0.92)
        static let contentColor = Color(red: 0.10, green: 0.14, blue: 0.20)
        static let levelAnimation: Animation = .easeInOut(duration: 0.25)
    }

    var body: some View {
        HStack(spacing: BatteryIndicatorLayout.outsideTextSpacing) {
            if shouldShowOutsidePercentage {
                Text("\(batteryLevel)%")
                    .font(.system(size: 11))
                    .monospacedDigit()
            }

            HStack(spacing: BatteryIndicatorLayout.terminalSpacing) {
                batteryBody
                BatteryTerminal(
                    width: BatteryIndicatorLayout.terminalWidth,
                    height: BatteryIndicatorLayout.terminalHeight,
                    cornerRadius: 0.5
                )
            }
        }
        .foregroundStyle(.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = [
            AidenteL10n.t(
                "电池电量 \(batteryLevel)%",
                "Battery level \(batteryLevel)%"
            )
        ]
        switch chargingMode {
        case .charging: parts.append(AidenteL10n.t("正在充电"))
        case .pluggedIn: parts.append(AidenteL10n.t("已接通电源", "Plugged In"))
        case .discharging: break
        }
        if isLowPowerModeEnabled {
            parts.append(AidenteL10n.t("低电量模式", "Low Power Mode"))
        }
        return parts.joined(separator: "，")
    }

    private var batteryBody: some View {
        ZStack {
            Rectangle()
                .fill(Layout.trackColor)

            GeometryReader { geo in
                Rectangle()
                    .fill(fillColor)
                    .frame(width: fillWidth(usableWidth: geo.size.width))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(Layout.levelAnimation, value: batteryLevel)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .strokeBorder(.primary.opacity(Layout.outlineOpacity), lineWidth: Layout.strokeWidth)
        }
        .overlay {
            if shouldShowInsidePercentage {
                insideContent
            } else {
                chargingGlyph
            }
        }
        .foregroundStyle(Layout.contentColor)
        .frame(
            width: shouldShowInsidePercentage ? BatteryIndicatorLayout.insideBodyWidth : BatteryIndicatorLayout.bodyWidth,
            height: shouldShowInsidePercentage ? BatteryIndicatorLayout.insideBodyHeight : BatteryIndicatorLayout.bodyHeight
        )
    }

    private func fillWidth(usableWidth: CGFloat) -> CGFloat {
        usableWidth * CGFloat(min(100, max(0, batteryLevel))) / 100
    }

    private var insideContent: some View {
        HStack(spacing: 0.5) {
            Text(verbatim: "\(batteryLevel)")
                .font(.system(size: batteryLevel >= 100 ? 8.2 : 9, weight: .semibold))
                .monospacedDigit()
                .fixedSize()
            chargingGlyph
        }
        .lineLimit(1)
        .fixedSize()
    }

    @ViewBuilder
    private var chargingGlyph: some View {
        if chargingMode == .charging {
            Image(systemName: "bolt.fill")
                .resizable().scaledToFit().frame(width: 3.5, height: 6)
        } else if chargingMode == .pluggedIn {
            Image(systemName: "powerplug.fill")
                .resizable().scaledToFit().frame(width: 4.2, height: 6)
        }
    }
}

struct BatteryTerminal: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: cornerRadius,
            topTrailingRadius: cornerRadius
        )
        .fill(.primary)
        .frame(width: width, height: height)
        .opacity(0.55)
    }
}
