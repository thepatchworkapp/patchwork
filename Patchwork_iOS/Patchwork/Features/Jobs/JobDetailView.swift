import SwiftUI

struct JobDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    let jobId: ConvexID

    @State private var detail: JobDetail?
    @State private var canReview = false
    @State private var isCompleting = false
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading job...")
            } else if let detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        JobHeaderCard(detail: detail)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                            Text(detail.notes?.isEmpty == false ? detail.notes ?? "" : detail.description)
                                .foregroundStyle(.secondary)
                        }

                        JobMetaGrid(detail: detail)

                        if canShowCompleteButton(detail: detail) {
                            Button(isCompleting ? "Completing..." : "Complete Job") {
                                Task { await completeJob() }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isCompleting)
                            .accessibilityIdentifier("JobDetail.completeButton")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .safeAreaInset(edge: .bottom) {
                    if detail.status == "completed" && canReview {
                        NavigationLink {
                            LeaveReviewView(jobId: jobId)
                        } label: {
                            Text("Leave Review")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                        .background(.thinMaterial)
                        .accessibilityIdentifier("JobDetail.leaveReviewButton")
                    }
                }
            } else {
                ContentUnavailableView("Job not found", systemImage: "doc.text.magnifyingglass")
            }
        }
        .navigationTitle("Job Detail")
        .task(id: jobId) {
            await load()
        }
    }

    private func canShowCompleteButton(detail: JobDetail) -> Bool {
        detail.status == "in_progress" && detail.seekerId == appState.currentUser?.id
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let detailCall: JobDetail? = sessionStore.client.query("jobs:getJob", args: ["jobId": jobId])
            async let canReviewCall: Bool = sessionStore.client.query("reviews:canReview", args: ["jobId": jobId])
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
            await load()
        } catch {
            appState.lastError = error.localizedDescription
        }
    }
}

private struct JobHeaderCard: View {
    let detail: JobDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.categoryName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.title3.weight(.semibold))
                }

                Spacer(minLength: 0)

                Text(detail.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(statusColor)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
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
            return .green
        case "in_progress":
            return .indigo
        default:
            return .secondary
        }
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
        return dollars.formatted(.currency(code: "USD"))
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
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
