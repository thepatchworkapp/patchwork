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
            PatchworkIconSpinner(size: 82)

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

private struct PatchworkIconSpinner: View {
    let size: CGFloat
    let spinDuration: Double
    let pauseDuration: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(size: CGFloat = 86, spinDuration: Double = 1.0, pauseDuration: Double = 0.45) {
        self.size = size
        self.spinDuration = spinDuration
        self.pauseDuration = pauseDuration
    }

    var body: some View {
        Group {
            if reduceMotion {
                Image("PatchworkLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .overlay(
                        Circle()
                            .stroke(PatchworkTheme.brand.opacity(0.12), lineWidth: 1)
                            .frame(width: size * 0.86, height: size * 0.86)
                    )
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let cycleDuration = spinDuration + pauseDuration
                    let elapsedInCycle = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycleDuration)
                    let progress = elapsedInCycle / cycleDuration
                    let spinProgress = min(progress / (spinDuration / cycleDuration), 1)
                    let rotation = progress < spinDuration / cycleDuration ? spinProgress * 360 : 360

                    Image("PatchworkLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .rotationEffect(.degrees(rotation))
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: PatchworkTheme.brand.opacity(0.12), radius: 14, y: 8)
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
