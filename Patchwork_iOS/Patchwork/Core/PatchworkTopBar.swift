import SwiftUI

struct PatchworkTopBar: View {
    let title: String
    let onBack: (() -> Void)?

    var body: some View {
        HStack {
            if let onBack {
                Button("Back", systemImage: "chevron.left", action: onBack)
                    .labelStyle(.iconOnly)
                    .buttonStyle(PatchworkIconButtonStyle(fill: PatchworkTheme.surface.opacity(0.85)))
                    .accessibilityLabel("Back")
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
}
