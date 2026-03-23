import SwiftUI

private struct PatchworkInputFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.patchworkBody)
            .foregroundStyle(PatchworkTheme.textPrimary)
            .padding(.horizontal, 16)
            .frame(height: PatchworkMetrics.fieldHeight)
            .background(
                PatchworkTheme.surface,
                in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                    .stroke(PatchworkTheme.stroke, lineWidth: 1)
            )
    }
}

extension View {
    func patchworkInputFieldStyle() -> some View {
        modifier(PatchworkInputFieldModifier())
    }
}
