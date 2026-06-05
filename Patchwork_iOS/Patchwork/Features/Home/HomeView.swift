import Foundation
import SwiftUI

struct HomeView: View {
    private enum MainLayout {
        static let horizontalGutter: CGFloat = 20
        static let topRhythm: CGFloat = 16
    }

    private struct TaskerRoute: Hashable, Identifiable {
        let id: ConvexID
    }

    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    @State private var selectedCategorySlug: String?
    @State private var selectedCategoryGroupSlug: String?
    @State private var selectedCategorySlugs = Set<String>()
    @State private var radiusKm = 25
    @State private var showRadiusSheet = false
    @State private var showCategorySheet = false
    @State private var categorySearchText = ""
    @State private var isStartingChat = false
    @State private var currentCardIndex = 0
    @State private var cardDragOffset: CGFloat = 0
    @State private var dismissedTaskerIDs = Set<ConvexID>()
    @State private var taskerRoute: TaskerRoute?
    private let usesVisualPreview = ProcessInfo.processInfo.arguments.contains("PATCHWORK_UI_EMPTY_TABS")

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brand)

            VStack(spacing: 0) {
                header
                spotlightContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showRadiusSheet) {
            radiusSheet
                .patchworkSheetChrome(detents: [.height(360)])
        }
        .sheet(isPresented: $showCategorySheet) {
            categorySheet
                .patchworkSheetChrome(detents: [.medium, .large])
        }
        .onChange(of: showCategorySheet) { _, isPresented in
            if !isPresented {
                categorySearchText = ""
            }
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
            await reload(resetDismissedTaskers: true)
        }
        .task(id: coordinateRefreshKey) {
            guard !usesVisualPreview else {
                return
            }
            guard appState.currentUser?.location?.coordinates != nil else {
                return
            }
            await reload(resetDismissedTaskers: false)
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
                    .accessibilityLabel("Search radius")
                    .accessibilityValue("\(locationDisplayLabel), \(radiusKm) kilometers")
                    .accessibilityHint("Opens radius settings")
                }

                categoryPicker
            }
        }
        .padding(.horizontal, MainLayout.horizontalGutter)
        .padding(.top, MainLayout.topRhythm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var categoryPicker: some View {
        if categoriesUnavailable {
            Button {
                Task { await retryCategories() }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Categories unavailable")
                            .font(.patchworkBodyStrong)
                            .foregroundStyle(PatchworkTheme.textPrimary)

                        Text(categoryAvailabilityMessage)
                            .font(.patchworkCaption)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    if appState.isLoadingCategories {
                        ProgressView()
                            .tint(PatchworkTheme.brand)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PatchworkTheme.brand)
                    }
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(PatchworkTheme.brandSoft.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Home.categoryRetryButton")
            .accessibilityLabel("Retry categories")
            .accessibilityHint(categoryAvailabilityMessage)
        } else {
            Button {
                showCategorySheet = true
            } label: {
                HStack {
                    Text(selectedCategoryLabel)
                        .lineLimit(1)
                        .foregroundStyle(PatchworkTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.subheadline)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(PatchworkTheme.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Home.categoryMenu")
            .accessibilityLabel("Category filter")
            .accessibilityValue(selectedCategoryLabel)
            .accessibilityHint("Opens category choices")
        }
    }

    private var spotlightContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                if visibleTaskers.isEmpty {
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
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .refreshable {
            await reload(resetDismissedTaskers: false)
        }
        .scrollIndicators(.hidden)
    }

    private func spotlightCard(_ tasker: TaskerSummary) -> some View {
        VStack(spacing: 0) {
            heroImage(tasker)
            .frame(height: 270)
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityHidden(true)
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
            .overlay(alignment: .bottomTrailing) {
                PatchworkRemoteImage(
                    asset: tasker.avatarImage,
                    legacyURL: tasker.avatarUrl,
                    preferredVariant: .thumb,
                    contentMode: .fill
                ) {
                    Circle().fill(PatchworkTheme.brandSoft)
                }
                .frame(width: 46, height: 46)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.9), lineWidth: 2)
                )
                .padding(14)
                .accessibilityHidden(true)
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

                taskerPrimaryLinks(tasker)

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
                            dismissCurrentCard()
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
                    .accessibilityLabel("Skip tasker")
                    .accessibilityHint("Shows the next profile")

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

    @ViewBuilder
    private func taskerPrimaryLinks(_ tasker: TaskerSummary) -> some View {
        let primaryWebsite = tasker.websiteLinks.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let primarySocial = tasker.socialLinks.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        if primaryWebsite?.isEmpty == false || primarySocial?.isEmpty == false {
            HStack(spacing: 10) {
                if let primaryWebsite, !primaryWebsite.isEmpty {
                    Label(primaryWebsite, systemImage: "globe")
                        .lineLimit(1)
                }
                if let primarySocial, !primarySocial.isEmpty {
                    Label(primarySocial, systemImage: "at")
                        .lineLimit(1)
                }
            }
            .font(.footnote)
            .foregroundStyle(PatchworkTheme.brand)
        }
    }

    private var emptyState: some View {
        PatchworkEmptyStateCard(
            systemImage: hasSearchCoordinates ? "sparkles" : "location.slash",
            title: hasSearchCoordinates ? "No taskers found" : "Location unavailable",
            message: hasSearchCoordinates ? "Try a broader radius or switch categories to discover more nearby professionals." : "Update your location to search nearby taskers."
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
                        Task { await reload(resetDismissedTaskers: true) }
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

    private var categorySheet: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brandBright)

            PatchworkSurfaceCard {
                VStack(spacing: 18) {
                    PatchworkTopBar(title: "Category", onBack: { showCategorySheet = false })

                    HStack(spacing: 10) {
                        Button {
                            recordCategorySearchSubmitIfNeeded()
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PatchworkTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Home.categorySearchSubmitButton")
                        .accessibilityLabel("Search categories")

                        TextField("Search categories", text: $categorySearchText)
                            .font(.patchworkBody)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .submitLabel(.search)
                            .onSubmit {
                                recordCategorySearchSubmitIfNeeded()
                            }
                            .accessibilityIdentifier("Home.categorySearchField")
                            .accessibilityLabel("Search categories")

                        if !categorySearchText.isEmpty {
                            Button {
                                categorySearchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(PatchworkTheme.textTertiary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("Home.categorySearchClearButton")
                            .accessibilityLabel("Clear category search")
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(PatchworkTheme.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(PatchworkTheme.stroke, lineWidth: 1)
                    )
                    .padding(.horizontal, 12)

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if shouldShowAllCategoriesOption {
                                categorySheetRow(
                                    label: "All categories",
                                    isSelected: selectedCategorySlug == nil
                                        && selectedCategoryGroupSlug == nil
                                        && selectedCategorySlugs.isEmpty,
                                    accessibilityIdentifier: "Home.categoryOption.all"
                                ) {
                                    selectCategory(nil)
                                }
                            }

                            ForEach(discoverCategoryGroupOptions, id: \.id) { group in
                                categorySheetRow(
                                    label: group.name,
                                    isSelected: selectedCategoryGroupSlug == group.slug && selectedCategorySlugs.count == group.categories.count,
                                    accessibilityIdentifier: "Home.categoryGroupOption.\(group.slug)"
                                ) {
                                    selectCategoryGroup(group)
                                }
                            }

                            if selectedCategoryGroup != nil && !discoverMemberCategoryOptions.isEmpty {
                                ForEach(discoverMemberCategoryOptions, id: \.id) { category in
                                    categorySheetRow(
                                        label: categoryMenuLabel(for: category),
                                        isSelected: selectedCategorySlugs.contains(category.slug),
                                        accessibilityIdentifier: "Home.categoryGroupMemberOption.\(category.slug)"
                                    ) {
                                        toggleSelectedMemberCategory(category)
                                    }
                                }
                            }

                            ForEach(discoverCategoryOptions, id: \.id) { category in
                                categorySheetRow(
                                    label: categoryMenuLabel(for: category),
                                    isSelected: selectedCategorySlug == category.slug && selectedCategoryGroupSlug == nil,
                                    accessibilityIdentifier: "Home.categoryOption.\(category.slug)"
                                ) {
                                    selectCategory(category.slug)
                                }
                            }

                            if discoverCategoryGroupOptions.isEmpty && discoverCategoryOptions.isEmpty && discoverMemberCategoryOptions.isEmpty && !shouldShowAllCategoriesOption {
                                VStack(spacing: 10) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(PatchworkTheme.brand)
                                        .accessibilityHidden(true)

                                    Text("No categories found")
                                        .font(.patchworkBodyStrong)
                                        .foregroundStyle(PatchworkTheme.textPrimary)

                                    Text("Try a different search term.")
                                        .font(.patchworkCaption)
                                        .foregroundStyle(PatchworkTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .accessibilityIdentifier("Home.categorySearchEmptyState")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
    }

    private func categorySheetRow(
        label: String,
        isSelected: Bool,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.patchworkBodyStrong)
                    .foregroundStyle(PatchworkTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(PatchworkTheme.brand)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 56)
            .background(
                isSelected ? PatchworkTheme.brandSoft.opacity(0.7) : PatchworkTheme.surface.opacity(0.92),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? PatchworkTheme.strokeStrong : PatchworkTheme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private var selectedCategoryLabel: String {
        if let selectedCategorySlug,
           let category = appState.categories.first(where: { $0.slug == selectedCategorySlug }) {
            return categoryMenuLabel(for: category)
        }
        if let selectedCategoryGroup {
            if selectedCategorySlugs.count == selectedCategoryGroup.categories.count {
                return selectedCategoryGroup.name
            }
            let selectedNames = selectedCategoryGroup.categories
                .filter { selectedCategorySlugs.contains($0.slug) }
                .map(\.name)
            if !selectedNames.isEmpty {
                return "\(selectedCategoryGroup.name): \(selectedNames.joined(separator: ", "))"
            }
        }
        return "All categories"
    }

    private func categoryMenuLabel(for category: Category) -> String {
        let emoji = category.emoji.map { "\($0) " } ?? ""
        return "\(emoji)\(category.name)"
    }

    private var discoverCategoryOptions: [Category] {
        sortedDiscoverCategories.filter { category in
            let query = trimmedCategorySearchText
            return query.isEmpty || category.name.localizedStandardContains(query)
        }
    }

    private var discoverCategoryGroupOptions: [CategoryGroup] {
        sortedDiscoverCategoryGroups.filter { group in
            let query = trimmedCategorySearchText
            return query.isEmpty
                || group.name.localizedStandardContains(query)
                || group.categories.contains { $0.name.localizedStandardContains(query) }
        }
    }

    private var discoverMemberCategoryOptions: [Category] {
        guard let selectedCategoryGroup else {
            return []
        }
        let query = trimmedCategorySearchText
        return selectedCategoryGroup.categories
            .sorted { lhs, rhs in lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending }
            .filter { category in
                query.isEmpty || category.name.localizedStandardContains(query)
            }
    }

    private var sortedDiscoverCategories: [Category] {
        appState.categories.sorted { lhs, rhs in
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private var sortedDiscoverCategoryGroups: [CategoryGroup] {
        appState.categoryGroups.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private var selectedCategoryGroup: CategoryGroup? {
        guard let selectedCategoryGroupSlug else {
            return nil
        }
        return appState.categoryGroups.first { $0.slug == selectedCategoryGroupSlug }
    }

    private var shouldShowAllCategoriesOption: Bool {
        trimmedCategorySearchText.isEmpty || "All categories".localizedStandardContains(trimmedCategorySearchText)
    }

    private var trimmedCategorySearchText: String {
        categorySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var categoriesUnavailable: Bool {
        appState.categories.isEmpty
    }

    private var categoryAvailabilityMessage: String {
        if let errorMessage = appState.categoriesErrorMessage, !errorMessage.isEmpty {
            return errorMessage
        }
        return "We could not load the category library. Try again."
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(reviewSummaryAccessibilityLabel(averageRating: averageRating, reviewCount: reviewCount))
        }
    }

    @ViewBuilder
    private func heroImage(_ tasker: TaskerSummary) -> some View {
        if let categoryCoverImage = tasker.categoryCoverImage {
            PatchworkRemoteImage(
                asset: categoryCoverImage,
                legacyURL: tasker.categoryPhotoUrl,
                preferredVariant: .large,
                contentMode: .fill
            ) {
                avatarFallbackHeroImage(tasker)
            }
        } else if let categoryPhotoUrl = tasker.categoryPhotoUrl,
                  !categoryPhotoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            PatchworkRemoteImage(
                asset: nil,
                legacyURL: categoryPhotoUrl,
                preferredVariant: .large,
                contentMode: .fill
            ) {
                avatarFallbackHeroImage(tasker)
            }
        } else {
            avatarFallbackHeroImage(tasker)
        }
    }

    private func avatarFallbackHeroImage(_ tasker: TaskerSummary) -> some View {
        PatchworkRemoteImage(
            asset: tasker.avatarImage,
            legacyURL: tasker.avatarUrl,
            preferredVariant: .large,
            contentMode: .fill
        ) {
            PatchworkTheme.stroke
        }
    }

    private func reviewSummaryAccessibilityLabel(averageRating: Double, reviewCount: Int) -> String {
        let rating = averageRating.formatted(.number.precision(.fractionLength(1)))
        return "\(rating) stars from \(reviewCount) review\(reviewCount == 1 ? "" : "s")"
    }

    private func retryCategories() async {
        await appState.refreshCategories(client: sessionStore.client)
        if appState.currentUser != nil {
            await reload(resetDismissedTaskers: true)
        }
    }

    private func selectCategory(_ slug: String?) {
        selectedCategorySlug = slug
        selectedCategoryGroupSlug = nil
        selectedCategorySlugs.removeAll()
        showCategorySheet = false
        Task { await reload(resetDismissedTaskers: true) }
        if let slug {
            recordDiscoverCategorySelection(categorySlug: slug)
        }
    }

    private func selectCategoryGroup(_ group: CategoryGroup) {
        selectedCategorySlug = nil
        selectedCategoryGroupSlug = group.slug
        selectedCategorySlugs = Set(group.categories.map(\.slug))
        Task { await reload(resetDismissedTaskers: true) }
    }

    private func toggleSelectedMemberCategory(_ category: Category) {
        selectedCategorySlug = nil
        if selectedCategorySlugs.contains(category.slug) {
            guard selectedCategorySlugs.count > 1 else {
                return
            }
            selectedCategorySlugs.remove(category.slug)
        } else {
            selectedCategorySlugs.insert(category.slug)
        }
        Task { await reload(resetDismissedTaskers: true) }
        recordDiscoverCategorySelection(categorySlug: category.slug)
    }

    private func reload(resetDismissedTaskers: Bool) async {
        appState.activeCategorySlug = selectedCategorySlug
        appState.activeCategorySlugs = selectedSearchCategorySlugs ?? []
        appState.searchRadius = radiusKm
        await appState.searchTaskers(
            client: sessionStore.client,
            categorySlug: selectedCategorySlug,
            categorySlugs: selectedSearchCategorySlugs,
            radiusKm: radiusKm,
            excludeCurrentUserWhenTasker: true
        )
        if resetDismissedTaskers {
            dismissedTaskerIDs.removeAll()
        } else {
            dismissedTaskerIDs.formIntersection(Set(appState.taskers.map(\.id)))
        }
        if visibleTaskers.isEmpty {
            currentCardIndex = 0
        } else if currentCardIndex >= visibleTaskers.count {
            currentCardIndex = visibleTaskers.count - 1
        }
    }

    private var selectedSearchCategorySlugs: [String]? {
        if let selectedCategorySlug {
            return [selectedCategorySlug]
        }
        if selectedCategoryGroupSlug != nil {
            let slugs = selectedCategorySlugs.sorted()
            return slugs.isEmpty ? [] : slugs
        }
        return nil
    }

    private func recordDiscoverCategorySelection(categorySlug: String) {
        let trimmedSlug = categorySlug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSlug.isEmpty else {
            return
        }

        let client = sessionStore.client
        Task(priority: .utility) {
            do {
                try await PatchworkAPI(client: client).analytics.recordDiscoverCategorySelection(categorySlug: trimmedSlug)
            } catch {
                print("[HomeView] Failed to record Discover category selection: \(error.localizedDescription)")
            }
        }
    }

    private func recordCategorySearchSubmitIfNeeded() {
        let term = trimmedCategorySearchText
        guard !term.isEmpty else {
            return
        }

        let client = sessionStore.client
        Task(priority: .utility) {
            do {
                try await PatchworkAPI(client: client).analytics.recordDiscoverCategorySearchSubmit(term: term)
            } catch {
                print("[HomeView] Failed to record Discover category search: \(error.localizedDescription)")
            }
        }
    }

    private var currentTasker: TaskerSummary? {
        guard !visibleTaskers.isEmpty else {
            return nil
        }
        let safeIndex = min(max(0, currentCardIndex), visibleTaskers.count - 1)
        return visibleTaskers[safeIndex]
    }

    private var visibleTaskers: [TaskerSummary] {
        appState.taskers.filter { !dismissedTaskerIDs.contains($0.id) }
    }

    private func dismissCurrentCard() {
        guard let tasker = currentTasker else {
            return
        }
        dismissedTaskerIDs.insert(tasker.id)
        if visibleTaskers.isEmpty {
            dismissedTaskerIDs.removeAll()
            currentCardIndex = 0
        } else if currentCardIndex >= visibleTaskers.count {
            currentCardIndex = visibleTaskers.count - 1
        }
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
        let swipedTasker = currentTasker

        withAnimation(.easeOut(duration: 0.16)) {
            cardDragOffset = offscreenOffset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            if direction == .left {
                dismissCurrentCard()
            } else if let swipedTasker {
                Task { await startChat(with: swipedTasker.userId) }
            }
            cardDragOffset = -offscreenOffset * 0.14
            withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                cardDragOffset = 0
            }
        }
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

}
