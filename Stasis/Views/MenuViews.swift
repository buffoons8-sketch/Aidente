import Defaults
import SwiftUI

struct BatteryMainInfo: View {
    @Default(.appLanguage) private var appLanguage

    let label: String
    let value: String
    let status: String

    var body: some View {
        HStack(spacing: 13) {
            IadenteIconBadge(
                icon: "battery.100.bolt",
                colors: [
                    IadenteTheme.jade,
                    IadenteTheme.mint,
                    IadenteTheme.gold,
                ],
                size: 46,
                cornerRadius: 14
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(IadenteL10n.t(label))
                    .font(.headline)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            Text(value)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [IadenteTheme.jade, IadenteTheme.ocean],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .white.opacity(0.75), radius: 0.5, y: 1)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.42),
                                    IadenteTheme.jade.opacity(0.10),
                                    IadenteTheme.ocean.opacity(0.07),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.82), IadenteTheme.jade.opacity(0.26)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .shadow(color: .black.opacity(0.17), radius: 6, y: 3)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
    }
}

struct BatteryAdditionalInfo: View {
    @Default(.appLanguage) private var appLanguage

    let label: String
    let value: String
    let icon: String
    let colors: [Color]

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            IadenteIconBadge(icon: icon, colors: colors, size: 25)

            Text(IadenteL10n.t(label))
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.callout.weight(.medium))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .foregroundStyle(.primary)
        }
        .font(.callout)
        .padding(.horizontal, 13)
        .padding(.vertical, 4)
    }
}
