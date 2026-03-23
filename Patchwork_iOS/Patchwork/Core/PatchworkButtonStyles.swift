import SwiftUI

struct PatchworkPrimaryButtonStyle: ButtonStyle {
    let fill: LinearGradient

    init(fill: LinearGradient = PatchworkTheme.heroGradient) {
        self.fill = fill
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.patchworkButton)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: PatchworkMetrics.buttonHeight)
            .background(fill, in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous))
            .shadow(color: PatchworkTheme.brand.opacity(configuration.isPressed ? 0.12 : 0.24), radius: configuration.isPressed ? 8 : 18, y: configuration.isPressed ? 4 : 10)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct PatchworkSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.patchworkButton)
            .foregroundStyle(PatchworkTheme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: PatchworkMetrics.buttonHeight)
            .background(
                PatchworkTheme.surface.opacity(configuration.isPressed ? 0.98 : 0.88),
                in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                    .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct PatchworkTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.patchworkBodyStrong)
            .foregroundStyle(configuration.isPressed ? PatchworkTheme.brand.opacity(0.7) : PatchworkTheme.brand)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
    }
}
