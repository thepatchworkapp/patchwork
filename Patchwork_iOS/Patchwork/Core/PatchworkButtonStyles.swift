import SwiftUI

struct PatchworkPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    let fill: LinearGradient

    init(fill: LinearGradient = PatchworkTheme.heroGradient) {
        self.fill = fill
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.patchworkButton)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: PatchworkMetrics.buttonHeight)
            .contentShape(Rectangle())
            .background(fill, in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous))
            .shadow(color: PatchworkTheme.brand.opacity(configuration.isPressed ? 0.12 : 0.24), radius: configuration.isPressed ? 8 : 18, y: configuration.isPressed ? 4 : 10)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct PatchworkSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    let foreground: Color
    let stroke: Color
    let fill: Color

    init(
        foreground: Color = PatchworkTheme.textPrimary,
        stroke: Color = PatchworkTheme.strokeStrong,
        fill: Color = PatchworkTheme.surface
    ) {
        self.foreground = foreground
        self.stroke = stroke
        self.fill = fill
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.patchworkButton)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: PatchworkMetrics.buttonHeight)
            .contentShape(Rectangle())
            .background(
                fill.opacity(configuration.isPressed ? 0.98 : 0.88),
                in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct PatchworkDestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.patchworkButton)
            .foregroundStyle(PatchworkTheme.danger)
            .frame(maxWidth: .infinity, minHeight: PatchworkMetrics.buttonHeight)
            .contentShape(Rectangle())
            .background(
                PatchworkTheme.danger.opacity(configuration.isPressed ? 0.16 : 0.10),
                in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                    .stroke(PatchworkTheme.danger.opacity(0.26), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct PatchworkTextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.patchworkBodyStrong)
            .foregroundStyle(isEnabled ? (configuration.isPressed ? PatchworkTheme.brand.opacity(0.7) : PatchworkTheme.brand) : PatchworkTheme.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
    }
}

struct PatchworkIconButtonStyle: ButtonStyle {
    let size: CGFloat
    let foreground: Color
    let fill: Color
    let stroke: Color

    init(
        size: CGFloat = 44,
        foreground: Color = PatchworkTheme.textPrimary,
        fill: Color = PatchworkTheme.surface,
        stroke: Color = PatchworkTheme.stroke
    ) {
        self.size = size
        self.foreground = foreground
        self.fill = fill
        self.stroke = stroke
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.patchworkBodyStrong)
            .foregroundStyle(foreground.opacity(configuration.isPressed ? 0.72 : 1))
            .frame(width: size, height: size)
            .background(fill.opacity(configuration.isPressed ? 0.78 : 0.92), in: Circle())
            .overlay(Circle().stroke(stroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
