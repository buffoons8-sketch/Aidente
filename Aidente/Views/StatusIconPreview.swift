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
            ForEach([5, 20, 79, 100], id: \.self) { level in
                VStack(spacing: 12) {
                    BatteryIndicatorView(batteryLevel: level, chargingMode: .discharging,
                                         percentageDisplayLocation: .insideIcon, showState: true)
                    BatteryIndicatorView(batteryLevel: level, chargingMode: .charging,
                                         percentageDisplayLocation: .insideIcon, showState: true)
                    BatteryIndicatorView(batteryLevel: level, chargingMode: .pluggedIn,
                                         percentageDisplayLocation: .insideIcon, showState: true)
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
                    .border(Color.orange.opacity(0.4))
                }
            }
        }
        .padding(24)
        .background(dark ? Color(white: 0.12) : Color(white: 0.96))
        .environment(\.colorScheme, dark ? .dark : .light)
    }
}
