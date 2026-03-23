import SwiftUI

struct PatchworkSectionIntro: View {
    let eyebrow: String?
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.patchworkCaption)
                    .tracking(1.2)
                    .foregroundStyle(PatchworkTheme.brand)
            }

            Text(title)
                .font(.patchworkSectionTitle)
                .foregroundStyle(PatchworkTheme.textPrimary)

            Text(message)
                .font(.patchworkBody)
                .foregroundStyle(PatchworkTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
