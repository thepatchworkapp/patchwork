import CoreLocation
import Foundation
import SwiftUI
import UIKit

enum PremiumPinSearchInput {
    static let placeholder = "Premium Pin"
    static let characterLimit = 8

    static func normalize(_ value: String) -> String {
        String(value.uppercased().filter { $0.isNumber || $0.isLetter }.prefix(characterLimit))
    }
}

struct HomeView: View {
    private enum MainLayout {
        static let horizontalGutter: CGFloat = 20
        static let topRhythm: CGFloat = 16
    }

    private struct TaskerRoute: Hashable, Identifiable {
        let id: ConvexID
    }

    private struct EmojiMark: UIViewRepresentable {
        let emoji: String
        let size: CGFloat

        func makeUIView(context: Context) -> UILabel {
            let label = UILabel()
            label.backgroundColor = .clear
            label.isAccessibilityElement = false
            label.numberOfLines = 1
            label.textAlignment = .center
            label.adjustsFontForContentSizeCategory = false
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
            label.setContentHuggingPriority(.required, for: .horizontal)
            label.font = Self.font(size: size)
            return label
        }

        func updateUIView(_ uiView: UILabel, context: Context) {
            uiView.text = emoji
            uiView.font = Self.font(size: size)
        }

        private static func font(size: CGFloat) -> UIFont {
            UIFont(name: "AppleColorEmoji", size: size)
                ?? UIFont(name: "Apple Color Emoji", size: size)
                ?? UIFont.systemFont(ofSize: size)
        }
    }

    @Environment(AppState.self) private var appState
    @Environment(LocationManager.self) private var locationManager
    @Environment(SessionStore.self) private var sessionStore

    @State private var selectedCategorySlug: String?
    @State private var selectedCategoryGroupSlug: String?
    @State private var selectedCategorySlugs = Set<String>()
    @State private var expandedCategoryGroupSlugs = Set<String>()
    @State private var radiusKm = 25
    @State private var showRadiusSheet = false
    @State private var showCategorySheet = false
    @State private var categorySearchText = ""
    @State private var isStartingChat = false
    @State private var currentCardIndex = 0
    @State private var cardDragOffset: CGFloat = 0
    @State private var dismissedTaskerIDs = Set<ConvexID>()
    @State private var taskerRoute: TaskerRoute?
    @State private var selectedSearchCityText = ""
    @State private var selectedSearchHomeBase: HomeBaseOption?
    @State private var isResolvingSearchOrigin = false
    @State private var searchOriginErrorMessage: String?
    @State private var isPremiumPinExpanded = false
    @State private var premiumPinText = ""
    @State private var premiumPinResultTaskers: [TaskerSummary] = []
    @State private var isSearchingPremiumPin = false
    @State private var premiumPinErrorMessage: String?
    @State private var lastSubmittedPremiumPin: String?
    private let usesVisualPreview = ProcessInfo.processInfo.arguments.contains("PATCHWORK_UI_EMPTY_TABS")

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brand)

            VStack(spacing: 0) {
                header
                spotlightContent
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    premiumPinSearchControl
                }
                .padding(.horizontal, MainLayout.horizontalGutter)
                .padding(.bottom, 18)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showRadiusSheet) {
            radiusSheet
                .patchworkSheetChrome(detents: [.medium, .large])
        }
        .sheet(isPresented: $showCategorySheet) {
            categorySheet
                .patchworkSheetChrome(detents: [.fraction(0.68), .large])
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
            await ensureDiscoverSearchOrigin()
            await reload(resetDismissedTaskers: true)
        }
        .task(id: currentGpsRefreshKey) {
            guard !usesVisualPreview else {
                return
            }
            guard appState.discoverSearchOrigin?.mode == .currentLocation,
                  let origin = DiscoverSearchOrigin.currentLocation(from: appState.currentUser) else {
                return
            }
            appState.discoverSearchOrigin = origin
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

    private var premiumPinSearchControl: some View {
        HStack(spacing: 10) {
            if isPremiumPinExpanded {
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 8) {
                        if isSearchingPremiumPin {
                            ProgressView()
                                .tint(PatchworkTheme.brand)
                                .scaleEffect(0.82)
                        }

                        TextField(PremiumPinSearchInput.placeholder, text: Binding(
                            get: { premiumPinText },
                            set: { updatePremiumPinText($0) }
                        ))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                        .submitLabel(.search)
                        .frame(width: 104)
                        .accessibilityIdentifier("Home.premiumPinField")
                        .onSubmit {
                            Task { await searchPremiumPinIfReady(force: true) }
                        }

                        if !premiumPinText.isEmpty || !premiumPinResultTaskers.isEmpty {
                            Button {
                                clearPremiumPinSearch()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PatchworkTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear premium pin search")
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(PatchworkTheme.surface.opacity(0.96), in: Capsule())
                    .overlay(Capsule().stroke(PatchworkTheme.strokeStrong, lineWidth: 1))

                    if let premiumPinErrorMessage {
                        Text(premiumPinErrorMessage)
                            .font(.patchworkCaption)
                            .foregroundStyle(PatchworkTheme.warning)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(PatchworkTheme.surface.opacity(0.96), in: Capsule())
                            .accessibilityIdentifier("Home.premiumPinMessage")
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            Button {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                    isPremiumPinExpanded.toggle()
                }
            } label: {
                Image(systemName: "crown.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PatchworkTheme.surface)
                    .frame(width: 46, height: 46)
                    .background(PatchworkTheme.heroGradient, in: Circle())
                    .shadow(color: PatchworkTheme.brand.opacity(0.18), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Home.premiumPinButton")
            .accessibilityLabel("Search premium pin")
        }
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
            message: hasSearchCoordinates ? "Try a broader radius or switch categories to discover more nearby professionals." : "Enable location or choose a city to search nearby taskers."
        )
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("Home.emptyState")
    }

    private var radiusSheet: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brandBright)

            PatchworkSurfaceCard {
                VStack(spacing: 18) {
                    PatchworkTopBar(title: "Search", onBack: { showRadiusSheet = false })

                    searchOriginControls

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

    private var searchOriginControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Search from", selection: Binding(
                get: { selectedOriginMode },
                set: { mode in
                    Task { await selectSearchOriginMode(mode) }
                }
            )) {
                Text("Current location").tag(DiscoverSearchOriginMode.currentLocation)
                Text("Choose city").tag(DiscoverSearchOriginMode.selectedCity)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("Home.searchOriginPicker")

            if selectedOriginMode == .selectedCity {
                HomeBaseDropdownField(
                    placeholder: "Choose city",
                    text: $selectedSearchCityText,
                    selectedHomeBase: $selectedSearchHomeBase,
                    fieldAccessibilityIdentifier: "Home.searchCityField",
                    suggestionAccessibilityPrefix: "Home.searchCitySuggestion",
                    noResultsAccessibilityIdentifier: "Home.searchCityNoResults",
                    noResultsMessage: "Select a suggested city to search there.",
                    onTextChanged: {
                        clearSearchCitySelectionIfNeeded()
                    },
                    onSelect: { suggestion in
                        Task { await applySelectedCitySearchOrigin(suggestion, reloadAfterSelection: true) }
                    }
                )
            }

            if isResolvingSearchOrigin {
                ProgressView()
                    .tint(PatchworkTheme.brand)
                    .accessibilityIdentifier("Home.searchOriginProgress")
            }

            if let searchOriginErrorMessage {
                PatchworkInlineStatusBanner(tone: .error, text: searchOriginErrorMessage)
                    .accessibilityIdentifier("Home.searchOriginError")
            }
        }
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
                                    emoji: "📋",
                                    isSelected: selectedCategorySlug == nil
                                        && selectedCategoryGroupSlug == nil
                                        && selectedCategorySlugs.isEmpty,
                                    accessibilityIdentifier: "Home.categoryOption.all"
                                ) {
                                    selectCategory(nil)
                                }
                            }

                            ForEach(discoverCategoryGroupOptions, id: \.id) { group in
                                VStack(spacing: 8) {
                                    categoryGroupSheetRow(group)

                                    if shouldShowMembers(for: group) {
                                        ForEach(discoverMemberCategoryOptions(for: group), id: \.id) { category in
                                            categorySheetRow(
                                                label: category.name,
                                                emoji: categoryEmoji(for: category),
                                                isSelected: selectedCategorySlug == category.slug && selectedCategoryGroupSlug == nil,
                                                accessibilityIdentifier: "Home.categoryGroupMemberOption.\(category.slug)",
                                                leadingIndent: 22
                                            ) {
                                                selectCategoryMember(category)
                                            }
                                        }
                                    }
                                }
                            }

                            ForEach(discoverCategoryOptions, id: \.id) { category in
                                categorySheetRow(
                                    label: category.name,
                                    emoji: categoryEmoji(for: category),
                                    isSelected: selectedCategorySlug == category.slug && selectedCategoryGroupSlug == nil,
                                    accessibilityIdentifier: "Home.categoryOption.\(category.slug)"
                                ) {
                                    selectCategory(category.slug)
                                }
                            }

                            if discoverCategoryGroupOptions.isEmpty && discoverCategoryOptions.isEmpty && !shouldShowAllCategoriesOption {
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
        emoji: String,
        isSelected: Bool,
        accessibilityIdentifier: String,
        leadingIndent: CGFloat = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                categoryEmojiMark(emoji)

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
                        .accessibilityHidden(true)
                }
            }
            .padding(.leading, 16 + leadingIndent)
            .padding(.trailing, 16)
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

    private func categoryGroupSheetRow(_ group: CategoryGroup) -> some View {
        let isExpanded = isGroupExpanded(group)
        let isSelected = selectedCategoryGroupSlug == group.slug
            && selectedCategorySlugs == Set(group.categories.map(\.slug))

        return HStack(spacing: 0) {
            Button {
                selectCategoryGroup(group)
            } label: {
                HStack(spacing: 12) {
                    categoryEmojiMark(categoryGroupEmoji(for: group))

                    Text(group.name)
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
                            .accessibilityHidden(true)
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 56)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Home.categoryGroupOption.\(group.slug)")
            .accessibilityValue(isSelected ? "Selected" : "Not selected")

            Button {
                toggleCategoryGroupExpansion(group)
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PatchworkTheme.textSecondary)
                    .frame(width: 48, height: 56)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Home.categoryGroupDisclosure.\(group.slug)")
            .accessibilityLabel(isExpanded ? "Collapse \(group.name)" : "Expand \(group.name)")
        }
        .background(
            isSelected ? PatchworkTheme.brandSoft.opacity(0.7) : PatchworkTheme.surface.opacity(0.92),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? PatchworkTheme.strokeStrong : PatchworkTheme.stroke, lineWidth: 1)
        )
    }

    private var selectedCategoryLabel: String {
        if let selectedCategorySlug,
           let category = appState.categories.first(where: { $0.slug == selectedCategorySlug }) {
            return categoryMenuLabel(for: category)
        }
        if let selectedCategoryGroup {
            return selectedCategoryGroup.name
        }
        return "All categories"
    }

    private func categoryMenuLabel(for category: Category) -> String {
        let emoji = category.emoji.map { "\($0) " } ?? ""
        return "\(emoji)\(category.name)"
    }

    private var discoverCategoryOptions: [Category] {
        sortedDiscoverCategories.filter { category in
            guard !groupedCategorySlugs.contains(category.slug) else {
                return false
            }
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

    private func discoverMemberCategoryOptions(for group: CategoryGroup) -> [Category] {
        let query = trimmedCategorySearchText
        return group.categories
            .sorted { lhs, rhs in lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending }
            .filter { category in
                query.isEmpty
                    || group.name.localizedStandardContains(query)
                    || category.name.localizedStandardContains(query)
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

    private var groupedCategorySlugs: Set<String> {
        Set(appState.categoryGroups.flatMap { group in
            group.categories.map(\.slug)
        })
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

    private func shouldShowMembers(for group: CategoryGroup) -> Bool {
        isGroupExpanded(group) || !trimmedCategorySearchText.isEmpty
    }

    private func isGroupExpanded(_ group: CategoryGroup) -> Bool {
        expandedCategoryGroupSlugs.contains(group.slug)
    }

    @ViewBuilder
    private func categoryEmojiMark(_ emoji: String) -> some View {
        if let image = UIImage(named: categoryEmojiAssetName(for: emoji)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)
        } else {
            EmojiMark(emoji: emoji, size: 22)
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)
        }
    }

    private func categoryEmojiAssetName(for emoji: String) -> String {
        let scalars = emoji.unicodeScalars
            .map { String(format: "%04X", Int($0.value)) }
            .joined(separator: "_")
        return "CategoryEmoji_\(scalars)"
    }

    private func categoryGroupEmoji(for group: CategoryGroup) -> String {
        let normalized = "\(group.slug) \(group.name)".lowercased()
        switch normalized {
        case let value where value.localizedStandardContains("beauty"):
            return "💄"
        case let value where value.localizedStandardContains("child"):
            return "🧸"
        case let value where value.localizedStandardContains("health") || value.localizedStandardContains("wellbeing"):
            return "💚"
        case let value where value.localizedStandardContains("clothing"):
            return "👗"
        case let value where value.localizedStandardContains("home") || value.localizedStandardContains("garden"):
            return "🏠"
        case let value where value.localizedStandardContains("food"):
            return "🍽️"
        case let value where value.localizedStandardContains("creative") || value.localizedStandardContains("design"):
            return "🎨"
        case let value where value.localizedStandardContains("technical"):
            return "💻"
        case let value where value.localizedStandardContains("mechanical") || value.localizedStandardContains("repair"):
            return "🔧"
        case let value where value.localizedStandardContains("planner") || value.localizedStandardContains("event"):
            return "🎉"
        case let value where value.localizedStandardContains("pet"):
            return "🐾"
        case let value where value.localizedStandardContains("care"):
            return "🧸"
        case let value where value.localizedStandardContains("music"):
            return "🎵"
        case let value where value.localizedStandardContains("sport"):
            return "⚾"
        case let value where value.localizedStandardContains("legal"):
            return "⚖️"
        case let value where value.localizedStandardContains("writing"):
            return "✍️"
        default:
            return "📋"
        }
    }

    private func categoryEmoji(for category: Category) -> String {
        if let emoji = category.emoji?.trimmingCharacters(in: .whitespacesAndNewlines),
           !emoji.isEmpty {
            return emoji
        }
        let normalized = "\(category.slug) \(category.name)".lowercased()
        switch normalized {
        case let value where value.localizedStandardContains("barber"):
            return "💈"
        case let value where value.localizedStandardContains("hair removal"):
            return "🧖"
        case let value where value.localizedStandardContains("hair stylist") || value.localizedStandardContains("hair"):
            return "💇"
        case let value where value.localizedStandardContains("lash"):
            return "👁️"
        case let value where value.localizedStandardContains("makeup"):
            return "💄"
        case let value where value.localizedStandardContains("microblading"):
            return "✒️"
        case let value where value.localizedStandardContains("nail"):
            return "💅"
        case let value where value.localizedStandardContains("tattoo"):
            return "🖋️"
        case let value where value.localizedStandardContains("skin"):
            return "🧴"
        case let value where value.localizedStandardContains("day-care") || value.localizedStandardContains("baby"):
            return "🧸"
        case let value where value.localizedStandardContains("tutor"):
            return "📚"
        case let value where value.localizedStandardContains("clothing stylist"):
            return "👗"
        case let value where value.localizedStandardContains("tailor"):
            return "🧵"
        case let value where value.localizedStandardContains("engraver"):
            return "🔖"
        case let value where value.localizedStandardContains("graphic"):
            return "🖼️"
        case let value where value.localizedStandardContains("photographer"):
            return "📸"
        case let value where value.localizedStandardContains("printer"):
            return "🖨️"
        case let value where value.localizedStandardContains("social"):
            return "📣"
        case let value where value.localizedStandardContains("videographer"):
            return "🎥"
        case let value where value.localizedStandardContains("artist") || value.localizedStandardContains("interior painter"):
            return "🎨"
        case let value where value.localizedStandardContains("baker"):
            return "🧁"
        case let value where value.localizedStandardContains("cater"):
            return "🍽️"
        case let value where value.localizedStandardContains("chef"):
            return "👨‍🍳"
        case let value where value.localizedStandardContains("in-home care"):
            return "🏥"
        case let value where value.localizedStandardContains("life coach"):
            return "🧭"
        case let value where value.localizedStandardContains("massage"):
            return "💆"
        case let value where value.localizedStandardContains("nutrition"):
            return "🍏"
        case let value where value.localizedStandardContains("personal assistant"):
            return "🗂️"
        case let value where value.localizedStandardContains("errand"):
            return "🏃"
        case let value where value.localizedStandardContains("trainer"):
            return "🏋️"
        case let value where value.localizedStandardContains("carpenter"):
            return "🪚"
        case let value where value.localizedStandardContains("carpet"):
            return "🧼"
        case let value where value.localizedStandardContains("exterior painter"):
            return "🖌️"
        case let value where value.localizedStandardContains("florist"):
            return "💐"
        case let value where value.localizedStandardContains("contractor"):
            return "🏗️"
        case let value where value.localizedStandardContains("handy"):
            return "🔨"
        case let value where value.localizedStandardContains("interior cleaning"):
            return "🧹"
        case let value where value.localizedStandardContains("interior designer"):
            return "🛋️"
        case let value where value.localizedStandardContains("landscaper"):
            return "🪴"
        case let value where value.localizedStandardContains("mortgage"):
            return "🏦"
        case let value where value.localizedStandardContains("plumb"):
            return "🚰"
        case let value where value.localizedStandardContains("organizer"):
            return "📦"
        case let value where value.localizedStandardContains("realtor"):
            return "🏘️"
        case let value where value.localizedStandardContains("snow"):
            return "❄️"
        case let value where value.localizedStandardContains("window"):
            return "🪟"
        case let value where value.localizedStandardContains("gutter") || value.localizedStandardContains("roof"):
            return "🏠"
        case let value where value.localizedStandardContains("lawyer"):
            return "⚖️"
        case let value where value.localizedStandardContains("auto"):
            return "🚗"
        case let value where value.localizedStandardContains("small engine") || value.localizedStandardContains("repair"):
            return "🔧"
        case let value where value.localizedStandardContains("band") || value.localizedStandardContains("musician"):
            return "🎵"
        case let value where value.localizedStandardContains("dj"):
            return "🎧"
        case let value where value.localizedStandardContains("guitar"):
            return "🎸"
        case let value where value.localizedStandardContains("piano"):
            return "🎹"
        case let value where value.localizedStandardContains("dog"):
            return "🐕"
        case let value where value.localizedStandardContains("groom"):
            return "✂️"
        case let value where value.localizedStandardContains("pet"):
            return "🐾"
        case let value where value.localizedStandardContains("event"):
            return "🎉"
        case let value where value.localizedStandardContains("travel"):
            return "✈️"
        case let value where value.localizedStandardContains("wedding"):
            return "💍"
        case let value where value.localizedStandardContains("baseball"):
            return "⚾"
        case let value where value.localizedStandardContains("skating"):
            return "⛸️"
        case let value where value.localizedStandardContains("golf"):
            return "⛳"
        case let value where value.localizedStandardContains("hockey"):
            return "🏒"
        case let value where value.localizedStandardContains("tennis"):
            return "🎾"
        case let value where value.localizedStandardContains("architect"):
            return "📐"
        case let value where value.localizedStandardContains("computer"):
            return "💻"
        case let value where value.localizedStandardContains("developer"):
            return "⌨️"
        case let value where value.localizedStandardContains("electric"):
            return "🔌"
        case let value where value.localizedStandardContains("engineer"):
            return "⚙️"
        case let value where value.localizedStandardContains("tax"):
            return "🧾"
        case let value where value.localizedStandardContains("web"):
            return "🌐"
        case let value where value.localizedStandardContains("copywriter"):
            return "✍️"
        case let value where value.localizedStandardContains("editor"):
            return "📝"
        case let value where value.localizedStandardContains("resume"):
            return "📄"
        case let value where value.localizedStandardContains("designer") || value.localizedStandardContains("paint"):
            return "🎨"
        default:
            return "📋"
        }
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
        appState.discoverSearchOrigin?.displayLabel ?? "Location unavailable"
    }

    private var hasSearchCoordinates: Bool {
        appState.discoverSearchOrigin != nil
    }

    private var currentGpsRefreshKey: String {
        let latitude = appState.currentUser?.location?.gpsCoordinates?.lat ?? .nan
        let longitude = appState.currentUser?.location?.gpsCoordinates?.lng ?? .nan
        let checkedInAt = appState.currentUser?.location?.gpsCoordinates?.checkedInAt ?? -1
        return "\(latitude)|\(longitude)|\(checkedInAt)"
    }

    private var selectedOriginMode: DiscoverSearchOriginMode {
        appState.discoverSearchOrigin?.mode
            ?? (DiscoverSearchOrigin.currentLocation(from: appState.currentUser) == nil ? .selectedCity : .currentLocation)
    }

    private var currentHomeBaseOption: HomeBaseOption? {
        let city = appState.currentUser?.location?.city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let province = appState.currentUser?.location?.province?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !city.isEmpty, !province.isEmpty else {
            return nil
        }
        return HomeBaseOption(city: city, province: province)
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

    private func ensureDiscoverSearchOrigin() async {
        if let origin = appState.discoverSearchOrigin {
            syncSelectedCityState(from: origin)
            return
        }

        if let origin = DiscoverSearchOrigin.currentLocation(from: appState.currentUser) {
            appState.discoverSearchOrigin = origin
            syncSelectedCityState(from: origin)
            return
        }

        if let homeBase = currentHomeBaseOption {
            await applySelectedCitySearchOrigin(homeBase, reloadAfterSelection: false)
        }
    }

    private func syncSelectedCityState(from origin: DiscoverSearchOrigin) {
        guard origin.mode == .selectedCity,
              let city = origin.city,
              let province = origin.province else {
            return
        }
        let option = HomeBaseOption(city: city, province: province)
        selectedSearchHomeBase = option
        selectedSearchCityText = option.city
    }

    private func selectSearchOriginMode(_ mode: DiscoverSearchOriginMode) async {
        searchOriginErrorMessage = nil

        switch mode {
        case .currentLocation:
            await applyCurrentLocationSearchOrigin()
        case .selectedCity:
            if let selectedSearchHomeBase {
                await applySelectedCitySearchOrigin(selectedSearchHomeBase, reloadAfterSelection: true)
            } else if let homeBase = currentHomeBaseOption {
                selectedSearchCityText = homeBase.city
                selectedSearchHomeBase = homeBase
                await applySelectedCitySearchOrigin(homeBase, reloadAfterSelection: true)
            } else {
                appState.discoverSearchOrigin = nil
                searchOriginErrorMessage = "Choose a city to search there."
                await reload(resetDismissedTaskers: true)
            }
        }
    }

    private func applyCurrentLocationSearchOrigin() async {
        if let origin = DiscoverSearchOrigin.currentLocation(from: appState.currentUser) {
            appState.discoverSearchOrigin = origin
            await reload(resetDismissedTaskers: true)
            return
        }

        isResolvingSearchOrigin = true
        defer { isResolvingSearchOrigin = false }

        let status = await locationManager.requestWhenInUseAuthorizationIfNeeded()
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            searchOriginErrorMessage = "Enable location to use current location."
            return
        }

        guard let coordinate = await locationManager.requestCurrentCoordinate() else {
            searchOriginErrorMessage = "Current location is unavailable. Choose a city instead."
            return
        }

        let didSync = await appState.syncLocation(
            client: sessionStore.client,
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            source: "gps"
        )
        guard didSync else {
            return
        }

        applyLocalGpsCoordinate(coordinate)
        if let userId = appState.currentUser?.id {
            LocationSyncCache.store(coordinate, for: userId)
        }
        if let origin = DiscoverSearchOrigin.currentLocation(from: appState.currentUser) {
            appState.discoverSearchOrigin = origin
        }
        await reload(resetDismissedTaskers: true)
    }

    private func applySelectedCitySearchOrigin(_ option: HomeBaseOption, reloadAfterSelection: Bool) async {
        searchOriginErrorMessage = nil
        selectedSearchHomeBase = option
        selectedSearchCityText = option.city
        isResolvingSearchOrigin = true
        defer { isResolvingSearchOrigin = false }

        guard let coordinate = await locationManager.geocode(city: option.city, province: option.province) else {
            searchOriginErrorMessage = "We could not find that city. Choose another city."
            return
        }

        appState.discoverSearchOrigin = DiscoverSearchOrigin.selectedCity(
            option,
            coordinates: Coordinates(lat: coordinate.latitude, lng: coordinate.longitude)
        )

        if reloadAfterSelection {
            await reload(resetDismissedTaskers: true)
        }
    }

    private func applyLocalGpsCoordinate(_ coordinate: CLLocationCoordinate2D) {
        guard let currentUser = appState.currentUser else {
            return
        }

        appState.currentUser = CurrentUser(
            id: currentUser.id,
            email: currentUser.email,
            name: currentUser.name,
            roles: currentUser.roles,
            location: UserLocation(
                city: currentUser.location?.city,
                province: currentUser.location?.province,
                coordinates: Coordinates(lat: coordinate.latitude, lng: coordinate.longitude),
                gpsCoordinates: GPSCoordinates(
                    lat: coordinate.latitude,
                    lng: coordinate.longitude,
                    checkedInAt: Int(Date().timeIntervalSince1970 * 1000)
                )
            ),
            settings: UserSettings(
                notificationsEnabled: currentUser.settings?.notificationsEnabled,
                locationEnabled: true
            ),
            createdAt: currentUser.createdAt,
            photoImage: currentUser.photoImage
        )
    }

    private func clearSearchCitySelectionIfNeeded() {
        guard selectedSearchHomeBase != nil else {
            return
        }
        if selectedSearchHomeBase?.city.caseInsensitiveCompare(selectedSearchCityText.trimmingCharacters(in: .whitespacesAndNewlines)) != .orderedSame {
            selectedSearchHomeBase = nil
        }
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

    private func selectCategoryMember(_ category: Category) {
        selectedCategorySlug = category.slug
        selectedCategoryGroupSlug = nil
        selectedCategorySlugs.removeAll()
        Task { await reload(resetDismissedTaskers: true) }
        recordDiscoverCategorySelection(categorySlug: category.slug)
    }

    private func toggleCategoryGroupExpansion(_ group: CategoryGroup) {
        withAnimation(.snappy(duration: 0.18)) {
            if expandedCategoryGroupSlugs.contains(group.slug) {
                expandedCategoryGroupSlugs.remove(group.slug)
            } else {
                expandedCategoryGroupSlugs.insert(group.slug)
            }
        }
    }

    private func reload(resetDismissedTaskers: Bool) async {
        appState.activeCategorySlug = selectedCategorySlug
        appState.activeCategorySlugs = selectedSearchCategorySlugs ?? []
        appState.searchRadius = radiusKm
        await appState.searchTaskers(
            client: sessionStore.client,
            categorySlug: selectedCategorySlug,
            categorySlugs: selectedSearchCategorySlugs,
            searchOrigin: appState.discoverSearchOrigin,
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
        taskerCardSource.filter { !dismissedTaskerIDs.contains($0.id) }
    }

    private var taskerCardSource: [TaskerSummary] {
        premiumPinResultTaskers.isEmpty ? appState.taskers : premiumPinResultTaskers
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

    private func updatePremiumPinText(_ value: String) {
        let normalized = normalizePremiumPin(value)
        premiumPinText = normalized
        premiumPinErrorMessage = nil

        if normalized.count < PremiumPinSearchInput.characterLimit {
            premiumPinResultTaskers = []
            lastSubmittedPremiumPin = nil
            currentCardIndex = 0
            dismissedTaskerIDs.removeAll()
        } else if normalized.count == PremiumPinSearchInput.characterLimit, normalized != lastSubmittedPremiumPin {
            Task { await searchPremiumPinIfReady(force: false) }
        }
    }

    private func normalizePremiumPin(_ value: String) -> String {
        PremiumPinSearchInput.normalize(value)
    }

    private func clearPremiumPinSearch() {
        premiumPinText = ""
        premiumPinResultTaskers = []
        premiumPinErrorMessage = nil
        lastSubmittedPremiumPin = nil
        currentCardIndex = 0
        dismissedTaskerIDs.removeAll()
    }

    private func searchPremiumPinIfReady(force: Bool) async {
        let pin = normalizePremiumPin(premiumPinText)
        guard pin.count == PremiumPinSearchInput.characterLimit else {
            return
        }
        guard force || pin != lastSubmittedPremiumPin else {
            return
        }

        isSearchingPremiumPin = true
        premiumPinErrorMessage = nil
        defer { isSearchingPremiumPin = false }

        do {
            let taskers = try await PatchworkAPI(client: sessionStore.client).search.taskerByPremiumPin(
                pin: pin,
                excludeUserId: appState.currentUser?.id
            )
            lastSubmittedPremiumPin = pin
            premiumPinResultTaskers = taskers
            currentCardIndex = 0
            dismissedTaskerIDs.removeAll()
            if taskers.isEmpty {
                premiumPinErrorMessage = "No match for \(pin)."
            }
        } catch {
            premiumPinErrorMessage = "Pin search failed."
            appState.lastError = error.localizedDescription
        }
    }

}
