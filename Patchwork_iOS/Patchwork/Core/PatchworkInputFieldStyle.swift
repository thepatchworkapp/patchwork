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

extension View {
    func patchworkInputFieldStyle() -> some View {
        modifier(PatchworkInputFieldModifier())
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
