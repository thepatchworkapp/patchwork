import SwiftUI

struct BrowseView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    @State private var view = "list"

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Browse Taskers")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Button {
                        // PoC shows icon-only action in app bar.
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(.white)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(appState.taskers.count) Taskers near you")
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 2) {
                            Button {
                                view = "list"
                            } label: {
                                Image(systemName: "list.bullet")
                                    .frame(width: 32, height: 32)
                                    .background(view == "list" ? .white : .clear, in: RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(view == "list" ? Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255) : .secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("Browse.viewMode.list")

                            Button {
                                view = "map"
                            } label: {
                                Image(systemName: "map")
                                    .frame(width: 32, height: 32)
                                    .background(view == "map" ? .white : .clear, in: RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(view == "map" ? Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255) : .secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("Browse.viewMode.map")
                        }
                        .padding(4)
                        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10))
                    }

                    Text("Ranked by rating, proximity, and activity-never paid placement")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(.white)

                if appState.taskers.isEmpty {
                    Spacer()
                    Text("No Taskers found in your area.")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else if view == "map" {
                    Spacer()
                    Text("Map View coming soon")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(appState.taskers) { tasker in
                                NavigationLink {
                                    ProviderDetailView(taskerId: tasker.id)
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        AsyncImage(url: avatarURL(tasker)) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            Color(.systemGray5)
                                        }
                                        .frame(width: 56, height: 56)
                                        .clipShape(Circle())

                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(tasker.displayName)
                                                    .foregroundStyle(.primary)
                                                    .font(.subheadline.weight(.semibold))
                                                if tasker.verified == true {
                                                    Text("✓")
                                                        .foregroundStyle(Color(red: 22 / 255, green: 163 / 255, blue: 74 / 255))
                                                }
                                            }
                                            Text(tasker.categoryName ?? "General")
                                                .foregroundStyle(.secondary)
                                                .font(.footnote)

                                            HStack(spacing: 10) {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "star.fill")
                                                        .foregroundStyle(.yellow)
                                                    Text(String(format: "%.1f", tasker.averageRating ?? 0))
                                                    Text("(\(tasker.reviewCount ?? 0))")
                                                        .foregroundStyle(.secondary)
                                                }
                                                .font(.footnote)

                                                if let distance = tasker.distanceLabel {
                                                    Label(distance, systemImage: "mappin")
                                                        .font(.footnote)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }

                                            Text(tasker.rateLabel ?? "Rate on request")
                                                .font(.footnote)
                                                .foregroundStyle(.primary)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray5), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("Browse.taskerRow.\(tasker.id)")
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await reloadBrowseTaskers()
        }
    }

    private func reloadBrowseTaskers() async {
        await appState.searchTaskers(
            client: sessionStore.client,
            categorySlug: nil,
            radiusKm: 25,
            excludeCurrentUserWhenTasker: true
        )
    }

    private func avatarURL(_ tasker: TaskerSummary) -> URL? {
        if let avatarUrl = tasker.avatarUrl, let url = URL(string: avatarUrl) {
            return url
        }
        if let categoryPhotoUrl = tasker.categoryPhotoUrl, let url = URL(string: categoryPhotoUrl) {
            return url
        }
        return nil
    }
}

struct ProviderDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    let taskerId: ConvexID

    @State private var selectedCategoryID: ConvexID?
    @State private var isStartingChat = false
    @State private var chatError: String?

    var body: some View {
        Group {
            if let tasker {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(tasker.displayName)
                                        .font(.title.bold())
                                    Text(selectedProfile?.categoryName ?? "Service Provider")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if tasker.verified == true {
                                    Text("Verified")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.green, in: Capsule())
                                }
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text(String(format: "%.1f", tasker.averageRating ?? 0))
                                    .font(.subheadline.weight(.semibold))
                                Text("(\(tasker.reviewCount ?? 0))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if tasker.categoryProfiles.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(tasker.categoryProfiles) { profile in
                                        let isSelected = selectedProfile?.id == profile.id
                                        Button(profile.categoryName) {
                                            selectedCategoryID = profile.id
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(isSelected ? .indigo : .gray)
                                        .accessibilityIdentifier("ProviderDetail.serviceCategory.\(profile.id)")
                                    }
                                }
                            }
                        }

                        if let bio = selectedProfile?.categoryBio ?? tasker.bio {
                            providerCard(title: "About", content: bio)
                        }

                        if let firstPhotoUrl = selectedProfile?.firstPhotoUrl,
                           let photoURL = URL(string: firstPhotoUrl) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Work Photo")
                                    .font(.headline)
                                AsyncImage(url: photoURL) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Color(.systemGray5)
                                }
                                .frame(height: 190)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pricing")
                                .font(.headline)
                            VStack(alignment: .leading, spacing: 10) {
                                pricingRow(
                                    title: selectedProfile?.rateType == "hourly" ? "Hourly rate" : "Fixed rate",
                                    value: rateLabel(for: selectedProfile)
                                )
                                pricingRow(
                                    title: "Service area",
                                    value: selectedProfile?.serviceRadius.map { "\($0) km radius" } ?? "Not specified"
                                )
                                pricingRow(
                                    title: "Jobs completed",
                                    value: "\(selectedProfile?.completedJobs ?? tasker.completedJobs ?? 0)"
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Reviews")
                                    .font(.headline)
                                Spacer()
                                if (tasker.reviewCount ?? 0) > 0 {
                                    Text("See all \(tasker.reviewCount ?? 0)")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.indigo)
                                }
                            }
                            if tasker.reviews.isEmpty {
                                Text("No reviews yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(14)
                                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                            } else {
                                ForEach(tasker.reviews.prefix(3)) { review in
                                    ProviderReviewRow(review: review)
                                }
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 80)
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Button {
                            } label: {
                                Image(systemName: "heart")
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("ProviderDetail.favoriteButton")

                            Button {
                                Task { await startChat(with: tasker.userId) }
                            } label: {
                                HStack(spacing: 8) {
                                    if isStartingChat {
                                        ProgressView()
                                            .tint(.white)
                                        Text("Opening chat...")
                                    } else {
                                        Image(systemName: "message")
                                        Text("Chat")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isStartingChat)
                            .accessibilityIdentifier("ProviderDetail.startChatButton")
                        }

                        if let chatError {
                            Text(chatError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .accessibilityIdentifier("ProviderDetail.chatError")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial)
                }
            } else {
                ProgressView("Loading profile...")
            }
        }
        .navigationTitle("Provider")
        .task {
            await appState.loadTaskerDetail(client: sessionStore.client, taskerId: taskerId)
            if selectedCategoryID == nil {
                selectedCategoryID = tasker?.categoryProfiles.first?.id
            }
        }
        .onChange(of: tasker?.id) { _, _ in
            selectedCategoryID = tasker?.categoryProfiles.first?.id
        }
    }

    private var tasker: TaskerDetail? {
        guard let selected = appState.selectedTasker, selected.id == taskerId else { return nil }
        return selected
    }

    private var selectedProfile: TaskerCategoryProfile? {
        guard let tasker else { return nil }
        if let selectedCategoryID,
           let selected = tasker.categoryProfiles.first(where: { $0.id == selectedCategoryID }) {
            return selected
        }
        return tasker.categoryProfiles.first
    }

    private func pricingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    private func providerCard(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func rateLabel(for profile: TaskerCategoryProfile?) -> String {
        guard let profile else { return "Contact for pricing" }
        if profile.rateType == "hourly", let hourlyRate = profile.hourlyRate {
            return "$\(String(format: "%.2f", Double(hourlyRate) / 100))/hr"
        }
        if let fixedRate = profile.fixedRate {
            return "$\(String(format: "%.2f", Double(fixedRate) / 100)) flat"
        }
        return "Contact for pricing"
    }

    private func startChat(with taskerUserId: ConvexID) async {
        guard !isStartingChat else { return }
        isStartingChat = true
        chatError = nil
        defer { isStartingChat = false }
        do {
            let conversationId: ConvexID = try await sessionStore.client.mutation(
                "conversations:startConversation",
                args: ["taskerId": taskerUserId]
            )
            appState.selectedTab = .messages
            await appState.loadConversation(client: sessionStore.client, conversationId: conversationId)
            await appState.refreshAuthedData(client: sessionStore.client)
        } catch {
            chatError = "Unable to start chat right now. Please try again."
            appState.lastError = error.localizedDescription
        }
    }
}

private struct ProviderReviewRow: View {
    let review: TaskerReview

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: avatarURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color(.systemGray5)
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(review.reviewerName)
                        .font(.subheadline.weight(.semibold))
                    Text("Verified hire")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .foregroundStyle(.green)
                        .background(Color.green.opacity(0.14), in: Capsule())
                    Spacer()
                    Text(reviewDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 2) {
                    ForEach(0 ..< max(1, review.rating), id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }

                Text(review.text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private var avatarURL: URL? {
        guard let urlString = review.reviewerPhotoUrl else { return nil }
        return URL(string: urlString)
    }

    private var reviewDate: String {
        let date = Date(timeIntervalSince1970: TimeInterval(review.createdAt) / 1000)
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
