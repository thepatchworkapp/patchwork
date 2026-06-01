import SwiftUI

struct JobDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    let jobId: ConvexID

    @State private var detail: JobDetail?
    @State private var canReview = false
    @State private var isCompleting = false
    @State private var isLoading = true
    @State private var isShowingReviewComposer = false

    var body: some View {
        Group {
            if isLoading {
                ZStack {
                    PatchworkBackdrop(tint: PatchworkTheme.brandBright)

                    PatchworkLoadingCard(
                        title: "Loading job...",
                        message: "Fetching the latest job details and review status."
                    )
                    .padding(.horizontal, 20)
                }
                .accessibilityIdentifier("JobDetail.loading")
            } else if let detail {
                ZStack {
                    PatchworkBackdrop(tint: PatchworkTheme.brandBright)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            PatchworkSectionIntro(
                                eyebrow: "Job",
                                title: "Job detail",
                                message: "Review scope, dates, and completion status with the same high-trust bordered treatment as the rest of the app."
                            )

                            JobHeaderCard(detail: detail)

                            PatchworkSurfaceCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Description")
                                        .font(.patchworkCardTitle)
                                        .foregroundStyle(PatchworkTheme.textPrimary)
                                        .accessibilityAddTraits(.isHeader)
                                    Text(detail.notes?.isEmpty == false ? detail.notes ?? "" : detail.description)
                                        .font(.patchworkBody)
                                        .foregroundStyle(PatchworkTheme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .accessibilityElement(children: .combine)

                            JobMetaGrid(detail: detail)

                            if canShowCompleteButton(detail: detail) {
                                Button(isCompleting ? "Completing..." : "Complete Job") {
                                    Task { await completeJob() }
                                }
                                .buttonStyle(PatchworkPrimaryButtonStyle())
                                .disabled(isCompleting)
                                .accessibilityIdentifier("JobDetail.completeButton")
                                .accessibilityLabel("Complete job")
                                .accessibilityHint("Marks this job as complete")
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .scrollIndicators(.hidden)
                }
                .safeAreaInset(edge: .bottom) {
                    if detail.status == "completed" && canReview {
                        PatchworkSurfaceCard {
                            Button("Leave Review") {
                                isShowingReviewComposer = true
                            }
                            .buttonStyle(PatchworkPrimaryButtonStyle())
                            .accessibilityIdentifier("JobDetail.leaveReviewButton")
                            .accessibilityHint("Opens the review composer")
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    }
                }
            } else {
                ZStack {
                    PatchworkBackdrop(tint: PatchworkTheme.brandBright)

                    PatchworkEmptyStateCard(
                        systemImage: "doc.text.magnifyingglass",
                        title: "Job not found",
                        message: "This job is unavailable or has already been removed."
                    )
                    .padding(.horizontal, 20)
                }
                .accessibilityIdentifier("JobDetail.notFound")
            }
        }
        .navigationTitle("Job Detail")
        .task(id: jobId) {
            await load()
        }
        .navigationDestination(isPresented: $isShowingReviewComposer) {
            LeaveReviewView(jobId: jobId)
        }
        .onAppear {
            guard detail != nil else {
                return
            }
            Task { await load() }
        }
    }

    private func canShowCompleteButton(detail: JobDetail) -> Bool {
        detail.status == "in_progress" && detail.seekerId == appState.currentUser?.id
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let currentTimeMs = Int(Date().timeIntervalSince1970 * 1000)
            async let detailCall: JobDetail? = sessionStore.client.query("jobs:getJob", args: ["jobId": jobId])
            async let canReviewCall: Bool = sessionStore.client.query(
                "reviews:canReview",
                args: ["jobId": jobId, "currentTimeMs": currentTimeMs]
            )
            detail = try await detailCall
            canReview = try await canReviewCall
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func completeJob() async {
        isCompleting = true
        defer { isCompleting = false }
        do {
            struct Result: Decodable {
                let jobId: ConvexID
            }
            _ = try await sessionStore.client.mutation("jobs:completeJob", args: ["jobId": jobId]) as Result
            await appState.refreshJobs(client: sessionStore.client, statusGroup: appState.jobsStatusGroup)
            await load()
        } catch {
            appState.lastError = error.localizedDescription
        }
    }
}

private struct JobHeaderCard: View {
    let detail: JobDetail

    var body: some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(detail.categoryName.uppercased())
                            .font(.patchworkCaption)
                            .foregroundStyle(PatchworkTheme.brand)
                            .tracking(0.6)
                        Text(title)
                            .font(.patchworkSectionTitle)
                            .foregroundStyle(PatchworkTheme.textPrimary)
                    }

                    Spacer(minLength: 0)

                    Text(detail.status.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.patchworkCaption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(statusColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(statusColor)
                }

                Label("Verified job record", systemImage: "checkmark.shield.fill")
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(headerAccessibilityLabel)
    }

    private var title: String {
        let firstLine = detail.description.split(separator: "\n").first.map(String.init) ?? detail.description
        let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 50 { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: 50)
        return "\(trimmed[..<index])..."
    }

    private var statusColor: Color {
        switch detail.status {
        case "completed":
            return PatchworkTheme.success
        case "in_progress":
            return PatchworkTheme.brand
        default:
            return PatchworkTheme.textSecondary
        }
    }

    private var headerAccessibilityLabel: String {
        let title = title
        let status = detail.status.replacingOccurrences(of: "_", with: " ").capitalized
        let category = detail.categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryPart = category.isEmpty ? nil : "\(category)."
        return [categoryPart, "\(title).", "\(status).", "Verified job record."]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

private struct JobMetaGrid: View {
    let detail: JobDetail

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            JobMetaCard(icon: "clock", title: detail.status == "completed" ? "Completed" : "Start Date", value: displayDate(detail.status == "completed" ? detail.completedDate : detail.startDate))
            JobMetaCard(icon: "dollarsign", title: "Rate", value: "\(currencyRate) / \(detail.rateType)")
            JobMetaCard(icon: "calendar", title: "Created", value: createdDate)
            JobMetaCard(icon: "message", title: "Status", value: detail.status.replacingOccurrences(of: "_", with: " ").capitalized)
        }
    }

    private var currencyRate: String {
        let dollars = Double(detail.rate) / 100
        return dollars.formatted(.currency(code: "CAD"))
    }

    private var createdDate: String {
        let date = Date(timeIntervalSince1970: TimeInterval(detail.createdAt) / 1000)
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func displayDate(_ value: String?) -> String {
        guard let value,
              let date = Self.iso8601FormatterWithFractional.date(from: value) ?? Self.iso8601Formatter.date(from: value)
        else {
            return value ?? "-"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
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

private struct JobMetaCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.textSecondary)
            Text(value)
                .font(.patchworkBodyStrong)
                .foregroundStyle(PatchworkTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }
}
