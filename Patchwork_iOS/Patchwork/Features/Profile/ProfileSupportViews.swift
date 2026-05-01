import SafariServices
import SwiftUI
import UIKit

struct ProfileSupportSection: View {
    let onSignOut: () async -> Void
    let onDeleteAccount: () async throws -> Void

    @State private var isShowingDeleteConfirmation = false
    @State private var deleteConfirmationText = ""
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?

    private var canConfirmAccountDeletion: Bool {
        deleteConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "delete"
    }

    var body: some View {
        PatchworkSurfaceCard {
            VStack(spacing: 14) {
                NavigationLink {
                    HelpView()
                } label: {
                    ProfileLinkRowLabel(title: "Help & Support")
                }
                .buttonStyle(.plain)
                .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "Profile.helpLink"))

                Button("Sign Out", role: .destructive) {
                    Task {
                        await onSignOut()
                    }
                }
                .buttonStyle(PatchworkDestructiveButtonStyle())
                .accessibilityIdentifier("Profile.signOutButton")

                Button(isDeletingAccount ? "Deleting..." : "Delete Account", role: .destructive) {
                    deleteConfirmationText = ""
                    deleteAccountError = nil
                    isShowingDeleteConfirmation = true
                }
                .buttonStyle(PatchworkDestructiveButtonStyle())
                .disabled(isDeletingAccount)
                .accessibilityIdentifier("Profile.deleteAccountButton")

                if let deleteAccountError {
                    PatchworkInlineStatusBanner(tone: .error, text: deleteAccountError)
                    .accessibilityIdentifier("Profile.deleteAccountError")
                }
            }
        }
        .alert("Delete Account", isPresented: $isShowingDeleteConfirmation) {
            TextField("Type delete", text: $deleteConfirmationText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Delete Account", role: .destructive) {
                Task { await deleteAccount() }
            }
            .disabled(!canConfirmAccountDeletion || isDeletingAccount)

            Button("Cancel", role: .cancel) {
                deleteConfirmationText = ""
            }
        } message: {
            Text("This removes your account information and uploaded profile photos. Completed jobs and message threads are retained for transaction history. If you have an active App Store subscription, billing continues until you cancel it with Apple.")
        }
    }

    private func deleteAccount() async {
        guard canConfirmAccountDeletion, !isDeletingAccount else {
            return
        }

        isDeletingAccount = true
        deleteAccountError = nil
        defer { isDeletingAccount = false }

        do {
            try await onDeleteAccount()
        } catch {
            deleteAccountError = error.localizedDescription
        }
    }
}


struct HelpView: View {
    @State private var legalDocument: LegalDocument?

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.accent)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PatchworkSectionIntro(
                        eyebrow: "Support",
                        title: "Help",
                        message: "Review Patchwork's policies or send feedback directly from the app."
                    )

                    PatchworkSurfaceCard {
                        VStack(spacing: 14) {
                            Button {
                                legalDocument = .terms
                            } label: {
                                ProfileLinkRowLabel(title: "Terms of Service")
                            }
                            .buttonStyle(.plain)
                            .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "Help.termsLink"))

                            Button {
                                legalDocument = .privacy
                            } label: {
                                ProfileLinkRowLabel(title: "Privacy Policy")
                            }
                            .buttonStyle(.plain)
                            .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "Help.privacyLink"))

                            NavigationLink {
                                FeedbackView()
                            } label: {
                                ProfileLinkRowLabel(title: "Send Feedback")
                            }
                            .buttonStyle(.plain)
                            .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "Help.feedbackLink"))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Help")
        .sheet(item: $legalDocument) { document in
            LegalDocumentView(document: document)
        }
        .accessibilityIdentifier("Help.list")
    }
}


enum LegalDocument: String, Identifiable {
    case privacy
    case terms

    var id: String { rawValue }

    var url: URL {
        switch self {
        case .privacy:
            return URL(string: "https://ddga.ltd/patchwork/privacy")!
        case .terms:
            return URL(string: "https://ddga.ltd/patchwork/terms")!
        }
    }
}


struct LegalDocumentView: UIViewControllerRepresentable {
    let document: LegalDocument

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: document.url)
        controller.preferredControlTintColor = UIColor(PatchworkTheme.brand)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}


struct FeedbackView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var message = ""
    @State private var feedbackMessage: SubscriptionFeedbackMessage?
    @State private var isSubmitting = false

    private let maxFeedbackLength = 2000

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brandBright)

            ScrollView {
                VStack(spacing: 18) {
                    PatchworkSurfaceCard {
                        VStack(alignment: .leading, spacing: 18) {
                            PatchworkSectionIntro(
                                eyebrow: "Support",
                                title: "Send Feedback",
                                message: "Share product feedback, bugs, or rough edges in your own words."
                            )

                            if let feedbackMessage {
                                PatchworkInlineStatusBanner(tone: feedbackMessage.tone, text: feedbackMessage.text)
                                    .accessibilityIdentifier("Feedback.statusBanner")
                            }

                            TextEditor(text: $message)
                                .patchworkTextEditorStyle(minHeight: 160)
                                .onChange(of: message) { _, newValue in
                                    if newValue.count > maxFeedbackLength {
                                        message = String(newValue.prefix(maxFeedbackLength))
                                    }
                                }
                                .accessibilityIdentifier("Feedback.messageField")

                            Text("\(message.count)/\(maxFeedbackLength)")
                                .font(.patchworkCaption)
                                .foregroundStyle(message.count >= maxFeedbackLength ? PatchworkTheme.warning : PatchworkTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .accessibilityIdentifier("Feedback.messageCount")

                            Button(isSubmitting ? "Sending..." : "Send Feedback") {
                                Task { await submitFeedback() }
                            }
                            .buttonStyle(PatchworkPrimaryButtonStyle())
                            .disabled(isSubmitting || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("Feedback.submitButton")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Feedback")
    }

    private func submitFeedback() async {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: "Enter your feedback before sending.")
            return
        }

        isSubmitting = true
        feedbackMessage = nil
        defer { isSubmitting = false }

        do {
            _ = try await sessionStore.client.mutation("feedback:submit", args: ["message": trimmedMessage]) as ConvexID
            feedbackMessage = SubscriptionFeedbackMessage(tone: .success, text: "Feedback sent. Thank you.")
            try? await Task.sleep(nanoseconds: 500_000_000)
            dismiss()
        } catch {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
    }
}
