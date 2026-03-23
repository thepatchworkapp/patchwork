import Foundation
import PhotosUI
import SwiftUI

struct LeaveReviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss

    let jobId: ConvexID

    @State private var detail: JobDetail?
    @State private var rating = 0
    @State private var text = ""
    @State private var isSubmitting = false
    @State private var selectedPhotos: [PhotosPickerItem] = []

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.accent)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PatchworkSectionIntro(
                        eyebrow: "Trust",
                        title: "Leave a review",
                        message: "Capture quality, professionalism, and reliability with a calm premium review flow."
                    )

                    if let detail {
                        reviewContextCard(detail: detail)
                    }

                    ratingSection
                    reviewSection
                    photoSection
                    policySection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            PatchworkSurfaceCard {
                Button(isSubmitting ? "Submitting..." : "Submit Review") {
                    Task { await submit() }
                }
                .buttonStyle(PatchworkPrimaryButtonStyle())
                .disabled(isSubmitting || !canSubmit)
                .accessibilityIdentifier("LeaveReview.submitButton")
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .navigationTitle("Leave Review")
        .task(id: jobId) {
            await loadJobDetail()
        }
    }

    private var canSubmit: Bool {
        rating > 0 && trimmedText.count >= 10
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var ratingLabel: String {
        switch rating {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Very good"
        case 5: return "Excellent"
        default: return "Tap to rate"
        }
    }

    private var remainingCharactersHint: String {
        if trimmedText.count >= 10 {
            return "Looks good."
        }
        return "Add at least \(10 - trimmedText.count) more character\(trimmedText.count == 9 ? "" : "s")."
    }

    private var ratingSection: some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("How was your experience?")
                    .font(.patchworkCardTitle)
                    .foregroundStyle(PatchworkTheme.textPrimary)

                HStack(spacing: 10) {
                    ForEach(1 ... 5, id: \.self) { star in
                        Button {
                            rating = star
                        } label: {
                            Label("\(star) star\(star == 1 ? "" : "s")", systemImage: star <= rating ? "star.fill" : "star")
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .foregroundStyle(star <= rating ? PatchworkTheme.warning : PatchworkTheme.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(star <= rating ? PatchworkTheme.warning.opacity(0.28) : PatchworkTheme.stroke, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                        .accessibilityIdentifier("LeaveReview.star.\(star)")
                    }
                }

                Text(ratingLabel)
                    .font(.patchworkBody)
                    .foregroundStyle(PatchworkTheme.textSecondary)
            }
        }
    }

    private var reviewSection: some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tell others about your experience")
                    .font(.patchworkCardTitle)
                    .foregroundStyle(PatchworkTheme.textPrimary)

                TextEditor(text: $text)
                    .font(.patchworkBody)
                    .foregroundStyle(PatchworkTheme.textPrimary)
                    .frame(minHeight: 140)
                    .padding(10)
                    .background(PatchworkTheme.surface, in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                            .stroke(PatchworkTheme.stroke, lineWidth: 1)
                    )
                    .accessibilityIdentifier("LeaveReview.textField")

                Text("Share details about quality, professionalism, communication, and timeliness.")
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textSecondary)

                Text(remainingCharactersHint)
                    .font(.patchworkCaption)
                    .foregroundStyle(trimmedText.count >= 10 ? PatchworkTheme.success : PatchworkTheme.textSecondary)
            }
        }
    }

    private var photoSection: some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Add photos (optional)")
                    .font(.patchworkCardTitle)
                    .foregroundStyle(PatchworkTheme.textPrimary)

                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                    Label("Upload photos of completed work", systemImage: "photo.on.rectangle")
                        .font(.patchworkBodyStrong)
                        .frame(maxWidth: .infinity, minHeight: PatchworkMetrics.buttonHeight)
                        .foregroundStyle(PatchworkTheme.textPrimary)
                        .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                                .stroke(PatchworkTheme.stroke, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("LeaveReview.photosPicker")

                if !selectedPhotos.isEmpty {
                    Text("\(selectedPhotos.count) photo\(selectedPhotos.count == 1 ? "" : "s") selected")
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                }

                Text("Photo attachments are optional and currently not included in review submission.")
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textSecondary)
            }
        }
    }

    private var policySection: some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Review policy")
                    .font(.patchworkCardTitle)
                    .foregroundStyle(PatchworkTheme.textPrimary)
                Text("Only verified job participants can leave reviews. Reviews are public and help maintain trust and quality in Patchwork.")
                    .font(.patchworkBody)
                    .foregroundStyle(PatchworkTheme.textSecondary)
                Text("Need help? Contact support if this job was completed incorrectly.")
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textSecondary)
            }
        }
        .accessibilityIdentifier("LeaveReview.policySection")
    }

    private func reviewContextCard(detail: JobDetail) -> some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(detail.categoryName.uppercased())
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.brand)
                        .tracking(0.6)
                    Spacer()
                    if detail.status == "completed" {
                        Label("Completed", systemImage: "checkmark.seal.fill")
                            .font(.patchworkCaption)
                            .foregroundStyle(PatchworkTheme.success)
                    }
                }

                Text(detail.description)
                    .font(.patchworkCardTitle)
                    .foregroundStyle(PatchworkTheme.textPrimary)

                if let completedDate = formatDate(detail.completedDate) {
                    Text("Job completed \(completedDate)")
                        .font(.patchworkBody)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                }
            }
        }
    }

    private func formatDate(_ value: String?) -> String? {
        guard let value,
              let date = Self.iso8601FormatterWithFractional.date(from: value) ?? Self.iso8601Formatter.date(from: value)
        else {
            return nil
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func loadJobDetail() async {
        do {
            detail = try await sessionStore.client.query("jobs:getJob", args: ["jobId": jobId])
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            _ = try await sessionStore.client.mutation(
                "reviews:createReview",
                args: [
                    "jobId": jobId,
                    "rating": rating,
                    "text": trimmedText,
                ]
            ) as ConvexID
            await appState.refreshJobs(client: sessionStore.client, statusGroup: appState.jobsStatusGroup)
            await appState.refreshAuthedData(client: sessionStore.client, surfaceErrors: false)
            dismiss()
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private static let iso8601FormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
