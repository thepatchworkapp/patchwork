import SwiftUI

struct PatchworkEmptyStateCard: View {
    let systemImage: String
    let title: String
    let message: String
    var tint: Color = PatchworkTheme.brand
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        PatchworkSurfaceCard {
            VStack(spacing: 16) {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 84, height: 84)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(tint)
                    }

                Text(title)
                    .font(.patchworkSectionTitle)
                    .foregroundStyle(PatchworkTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.patchworkBody)
                    .foregroundStyle(PatchworkTheme.textSecondary)
                    .multilineTextAlignment(.center)

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(PatchworkPrimaryButtonStyle())
                }
            }
            .frame(maxWidth: PatchworkMetrics.emptyStateContentMaxWidth)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }
}

struct PatchworkSearchField: View {
    let placeholder: String
    @Binding var text: String
    var isEnabled: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PatchworkTheme.textSecondary)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .autocorrectionDisabled(true)
                .font(.patchworkBody)
                .foregroundStyle(PatchworkTheme.textPrimary)
                .disabled(!isEnabled)
                .accessibilityLabel(placeholder)
        }
        .padding(.horizontal, 16)
        .frame(height: PatchworkMetrics.fieldHeight)
        .background(PatchworkTheme.surface, in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
    }
}

struct PatchworkLoadingCard: View {
    let title: String
    var message: String?

    var body: some View {
        PatchworkSurfaceCard {
            VStack(spacing: 16) {
                ProgressView()
                    .tint(PatchworkTheme.brand)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.patchworkBodyStrong)
                    .foregroundStyle(PatchworkTheme.textPrimary)

                if let message {
                    Text(message)
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }
}

struct PatchworkBrandLoadingCard: View {
    var title: String?
    var message: String?

    var body: some View {
        VStack(spacing: title == nil && message == nil ? 0 : 16) {
            PatchworkAnimatedMark(size: 82)

            if let title {
                Text(title)
                    .font(.patchworkBodyStrong)
                    .foregroundStyle(PatchworkTheme.textPrimary)
            }

            if let message {
                Text(message)
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, title == nil && message == nil ? 8 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, title == nil && message == nil ? 0 : 4)
        .accessibilityElement(children: .combine)
    }
}

struct PatchworkPill: View {
    let title: String
    var systemImage: String? = nil
    var foreground: Color = PatchworkTheme.brand
    var fill: Color?
    var horizontalPadding: CGFloat = 10
    var verticalPadding: CGFloat = 6

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }

            Text(title)
        }
        .font(.patchworkCaption)
        .foregroundStyle(foreground)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(fill ?? foreground.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct PatchworkAnimatedMark: View {
    enum ForegroundTreatment {
        case standard
        case lightOnDark

        var wordmarkColor: Color {
            switch self {
            case .standard:
                return PatchworkTheme.textPrimary
            case .lightOnDark:
                return .white
            }
        }

        var wordmarkShadowColor: Color {
            switch self {
            case .standard:
                return PatchworkTheme.brand.opacity(0.14)
            case .lightOnDark:
                return .black.opacity(0.16)
            }
        }

        var markShadowColor: Color {
            switch self {
            case .standard:
                return PatchworkTheme.brand.opacity(0.14)
            case .lightOnDark:
                return .black.opacity(0.16)
            }
        }

        var haloColor: Color {
            switch self {
            case .standard:
                return PatchworkTheme.brand.opacity(0.10)
            case .lightOnDark:
                return .white.opacity(0.12)
            }
        }
    }

    let size: CGFloat
    var showsWordmark: Bool
    var foregroundTreatment: ForegroundTreatment
    let swirlDuration: Double
    let pauseDuration: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")

    init(
        size: CGFloat = 86,
        showsWordmark: Bool = false,
        foregroundTreatment: ForegroundTreatment = .standard,
        swirlDuration: Double = 1.9,
        pauseDuration: Double = 0.42
    ) {
        self.size = size
        self.showsWordmark = showsWordmark
        self.foregroundTreatment = foregroundTreatment
        self.swirlDuration = swirlDuration
        self.pauseDuration = pauseDuration
    }

    var body: some View {
        VStack(spacing: showsWordmark ? 14 : 0) {
            ZStack {
                Circle()
                    .fill(foregroundTreatment.haloColor)
                    .frame(width: size * 1.04, height: size * 1.04)
                    .blur(radius: size * 0.18)

                Group {
                    if reduceMotion || isUITesting {
                        PatchworkMarkCircles(size: size, settleProgress: 1)
                    } else {
                        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                            let cycleDuration = swirlDuration + pauseDuration
                            let elapsedInCycle = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycleDuration)
                            let settleProgress = min(elapsedInCycle / swirlDuration, 1)

                            PatchworkMarkCircles(size: size, settleProgress: settleProgress)
                        }
                    }
                }
                .frame(width: size, height: size)
            }
            .frame(width: size, height: size)
            .shadow(color: foregroundTreatment.markShadowColor, radius: size * 0.16, y: size * 0.09)
            .accessibilityHidden(true)

            if showsWordmark {
                Text("patchwork")
                    .font(size > 100 ? .patchworkDisplay : .patchworkWordmark)
                    .tracking(size > 100 ? 0.8 : 0.45)
                    .foregroundStyle(foregroundTreatment.wordmarkColor)
                    .shadow(color: foregroundTreatment.wordmarkShadowColor, radius: size * 0.14, y: size * 0.08)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Patchwork")
    }
}

private struct PatchworkMarkCircles: View {
    private struct CircleSpec {
        let color: Color
        let center: CGPoint
        let radiusRatio: CGFloat
        let phase: Double
        let swirlStrength: CGFloat
        let zIndex: Double
    }

    private static let iconYellow = Color(red: 250 / 255, green: 184 / 255, blue: 41 / 255)
    private static let iconCoral = Color(red: 231 / 255, green: 118 / 255, blue: 98 / 255)
    private static let iconTeal = Color(red: 117 / 255, green: 187 / 255, blue: 182 / 255)

    private static let circles: [CircleSpec] = [
        CircleSpec(color: iconCoral, center: CGPoint(x: 0.50, y: 0.77), radiusRatio: 0.19, phase: 0.55, swirlStrength: 1.18, zIndex: 0),
        CircleSpec(color: iconYellow, center: CGPoint(x: 0.77, y: 0.49), radiusRatio: 0.19, phase: 1.80, swirlStrength: 0.95, zIndex: 1),
        CircleSpec(color: iconYellow, center: CGPoint(x: 0.29, y: 0.38), radiusRatio: 0.19, phase: 3.35, swirlStrength: 1.05, zIndex: 2),
        CircleSpec(color: iconCoral, center: CGPoint(x: 0.60, y: 0.25), radiusRatio: 0.19, phase: 4.55, swirlStrength: 1.12, zIndex: 3),
        CircleSpec(color: iconTeal, center: CGPoint(x: 0.33, y: 0.77), radiusRatio: 0.19, phase: 2.45, swirlStrength: 1.24, zIndex: 4),
    ]

    let size: CGFloat
    let settleProgress: Double

    var body: some View {
        let clampedProgress = min(max(settleProgress, 0), 1)
        ZStack {
            ForEach(Array(Self.circles.enumerated()), id: \.offset) { _, circle in
                Circle()
                    .fill(circle.color)
                    .frame(width: size * circle.radiusRatio * 2, height: size * circle.radiusRatio * 2)
                    .position(position(for: circle, progress: clampedProgress))
                    .zIndex(circle.zIndex)
            }
        }
    }

    private func position(for circle: CircleSpec, progress: Double) -> CGPoint {
        let eased = CGFloat(progress * progress * (3 - 2 * progress))
        let center = CGPoint(x: size * 0.5, y: size * 0.5)
        let finalCenter = CGPoint(x: size * circle.center.x, y: size * circle.center.y)

        let startRadius = size * 0.30
        let startCenter = CGPoint(
            x: center.x + CGFloat(cos(circle.phase)) * startRadius,
            y: center.y + CGFloat(sin(circle.phase)) * startRadius
        )

        let settleCenter = CGPoint(
            x: startCenter.x + (finalCenter.x - startCenter.x) * eased,
            y: startCenter.y + (finalCenter.y - startCenter.y) * eased
        )

        let orbitAngle = (progress * .pi * 2 * (1.45 + Double(circle.swirlStrength))) + circle.phase
        let orbitRadius = size * 0.13 * (1 - eased) * circle.swirlStrength
        let orbitOffset = CGPoint(
            x: CGFloat(cos(orbitAngle)) * orbitRadius,
            y: CGFloat(sin(orbitAngle * 0.9)) * orbitRadius
        )

        return CGPoint(
            x: settleCenter.x + orbitOffset.x,
            y: settleCenter.y + orbitOffset.y
        )
    }
}

struct PatchworkInlineStatusBanner: View {
    enum Tone {
        case warning
        case error
        case success

        var color: Color {
            switch self {
            case .warning:
                return PatchworkTheme.warning
            case .error:
                return PatchworkTheme.danger
            case .success:
                return PatchworkTheme.success
            }
        }

        var systemImage: String {
            switch self {
            case .warning:
                return "exclamationmark.circle.fill"
            case .error:
                return "xmark.octagon.fill"
            case .success:
                return "checkmark.circle.fill"
            }
        }
    }

    let tone: Tone
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: tone.systemImage)
                .foregroundStyle(tone.color)
                .accessibilityHidden(true)

            Text(text)
                .font(.patchworkBodyStrong)
                .foregroundStyle(PatchworkTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(tone.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tone.color.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
