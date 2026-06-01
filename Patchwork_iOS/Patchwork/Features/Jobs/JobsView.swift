import SwiftUI

struct JobsView: View {
    private enum MainLayout {
        static let horizontalGutter: CGFloat = 20
        static let topRhythm: CGFloat = 16
        static let bottomPadding: CGFloat = 20
        static let controlSpacing: CGFloat = 14
    }

    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    @State private var statusGroup = "active"
    @State private var searchText = ""
    private let usesVisualPreview = ProcessInfo.processInfo.arguments.contains("PATCHWORK_UI_EMPTY_TABS")

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brandBright)

            VStack(spacing: 0) {
                topControls

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if filteredJobs.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(filteredJobs) { job in
                                    NavigationLink {
                                        JobDetailView(jobId: job.id)
                                    } label: {
                                        jobCard(job)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("Jobs.row.\(job.id)")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, MainLayout.horizontalGutter)
                    .padding(.top, MainLayout.topRhythm)
                    .padding(.bottom, MainLayout.bottomPadding)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            statusGroup = appState.jobsStatusGroup
            guard !usesVisualPreview else {
                return
            }
            await loadJobs()
        }
        .onAppear {
            statusGroup = appState.jobsStatusGroup
            guard !usesVisualPreview else {
                return
            }
            Task { await loadJobs() }
        }
        .onChange(of: statusGroup) { _, _ in
            guard !usesVisualPreview else {
                return
            }
            Task { await loadJobs() }
        }
    }

    private var topControls: some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: MainLayout.controlSpacing) {
                statusTabs
                searchField
            }
        }
        .padding(.horizontal, MainLayout.horizontalGutter)
        .padding(.top, MainLayout.topRhythm)
    }

    private var statusTabs: some View {
        HStack(spacing: 12) {
            tabButton(title: "In Progress", value: "active", systemImage: "briefcase.fill")
            tabButton(title: "Completed", value: "completed", systemImage: "checkmark.seal.fill")
        }
    }

    private var searchField: some View {
        PatchworkSearchField(placeholder: "Search jobs or people...", text: $searchText)
            .accessibilityIdentifier("Jobs.searchField")
            .accessibilityLabel("Search jobs or people")
    }

    private func tabButton(title: String, value: String, systemImage: String) -> some View {
        Button {
            statusGroup = value
        } label: {
            Label(title, systemImage: systemImage)
                .font(.patchworkBodyStrong)
                .foregroundStyle(statusGroup == value ? PatchworkTheme.brand : PatchworkTheme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: PatchworkMetrics.buttonHeight)
                .background(
                    statusGroup == value ? PatchworkTheme.brandSoft : PatchworkTheme.surface.opacity(0.88),
                    in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                        .stroke(statusGroup == value ? PatchworkTheme.brand.opacity(0.28) : PatchworkTheme.stroke, lineWidth: 1)
                )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("Jobs.statusTab.\(value)")
        .accessibilityLabel(title)
        .accessibilityValue(statusGroup == value ? "Selected" : "Not selected")
        .accessibilityHint("Filters jobs by \(title.lowercased())")
        .accessibilityAddTraits(statusGroup == value ? .isSelected : [])
    }

    private func jobCard(_ job: JobSummary) -> some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let categoryName = job.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !categoryName.isEmpty {
                            Text(categoryName.uppercased())
                                .font(.patchworkCaption)
                                .foregroundStyle(PatchworkTheme.brand)
                                .tracking(0.6)
                        }

                        Text(jobTitle(job) ?? "Job details unavailable")
                            .font(.patchworkCardTitle)
                            .foregroundStyle(PatchworkTheme.textPrimary)
                            .lineLimit(2)
                    }

                    Spacer()

                    statusBadge(job.status)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    metaCell("Date", value: dateLabel(job), systemImage: "calendar")
                    metaCell("Rate", value: rateLabel(job), systemImage: "banknote")
                }

                HStack(spacing: 8) {
                    PatchworkRemoteImage(
                        asset: job.counterpartyImage,
                        legacyURL: job.counterpartyPhotoUrl,
                        preferredVariant: .thumb,
                        contentMode: .fill
                    ) {
                        counterpartyPlaceholder(for: job)
                    }
                    .frame(width: 22, height: 22)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(PatchworkTheme.stroke, lineWidth: 1)
                    )
                    .accessibilityHidden(true)

                    Text(counterpartyLabel(for: job))
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                    Spacer()
                    Label("Open details", systemImage: "arrow.right")
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(jobCardAccessibilityLabel(job))
        .accessibilityHint("Opens job details")
    }

    private func statusBadge(_ status: String) -> some View {
        let title = status.replacingOccurrences(of: "_", with: " ").capitalized
        let foreground: Color = status == "completed" ? PatchworkTheme.success : PatchworkTheme.brand
        return PatchworkPill(title: title, foreground: foreground)
    }

    private func metaCell(_ title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.textSecondary)
            Text(value)
                .font(.patchworkBodyStrong)
                .foregroundStyle(PatchworkTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .patchworkInsetSurface()
    }

    private var emptyState: some View {
        let isSearchEmptyState = !searchQuery.isEmpty && !appState.jobs.isEmpty
        return PatchworkEmptyStateCard(
            systemImage: isSearchEmptyState ? "magnifyingglass" : (statusGroup == "completed" ? "checkmark.seal.fill" : "briefcase.fill"),
            title: isSearchEmptyState ? "No matching jobs" : (statusGroup == "completed" ? "No completed jobs yet" : "No jobs in progress"),
            message: isSearchEmptyState ? "Try a different search term to find the job, category, or customer you're looking for." : (statusGroup == "completed" ? "Completed jobs will appear here once work is wrapped up." : "Your active jobs will appear here once proposals are accepted.")
        )
        .frame(maxWidth: .infinity)
    }

    private var filteredJobs: [JobSummary] {
        guard !searchQuery.isEmpty else {
            return appState.jobs
        }

        return appState.jobs.filter { job in
            searchableStrings(for: job).contains { value in
                value.localizedStandardContains(searchQuery)
            }
        }
    }

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func searchableStrings(for job: JobSummary) -> [String] {
        [
            job.description,
            job.categoryName,
            job.counterpartyName
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    }

    private func counterpartyLabel(for job: JobSummary) -> String {
        if let name = job.counterpartyName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        return "Counterparty unavailable"
    }

    private func jobTitle(_ job: JobSummary) -> String? {
        if let description = job.description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
            return description
        }
        if let counterpartyName = job.counterpartyName?.trimmingCharacters(in: .whitespacesAndNewlines), !counterpartyName.isEmpty {
            return counterpartyName
        }
        if let categoryName = job.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines), !categoryName.isEmpty {
            return categoryName
        }
        return nil
    }

    private func rateLabel(_ job: JobSummary) -> String {
        guard let rate = job.rate else {
            return "Rate unavailable"
        }
        let base = PatchworkCurrency.formatted(cents: rate)
        return job.rateType == "hourly" ? "\(base)/hr" : base
    }

    private func counterpartyPlaceholder(for job: JobSummary) -> some View {
        let name = counterpartyLabel(for: job)
        return ZStack {
            PatchworkTheme.brandSoft
            Text(String(name.prefix(1)).uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(PatchworkTheme.brand)
        }
    }

    private func jobCardAccessibilityLabel(_ job: JobSummary) -> String {
        let title = jobTitle(job) ?? "Job details unavailable"
        let category = job.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let status = job.status.replacingOccurrences(of: "_", with: " ").capitalized
        let date = dateLabel(job)
        let rate = rateLabel(job)
        let counterparty = counterpartyLabel(for: job)

        let parts = [
            category?.isEmpty == false ? "\(category!)." : nil,
            "\(title).",
            "\(status).",
            "\(date).",
            "\(rate).",
            counterparty == "Counterparty unavailable" ? nil : "With \(counterparty)."
        ].compactMap { $0 }

        return parts.joined(separator: " ")
    }

    private func dateLabel(_ job: JobSummary) -> String {
        if statusGroup == "completed", let completedDate = job.completedDate {
            return formattedJobDate(completedDate)
        }
        guard let startDate = job.startDate else {
            return statusGroup == "completed" ? "Completion date unavailable" : "Schedule unavailable"
        }
        return formattedJobDate(startDate)
    }

    private func loadJobs() async {
        await appState.refreshJobs(client: sessionStore.client, statusGroup: statusGroup)
    }

    private func formattedJobDate(_ value: String) -> String {
        if let date = Self.iso8601FormatterWithFractional.date(from: value) ?? Self.iso8601Formatter.date(from: value) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return value
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
