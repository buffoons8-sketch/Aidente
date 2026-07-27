import AppKit
import Defaults
import SwiftUI

enum IadenteTheme {
    static let jade = Color(red: 0.18, green: 0.84, blue: 0.50)
    static let mint = Color(red: 0.40, green: 0.92, blue: 0.68)
    static let ocean = Color(red: 0.24, green: 0.56, blue: 0.98)
    static let sky = Color(red: 0.36, green: 0.74, blue: 0.98)
    static let violet = Color(red: 0.55, green: 0.42, blue: 0.98)
    static let pink = Color(red: 0.90, green: 0.38, blue: 0.86)
    static let amber = Color(red: 1.00, green: 0.59, blue: 0.18)
    static let gold = Color(red: 1.00, green: 0.76, blue: 0.27)
    static let coral = Color(red: 0.98, green: 0.34, blue: 0.30)
    static let graphite = Color(red: 0.11, green: 0.12, blue: 0.14)
    static let panel = Color(red: 0.13, green: 0.13, blue: 0.14)

    static let generalColors = [ocean, sky]
    static let dashboardColors = [violet, pink]
    static let chargingColors = [jade, mint]
    static let automationColors = [amber, gold]
    static let advancedColors = [Color.indigo, violet]
    static let aboutColors = [coral, amber]
}

struct IadenteVisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
    }
}

struct IadenteMaterialLayer: View {
    @Default(.interfaceMaterialStyle) private var materialStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            switch materialStyle {
            case .solid:
                Color(
                    nsColor: colorScheme == .dark
                        ? NSColor(calibratedWhite: 0.105, alpha: 1)
                        : NSColor(calibratedWhite: 0.975, alpha: 1)
                )
            case .glass:
                Rectangle()
                    .fill(.regularMaterial)
                Color.black.opacity(colorScheme == .dark ? 0.04 : 0.01)
            case .frosted:
                IadenteVisualEffectView(
                    material: .hudWindow,
                    blendingMode: .behindWindow
                )
                Color(
                    red: 0.065,
                    green: 0.052,
                    blue: 0.043
                )
                .opacity(colorScheme == .dark ? 0.58 : 0.08)
            }
        }
    }
}

struct IadenteWindowBackdrop: View {
    @Default(.interfaceMaterialStyle) private var materialStyle
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            switch materialStyle {
            case .solid:
                Color(
                    nsColor: colorScheme == .dark
                        ? NSColor(calibratedRed: 0.10, green: 0.095, blue: 0.09, alpha: 1)
                        : NSColor(calibratedWhite: 0.96, alpha: 1)
                )
            case .glass:
                IadenteVisualEffectView(
                    material: .popover,
                    blendingMode: .behindWindow
                )
                Color(
                    red: 0.08,
                    green: 0.065,
                    blue: 0.05
                )
                .opacity(colorScheme == .dark ? 0.22 : 0.035)
            case .frosted:
                IadenteVisualEffectView(
                    material: .underWindowBackground,
                    blendingMode: .behindWindow
                )
                Color(
                    red: 0.07,
                    green: 0.055,
                    blue: 0.045
                )
                .opacity(colorScheme == .dark ? 0.50 : 0.085)
            }

            LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        Color.white.opacity(0.035),
                        Color(red: 0.17, green: 0.14, blue: 0.10).opacity(0.20),
                        Color.black.opacity(0.18),
                    ]
                    : [
                        Color.white.opacity(0.34),
                        IadenteTheme.jade.opacity(0.025),
                        Color.black.opacity(0.025),
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

struct IadenteSettingsBackground: View {
    var body: some View {
        IadenteWindowBackdrop()
    }
}

struct IadenteIconBadge: View {
    let icon: String
    let colors: [Color]
    var size: CGFloat = 36
    var cornerRadius: CGFloat? = nil

    private var tint: Color { colors.first ?? IadenteTheme.jade }
    private var iconTint: Color { colors.last ?? tint }

    var body: some View {
        let radius = cornerRadius ?? max(7, size * 0.27)

        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint.opacity(0.16))
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(tint.opacity(0.34), lineWidth: 1)
            Image(systemName: icon)
                .font(.system(size: size * 0.46, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(iconTint)
        }
        .frame(width: size, height: size)
        .shadow(color: tint.opacity(0.16), radius: 4, y: 2)
    }
}

struct IadenteSectionHeader: View {
    @Default(.appLanguage) private var appLanguage

    let title: String
    let subtitle: String?
    let icon: String
    let colors: [Color]

    init(
        _ title: String,
        subtitle: String? = nil,
        icon: String,
        colors: [Color]
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.colors = colors
    }

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            IadenteIconBadge(icon: icon, colors: colors, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(IadenteL10n.t(title))
                    .font(.system(size: 14, weight: .semibold))
                if let subtitle {
                    Text(IadenteL10n.t(subtitle))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

struct IadenteCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String?
    let icon: String
    let colors: [Color]
    @ViewBuilder let content: Content

    init(
        _ title: String,
        subtitle: String? = nil,
        icon: String,
        colors: [Color],
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.colors = colors
        self.content = content()
    }

    private var tint: Color { colors.first ?? IadenteTheme.jade }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            IadenteSectionHeader(
                title,
                subtitle: subtitle,
                icon: icon,
                colors: colors
            )

            Rectangle()
                .fill(.primary.opacity(0.10))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 11) {
                content
            }
        }
        .padding(16)
        .background {
            IadenteMaterialLayer()
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(colorScheme == .dark ? 0.13 : 0.60),
                            tint.opacity(0.13),
                            .black.opacity(0.10),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.22 : 0.10),
            radius: 8,
            y: 3
        )
    }
}

struct IadenteSettingsPage<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                content
            }
            .padding(20)
            .frame(maxWidth: 740)
            .frame(maxWidth: .infinity)
        }
        .background(Color.clear)
        .tint(IadenteTheme.jade)
    }
}

struct IadenteSettingToggle: View {
    @Default(.appLanguage) private var appLanguage

    let title: String
    let subtitle: String?
    let icon: String
    let colors: [Color]
    @Binding var isOn: Bool

    init(
        _ title: String,
        subtitle: String? = nil,
        icon: String,
        colors: [Color],
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.colors = colors
        _isOn = isOn
    }

    var body: some View {
        HStack(spacing: 10) {
            IadenteIconBadge(icon: icon, colors: colors, size: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(IadenteL10n.t(title))
                    .font(.system(size: 13, weight: .medium))
                if let subtitle {
                    Text(IadenteL10n.t(subtitle))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(colors.first ?? IadenteTheme.jade)
        }
        .padding(.vertical, 2)
    }
}

struct IadenteControlRow<Trailing: View>: View {
    @Default(.appLanguage) private var appLanguage

    let title: String
    let subtitle: String?
    let icon: String
    let colors: [Color]
    @ViewBuilder let trailing: Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        icon: String,
        colors: [Color],
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.colors = colors
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 10) {
            IadenteIconBadge(icon: icon, colors: colors, size: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(IadenteL10n.t(title))
                    .font(.system(size: 13, weight: .medium))
                if let subtitle {
                    Text(IadenteL10n.t(subtitle))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)
            trailing
        }
        .padding(.vertical, 2)
    }
}

struct IadenteRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.09))
            .frame(height: 1)
    }
}

struct IadenteNotice: View {
    @Default(.appLanguage) private var appLanguage

    let text: String
    var icon = "exclamationmark.triangle.fill"
    var colors = [IadenteTheme.amber, IadenteTheme.gold]

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            IadenteIconBadge(icon: icon, colors: colors, size: 26)
            Text(IadenteL10n.t(text))
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill((colors.first ?? IadenteTheme.amber).opacity(0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder((colors.first ?? IadenteTheme.amber).opacity(0.20))
        )
    }
}

struct IadenteActionButtonStyle: ButtonStyle {
    let colors: [Color]

    private var tint: Color { colors.first ?? IadenteTheme.ocean }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.13 : 0.20))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(tint.opacity(0.34), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct IadenteInsetPanel<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(.primary.opacity(0.09), lineWidth: 1)
            }
    }
}
