import SwiftUI

struct PowerSankeyView: View {
    let powerSource: PowerSource
    let isCharging: Bool
    let batteryPower: Double
    let adapterPower: Double
    let systemPower: Double

    private enum Layout {
        static let nodeWidth: CGFloat = 60
        static let gap: CGFloat = 5
        static let spacerHeight: CGFloat = 20
        static let largeNodeHeight: CGFloat = 100
        static let viewHeight: CGFloat = 125
        static let flowOpacity: Double = 0.20
        static let powerLabelSize: CGFloat = 13
        static let powerLabelSpacing: CGFloat = 45
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                flowsAndLabels

                HStack {
                    leftNodes
                    Spacer()
                    rightNodes
                }
            }
        }
        .frame(height: Layout.viewHeight)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var flowsAndLabels: some View {
        switch powerSource {
        case .acAdapter:
            if batteryPower > 0 {
                Canvas { context, size in
                    drawSplitSankeyFlow(context: context, size: size)
                }
                VStack(spacing: Layout.powerLabelSpacing) {
                    PowerLabel(power: batteryPower)
                    PowerLabel(power: systemPower)
                }
            } else {
                Canvas { context, size in
                    drawSimpleFlow(context: context, size: size)
                }
                PowerLabel(power: adapterPower)
            }

        case .both:
            Canvas { context, size in
                drawMergeSankeyFlow(context: context, size: size)
            }
            VStack(spacing: Layout.powerLabelSpacing) {
                PowerLabel(power: batteryPower)
                PowerLabel(power: adapterPower)
            }

        case .battery:
            Canvas { context, size in
                drawSimpleFlow(context: context, size: size)
            }
            PowerLabel(power: systemPower)
        }
    }

    @ViewBuilder
    private var leftNodes: some View {
        VStack {
            switch powerSource {
            case .acAdapter:
                if batteryPower > 0 {
                    NodeView(
                        icon: "bolt.fill",
                        value: abs(adapterPower),
                        isLeftSide: true
                    )
                    .frame(height: Layout.largeNodeHeight)
                } else {
                    NodeView(
                        icon: "powerplug.fill",
                        value: nil,
                        isLeftSide: true
                    )
                }
            case .both:
                NodeView(icon: "battery.100", value: nil, isLeftSide: true)
                Spacer(minLength: Layout.spacerHeight)
                NodeView(icon: "powerplug.fill", value: nil, isLeftSide: true)
            case .battery:
                NodeView(icon: "battery.100", value: nil, isLeftSide: true)
            }
        }
    }

    @ViewBuilder
    private var rightNodes: some View {
        VStack {
            switch powerSource {
            case .acAdapter:
                if batteryPower > 0 {
                    NodeView(
                        icon: isCharging ? "battery.100.bolt" : "battery.100",
                        value: nil,
                        isLeftSide: false
                    )
                    Spacer(minLength: Layout.spacerHeight)
                    NodeView(
                        icon: "laptopcomputer",
                        value: nil,
                        isLeftSide: false
                    )
                } else {
                    NodeView(
                        icon: "laptopcomputer",
                        value: nil,
                        isLeftSide: false
                    )
                }
            case .both:
                NodeView(
                    icon: "laptopcomputer",
                    value: systemPower,
                    isLeftSide: false
                )
                .frame(height: Layout.largeNodeHeight)
            case .battery:
                NodeView(icon: "laptopcomputer", value: nil, isLeftSide: false)
            }
        }
    }

    private func drawMergeSankeyFlow(context: GraphicsContext, size: CGSize) {
        let leftX = Layout.nodeWidth + Layout.gap
        let rightX = size.width - Layout.nodeWidth - Layout.gap
        let smallHeight = (size.height - Layout.spacerHeight) / 2

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: 0),
            bottomLeft: CGPoint(x: leftX, y: smallHeight),
            topRight: CGPoint(
                x: rightX,
                y: size.height / 2 - Layout.largeNodeHeight / 2
            ),
            bottomRight: CGPoint(x: rightX, y: size.height / 2)
        )

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: size.height - smallHeight),
            bottomLeft: CGPoint(x: leftX, y: size.height),
            topRight: CGPoint(x: rightX, y: size.height / 2),
            bottomRight: CGPoint(
                x: rightX,
                y: size.height / 2 + Layout.largeNodeHeight / 2
            )
        )
    }

    private func drawSplitSankeyFlow(context: GraphicsContext, size: CGSize) {
        let leftX = Layout.nodeWidth + Layout.gap
        let rightX = size.width - Layout.nodeWidth - Layout.gap
        let smallHeight = (size.height - Layout.spacerHeight) / 2

        drawTube(
            context: context,
            topLeft: CGPoint(
                x: leftX,
                y: size.height / 2 - Layout.largeNodeHeight / 2
            ),
            bottomLeft: CGPoint(x: leftX, y: size.height / 2),
            topRight: CGPoint(x: rightX, y: 0),
            bottomRight: CGPoint(x: rightX, y: smallHeight)
        )

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: size.height / 2),
            bottomLeft: CGPoint(
                x: leftX,
                y: size.height / 2 + Layout.largeNodeHeight / 2
            ),
            topRight: CGPoint(x: rightX, y: size.height - smallHeight),
            bottomRight: CGPoint(x: rightX, y: size.height)
        )
    }

    private func drawSimpleFlow(context: GraphicsContext, size: CGSize) {
        let leftX = Layout.nodeWidth + Layout.gap
        let rightX = size.width - Layout.nodeWidth - Layout.gap

        drawTube(
            context: context,
            topLeft: CGPoint(x: leftX, y: 0),
            bottomLeft: CGPoint(x: leftX, y: size.height),
            topRight: CGPoint(x: rightX, y: 0),
            bottomRight: CGPoint(x: rightX, y: size.height)
        )
    }

    /// Draws a unified curved "tube" between four specific corners
    private func drawTube(
        context: GraphicsContext,
        topLeft: CGPoint,
        bottomLeft: CGPoint,
        topRight: CGPoint,
        bottomRight: CGPoint
    ) {
        let controlX = topLeft.x + (topRight.x - topLeft.x) * 0.5

        let path = Path { p in
            p.move(to: topLeft)
            p.addCurve(
                to: topRight,
                control1: CGPoint(x: controlX, y: topLeft.y),
                control2: CGPoint(x: controlX, y: topRight.y)
            )
            p.addLine(to: bottomRight)
            p.addCurve(
                to: bottomLeft,
                control1: CGPoint(x: controlX, y: bottomRight.y),
                control2: CGPoint(x: controlX, y: bottomLeft.y)
            )
            p.closeSubpath()
        }

        context.fill(
            path,
            with: .linearGradient(
                Gradient(colors: [
                    IadenteTheme.ocean.opacity(Layout.flowOpacity),
                    IadenteTheme.jade.opacity(Layout.flowOpacity),
                    IadenteTheme.gold.opacity(Layout.flowOpacity * 0.92),
                ]),
                startPoint: CGPoint(x: topLeft.x, y: topLeft.y),
                endPoint: CGPoint(x: topRight.x, y: bottomRight.y)
            )
        )
    }
}

struct PowerLabel: View {
    let power: Double
    var body: some View {
        Text(String(format: "%.2f W", abs(power)))
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(.black.opacity(0.28))
            )
            .overlay(
                Capsule()
                    .strokeBorder(.white.opacity(0.11))
            )
            .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
    }
}

struct NodeView: View {
    let icon: String
    let value: Double?
    let isLeftSide: Bool
    let cornerRadius: CGFloat = 16.0

    private var colors: [Color] {
        if icon.contains("battery") {
            return IadenteTheme.chargingColors
        }
        if icon.contains("plug") || icon.contains("bolt") {
            return IadenteTheme.automationColors
        }
        return IadenteTheme.generalColors
    }

    var body: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: isLeftSide ? cornerRadius : 0,
                bottomLeadingRadius: isLeftSide ? cornerRadius : 0,
                bottomTrailingRadius: isLeftSide ? 0 : cornerRadius,
                topTrailingRadius: isLeftSide ? 0 : cornerRadius,
                style: .continuous
            )
            .fill(
                (colors.first ?? IadenteTheme.ocean).opacity(0.17)
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: isLeftSide ? cornerRadius : 0,
                    bottomLeadingRadius: isLeftSide ? cornerRadius : 0,
                    bottomTrailingRadius: isLeftSide ? 0 : cornerRadius,
                    topTrailingRadius: isLeftSide ? 0 : cornerRadius,
                    style: .continuous
                )
                .strokeBorder(
                    (colors.first ?? IadenteTheme.ocean).opacity(0.42),
                    lineWidth: 1
                )
            )
            .frame(width: 60)
            .shadow(
                color: (colors.first ?? IadenteTheme.ocean).opacity(0.16),
                radius: 3,
                y: 2
            )

            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(colors.last ?? IadenteTheme.sky)
                if let value {
                    Text(String(format: "%.2f W", abs(value)))
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(colors.last ?? IadenteTheme.sky)
                        .minimumScaleFactor(0.75)
                }
            }
        }
    }
}
