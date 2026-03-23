import Foundation
import SwiftUI

struct HomeView: View {
    private enum MainLayout {
        static let horizontalGutter: CGFloat = 20
        static let topRhythm: CGFloat = 16
    }

    private enum LayoutMode {
        case spotlight
        case list
    }

    private struct TaskerRoute: Hashable, Identifiable {
        let id: ConvexID
    }

    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    @State private var selectedCategorySlug: String?
    @State private var radiusKm = 25
    @State private var showRadiusSheet = false
    @State private var isStartingChat = false
    @State private var currentCardIndex = 0
    @State private var layoutMode: LayoutMode = .spotlight
    @State private var cardDragOffset: CGFloat = 0
    @State private var taskerRoute: TaskerRoute?
    private let usesVisualPreview = ProcessInfo.processInfo.arguments.contains("PATCHWORK_UI_EMPTY_TABS")

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brand)

            VStack(spacing: 0) {
                header
                if layoutMode == .spotlight {
                    spotlightContent
                } else {
                    listContent
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showRadiusSheet) {
            radiusSheet
                .patchworkSheetChrome(detents: [.height(360)])
        }
        .navigationDestination(item: $taskerRoute) { route in
            ProviderDetailView(taskerId: route.id)
        }
        .task {
            guard !usesVisualPreview else {
                selectedCategorySlug = appState.activeCategorySlug
                radiusKm = appState.searchRadius
                return
            }
            selectedCategorySlug = appState.activeCategorySlug
            radiusKm = appState.searchRadius
            await reload()
        }
        .task(id: coordinateRefreshKey) {
            guard !usesVisualPreview else {
                return
            }
            guard appState.currentUser?.location?.coordinates != nil else {
                return
            }
            await reload()
        }
    }

    private var header: some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Button {
                        showRadiusSheet = true
                    } label: {
                        Label("\(locationDisplayLabel) · \(radiusKm) km", systemImage: "mappin.and.ellipse")
                            .font(.patchworkBodyStrong)
                            .foregroundStyle(PatchworkTheme.brand)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .frame(height: 50)
                            .background(PatchworkTheme.brandSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Home.radiusButton")

                    HStack(spacing: 6) {
                        layoutButton(mode: .spotlight, icon: "rectangle.portrait")
                        layoutButton(mode: .list, icon: "list.bullet")
                    }
                    .padding(4)
                    .background(PatchworkTheme.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
                    )
                }

                Menu {
                    Button("All categories") {
                        selectedCategorySlug = nil
                        Task { await reload() }
                    }
                    ForEach(appState.categories, id: \.id) { category in
                        Button(category.name) {
                            selectedCategorySlug = category.slug
                            Task { await reload() }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedCategoryName)
                            .foregroundStyle(PatchworkTheme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.subheadline)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(PatchworkTheme.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
                    )
                }
                .accessibilityIdentifier("Home.categoryMenu")
            }
        }
        .padding(.horizontal, MainLayout.horizontalGutter)
        .padding(.top, MainLayout.topRhythm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var listContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                if appState.taskers.isEmpty {
                    emptyState
                } else {
                    ForEach(appState.taskers) { tasker in
                        taskerListRow(tasker)
                            .accessibilityIdentifier("Home.taskerRow.\(tasker.id)")
                    }
                }
            }
            .padding(.horizontal, MainLayout.horizontalGutter)
            .padding(.top, MainLayout.topRhythm)
            .padding(.bottom, MainLayout.horizontalGutter)
        }
    }

    private var spotlightContent: some View {
        VStack(spacing: 0) {
            if appState.taskers.isEmpty {
                emptyState
                    .padding(.horizontal, MainLayout.horizontalGutter)
                    .padding(.top, MainLayout.topRhythm)
            } else if let tasker = currentTasker {
                spotlightCard(tasker)
                    .padding(.horizontal, MainLayout.horizontalGutter)
                    .padding(.top, MainLayout.topRhythm)
                    .offset(x: cardDragOffset)
                    .rotationEffect(.degrees(Double(cardDragOffset / 24)))
                    .opacity(Double(1 - min(CGFloat(0.25), abs(cardDragOffset) / CGFloat(420))))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                cardDragOffset = max(-140, min(140, value.translation.width))
                            }
                            .onEnded { value in
                                handleSpotlightSwipeEnd(value)
                            }
                    )

                Text("\(currentCardIndex + 1) of \(appState.taskers.count)")
                    .font(.subheadline)
                    .foregroundStyle(PatchworkTheme.textSecondary)
                    .padding(.top, 14)
            }

            Spacer(minLength: 0)
        }
    }

    private func spotlightCard(_ tasker: TaskerSummary) -> some View {
        VStack(spacing: 0) {
            AsyncImage(url: imageURL(tasker)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                PatchworkTheme.stroke
            }
            .frame(height: 270)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.22)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .overlay(alignment: .bottomLeading) {
                    Text(tasker.displayName)
                        .font(.patchworkCardTitle)
                        .foregroundStyle(.white)
                        .padding(18)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let categoryName = tasker.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !categoryName.isEmpty {
                            Text(categoryName)
                                .font(.patchworkBody)
                                .foregroundStyle(PatchworkTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        reviewSummary(tasker)
                        if let rateLabel = tasker.rateLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !rateLabel.isEmpty {
                            Text(rateLabel)
                                .font(.patchworkCardTitle)
                                .foregroundStyle(PatchworkTheme.brand)
                        }
                    }
                }

                HStack(spacing: 14) {
                    if let distanceLabel = tasker.distanceLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !distanceLabel.isEmpty {
                        Label("\(distanceLabel) away", systemImage: "mappin")
                            .font(.footnote)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                    }
                    if let completedJobs = tasker.completedJobs {
                        Text("\(completedJobs) jobs completed")
                            .font(.footnote)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                    }
                }

                if let bio = tasker.bio?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !bio.isEmpty {
                    Text(bio)
                        .font(.patchworkBody)
                        .foregroundStyle(PatchworkTheme.textPrimary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    taskerRoute = TaskerRoute(id: tasker.id)
                } label: {
                    Label("View full profile", systemImage: "arrow.up.right.circle")
                        .font(.patchworkBodyStrong)
                        .foregroundStyle(PatchworkTheme.brand)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("Home.spotlightViewProfileButton")
                .accessibilityLabel("View \(tasker.displayName) profile")

                HStack(spacing: 14) {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            advanceCard()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(PatchworkTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(PatchworkTheme.surfaceMuted, in: Capsule())
                            .overlay(Capsule().stroke(PatchworkTheme.strokeStrong, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Home.skipButton")

                    Button {
                        Task { await startChat(with: tasker.userId) }
                    } label: {
                        Image(systemName: isStartingChat ? "hourglass" : "message")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(PatchworkTheme.surface)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(PatchworkTheme.heroGradient, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isStartingChat)
                    .accessibilityIdentifier("Home.spotlightStartChatButton.\(tasker.userId)")
                    .accessibilityLabel("Start chat with \(tasker.displayName)")
                }
            }
            .padding(18)
        }
        .background(PatchworkTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
        .shadow(color: PatchworkTheme.brand.opacity(0.1), radius: 24, y: 14)
    }

    private func taskerListRow(_ tasker: TaskerSummary) -> some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: imageURL(tasker)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                PatchworkTheme.stroke
            }
            .frame(width: 56, height: 56)
            .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(tasker.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PatchworkTheme.textPrimary)
                    if tasker.verified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(PatchworkTheme.success)
                    }
                }

                if let categoryName = tasker.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !categoryName.isEmpty {
                    Text(categoryName)
                        .font(.footnote)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                }

                HStack(spacing: 10) {
                    reviewSummary(tasker)
                    if let distance = tasker.distanceLabel {
                        Label(distance, systemImage: "mappin")
                            .font(.footnote)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                    }
                }

                HStack {
                    if let rateLabel = tasker.rateLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !rateLabel.isEmpty {
                        Text(rateLabel)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(PatchworkTheme.brand)
                    }

                    Spacer()

                    Button {
                        taskerRoute = TaskerRoute(id: tasker.id)
                    } label: {
                        Text("View")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(PatchworkTheme.brand)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Home.viewTaskerButton.\(tasker.id)")
                    .accessibilityLabel("View \(tasker.displayName) profile")
                }
            }

            VStack(spacing: 8) {
                Button {
                    Task { await startChat(with: tasker.userId) }
                } label: {
                    Label("Start chat", systemImage: isStartingChat ? "hourglass" : "message.fill")
                        .labelStyle(.iconOnly)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PatchworkTheme.surface)
                        .frame(width: 34, height: 34)
                        .background(PatchworkTheme.brand, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isStartingChat)
                .accessibilityIdentifier("Home.listStartChatButton.\(tasker.userId)")
                .accessibilityLabel("Start chat with \(tasker.displayName)")

                Button {
                    taskerRoute = TaskerRoute(id: tasker.id)
                } label: {
                    Label("View profile", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PatchworkTheme.textSecondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("Home.chevronTaskerButton.\(tasker.id)")
            }
        }
        .padding(16)
        .background(PatchworkTheme.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
    }

    private var emptyState: some View {
        PatchworkEmptyStateCard(
            systemImage: hasSearchCoordinates ? "sparkles" : "location.slash",
            title: hasSearchCoordinates ? "No taskers found" : "Location unavailable",
            message: hasSearchCoordinates ? "Try a broader radius or switch categories to surface more nearby professionals." : "Update your location to search nearby taskers."
        )
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("Home.emptyState")
    }

    private var radiusSheet: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brandBright)

            PatchworkSurfaceCard {
                VStack(spacing: 18) {
                    PatchworkTopBar(title: "Search Radius", onBack: { showRadiusSheet = false })

                    HStack {
                        Label(locationDisplayLabel, systemImage: "mappin")
                            .foregroundStyle(PatchworkTheme.brand)
                        Spacer()
                        Text("\(radiusKm) km")
                            .foregroundStyle(PatchworkTheme.textPrimary)
                    }

                    Slider(value: Binding(
                        get: { Double(radiusKm) },
                        set: { radiusKm = Int($0.rounded()) }
                    ), in: 1 ... 250, step: 1)
                    .tint(PatchworkTheme.brand)
                    .accessibilityIdentifier("Home.radiusStepper")

                    HStack {
                        Text("1 km")
                        Spacer()
                        Text("250 km")
                    }
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textSecondary)

                    Button("Apply") {
                        Task { await reload() }
                        showRadiusSheet = false
                    }
                    .buttonStyle(PatchworkPrimaryButtonStyle())
                    .accessibilityIdentifier("Home.radiusApplyButton")
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
    }

    private var selectedCategoryName: String {
        if let selectedCategorySlug,
           let category = appState.categories.first(where: { $0.slug == selectedCategorySlug }) {
            return category.name
        }
        return "All categories"
    }

    private var locationDisplayLabel: String {
        let city = appState.currentUser?.location?.city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let province = appState.currentUser?.location?.province?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if city.isEmpty && province.isEmpty {
            return "Location unavailable"
        }
        if city.isEmpty {
            return province
        }
        if province.isEmpty {
            return city
        }
        return "\(city), \(province)"
    }

    private var hasSearchCoordinates: Bool {
        appState.currentUser?.location?.coordinates != nil
    }

    private var coordinateRefreshKey: String {
        let latitude = appState.currentUser?.location?.coordinates?.lat ?? .nan
        let longitude = appState.currentUser?.location?.coordinates?.lng ?? .nan
        return "\(latitude)|\(longitude)"
    }

    @ViewBuilder
    private func reviewSummary(_ tasker: TaskerSummary) -> some View {
        if let averageRating = tasker.averageRating,
           let reviewCount = tasker.reviewCount,
           reviewCount > 0 {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(PatchworkTheme.ratingStar)
                Text(averageRating.formatted(.number.precision(.fractionLength(1))))
                    .font(.footnote)
                    .foregroundStyle(PatchworkTheme.textPrimary)
                Text("(\(reviewCount))")
                    .font(.footnote)
                    .foregroundStyle(PatchworkTheme.textSecondary)
            }
        }
    }

    private func reload() async {
        appState.activeCategorySlug = selectedCategorySlug
        appState.searchRadius = radiusKm
        await appState.searchTaskers(
            client: sessionStore.client,
            categorySlug: selectedCategorySlug,
            radiusKm: radiusKm,
            excludeCurrentUserWhenTasker: true
        )
        if appState.taskers.isEmpty {
            currentCardIndex = 0
        } else if currentCardIndex >= appState.taskers.count {
            currentCardIndex = appState.taskers.count - 1
        }
    }

    private var currentTasker: TaskerSummary? {
        guard !appState.taskers.isEmpty else {
            return nil
        }
        let safeIndex = min(max(0, currentCardIndex), appState.taskers.count - 1)
        return appState.taskers[safeIndex]
    }

    private func advanceCard() {
        guard !appState.taskers.isEmpty else {
            return
        }
        currentCardIndex = (currentCardIndex + 1) % appState.taskers.count
    }

    private func retreatCard() {
        guard !appState.taskers.isEmpty else {
            return
        }
        currentCardIndex = (currentCardIndex - 1 + appState.taskers.count) % appState.taskers.count
    }

    private func handleSpotlightSwipeEnd(_ value: DragGesture.Value) {
        let distance = value.translation.width
        let predictedDistance = value.predictedEndTranslation.width
        let distanceThreshold: CGFloat = 70
        let predictedThreshold: CGFloat = 120

        if distance < -distanceThreshold || predictedDistance < -predictedThreshold {
            performSpotlightSwipe(direction: .left)
        } else if distance > distanceThreshold || predictedDistance > predictedThreshold {
            performSpotlightSwipe(direction: .right)
        } else {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                cardDragOffset = 0
            }
        }
    }

    private enum SwipeDirection {
        case left
        case right
    }

    private func performSpotlightSwipe(direction: SwipeDirection) {
        let offscreenOffset: CGFloat = direction == .left ? -380 : 380

        withAnimation(.easeOut(duration: 0.16)) {
            cardDragOffset = offscreenOffset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            if direction == .left {
                advanceCard()
            } else {
                retreatCard()
            }
            cardDragOffset = -offscreenOffset * 0.14
            withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                cardDragOffset = 0
            }
        }
    }

    private func layoutButton(mode: LayoutMode, icon: String) -> some View {
        let isSelected = layoutMode == mode
        let title = mode == .spotlight ? "Spotlight layout" : "List layout"
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                layoutMode = mode
            }
        } label: {
            Label(title, systemImage: icon)
                .labelStyle(.iconOnly)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? PatchworkTheme.surface : PatchworkTheme.textSecondary)
                .frame(width: 30, height: 30)
                .background(isSelected ? PatchworkTheme.brand : PatchworkTheme.stroke, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(mode == .spotlight ? "Home.layout.spotlightButton" : "Home.layout.listButton")
    }

    private func startChat(with taskerUserId: ConvexID) async {
        isStartingChat = true
        defer { isStartingChat = false }
        do {
            let conversationId: ConvexID = try await sessionStore.client.mutation(
                "conversations:startConversation",
                args: ["taskerId": taskerUserId]
            )
            await appState.openConversation(
                client: sessionStore.client,
                conversationId: conversationId,
                role: "seeker"
            )
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
