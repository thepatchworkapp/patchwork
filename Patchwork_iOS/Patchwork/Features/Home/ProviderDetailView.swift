import SwiftUI

struct ProviderDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    let taskerId: ConvexID

    @State private var selectedCategoryID: ConvexID?
    @State private var isStartingChat = false
    @State private var chatError: String?
    @State private var hasLoadedTasker = false
    @State private var isFavourite = false
    @State private var isUpdatingFavourite = false

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brand)

            if let tasker {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        heroSection(tasker)
                        categorySelector(tasker)
                        portfolioGallerySection
                        aboutSection(tasker)
                        linksSection(tasker)
                        pricingSection(tasker)
                        reviewsSection(tasker)
                        bottomCTA(tasker)
                    }
                    .padding(16)
                    .padding(.bottom, 28)
                }
            } else {
                VStack(spacing: 14) {
                    ProgressView()
                    Text("Loading profile...")
                        .font(.patchworkBody)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                }
                .accessibilityIdentifier("ProviderDetail.loading")
            }
        }
        .navigationTitle("Provider")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if tasker != nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    favouriteToggleButton
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            isFavourite = tasker?.isFavourite ?? false
        }
        .task {
            await appState.loadTaskerDetail(client: sessionStore.client, taskerId: taskerId)
            if !hasLoadedTasker {
                selectedCategoryID = tasker?.categoryProfiles.first?.id
                isFavourite = tasker?.isFavourite ?? false
                hasLoadedTasker = true
            }
        }
        .onChange(of: tasker?.id) { _, _ in
            selectedCategoryID = tasker?.categoryProfiles.first?.id
            isFavourite = tasker?.isFavourite ?? false
            hasLoadedTasker = true
        }
        .onChange(of: tasker?.isFavourite) { _, newValue in
            if let newValue {
                isFavourite = newValue
            }
        }
        .accessibilityIdentifier("ProviderDetail.screen.\(taskerId)")
    }

    private var tasker: TaskerDetail? {
        guard let selected = appState.selectedTasker, selected.id == taskerId else { return nil }
        return selected
    }

    private var favouriteToggleButton: some View {
        let isOwnProfile = appState.currentUser?.id == tasker?.userId

        return Button {
            Task { await toggleFavourite() }
        } label: {
            Image(systemName: isFavourite ? "heart.fill" : "heart")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isFavourite ? PatchworkTheme.danger : PatchworkTheme.textPrimary)
                .frame(width: 34, height: 34)
                .background(PatchworkTheme.surface, in: Circle())
                .overlay(Circle().stroke(PatchworkTheme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isUpdatingFavourite || isOwnProfile)
        .opacity(isOwnProfile ? 0.55 : 1)
        .accessibilityLabel(isFavourite ? "Remove from favourites" : "Add to favourites")
        .accessibilityValue(isUpdatingFavourite ? "Updating" : (isFavourite ? "Favourite" : "Not favourite"))
        .accessibilityIdentifier("ProviderDetail.favouriteToggle")
    }

    private var selectedProfile: TaskerCategoryProfile? {
        guard let tasker else { return nil }
        if let selectedCategoryID,
           let selected = tasker.categoryProfiles.first(where: { $0.id == selectedCategoryID }) {
            return selected
        }
        return tasker.categoryProfiles.first
    }

    private func heroSection(_ tasker: TaskerDetail) -> some View {
        ZStack(alignment: .bottomLeading) {
            PatchworkRemoteImage(
                asset: heroImageAsset(tasker),
                legacyURL: heroImageLegacyURL(tasker),
                preferredVariant: .large,
                contentMode: .fill
            ) {
                ZStack {
                    PatchworkTheme.brandSoft
                    Image(systemName: "person.crop.square.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(PatchworkTheme.brand)
                }
            }
            .frame(height: 320)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.12), .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    if let categoryName = selectedProfile?.categoryName.trimmingCharacters(in: .whitespacesAndNewlines),
                       !categoryName.isEmpty {
                        Text(categoryName)
                            .font(.patchworkCaption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.16), in: Capsule())
                    }

                    if tasker.verified == true {
                        Label("Verified", systemImage: "checkmark.seal.fill")
                            .font(.patchworkCaption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(PatchworkTheme.success.opacity(0.8), in: Capsule())
                    }
                }

                HStack(spacing: 10) {
                    PatchworkRemoteImage(
                        asset: tasker.profileImage,
                        legacyURL: tasker.userPhotoUrl,
                        preferredVariant: .thumb,
                        contentMode: .fill
                    ) {
                        Circle().fill(.white.opacity(0.22))
                    }
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.9), lineWidth: 1.5)
                    )

                    Text(tasker.displayName)
                        .font(.patchworkHeroTitle)
                        .foregroundStyle(.white)
                }

                HStack(spacing: 12) {
                    ratingSummary(tasker)

                    if let completedJobs = selectedProfile?.completedJobs ?? tasker.completedJobs {
                        Label("\(completedJobs) jobs", systemImage: "checkmark.circle.fill")
                            .font(.patchworkCaption)
                            .foregroundStyle(.white.opacity(0.92))
                    }
                }
            }
            .padding(20)
        }
        .clipShape(.rect(cornerRadius: 30))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(PatchworkTheme.stroke.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: PatchworkTheme.brand.opacity(0.12), radius: 26, y: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(heroAccessibilityLabel(tasker))
    }

    @ViewBuilder
    private func categorySelector(_ tasker: TaskerDetail) -> some View {
        if tasker.categoryProfiles.count > 1 {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(tasker.categoryProfiles) { profile in
                        let isSelected = selectedProfile?.id == profile.id
                        Button(profile.categoryName) {
                            selectedCategoryID = profile.id
                        }
                        .buttonStyle(.plain)
                        .font(.patchworkBodyStrong)
                        .foregroundStyle(isSelected ? .white : PatchworkTheme.textSecondary)
                        .padding(.horizontal, 16)
                        .frame(height: 42)
                        .background(
                            isSelected ? PatchworkTheme.heroGradient : LinearGradient(colors: [PatchworkTheme.surface, PatchworkTheme.surface], startPoint: .top, endPoint: .bottom),
                            in: Capsule()
                        )
                        .overlay(Capsule().stroke(PatchworkTheme.stroke, lineWidth: isSelected ? 0 : 1))
                        .accessibilityIdentifier("ProviderDetail.serviceCategory.\(profile.id)")
                        .accessibilityLabel(profile.categoryName)
                        .accessibilityValue(isSelected ? "Selected" : "Not selected")
                        .accessibilityHint(isSelected ? "Currently selected" : "Selects this service category")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var portfolioGallerySection: some View {
        if !selectedPortfolioImages.isEmpty {
            PatchworkSurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Portfolio")
                        .font(.patchworkCardTitle)
                        .foregroundStyle(PatchworkTheme.textPrimary)

                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(selectedPortfolioImages, id: \.id) { asset in
                                PatchworkRemoteImage(
                                    asset: asset,
                                    preferredVariant: .display,
                                    contentMode: .fill
                                ) {
                                    PatchworkTheme.brandSoft
                                }
                                .frame(width: 136, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(PatchworkTheme.stroke, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    private func aboutSection(_ tasker: TaskerDetail) -> some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("About")
                    .font(.patchworkCardTitle)
                    .foregroundStyle(PatchworkTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text(selectedProfile?.categoryBio ?? "Profile details unavailable.")
                    .font(.patchworkBody)
                    .foregroundStyle(PatchworkTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func linksSection(_ tasker: TaskerDetail) -> some View {
        let primaryWebsite = tasker.websiteLinks.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let primarySocial = tasker.socialLinks.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        if primaryWebsite?.isEmpty == false || primarySocial?.isEmpty == false {
            PatchworkSurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Links")
                        .font(.patchworkCardTitle)
                        .foregroundStyle(PatchworkTheme.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    if let primaryWebsite, !primaryWebsite.isEmpty {
                        linkRow(title: "Website", value: primaryWebsite, systemImage: "globe")
                    }
                    if let primarySocial, !primarySocial.isEmpty {
                        linkRow(title: "Social", value: primarySocial, systemImage: "at")
                    }
                }
            }
        }
    }

    private func linkRow(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.patchworkBody)
                .foregroundStyle(PatchworkTheme.brand)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textSecondary)
                Text(value)
                    .font(.patchworkBodyStrong)
                    .foregroundStyle(PatchworkTheme.textPrimary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func pricingSection(_ tasker: TaskerDetail) -> some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Pricing and service details")
                    .font(.patchworkCardTitle)
                    .foregroundStyle(PatchworkTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: 10) {
                    if let rateLabel = rateLabel(for: selectedProfile) {
                        metricRow(
                            title: selectedProfile?.rateType == "hourly" ? "Hourly rate" : "Fixed rate",
                            value: rateLabel
                        )
                    }

                    if let serviceRadius = selectedProfile?.serviceRadius {
                        metricRow(title: "Service area", value: "\(serviceRadius) km radius")
                    }

                    if let completedJobs = selectedProfile?.completedJobs ?? tasker.completedJobs {
                        metricRow(title: "Jobs completed", value: "\(completedJobs)")
                    }
                }
            }
        }
    }

    private func reviewsSection(_ tasker: TaskerDetail) -> some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Recent reviews")
                        .font(.patchworkCardTitle)
                        .foregroundStyle(PatchworkTheme.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    if (tasker.reviewCount ?? 0) > 0 {
                        Text("\(tasker.reviewCount ?? 0) total")
                            .font(.patchworkCaption)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                    }
                }

                if tasker.reviews.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(PatchworkTheme.brand)
                        Text("No reviews yet")
                            .font(.patchworkBodyStrong)
                            .foregroundStyle(PatchworkTheme.textPrimary)
                        Text("This tasker is new to Patchwork or has not been reviewed on this category yet.")
                            .font(.patchworkBody)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                } else {
                    ForEach(tasker.reviews.prefix(3)) { review in
                        ProviderReviewRow(review: review)
                    }
                }
            }
        }
    }

    private func bottomCTA(_ tasker: TaskerDetail) -> some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
            if let chatError {
                Text(chatError)
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.danger)
                    .accessibilityIdentifier("ProviderDetail.chatError")
            }

                Text("Ready to reach out?")
                    .font(.patchworkBodyStrong)
                    .foregroundStyle(PatchworkTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Button {
                    Task { await startChat(with: tasker.userId) }
                } label: {
                    HStack(spacing: 10) {
                        if isStartingChat {
                            ProgressView()
                                .tint(.white)
                            Text("Opening chat...")
                        } else {
                            Image(systemName: "message.fill")
                            Text("Start chat")
                        }
                    }
                }
                .buttonStyle(PatchworkPrimaryButtonStyle())
                .disabled(isStartingChat)
                .accessibilityLabel(isStartingChat ? "Opening chat" : "Start chat")
                .accessibilityIdentifier("ProviderDetail.startChatButton")
                .accessibilityHint("Starts a chat with this provider")
            }
        }
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.patchworkBody)
                .foregroundStyle(PatchworkTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.patchworkBodyStrong)
                .foregroundStyle(PatchworkTheme.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
        .accessibilityIdentifier("ProviderDetail.metric.\(title.normalizedAccessibilityIdentifier)")
    }

    @ViewBuilder
    private func ratingSummary(_ tasker: TaskerDetail) -> some View {
        if let averageRating = tasker.averageRating,
           let reviewCount = tasker.reviewCount,
           reviewCount > 0 {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundStyle(Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255))
                Text(averageRating.formatted(.number.precision(.fractionLength(1))))
                    .font(.patchworkCaption)
                Text("(\(reviewCount))")
                    .font(.patchworkCaption)
                    .foregroundStyle(.white.opacity(0.76))
            }
        } else {
            Text("New on Patchwork")
                .font(.patchworkCaption)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var selectedPortfolioImages: [RemoteImageAsset] {
        selectedProfile?.portfolioImages ?? []
    }

    private func heroImageAsset(_ tasker: TaskerDetail) -> RemoteImageAsset? {
        if let cover = selectedProfile?.coverImage {
            return cover
        }
        if let firstPortfolio = selectedProfile?.portfolioImages?.first {
            return firstPortfolio
        }
        if selectedProfile?.firstPhotoUrl == nil {
            return tasker.profileImage
        }
        return nil
    }

    private func heroImageLegacyURL(_ tasker: TaskerDetail) -> String? {
        selectedProfile?.firstPhotoUrl ?? tasker.userPhotoUrl
    }

    private func heroAccessibilityLabel(_ tasker: TaskerDetail) -> String {
        let name = tasker.displayName
        let category = selectedProfile?.categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let verified = tasker.verified == true ? "Verified." : ""

        let ratingSummary: String
        if let averageRating = tasker.averageRating,
           let reviewCount = tasker.reviewCount,
           reviewCount > 0 {
            let rating = averageRating.formatted(.number.precision(.fractionLength(1)))
            ratingSummary = "\(rating) stars from \(reviewCount) review\(reviewCount == 1 ? "" : "s")."
        } else {
            ratingSummary = "New on Patchwork."
        }

        let completedJobs = selectedProfile?.completedJobs ?? tasker.completedJobs
        let jobsSummary = completedJobs.map { "\($0) jobs completed." } ?? ""

        let parts = [
            "Provider profile for \(name).",
            category?.isEmpty == false ? "\(category!)." : nil,
            verified.isEmpty ? nil : verified,
            ratingSummary,
            jobsSummary.isEmpty ? nil : jobsSummary
        ].compactMap { $0 }

        return parts.joined(separator: " ")
    }

    private func rateLabel(for profile: TaskerCategoryProfile?) -> String? {
        guard let profile else { return nil }
        if profile.rateType == "hourly", let hourlyRate = profile.hourlyRate {
            return "\(PatchworkCurrency.formatted(cents: hourlyRate))/hr"
        }
        if let fixedRate = profile.fixedRate {
            return "\(PatchworkCurrency.formatted(cents: fixedRate)) flat"
        }
        return nil
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
            await appState.openConversation(
                client: sessionStore.client,
                conversationId: conversationId,
                role: "seeker"
            )
        } catch {
            chatError = "Unable to start chat right now. Please try again."
            appState.lastError = error.localizedDescription
        }
    }

    private func toggleFavourite() async {
        guard !isUpdatingFavourite else { return }
        let previousValue = isFavourite
        let nextValue = !previousValue
        isFavourite = nextValue
        isUpdatingFavourite = true
        defer { isUpdatingFavourite = false }

        do {
            let result = try await PatchworkAPI(client: sessionStore.client).taskers.setFavourite(
                taskerId: taskerId,
                isFavourite: nextValue
            )
            isFavourite = result.isFavourite
            await appState.refreshFavouriteTaskers(client: sessionStore.client)
        } catch {
            isFavourite = previousValue
            appState.presentError(error, prefix: "Failed to update favourites")
        }
    }
}

private extension String {
    var normalizedAccessibilityIdentifier: String {
        lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
    }
}

private struct ProviderReviewRow: View {
    let review: TaskerReview

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PatchworkRemoteImage(
                asset: review.reviewerImage,
                legacyURL: review.reviewerPhotoUrl,
                preferredVariant: .thumb,
                contentMode: .fill
            ) {
                PatchworkTheme.brandSoft
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(review.reviewerName)
                            .font(.patchworkBodyStrong)
                            .foregroundStyle(PatchworkTheme.textPrimary)

                        Text("Verified hire")
                            .font(.patchworkCaption)
                            .foregroundStyle(PatchworkTheme.success)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(PatchworkTheme.success.opacity(0.12), in: Capsule())
                    }

                    Spacer()

                    Text(reviewDate)
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textTertiary)
                }

                HStack(spacing: 2) {
                    ForEach(0 ..< max(1, review.rating), id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255))
                    }
                }

                Text(review.text)
                    .font(.patchworkBody)
                    .foregroundStyle(PatchworkTheme.textSecondary)
            }
        }
        .padding(14)
        .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reviewAccessibilityLabel)
    }

    private var reviewDate: String {
        let date = Date(timeIntervalSince1970: TimeInterval(review.createdAt) / 1000)
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private var reviewAccessibilityLabel: String {
        let rating = "\(review.rating) star\(review.rating == 1 ? "" : "s")"
        return "Review from \(review.reviewerName), \(rating), verified hire. \(review.text)"
    }
}
