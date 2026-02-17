import SwiftUI

struct JobsView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    @State private var statusGroup = "active"
    @State private var jobs: [JobSummary] = []

    var body: some View {
        VStack(spacing: 0) {
            Picker("Jobs", selection: $statusGroup) {
                Text("In Progress").tag("active")
                Text("Completed").tag("completed")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .accessibilityIdentifier("Jobs.statusTabs")

            List(jobs) { job in
                NavigationLink {
                    JobDetailView(jobId: job.id)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job.counterpartyName ?? job.categoryName ?? "Job")
                            .font(.headline)
                        Text(job.status.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let description = job.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
                .accessibilityIdentifier("Jobs.row.\(job.id)")
            }
        }
        .navigationTitle("Jobs")
        .task {
            await loadJobs()
        }
        .onChange(of: statusGroup) { _, _ in
            Task { await loadJobs() }
        }
    }

    private func loadJobs() async {
        do {
            jobs = try await sessionStore.client.query(
                "jobs:listJobs",
                args: ["statusGroup": statusGroup, "limit": 50]
            )
        } catch {
            appState.lastError = error.localizedDescription
        }
    }
}
