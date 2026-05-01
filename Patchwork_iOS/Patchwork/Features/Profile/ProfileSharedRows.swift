import SwiftUI

struct ProfileMenuButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Menu", systemImage: "line.3.horizontal")
                .labelStyle(.iconOnly)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PatchworkTheme.brand)
                .frame(width: 44, height: 44)
                .background(PatchworkTheme.brandSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open settings menu")
        .accessibilityIdentifier("Profile.menuButton")
    }
}


struct ProfileLinkRowStyle: ViewModifier {
    let accessibilityIdentifier: String

    func body(content: Content) -> some View {
        content
            .font(.patchworkBodyStrong)
            .foregroundStyle(PatchworkTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PatchworkTheme.stroke, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .accessibilityIdentifier(accessibilityIdentifier)
    }
}


struct ProfileLinkRowLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 12)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PatchworkTheme.textTertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
