import SwiftUI
import UIKit

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

private struct PatchworkTextEditorModifier: ViewModifier {
    let minHeight: CGFloat

    func body(content: Content) -> some View {
        content
            .font(.patchworkBody)
            .foregroundStyle(PatchworkTheme.textPrimary)
            .scrollContentBackground(.hidden)
            .frame(minHeight: minHeight)
            .padding(10)
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

private struct PatchworkInsetSurfaceModifier: ViewModifier {
    let fill: Color
    let stroke: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
    }
}

extension View {
    func patchworkInputFieldStyle() -> some View {
        modifier(PatchworkInputFieldModifier())
    }

    func patchworkTextEditorStyle(minHeight: CGFloat = 120) -> some View {
        modifier(PatchworkTextEditorModifier(minHeight: minHeight))
    }

    func patchworkInsetSurface(
        fill: Color = PatchworkTheme.surfaceMuted,
        stroke: Color = PatchworkTheme.stroke,
        cornerRadius: CGFloat = PatchworkMetrics.controlRadius
    ) -> some View {
        modifier(PatchworkInsetSurfaceModifier(fill: fill, stroke: stroke, cornerRadius: cornerRadius))
    }

    func patchworkKeyboardDismissToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    PatchworkKeyboard.dismiss()
                }
            }
        }
    }
}

enum PatchworkKeyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
