import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    @State private var selectedCategorySlug: String?
    @State private var radiusKm = 25
    @State private var showRadiusSheet = false
    @State private var currentCardIndex = 0
    @State private var isStartingChat = false

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Discover Taskers")
                                .font(.title3.weight(.semibold))
                            Spacer()
                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient(
                                    colors: [Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255), Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 40, height: 40)
                        }

                        Button {
                            showRadiusSheet = true
                        } label: {
                            Label("Toronto, ON • \(radiusKm) km radius", systemImage: "mappin")
                                .font(.subheadline)
                                .foregroundStyle(Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Home.radiusButton")

                        Menu {
                            Button("All categories") {
                                selectedCategorySlug = nil
                                currentCardIndex = 0
                                Task { await reload() }
                            }
                            ForEach(appState.categories) { category in
                                Button(category.name) {
                                    selectedCategorySlug = category.slug
                                    currentCardIndex = 0
                                    Task { await reload() }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedCategoryName)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(.white, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }
                        .accessibilityIdentifier("Home.categoryMenu")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 14)
                    .background(.white)

                    if let tasker = currentTasker {
                        VStack(alignment: .leading, spacing: 12) {
                            ZStack(alignment: .topTrailing) {
                                AsyncImage(url: imageURL(tasker)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    LinearGradient(
                                        colors: [Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255), Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                }
                                .frame(height: 250)
                                .clipShape(RoundedRectangle(cornerRadius: 0))

                                if tasker.verified == true {
                                    Text("Verified")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color(red: 22 / 255, green: 163 / 255, blue: 74 / 255), in: Capsule())
                                        .padding(12)
                                }
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(tasker.displayName)
                                            .font(.headline)
                                        Text(tasker.categoryName ?? "General")
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "star.fill")
                                                .foregroundStyle(.yellow)
                                                .font(.subheadline)
                                            Text(String(format: "%.1f", tasker.averageRating ?? 0))
                                                .font(.subheadline)
                                            Text("(\(tasker.reviewCount ?? 0))")
                                                .foregroundStyle(.secondary)
                                                .font(.subheadline)
                                        }
                                        Text(tasker.rateLabel ?? "Rate on request")
                                            .foregroundStyle(Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255))
                                            .font(.subheadline)
                                    }
                                }

                                HStack(spacing: 12) {
                                    if let distance = tasker.distanceLabel {
                                        Label("\(distance) away", systemImage: "mappin")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let completedJobs = tasker.completedJobs {
                                        Text("\(completedJobs) jobs completed")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Text(tasker.bio?.isEmpty == false ? tasker.bio! : "No profile bio yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)

                                NavigationLink {
                                    ProviderDetailView(taskerId: tasker.id)
                                } label: {
                                    Label("View full profile", systemImage: "info.circle")
                                        .foregroundStyle(Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("Home.viewProfileLink")

                                HStack(spacing: 14) {
                                    Button {
                                        advanceCard()
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 56)
                                            .background(.white, in: Capsule())
                                            .overlay(Capsule().stroke(Color(.systemGray4), lineWidth: 2))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("Home.skipButton")

                                    Button {
                                        Task { await startChat(with: tasker.userId) }
                                    } label: {
                                        Image(systemName: isStartingChat ? "hourglass" : "message")
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 56)
                                            .background(Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isStartingChat)
                                    .accessibilityIdentifier("Home.startChatButton")
                                }
                            }
                            .padding(16)
                        }
                        .background(.white, in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(.systemGray5), lineWidth: 1))
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                        Text("\(currentCardIndex + 1) of \(appState.taskers.count)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                    } else {
                        VStack(spacing: 8) {
                            Text("No taskers found")
                                .font(.headline)
                            Text("Try adjusting your filters or search radius")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 120)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showRadiusSheet) {
            NavigationStack {
                VStack(spacing: 20) {
                    HStack {
                        Text("Search Radius")
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Button {
                            showRadiusSheet = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Label("Toronto, ON", systemImage: "mappin")
                            .foregroundStyle(Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255))
                        Spacer()
                        Text("\(radiusKm) km")
                    }

                    Slider(value: Binding(
                        get: { Double(radiusKm) },
                        set: { radiusKm = Int($0.rounded()) }
                    ), in: 1 ... 250, step: 1)
                    .tint(Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255))
                    .accessibilityIdentifier("Home.radiusStepper")

                    HStack {
                        Text("1 km")
                        Spacer()
                        Text("250 km")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Button("Apply") {
                        currentCardIndex = 0
                        Task { await reload() }
                        showRadiusSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255))
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("Home.radiusApplyButton")
                }
                .padding(24)
            }
            .presentationDetents([.height(320)])
        }
        .task {
            selectedCategorySlug = appState.activeCategorySlug
            await reload()
        }
    }

    private var selectedCategoryName: String {
        if let selectedCategorySlug,
           let category = appState.categories.first(where: { $0.slug == selectedCategorySlug }) {
            return category.name
        }
        return "All categories"
    }

    private var currentTasker: TaskerSummary? {
        guard !appState.taskers.isEmpty else { return nil }
        return appState.taskers[min(currentCardIndex, appState.taskers.count - 1)]
    }

    private func reload() async {
        appState.activeCategorySlug = selectedCategorySlug
        await appState.searchTaskers(
            client: sessionStore.client,
            categorySlug: selectedCategorySlug,
            radiusKm: radiusKm,
            excludeCurrentUserWhenTasker: true
        )
        if currentCardIndex >= appState.taskers.count {
            currentCardIndex = 0
        }
    }

    private func advanceCard() {
        guard !appState.taskers.isEmpty else {
            currentCardIndex = 0
            return
        }
        currentCardIndex = (currentCardIndex + 1) % appState.taskers.count
    }

    private func startChat(with taskerUserId: ConvexID) async {
        isStartingChat = true
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
            appState.lastError = error.localizedDescription
        }
    }

    private func imageURL(_ tasker: TaskerSummary) -> URL? {
        if let avatarUrl = tasker.avatarUrl, let url = URL(string: avatarUrl) {
            return url
        }
        if let categoryPhotoUrl = tasker.categoryPhotoUrl, let url = URL(string: categoryPhotoUrl) {
            return url
        }
        return nil
    }
}
