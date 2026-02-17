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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let detail {
                    reviewContextCard(detail: detail)
                }

                ratingSection
                reviewSection
                photoSection
                policySection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .safeAreaInset(edge: .bottom) {
            Button(isSubmitting ? "Submitting..." : "Submit Review") {
                Task { await submit() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting || !canSubmit)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(.thinMaterial)
            .accessibilityIdentifier("LeaveReview.submitButton")
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
        VStack(alignment: .leading, spacing: 10) {
            Text("How was your experience?")
                .font(.headline)

            HStack(spacing: 10) {
                ForEach(1 ... 5, id: \.self) { star in
                    Button {
                        rating = star
                    } label: {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(star <= rating ? .yellow : .secondary)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                    .accessibilityIdentifier("LeaveReview.star.\(star)")
                }
            }

            Text(ratingLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tell others about your experience")
                .font(.headline)

            TextEditor(text: $text)
                .frame(minHeight: 140)
                .padding(8)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("LeaveReview.textField")

            Text("Share details about quality, professionalism, communication, and timeliness.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(remainingCharactersHint)
                .font(.footnote.weight(.medium))
                .foregroundStyle(trimmedText.count >= 10 ? .green : .secondary)
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add photos (optional)")
                .font(.headline)

            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                Label("Upload photos of completed work", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("LeaveReview.photosPicker")

            if !selectedPhotos.isEmpty {
                Text("\(selectedPhotos.count) photo\(selectedPhotos.count == 1 ? "" : "s") selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Photo attachments are optional and currently not included in review submission.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var policySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Review policy")
                .font(.headline)
            Text("Only verified job participants can leave reviews. Reviews are public and help maintain trust and quality in Patchwork.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Need help? Contact support if this job was completed incorrectly.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("LeaveReview.policySection")
    }

    private func reviewContextCard(detail: JobDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(detail.categoryName)
                    .font(.headline)
                Spacer()
                if detail.status == "completed" {
                    Label("Completed", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
            if let completedDate = formatDate(detail.completedDate) {
                Text("Job completed \(completedDate)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
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
