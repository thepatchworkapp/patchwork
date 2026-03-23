import SwiftUI

struct PatchworkTopBar: View {
    let title: String
    let onBack: (() -> Void)?

    var body: some View {
        HStack {
            if let onBack {
                Button("Back", systemImage: "chevron.left", action: onBack)
                    .labelStyle(.iconOnly)
                    .font(.patchworkBodyStrong)
                    .foregroundStyle(PatchworkTheme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(PatchworkTheme.surface.opacity(0.85), in: Circle())
                    .overlay(Circle().stroke(PatchworkTheme.stroke, lineWidth: 1))
                    .buttonStyle(.plain)
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
