import SwiftUI

struct PatchworkSurfaceCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(PatchworkMetrics.screenPadding)
            .background(
                PatchworkTheme.surface.opacity(0.92),
                in: RoundedRectangle(cornerRadius: PatchworkMetrics.cardRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PatchworkMetrics.cardRadius, style: .continuous)
                    .stroke(PatchworkTheme.stroke, lineWidth: 1)
            )
            .shadow(color: PatchworkTheme.brand.opacity(0.08), radius: 24, y: 12)
    }
}
