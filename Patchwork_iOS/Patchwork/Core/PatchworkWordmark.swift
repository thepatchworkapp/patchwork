import SwiftUI

struct PatchworkWordmark: View {
    let size: CGFloat

    init(size: CGFloat = 72) {
        self.size = size
    }

    var body: some View {
        VStack(spacing: 12) {
            Image("PatchworkLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(.rect(cornerRadius: size * 0.22))
                .shadow(color: PatchworkTheme.brand.opacity(0.18), radius: 18, y: 10)
                .accessibilityHidden(true)

            Text("patchwork")
                .font(size > 100 ? .patchworkDisplay : .patchworkWordmark)
                .foregroundStyle(PatchworkTheme.textPrimary)
        }
    }
}
