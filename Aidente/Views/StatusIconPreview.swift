import AppKit
import SwiftUI

/// A hardware-free rendering fixture using the exact production SwiftUI icon.
@MainActor enum StatusIconPreview {
    static func render(to path: String) throws {
        let content = VStack(spacing: 0) {
            row(dark: false)
            row(dark: true)
        }
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try png.write(to: URL(fileURLWithPath: path))
    }

    private static func row(dark: Bool) -> some View {
        HStack(spacing: 20) {
            ForEach([0, 5, 50, 79, 100], id: \.self) { level in
                VStack(spacing: 12) {
                    insideIcon(level: level, mode: .discharging)
                    insideIcon(level: level, mode: .charging)
                    insideIcon(level: level, mode: .pluggedIn)
                    BatteryIndicatorView(batteryLevel: level, chargingMode: .pluggedIn,
                                         percentageDisplayLocation: .nextToIcon, showState: true)
                }
                .frame(width: 65)
            }
            VStack(spacing: 12) {
                ForEach([18.13, 99.99, 140.00], id: \.self) { power in
                    HStack(spacing: 3) {
                        BatteryIndicatorView(batteryLevel: 100, chargingMode: .charging,
                                             percentageDisplayLocation: .insideIcon, showState: true)
                        Text(String(format: "%.2fW", power))
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1).fixedSize()
                    }
                    .fixedSize()
                    .padding(.horizontal, BatteryIndicatorLayout.statusInset)
                    .border(Color.orange.opacity(0.4))
                }
            }
            VStack(spacing: 12) {
                insideIcon(level: 50, mode: .discharging, lowPower: true)
                insideIcon(level: 50, mode: .discharging, showState: false)
                insideIcon(level: 100, mode: .pluggedIn, showState: false)
                BatteryIndicatorView(batteryLevel: 50, chargingMode: .charging,
                                     percentageDisplayLocation: .hidden, showState: true)
            }
        }
        .padding(24)
        .background(dark ? Color(white: 0.12) : Color(white: 0.96))
        .environment(\.colorScheme, dark ? .dark : .light)
    }

    private static func insideIcon(level: Int, mode: ChargingMode,
                                   lowPower: Bool = false, showState: Bool = true) -> some View {
        BatteryIndicatorView(batteryLevel: level, chargingMode: mode,
                             isLowPowerModeEnabled: lowPower,
                             percentageDisplayLocation: .insideIcon, showState: showState)
            .padding(.horizontal, BatteryIndicatorLayout.statusInset)
            .frame(width: BatteryIndicatorLayout.width(insidePercentage: true)
                    + BatteryIndicatorLayout.statusInset * 2, height: 22)
            .clipped()
            .border(Color.orange.opacity(0.18))
    }
}
