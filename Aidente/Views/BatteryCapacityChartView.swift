import Defaults
import SwiftUI

enum CapacityHistoryRange: String, CaseIterable, Identifiable {
    case month
    case year
    case all

    var id: String { rawValue }

    var duration: TimeInterval? {
        switch self {
        case .month: 30 * 24 * 60 * 60
        case .year: 365 * 24 * 60 * 60
        case .all: nil
        }
    }

    var title: String {
        switch self {
        case .month: AidenteL10n.t("30 天", "30 Days")
        case .year: AidenteL10n.t("1 年", "1 Year")
        case .all: AidenteL10n.t("全部", "All")
        }
    }
}

struct BatteryCapacityChartView: View {
    @Default(.appLanguage) private var appLanguage

    let samples: [BatteryCapacitySample]
    let range: CapacityHistoryRange

    private var visibleSamples: [BatteryCapacitySample] {
        let filtered: [BatteryCapacitySample]
        if let duration = range.duration {
            let cutoff = Date().addingTimeInterval(-duration)
            filtered = samples.filter { $0.timestamp >= cutoff }
        } else {
            filtered = samples
        }
        guard filtered.count > 120 else { return filtered }

        let step = max(1, filtered.count / 120)
        var downsampled = filtered.enumerated().compactMap { index, sample in
            index % step == 0 ? sample : nil
        }
        if downsampled.last?.id != filtered.last?.id, let last = filtered.last {
            downsampled.append(last)
        }
        return downsampled
    }

    var body: some View {
        GeometryReader { geometry in
            let plotSize = CGSize(
                width: max(1, geometry.size.width - 34),
                height: max(1, geometry.size.height - 20)
            )
            let plotOrigin = CGPoint(x: 30, y: 2)
            let maximumValue = chartMaximum

            ZStack(alignment: .topLeading) {
                ForEach(0..<4, id: \.self) { index in
                    let y = plotOrigin.y + plotSize.height * CGFloat(index) / 3
                    Path { path in
                        path.move(to: CGPoint(x: plotOrigin.x, y: y))
                        path.addLine(
                            to: CGPoint(x: plotOrigin.x + plotSize.width, y: y)
                        )
                    }
                    .stroke(.white.opacity(index == 3 ? 0.14 : 0.07), lineWidth: 1)
                }

                if designCapacity > 0 {
                    Path { path in
                        let y = yPosition(
                            value: Double(designCapacity),
                            maximumValue: maximumValue,
                            plotOrigin: plotOrigin,
                            plotSize: plotSize
                        )
                        path.move(to: CGPoint(x: plotOrigin.x, y: y))
                        path.addLine(
                            to: CGPoint(x: plotOrigin.x + plotSize.width, y: y)
                        )
                    }
                    .stroke(
                        AidenteTheme.violet.opacity(0.72),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
                }

                if visibleSamples.count >= 2 {
                    currentCapacityFillPath(
                        plotOrigin: plotOrigin,
                        plotSize: plotSize,
                        maximumValue: maximumValue
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                AidenteTheme.jade.opacity(0.25),
                                AidenteTheme.jade.opacity(0.01),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    capacityPath(
                        keyPath: \.estimatedFullChargeCapacityMilliampHours,
                        plotOrigin: plotOrigin,
                        plotSize: plotSize,
                        maximumValue: maximumValue
                    )
                    .stroke(AidenteTheme.ocean, lineWidth: 1.8)

                    capacityPath(
                        keyPath: \.currentCapacityMilliampHours,
                        plotOrigin: plotOrigin,
                        plotSize: plotSize,
                        maximumValue: maximumValue
                    )
                    .stroke(AidenteTheme.jade, lineWidth: 2.2)
                } else if let sample = visibleSamples.last {
                    Circle()
                        .fill(AidenteTheme.jade)
                        .frame(width: 7, height: 7)
                        .position(
                            x: plotOrigin.x + plotSize.width / 2,
                            y: yPosition(
                                value: Double(sample.currentCapacityMilliampHours),
                                maximumValue: maximumValue,
                                plotOrigin: plotOrigin,
                                plotSize: plotSize
                            )
                        )
                }

                Text("\(Int(maximumValue.rounded()))")
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .position(x: 14, y: plotOrigin.y + 4)

                Text("0")
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .position(x: 14, y: plotOrigin.y + plotSize.height - 4)

                Text("mAh")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .position(x: 14, y: plotOrigin.y + plotSize.height / 2)

                Text(formattedDate(timeBounds.start))
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .position(
                        x: plotOrigin.x + 20,
                        y: plotOrigin.y + plotSize.height + 11
                    )

                Text(formattedDate(timeBounds.end))
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .position(
                        x: plotOrigin.x + plotSize.width - 20,
                        y: plotOrigin.y + plotSize.height + 11
                    )

                if visibleSamples.count < 2 {
                    Text(AidenteL10n.t("正在积累容量历史…", "Building capacity history…"))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .position(
                            x: plotOrigin.x + plotSize.width / 2,
                            y: plotOrigin.y + plotSize.height / 2
                        )
                }
            }
        }
        .frame(height: 112)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AidenteL10n.t("电池容量趋势", "Battery Capacity Trend"))
        .accessibilityValue(accessibilitySummary)
    }

    private var designCapacity: Int {
        visibleSamples.last?.designCapacityMilliampHours
            ?? samples.last?.designCapacityMilliampHours
            ?? 0
    }

    private var chartMaximum: Double {
        let values = visibleSamples.flatMap {
            [
                $0.currentCapacityMilliampHours,
                $0.estimatedFullChargeCapacityMilliampHours,
                $0.designCapacityMilliampHours,
            ]
        }
        return max(Double(values.max() ?? designCapacity), 1) * 1.05
    }

    private var timeBounds: (start: Date, end: Date) {
        guard let first = visibleSamples.first?.timestamp,
              let last = visibleSamples.last?.timestamp,
              last > first else {
            let now = Date()
            return (now.addingTimeInterval(-(range.duration ?? 30 * 24 * 60 * 60)), now)
        }
        return (first, last)
    }

    private func capacityPath(
        keyPath: KeyPath<BatteryCapacitySample, Int>,
        plotOrigin: CGPoint,
        plotSize: CGSize,
        maximumValue: Double
    ) -> Path {
        Path { path in
            for (index, sample) in visibleSamples.enumerated() {
                let point = point(
                    for: sample,
                    value: Double(sample[keyPath: keyPath]),
                    plotOrigin: plotOrigin,
                    plotSize: plotSize,
                    maximumValue: maximumValue
                )
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }

    private func currentCapacityFillPath(
        plotOrigin: CGPoint,
        plotSize: CGSize,
        maximumValue: Double
    ) -> Path {
        Path { path in
            guard let first = visibleSamples.first,
                  let last = visibleSamples.last else { return }
            let firstPoint = point(
                for: first,
                value: Double(first.currentCapacityMilliampHours),
                plotOrigin: plotOrigin,
                plotSize: plotSize,
                maximumValue: maximumValue
            )
            path.move(to: CGPoint(x: firstPoint.x, y: plotOrigin.y + plotSize.height))
            path.addLine(to: firstPoint)
            for sample in visibleSamples.dropFirst() {
                path.addLine(
                    to: point(
                        for: sample,
                        value: Double(sample.currentCapacityMilliampHours),
                        plotOrigin: plotOrigin,
                        plotSize: plotSize,
                        maximumValue: maximumValue
                    )
                )
            }
            let lastPoint = point(
                for: last,
                value: Double(last.currentCapacityMilliampHours),
                plotOrigin: plotOrigin,
                plotSize: plotSize,
                maximumValue: maximumValue
            )
            path.addLine(to: CGPoint(x: lastPoint.x, y: plotOrigin.y + plotSize.height))
            path.closeSubpath()
        }
    }

    private func point(
        for sample: BatteryCapacitySample,
        value: Double,
        plotOrigin: CGPoint,
        plotSize: CGSize,
        maximumValue: Double
    ) -> CGPoint {
        let bounds = timeBounds
        let duration = max(bounds.end.timeIntervalSince(bounds.start), 1)
        let elapsed = sample.timestamp.timeIntervalSince(bounds.start)
        let x = plotOrigin.x + plotSize.width * CGFloat(elapsed / duration)
        let y = yPosition(
            value: value,
            maximumValue: maximumValue,
            plotOrigin: plotOrigin,
            plotSize: plotSize
        )
        return CGPoint(x: x, y: y)
    }

    private func yPosition(
        value: Double,
        maximumValue: Double,
        plotOrigin: CGPoint,
        plotSize: CGSize
    ) -> CGFloat {
        let normalized = min(max(value / maximumValue, 0), 1)
        return plotOrigin.y + plotSize.height * CGFloat(1 - normalized)
    }

    private var accessibilitySummary: String {
        guard let latest = visibleSamples.last ?? samples.last else {
            return AidenteL10n.t("暂无容量历史", "No capacity history yet")
        }
        return AidenteL10n.t(
            "当前容量 \(latest.currentCapacityMilliampHours) 毫安时，估算满充 \(latest.estimatedFullChargeCapacityMilliampHours) 毫安时，设计容量 \(latest.designCapacityMilliampHours) 毫安时",
            "Current \(latest.currentCapacityMilliampHours) milliamp-hours, estimated full \(latest.estimatedFullChargeCapacityMilliampHours) milliamp-hours, design \(latest.designCapacityMilliampHours) milliamp-hours"
        )
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AidenteL10n.isEnglish ? "en_US" : "zh_CN")
        formatter.dateFormat = AidenteL10n.isEnglish ? "MMM d" : "M/d"
        return formatter.string(from: date)
    }
}
