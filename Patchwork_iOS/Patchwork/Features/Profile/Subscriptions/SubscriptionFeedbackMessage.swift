import Foundation

struct SubscriptionFeedbackMessage: Identifiable, Equatable {
    let id = UUID()
    let tone: PatchworkInlineStatusBanner.Tone
    let text: String
}
