import SwiftUI

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
        if isCritical { return .red }
        if isLowPowerModeEnabled { return .yellow }
        if chargingMode == .charging { return AidenteTheme.mint }
        if showState && chargingMode == .pluggedIn { return AidenteTheme.ocean }
        if showState { return AidenteTheme.jade }
        return .primary
    }

    private var filledTextColor: Color {
        if !showState && !isLowPowerModeEnabled && chargingMode != .charging {
            return Color(nsColor: .textBackgroundColor)
        }
        return .black.opacity(0.85)
    }

    private enum Layout {
        static let batteryHeight: CGFloat = 17
        static let batteryWidth: CGFloat = 11
        static let insideBatteryHeight: CGFloat = 17
        static let insideBatteryWidth: CGFloat = 17
        static let terminalWidth: CGFloat = 5
        static let terminalHeight: CGFloat = 2
        static let cornerRadius: CGFloat = 2.5
        static let insideCornerRadius: CGFloat = 2.5
        static let strokeWidth: CGFloat = 1
        static let fillInset: CGFloat = 1.5
        static let outlineOpacity: CGFloat = 0.4
        static let insideTrackColor = Color(nsColor: .tertiaryLabelColor)
        static let levelAnimation: Animation = .easeInOut(duration: 0.25)
    }

    var body: some View {
        HStack(spacing: 2) {
            if shouldShowOutsidePercentage {
                Text("\(batteryLevel)%")
                    .font(.system(size: 11))
                    .monospacedDigit()
            }

            VStack(spacing: 1) {
                BatteryTerminal(
                    width: Layout.terminalWidth,
                    height: Layout.terminalHeight,
                    cornerRadius: 1
                )
                batteryBody
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

    @ViewBuilder
    private var batteryBody: some View {
        if shouldShowInsidePercentage {
            knockoutBatteryBody
                .frame(width: Layout.insideBatteryWidth, height: Layout.insideBatteryHeight)
        } else {
            overlayBatteryBody
                .frame(width: Layout.batteryWidth, height: Layout.batteryHeight)
        }
    }

    private var knockoutBatteryBody: some View {
        ZStack {
            Rectangle()
                .fill(Layout.insideTrackColor)

            GeometryReader { geo in
                Rectangle()
                    .fill(fillColor)
                    .frame(height: fillHeight(usableHeight: geo.size.height))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .animation(Layout.levelAnimation, value: batteryLevel)
            }

            insideContent.foregroundStyle(.primary)
            insideContent.foregroundStyle(filledTextColor)
                .mask(alignment: .bottom) {
                    Rectangle().frame(height: fillHeight(usableHeight: Layout.insideBatteryHeight))
                }
        }
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: Layout.insideCornerRadius))
    }

    private func fillHeight(usableHeight: CGFloat) -> CGFloat {
        usableHeight * CGFloat(min(100, max(0, batteryLevel))) / 100
    }

    private var insideContent: some View {
        VStack(spacing: 0) {
            Text(verbatim: "\(batteryLevel)")
                .font(.system(size: batteryLevel >= 100 ? 8 : 9, weight: .semibold))
                .monospacedDigit()
                .fixedSize()
            chargingGlyph
        }
        .lineLimit(1)
        .frame(width: Layout.insideBatteryWidth, height: Layout.insideBatteryHeight)
    }

    @ViewBuilder
    private var chargingGlyph: some View {
        if chargingMode == .charging {
            Image(systemName: "bolt.fill")
                .resizable().scaledToFit().frame(width: 4, height: 5)
        } else if chargingMode == .pluggedIn {
            Image(systemName: "powerplug.fill")
                .resizable().scaledToFit().frame(width: 5, height: 5)
        }
    }

    private var overlayBatteryBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .stroke(lineWidth: Layout.strokeWidth)
                .opacity(Layout.outlineOpacity)

            GeometryReader { geo in
                let height = fillHeight(usableHeight: max(0, geo.size.height - Layout.fillInset * 2))
                RoundedRectangle(
                    cornerRadius: Layout.cornerRadius - Layout.fillInset
                )
                .fill(fillColor)
                .frame(height: height)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(Layout.fillInset)
                .animation(Layout.levelAnimation, value: batteryLevel)
            }
        }
        .overlay {
            if chargingMode == .charging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.85))
            } else if chargingMode == .pluggedIn {
                Image(systemName: "powerplug.fill")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
    }
}

struct BatteryTerminal: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: cornerRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: cornerRadius
        )
        .fill(.primary)
        .frame(width: width, height: height)
        .opacity(0.4)
    }
}
