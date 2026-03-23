import SwiftUI

private struct PatchworkSheetChromeModifier: ViewModifier {
    let detents: Set<PresentationDetent>?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let detents {
            content
                .presentationDetents(detents)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .presentationBackground(.clear)
        } else {
            content
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .presentationBackground(.clear)
        }
    }
}

extension View {
    func patchworkSheetChrome(detents: Set<PresentationDetent>? = nil) -> some View {
        modifier(PatchworkSheetChromeModifier(detents: detents))
    }
}
