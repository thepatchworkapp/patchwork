import SwiftUI

struct PatchworkTopBar: View {
    let title: String
    let onBack: (() -> Void)?
    let backButtonAccessibilityIdentifier: String?

    init(
        title: String,
        onBack: (() -> Void)?,
        backButtonAccessibilityIdentifier: String? = nil
    ) {
        self.title = title
        self.onBack = onBack
        self.backButtonAccessibilityIdentifier = backButtonAccessibilityIdentifier
    }

    var body: some View {
        HStack {
            if let onBack {
                backButton(action: onBack)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }

            Spacer()

            Text(title)
                .font(.patchworkBodyStrong)
                .foregroundStyle(PatchworkTheme.textPrimary)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func backButton(action: @escaping () -> Void) -> some View {
        if let backButtonAccessibilityIdentifier {
            Button("Back", systemImage: "chevron.left", action: action)
                .labelStyle(.iconOnly)
                .buttonStyle(PatchworkIconButtonStyle(fill: PatchworkTheme.surface.opacity(0.85)))
                .accessibilityLabel("Back")
                .accessibilityIdentifier(backButtonAccessibilityIdentifier)
        } else {
            Button("Back", systemImage: "chevron.left", action: action)
                .labelStyle(.iconOnly)
                .buttonStyle(PatchworkIconButtonStyle(fill: PatchworkTheme.surface.opacity(0.85)))
                .accessibilityLabel("Back")
        }
    }
}
