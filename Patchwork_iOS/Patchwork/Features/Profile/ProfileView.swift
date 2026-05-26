import SwiftUI
import UIKit

private enum ProfileSidebarDestination: String, Identifiable {
    case favourites
    case blocked

    var id: String { rawValue }
}

struct ProfileView: View {
    private enum MainLayout {
        static let horizontalGutter: CGFloat = 20
        static let topRhythm: CGFloat = 10
        static let bottomPadding: CGFloat = 16
    }

    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    @State private var isSidebarPresented = false
    @State private var activeDestination: ProfileSidebarDestination?

    let onSignOut: () async -> Void
    let onDeleteAccount: () async throws -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            PatchworkBackdrop(tint: PatchworkTheme.brand)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ProfileAccountSection(
                        user: appState.currentUser,
                        taskerProfile: appState.taskerProfile
                    ) {
                        withAnimation(.snappy(duration: 0.24)) {
                            isSidebarPresented = true
                        }
                    }

                    ProfileTaskerSection(
                        userName: appState.currentUser?.name,
                        taskerProfile: appState.taskerProfile
                    )
                    ProfileSupportSection(
                        onSignOut: onSignOut,
                        onDeleteAccount: onDeleteAccount
                    )
                    Text(appVersionLabel)
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, MainLayout.horizontalGutter)
            .padding(.top, MainLayout.topRhythm)
            .padding(.bottom, MainLayout.bottomPadding)
            .scrollIndicators(.hidden)
            .allowsHitTesting(!isSidebarPresented && activeDestination == nil)

            if isSidebarPresented {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        closeSidebar()
                    }
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }

            if isSidebarPresented {
                ProfileSidebarMenu(
                    userName: appState.currentUser?.name,
                    onClose: closeSidebar,
                    onOpenFavourites: {
                        openDestination(.favourites)
                    },
                    onOpenBlocked: {
                        openDestination(.blocked)
                    }
                )
                .padding(.top, MainLayout.topRhythm)
                .padding(.trailing, MainLayout.horizontalGutter)
                .padding(.bottom, 8)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(1)
            }

            if activeDestination == .favourites {
                FavouriteTaskersPanel(onClose: closeActiveDestination)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(2)
            }

            if activeDestination == .blocked {
                BlockedUsersPanel(onClose: closeActiveDestination)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .animation(.snappy(duration: 0.28), value: isSidebarPresented)
        .animation(.snappy(duration: 0.3), value: activeDestination)
        .task {
            await appState.refreshAuthedData(client: sessionStore.client)
        }
    }

    private func closeSidebar() {
        withAnimation(.snappy(duration: 0.24)) {
            isSidebarPresented = false
        }
    }

    private func openDestination(_ destination: ProfileSidebarDestination) {
        withAnimation(.snappy(duration: 0.18)) {
            isSidebarPresented = false
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(.snappy(duration: 0.3)) {
                activeDestination = destination
            }
        }
    }

    private func closeActiveDestination() {
        withAnimation(.snappy(duration: 0.28)) {
            activeDestination = nil
        }
    }

    private var appVersionLabel: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, buildNumber) {
        case let (version?, build?) where !version.isEmpty && !build.isEmpty:
            return "Version \(version) (\(build))"
        case let (version?, _) where !version.isEmpty:
            return "Version \(version)"
        case let (_, build?) where !build.isEmpty:
            return "Build \(build)"
        default:
            return "Version unavailable"
        }
    }
}

struct TaskerOnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var step = 1
    @State private var displayName = ""
    @State private var selectedCategoryId: ConvexID?
    @State private var websiteLinks = [""]
    @State private var socialLinks = [""]

    @State private var categoryBio = ""
    @State private var rateType = "hourly"
    @State private var hourlyRate = ""
    @State private var fixedRate = ""
    @State private var serviceRadius = 25
    @State private var taskerPhotoSource = "user"
    @State private var taskerCustomPhotoAssetId: ConvexID?
    @State private var onboardingPortfolioPhotos: [TaskerPortfolioPhoto] = []
    @State private var onboardingCoverPhotoId: String?
    @State private var isShowingSubscriptions = false
    @State private var isCreatingProfile = false

    @State private var profileDisplayName = ""
    @State private var profileWebsiteLinks: [String] = [""]
    @State private var profileSocialLinks: [String] = [""]
    @State private var addCategorySheet = false
    @State private var hasRestoredOnboardingDraft = false
    @AppStorage("Patchwork.taskerOnboardingDraft") private var onboardingDraftJSON = ""

    var body: some View {
        Group {
            if let profile = appState.taskerProfile, step < 6 {
                manageProfileView(profile)
            } else {
                createFlowView
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingSubscriptions) {
            TaskerBillingSheet()
                .patchworkSheetChrome(detents: [.large])
        }
        .task {
            restoreOnboardingDraftIfNeeded()
            await appState.refreshAuthedData(client: sessionStore.client)
        }
        .onChange(of: step) { _, _ in saveOnboardingDraft() }
        .onChange(of: displayName) { _, _ in saveOnboardingDraft() }
        .onChange(of: selectedCategoryId) { _, _ in saveOnboardingDraft() }
        .onChange(of: websiteLinks) { _, _ in saveOnboardingDraft() }
        .onChange(of: socialLinks) { _, _ in saveOnboardingDraft() }
        .onChange(of: categoryBio) { _, _ in saveOnboardingDraft() }
        .onChange(of: rateType) { _, _ in saveOnboardingDraft() }
        .onChange(of: hourlyRate) { _, _ in saveOnboardingDraft() }
        .onChange(of: fixedRate) { _, _ in saveOnboardingDraft() }
        .onChange(of: serviceRadius) { _, _ in saveOnboardingDraft() }
    }

    private func manageProfileView(_ profile: TaskerProfileSelf) -> some View {
        TaskerProfileManageView(
            profileDisplayName: $profileDisplayName,
            profileWebsiteLinks: $profileWebsiteLinks,
            profileSocialLinks: $profileSocialLinks,
            addCategorySheet: $addCategorySheet,
            categories: appState.categories,
            existingCategoryIDs: Set(profile.categories.map { $0.categoryId }),
            onSaveProfile: updateTaskerProfile,
            onRemoveCategory: removeCategory,
            onAddCategory: { draft in Task { await addCategory(draft: draft) } },
            onUpdateCategory: updateTaskerCategory
        )
        .onAppear {
            profileDisplayName = profile.displayName
            profileWebsiteLinks = editableLinks(profile.websiteLinks)
            profileSocialLinks = editableLinks(profile.socialLinks)
        }
    }

    private var createFlowView: some View {
        TaskerCreateFlowView(
            step: $step,
            displayName: $displayName,
            selectedCategoryId: $selectedCategoryId,
            websiteLinks: $websiteLinks,
            socialLinks: $socialLinks,
            categories: appState.categories,
            taskerPhotoSource: $taskerPhotoSource,
            taskerCustomPhotoAssetId: $taskerCustomPhotoAssetId,
            accountPhotoImage: appState.currentUser?.photoImage,
            categoryBio: $categoryBio,
            rateType: $rateType,
            hourlyRate: $hourlyRate,
            fixedRate: $fixedRate,
            serviceRadius: $serviceRadius,
            portfolioPhotos: $onboardingPortfolioPhotos,
            coverPhotoId: $onboardingCoverPhotoId,
            isCreatingProfile: $isCreatingProfile,
            onSubmit: { Task { await createProfile() } },
            onSubscribe: { isShowingSubscriptions = true },
            onDone: { dismiss() }
        )
    }

    private func createProfile() async {
        guard !isCreatingProfile else { return }
        guard let selectedCategoryId else { return }
        isCreatingProfile = true
        defer { isCreatingProfile = false }

        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategoryBio = categoryBio.trimmingCharacters(in: .whitespacesAndNewlines)
        let hourlyCents = Int((Double(hourlyRate) ?? 0) * 100)
        let fixedCents = Int((Double(fixedRate) ?? 0) * 100)
        let submittedRateCents = rateType == "hourly" ? hourlyCents : fixedCents
        guard submittedRateCents > 0 else {
            appState.lastError = "Enter a valid positive rate before creating your tasker profile."
            return
        }
        var args: [String: Any] = [
            "displayName": trimmedDisplayName,
            "websiteLinks": normalizedLinks(websiteLinks),
            "socialLinks": normalizedLinks(socialLinks),
            "categoryId": selectedCategoryId,
            "categoryBio": trimmedCategoryBio,
            "rateType": rateType,
            "serviceRadius": serviceRadius,
            "photoSource": taskerPhotoSource,
        ]
        if taskerPhotoSource == "custom", let taskerCustomPhotoAssetId {
            args["photoAssetId"] = taskerCustomPhotoAssetId
        }
        if rateType == "hourly" {
            args["hourlyRate"] = hourlyCents
        } else {
            args["fixedRate"] = fixedCents
        }

        do {
            let resolvedPortfolio = try await resolvePortfolioPhotos(
                onboardingPortfolioPhotos,
                coverPhotoId: onboardingCoverPhotoId
            )
            if resolvedPortfolio.shouldPersist {
                args["portfolioAssetIds"] = resolvedPortfolio.assetIds
                if let coverAssetId = resolvedPortfolio.coverAssetId {
                    args["coverAssetId"] = coverAssetId
                }
            }

            do {
                _ = try await sessionStore.client.mutation("taskers:createTaskerProfile", args: args) as ConvexID
            } catch {
                await cleanupUploadedPortfolioAssets(resolvedPortfolio.uploadedAssetIds)
                throw error
            }

            step = 6
            onboardingDraftJSON = ""
            Task {
                await appState.refreshAuthedData(client: sessionStore.client, surfaceErrors: false)
            }
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func updateTaskerProfile(displayName: String, websiteLinks: [String], socialLinks: [String]) async throws {
        let updatedProfile = try await sessionStore.client.mutation(
            "taskers:updateTaskerProfile",
            args: [
                "displayName": displayName,
                "websiteLinks": normalizedLinks(websiteLinks),
                "socialLinks": normalizedLinks(socialLinks),
            ]
        ) as TaskerProfileSelf
        appState.taskerProfile = updatedProfile
    }

    private func normalizedLinks(_ links: [String]) -> [String] {
        links.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func editableLinks(_ links: [String]) -> [String] {
        links.isEmpty ? [""] : links
    }

    private func saveOnboardingDraft() {
        let draft = TaskerOnboardingDraft(
            step: min(max(step, 1), 5),
            displayName: displayName,
            selectedCategoryId: selectedCategoryId,
            websiteLinks: websiteLinks,
            socialLinks: socialLinks,
            categoryBio: categoryBio,
            rateType: rateType,
            hourlyRate: hourlyRate,
            fixedRate: fixedRate,
            serviceRadius: serviceRadius
        )
        guard let data = try? JSONEncoder().encode(draft),
              let json = String(data: data, encoding: .utf8) else { return }
        onboardingDraftJSON = json
    }

    private func restoreOnboardingDraftIfNeeded() {
        guard !hasRestoredOnboardingDraft else {
            return
        }

        hasRestoredOnboardingDraft = true
        restoreOnboardingDraft()
    }

    private func restoreOnboardingDraft() {
        guard appState.taskerProfile == nil,
              !onboardingDraftJSON.isEmpty,
              let data = onboardingDraftJSON.data(using: .utf8),
              let draft = try? JSONDecoder().decode(TaskerOnboardingDraft.self, from: data) else { return }
        step = min(max(draft.step, 1), 5)
        displayName = draft.displayName
        selectedCategoryId = draft.selectedCategoryId
        websiteLinks = editableLinks(draft.websiteLinks)
        socialLinks = editableLinks(draft.socialLinks)
        categoryBio = draft.categoryBio
        rateType = draft.rateType
        hourlyRate = draft.hourlyRate
        fixedRate = draft.fixedRate
        serviceRadius = draft.serviceRadius
    }

    private func removeCategory(categoryId: ConvexID) async throws {
        _ = try await sessionStore.client.mutation(
            "taskers:removeTaskerCategory",
            args: ["categoryId": categoryId]
        ) as EmptyResponse
        await appState.refreshAuthedData(client: sessionStore.client)
    }

    private func addCategory(draft: TaskerCategoryDraft) async {
        do {
            let resolvedPortfolio = try await resolvePortfolioPhotos(
                draft.portfolioPhotos,
                coverPhotoId: draft.coverPhotoId
            )
            var args: [String: Any] = [
                "categoryId": draft.categoryId,
                "categoryBio": draft.categoryBio,
                "rateType": draft.rateType,
                "hourlyRate": draft.rateType == "hourly" ? max(Int((Double(draft.hourlyRate) ?? 0) * 100), 1) : nil,
                "fixedRate": draft.rateType == "fixed" ? max(Int((Double(draft.fixedRate) ?? 0) * 100), 1) : nil,
                "serviceRadius": draft.serviceRadius,
            ].compactMapValues { $0 }
            if resolvedPortfolio.shouldPersist {
                args["portfolioAssetIds"] = resolvedPortfolio.assetIds
                if let coverAssetId = resolvedPortfolio.coverAssetId {
                    args["coverAssetId"] = coverAssetId
                }
            }

            do {
                _ = try await sessionStore.client.mutation(
                    "taskers:addTaskerCategory",
                    args: args
                ) as EmptyResponse
            } catch {
                await cleanupUploadedPortfolioAssets(resolvedPortfolio.uploadedAssetIds)
                throw error
            }

            await appState.refreshAuthedData(client: sessionStore.client)
            addCategorySheet = false
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func updateTaskerCategory(draft: TaskerCategoryDraft) async throws {
        let resolvedPortfolio = try await resolvePortfolioPhotos(
            draft.portfolioPhotos,
            coverPhotoId: draft.coverPhotoId
        )
        var args: [String: Any] = [
            "categoryId": draft.categoryId,
            "categoryBio": draft.categoryBio,
            "rateType": draft.rateType,
            "hourlyRate": draft.rateType == "hourly" ? max(Int((Double(draft.hourlyRate) ?? 0) * 100), 1) : nil,
            "fixedRate": draft.rateType == "fixed" ? max(Int((Double(draft.fixedRate) ?? 0) * 100), 1) : nil,
            "serviceRadius": draft.serviceRadius,
        ].compactMapValues { $0 }
        args["portfolioAssetIds"] = resolvedPortfolio.assetIds
        if let coverAssetId = resolvedPortfolio.coverAssetId {
            args["coverAssetId"] = coverAssetId
        }

        let updatedProfile: TaskerProfileSelf
        do {
            updatedProfile = try await sessionStore.client.mutation(
                "taskers:updateTaskerCategory",
                args: args
            ) as TaskerProfileSelf
        } catch {
            await cleanupUploadedPortfolioAssets(resolvedPortfolio.uploadedAssetIds)
            throw error
        }
        appState.taskerProfile = updatedProfile
    }

    private func resolvePortfolioPhotos(
        _ photos: [TaskerPortfolioPhoto],
        coverPhotoId: String?
    ) async throws -> ResolvedTaskerPortfolio {
        let uploadService = ImageAssetUploadService(client: sessionStore.client)
        var assetIds: [ConvexID] = []
        var uploadedAssetIds: [ConvexID] = []
        var selectedCoverAssetId: ConvexID?

        do {
            for photo in photos.prefix(10) {
                let asset: RemoteImageAsset
                if let remoteAsset = photo.remoteAsset {
                    asset = remoteAsset
                } else if let draft = photo.localDraft {
                    asset = try await uploadService.uploadImage(
                        data: draft.data,
                        purpose: PhotoPurpose.taskerCategoryPortfolio.convexPurpose
                    )
                    uploadedAssetIds.append(asset.id)
                } else {
                    continue
                }

                assetIds.append(asset.id)
                if photo.id == coverPhotoId {
                    selectedCoverAssetId = asset.id
                }
            }
        } catch {
            await cleanupUploadedPortfolioAssets(uploadedAssetIds)
            throw error
        }

        return ResolvedTaskerPortfolio(
            assetIds: assetIds,
            coverAssetId: selectedCoverAssetId ?? assetIds.first,
            uploadedAssetIds: uploadedAssetIds
        )
    }

    private func cleanupUploadedPortfolioAssets(_ assetIds: [ConvexID]) async {
        guard !assetIds.isEmpty else { return }
        for assetId in assetIds {
            let _: RemoteImageAsset? = try? await sessionStore.client.mutation(
                "files:deleteImageAsset",
                args: ["imageAssetId": assetId]
            )
        }
    }
}

private struct ResolvedTaskerPortfolio {
    let assetIds: [ConvexID]
    let coverAssetId: ConvexID?
    let uploadedAssetIds: [ConvexID]

    var shouldPersist: Bool {
        !assetIds.isEmpty || coverAssetId != nil
    }
}

private struct TaskerPortfolioPhoto: Identifiable {
    let id: String
    let remoteAsset: RemoteImageAsset?
    let localDraft: PhotoDraft?

    static func remote(_ asset: RemoteImageAsset) -> TaskerPortfolioPhoto {
        TaskerPortfolioPhoto(
            id: remoteId(for: asset.id),
            remoteAsset: asset,
            localDraft: nil
        )
    }

    static func draft(_ draft: PhotoDraft) -> TaskerPortfolioPhoto {
        TaskerPortfolioPhoto(
            id: "draft:\(draft.id.uuidString)",
            remoteAsset: nil,
            localDraft: draft
        )
    }

    static func remoteId(for assetId: ConvexID) -> String {
        "remote:\(assetId)"
    }
}

private struct TaskerCategoryDraft {
    let categoryId: ConvexID
    let categoryBio: String
    let rateType: String
    let hourlyRate: String
    let fixedRate: String
    let serviceRadius: Int
    let portfolioPhotos: [TaskerPortfolioPhoto]
    let coverPhotoId: String?

    var shouldPersistPortfolio: Bool {
        !portfolioPhotos.isEmpty || coverPhotoId != nil
    }

    init(
        categoryId: ConvexID,
        categoryBio: String,
        rateType: String,
        hourlyRate: String,
        fixedRate: String,
        serviceRadius: Int,
        portfolioPhotos: [TaskerPortfolioPhoto] = [],
        coverPhotoId: String? = nil
    ) {
        self.categoryId = categoryId
        self.categoryBio = categoryBio
        self.rateType = rateType
        self.hourlyRate = hourlyRate
        self.fixedRate = fixedRate
        self.serviceRadius = serviceRadius
        self.portfolioPhotos = portfolioPhotos
        self.coverPhotoId = coverPhotoId
    }

    init(category: TaskerManagedCategory) {
        let remotePhotos = (category.portfolioImages ?? []).map(TaskerPortfolioPhoto.remote)
        let selectedCoverPhotoId = (category.coverAssetId ?? category.portfolioImages?.first?.id)
            .map(TaskerPortfolioPhoto.remoteId(for:))
        self.categoryId = category.categoryId
        self.categoryBio = category.bio
        self.rateType = category.rateType
        self.hourlyRate = Self.priceFieldText(from: category.hourlyRate)
        self.fixedRate = Self.priceFieldText(from: category.fixedRate)
        self.serviceRadius = category.serviceRadius
        self.portfolioPhotos = remotePhotos
        self.coverPhotoId = selectedCoverPhotoId
    }

    private static func priceFieldText(from cents: Int?) -> String {
        guard let cents else { return "" }
        return (Double(cents) / 100).formatted(.number.precision(.fractionLength(2)))
    }
}

private enum TaskerCreateFocusField: Hashable {
    case displayName
    case website
    case social
    case bio
    case hourlyRate
    case fixedRate
}

private struct TaskerOnboardingDraft: Codable {
    let step: Int
    let displayName: String
    let selectedCategoryId: ConvexID?
    let websiteLinks: [String]
    let socialLinks: [String]
    let categoryBio: String
    let rateType: String
    let hourlyRate: String
    let fixedRate: String
    let serviceRadius: Int
}

private struct TaskerLinksEditor: View {
    let title: String
    let placeholder: String
    let systemImage: String
    @Binding var links: [String]
    let accessibilityPrefix: String

    private let maxLinks = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.brand)
                    .frame(width: 18)
                Text(title)
                    .font(.patchworkBodyStrong)
                    .foregroundStyle(PatchworkTheme.textPrimary)
                Spacer()
                Text("\(normalizedLinks.count)/\(maxLinks)")
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textSecondary)
            }

            ForEach(Array(links.indices), id: \.self) { index in
                HStack(spacing: 8) {
                    linkField(index)

                    if links.count > 1 {
                        Button {
                            links.remove(at: index)
                            ensureOneField()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(PatchworkTheme.danger)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("\(accessibilityPrefix).remove.\(index)")
                        .accessibilityLabel("Remove \(title.lowercased()) link")
                    }
                }
            }

            Button {
                guard links.count < maxLinks else { return }
                links.append("")
            } label: {
                Label("Add \(title.lowercased()) link", systemImage: "plus.circle.fill")
                    .font(.patchworkBodyStrong)
                    .foregroundStyle(PatchworkTheme.brand)
            }
            .buttonStyle(.plain)
            .disabled(links.count >= maxLinks)
            .accessibilityIdentifier("\(accessibilityPrefix).addButton")
        }
        .onAppear(perform: ensureOneField)
    }

    private var normalizedLinks: [String] {
        links.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func linkField(_ index: Int) -> some View {
        let binding = Binding<String>(
            get: { links.indices.contains(index) ? links[index] : "" },
            set: { newValue in
                if links.indices.contains(index) {
                    links[index] = newValue
                }
            }
        )

        return TextField(placeholder, text: binding)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
            .autocorrectionDisabled()
            .patchworkInputFieldStyle()
            .accessibilityIdentifier("\(accessibilityPrefix).field.\(index)")
    }

    private func ensureOneField() {
        if links.isEmpty {
            links = [""]
        } else if links.count > maxLinks {
            links = Array(links.prefix(maxLinks))
        }
    }
}

private enum PortfolioPhotoSheet: Identifiable {
    case camera
    case gallery
    case crop(PhotoCropInput)

    var id: String {
        switch self {
        case .camera:
            return "camera"
        case .gallery:
            return "gallery"
        case .crop(let input):
            return "crop-\(input.id)"
        }
    }
}

private struct TaskerCreateFlowView: View {
    private enum PhotoSheet: Identifiable {
        case taskerCamera
        case taskerGallery
        case taskerCrop(PhotoCropInput)
        case portfolioCamera
        case portfolioGallery
        case portfolioCrop(PhotoCropInput)

        var id: String {
            switch self {
            case .taskerCamera:
                return "taskerCamera"
            case .taskerGallery:
                return "taskerGallery"
            case .taskerCrop(let input):
                return "taskerCrop-\(input.id)"
            case .portfolioCamera:
                return "portfolioCamera"
            case .portfolioGallery:
                return "portfolioGallery"
            case .portfolioCrop(let input):
                return "portfolioCrop-\(input.id)"
            }
        }
    }

    @Environment(SessionStore.self) private var sessionStore

    @Binding var step: Int
    @Binding var displayName: String
    @Binding var selectedCategoryId: ConvexID?
    @Binding var websiteLinks: [String]
    @Binding var socialLinks: [String]
    let categories: [Category]
    @Binding var taskerPhotoSource: String
    @Binding var taskerCustomPhotoAssetId: ConvexID?
    let accountPhotoImage: RemoteImageAsset?
    @Binding var categoryBio: String
    @Binding var rateType: String
    @Binding var hourlyRate: String
    @Binding var fixedRate: String
    @Binding var serviceRadius: Int
    @Binding var portfolioPhotos: [TaskerPortfolioPhoto]
    @Binding var coverPhotoId: String?
    @Binding var isCreatingProfile: Bool
    let onSubmit: () -> Void
    let onSubscribe: () -> Void
    let onDone: () -> Void

    @State private var acceptedTerms = false
    @State private var customPhotoAsset: RemoteImageAsset?
    @State private var showsTaskerPhotoOptions = false
    @State private var showsPortfolioPhotoOptions = false
    @State private var photoSheet: PhotoSheet?
    @State private var portfolioCropQueue: [UIImage] = []
    @State private var isUploadingTaskerPhoto = false
    @State private var isUploadingPortfolio = false
    @State private var photoStatusMessage: SubscriptionFeedbackMessage?
    @State private var portfolioStatusMessage: SubscriptionFeedbackMessage?
    @State private var isShowingPrimaryCategoryPicker = false
    @FocusState private var focusedField: TaskerCreateFocusField?

    private var canCompleteSetup: Bool {
        acceptedTerms && hasValidRate && !isUploadingTaskerPhoto && !isUploadingPortfolio && !isCreatingProfile
    }

    private var hasValidRate: Bool {
        if rateType == "hourly" {
            return (Double(hourlyRate) ?? 0) > 0
        }
        return (Double(fixedRate) ?? 0) > 0
    }

    var body: some View {
        ZStack {
            keyboardDismissLayer
            PatchworkBackdrop(tint: PatchworkTheme.brand)
            createFlowScroll
        }
        .patchworkKeyboardDismissToolbar(isPresented: focusedField != .displayName)
        .onAppear {
            if taskerPhotoSource == "custom", customPhotoAsset == nil, taskerCustomPhotoAssetId == nil {
                taskerPhotoSource = "user"
            }
        }
        .onChange(of: portfolioPhotos.map(\.id)) { _, _ in
            guard let coverPhotoId else {
                return
            }
            if !portfolioPhotos.contains(where: { $0.id == coverPhotoId }) {
                self.coverPhotoId = portfolioPhotos.first?.id
            }
        }
        .confirmationDialog("Tasker photo", isPresented: $showsTaskerPhotoOptions, titleVisibility: .visible) {
            if CameraCaptureView.isCameraAvailable {
                Button("Take Photo") {
                    photoSheet = .taskerCamera
                }
            }
            Button("Choose from Gallery") {
                photoSheet = .taskerGallery
            }
            if taskerPhotoSource == "custom", taskerCustomPhotoAssetId != nil {
                Button("Use Account Photo", role: .destructive) {
                    switchTaskerPhotoToAccount()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Portfolio photos", isPresented: $showsPortfolioPhotoOptions, titleVisibility: .visible) {
            if CameraCaptureView.isCameraAvailable {
                Button("Take Photo") {
                    photoSheet = .portfolioCamera
                }
            }
            Button("Choose from Gallery") {
                photoSheet = .portfolioGallery
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $photoSheet) { sheet in
            switch sheet {
            case .taskerCamera:
                CameraCaptureView { image in
                    presentTaskerCropIfNeeded(image)
                }
            case .taskerGallery:
                GalleryPickerView(selectionLimit: 1) { images in
                    presentTaskerCropIfNeeded(images.first)
                }
            case .taskerCrop(let input):
                PhotoCropEditor(input: input) {
                    photoSheet = nil
                } onConfirm: { draft in
                    Task { await uploadTaskerPhoto(draft) }
                }
            case .portfolioCamera:
                CameraCaptureView { image in
                    startPortfolioCropQueue(image.map { [$0] } ?? [])
                }
            case .portfolioGallery:
                GalleryPickerView(selectionLimit: max(1, 10 - portfolioPhotos.count)) { images in
                    startPortfolioCropQueue(images)
                }
            case .portfolioCrop(let input):
                PhotoCropEditor(input: input) {
                    portfolioCropQueue.removeAll()
                    photoSheet = nil
                } onConfirm: { draft in
                    addPortfolioDraft(draft)
                }
            }
        }
    }

    private var keyboardDismissLayer: some View {
        Color.clear
            .contentShape(Rectangle())
            .ignoresSafeArea()
            .onTapGesture {
                PatchworkKeyboard.dismiss()
            }
    }

    private var createFlowScroll: some View {
        ScrollView {
            VStack(spacing: 18) {
                StepHeader(currentStep: min(step, 5), totalSteps: 5)
                    .padding(.top, 12)
                createFlowContent
            }
        }
        .id("tasker-onboarding-step-\(step)")
        .scrollDismissesKeyboard(.interactively)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var createFlowContent: some View {
        if step >= 6 {
            taskerCreatedCard
        } else {
            onboardingStepContent
        }
    }

    private var taskerCreatedCard: some View {
        PatchworkSurfaceCard {
            VStack(spacing: 18) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(PatchworkTheme.success)

                Text("Tasker profile created")
                    .font(.patchworkSectionTitle)
                    .foregroundStyle(PatchworkTheme.textPrimary)

                Text("To become discoverable to Seekers in your area, unlock tasker mode.")
                    .font(.patchworkBody)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PatchworkTheme.textSecondary)

                Button("Unlock tasker mode", action: onSubscribe)
                    .buttonStyle(PatchworkPrimaryButtonStyle())
                    .accessibilityIdentifier("TaskerOnboarding5.subscribeButton")

                Button("Done", action: onDone)
                    .buttonStyle(PatchworkSecondaryButtonStyle())
                    .accessibilityIdentifier("TaskerOnboarding5.doneButton")
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var onboardingStepContent: some View {
        switch step {
        case 1:
            PatchworkSurfaceCard {
                VStack(alignment: .leading, spacing: 18) {
                    PatchworkSectionIntro(
                        eyebrow: "Tasker setup",
                        title: "Identity",
                        message: "Set the name, category, and avatar seekers see first."
                    )

                    TextField("Display name", text: $displayName)
                        .patchworkInputFieldStyle()
                        .focused($focusedField, equals: .displayName)
                        .accessibilityIdentifier("TaskerOnboarding1.displayNameField")

                    Button {
                        focusedField = nil
                        PatchworkKeyboard.dismiss()
                        isShowingPrimaryCategoryPicker = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Primary category")
                                    .font(.patchworkCaption)
                                    .foregroundStyle(PatchworkTheme.textSecondary)
                                Text(selectedCategoryName)
                                    .font(.patchworkBody)
                                    .foregroundStyle(PatchworkTheme.textPrimary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(PatchworkTheme.textTertiary)
                                .accessibilityHidden(true)
                        }
                        .padding(16)
                        .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(PatchworkTheme.stroke, lineWidth: 1)
                        )
                        .accessibilityElement(children: .combine)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("TaskerOnboarding1.categoryPicker")
                    .navigationDestination(isPresented: $isShowingPrimaryCategoryPicker) {
                        CategoriesView(
                            title: "Select Primary Category",
                            selectedCategoryID: selectedCategoryId,
                            dismissOnSelect: false,
                            onSelect: { category in
                                selectedCategoryId = category.id
                                isShowingPrimaryCategoryPicker = false
                            }
                        )
                    }

                    taskerPhotoSourceSection

                    Button("Continue") {
                        step = 2
                        focusedField = .bio
                    }
                    .buttonStyle(PatchworkPrimaryButtonStyle())
                    .disabled(
                        displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || selectedCategoryId == nil
                            || (taskerPhotoSource == "custom" && taskerCustomPhotoAssetId == nil)
                            || isUploadingTaskerPhoto
                    )
                    .accessibilityIdentifier("TaskerOnboarding1.continueButton")
                }
            }
        case 2:
            PatchworkSurfaceCard {
                VStack(alignment: .leading, spacing: 18) {
                    PatchworkSectionIntro(
                        eyebrow: "Tasker setup",
                        title: "Links",
                        message: "Add the web and social places seekers can use to check your work. This is optional."
                    )

                    TaskerLinksEditor(
                        title: "Websites",
                        placeholder: "https://example.com",
                        systemImage: "globe",
                        links: $websiteLinks,
                        accessibilityPrefix: "TaskerOnboarding2.websiteLinks"
                    )

                    TaskerLinksEditor(
                        title: "Social",
                        placeholder: "@yourhandle or profile link",
                        systemImage: "at",
                        links: $socialLinks,
                        accessibilityPrefix: "TaskerOnboarding2.socialLinks"
                    )

                    HStack(spacing: 12) {
                        Button("Back") { step = 1 }
                            .buttonStyle(PatchworkSecondaryButtonStyle())
                            .accessibilityIdentifier("TaskerOnboarding2.backButton")

                        Button(normalizedLinks(websiteLinks).isEmpty && normalizedLinks(socialLinks).isEmpty ? "Skip" : "Continue") {
                            step = 3
                            focusedField = .bio
                        }
                        .buttonStyle(PatchworkPrimaryButtonStyle())
                        .accessibilityIdentifier("TaskerOnboarding2.continueButton")
                    }
                }
            }
        case 3:
            VStack(spacing: 18) {
                CategoryServiceDetailsSection(
                    title: "Details",
                    eyebrow: "Tasker setup",
                    message: "Set your pricing and service range with clean, explicit terms.",
                    bio: $categoryBio,
                    rateType: $rateType,
                    hourlyRate: $hourlyRate,
                    fixedRate: $fixedRate,
                    serviceRadius: $serviceRadius,
                    focusedField: $focusedField,
                    accessibilityPrefix: "TaskerOnboarding3"
                )

                HStack(spacing: 12) {
                    Button("Back") { step = 2 }
                        .buttonStyle(PatchworkSecondaryButtonStyle())
                        .accessibilityIdentifier("TaskerOnboarding3.backButton")

                    Button("Continue") { step = 4 }
                        .buttonStyle(PatchworkPrimaryButtonStyle())
                        .disabled(categoryBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasValidRate)
                        .accessibilityIdentifier("TaskerOnboarding3.continueButton")
                }
            }
        case 4:
            VStack(spacing: 18) {
                PatchworkSurfaceCard {
                    PatchworkSectionIntro(
                        eyebrow: "Tasker setup",
                        title: "Portfolio",
                        message: "Add up to 10 photos. Pick one 4:3 cover image for your Profile Card."
                    )
                }

                TaskerCategoryPortfolioEditor(
                    portfolioPhotos: $portfolioPhotos,
                    coverPhotoId: $coverPhotoId,
                    isUploading: isUploadingPortfolio,
                    statusMessage: portfolioStatusMessage,
                    accessibilityPrefix: "TaskerOnboarding4.portfolio",
                    onAddPhotos: { showsPortfolioPhotoOptions = true }
                )

                HStack(spacing: 12) {
                    Button("Back") { step = 3 }
                        .buttonStyle(PatchworkSecondaryButtonStyle())
                        .accessibilityIdentifier("TaskerOnboarding4.backButton")

                    Button("Continue") { step = 5 }
                        .buttonStyle(PatchworkPrimaryButtonStyle())
                        .disabled(isUploadingPortfolio)
                        .accessibilityIdentifier("TaskerOnboarding4.continueButton")
                }
            }
        default:
            PatchworkSurfaceCard {
                VStack(alignment: .leading, spacing: 18) {
                    PatchworkSectionIntro(
                        eyebrow: "Tasker setup",
                        title: "Profile Card review",
                        message: "Preview how your card appears in Discover, then create your profile."
                    )

                    discoverCardPreview
                    onboardingSummaryRow("Display name", value: displayName)
                    onboardingSummaryRow("Primary website", value: normalizedLinks(websiteLinks).first ?? "None")
                    onboardingSummaryRow("Primary social", value: normalizedLinks(socialLinks).first ?? "None")
                    onboardingSummaryRow("Rate", value: reviewRateSummary)
                    onboardingSummaryRow("Radius", value: "\(serviceRadius) km")
                    onboardingSummaryRow("Portfolio", value: "\(portfolioPhotos.count)/10")

                    Button {
                        acceptedTerms.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Text("I agree to the Tasker terms and community guidelines.")
                                .font(.patchworkBody)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(PatchworkTheme.textPrimary)
                            Spacer(minLength: 12)
                            Image(systemName: acceptedTerms ? "checkmark.circle.fill" : "circle")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(acceptedTerms ? PatchworkTheme.brand : PatchworkTheme.strokeStrong)
                                .accessibilityHidden(true)
                        }
                        .padding(16)
                        .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(PatchworkTheme.stroke, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("I agree to the Tasker terms and community guidelines")
                    .accessibilityValue(acceptedTerms ? "Selected" : "Not selected")
                    .accessibilityHint("Required to complete setup")
                    .accessibilityIdentifier("TaskerOnboarding5.acceptTermsToggle")

                    HStack(spacing: 12) {
                        Button("Back") { step = 4 }
                            .buttonStyle(PatchworkSecondaryButtonStyle())
                            .accessibilityIdentifier("TaskerOnboarding5.backButton")

                        Button(isCreatingProfile ? "Creating…" : "Complete Setup", action: onSubmit)
                            .buttonStyle(PatchworkPrimaryButtonStyle())
                            .disabled(!canCompleteSetup)
                            .accessibilityIdentifier("TaskerOnboarding5.completeButton")
                    }
                }
            }
        }
    }

    private func onboardingSummaryRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.patchworkBodyStrong)
                .foregroundStyle(PatchworkTheme.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }

    private func normalizedLinks(_ links: [String]) -> [String] {
        links.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private var displayedTaskerPhotoAsset: RemoteImageAsset? {
        if taskerPhotoSource == "custom" {
            return customPhotoAsset
        }
        return accountPhotoImage
    }

    private var taskerPhotoSourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Public avatar")
                .font(.patchworkBodyStrong)
                .foregroundStyle(PatchworkTheme.textPrimary)

            HStack(spacing: 12) {
                PatchworkRemoteImage(
                    asset: displayedTaskerPhotoAsset,
                    preferredVariant: .display,
                    contentMode: .fill
                ) {
                    taskerPhotoPlaceholder
                }
                .frame(width: 66, height: 66)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
                )

                if taskerPhotoSource == "user" {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Using account profile photo.")
                            .font(.patchworkCaption)
                            .foregroundStyle(PatchworkTheme.textSecondary)

                        if accountPhotoImage == nil {
                            Text("No account avatar set yet.")
                                .font(.patchworkCaption)
                                .foregroundStyle(PatchworkTheme.warning)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    if taskerPhotoSource == "custom" {
                        Button {
                            switchTaskerPhotoToAccount()
                        } label: {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(PatchworkTheme.brand)
                                .frame(width: 34, height: 34)
                                .background(PatchworkTheme.surface.opacity(0.94), in: Circle())
                                .overlay(
                                    Circle()
                                        .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isUploadingTaskerPhoto)
                        .accessibilityIdentifier("TaskerOnboarding1.taskerPhotoUseAccountButton")
                        .accessibilityLabel("Use account photo")
                    }

                    taskerPhotoEditButton

                    if taskerPhotoSource == "custom", taskerCustomPhotoAssetId != nil {
                        Button {
                            switchTaskerPhotoToAccount()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(PatchworkTheme.warning)
                                .frame(width: 32, height: 32)
                                .background(PatchworkTheme.surface.opacity(0.94), in: Circle())
                                .overlay(
                                    Circle()
                                        .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isUploadingTaskerPhoto)
                        .accessibilityIdentifier("TaskerOnboarding1.taskerPhotoRemoveButton")
                        .accessibilityLabel("Remove custom tasker photo")
                    }
                }
            }

            if isUploadingTaskerPhoto {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(PatchworkTheme.brand)
                    Text("Uploading tasker photo...")
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                }
            } else if let photoStatusMessage {
                PatchworkInlineStatusBanner(tone: photoStatusMessage.tone, text: photoStatusMessage.text)
            }
        }
        .padding(16)
        .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
    }

    private var taskerPhotoPlaceholder: some View {
        ZStack {
            PatchworkTheme.brandSoft
            Image(systemName: "person.crop.circle")
                .font(.title2.weight(.semibold))
                .foregroundStyle(PatchworkTheme.brand)
        }
    }

    private var taskerPhotoEditButton: some View {
        Button {
            showsTaskerPhotoOptions = true
        } label: {
            Image(systemName: taskerCustomPhotoAssetId == nil ? "plus" : "pencil")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(PatchworkTheme.brand)
                .frame(width: 34, height: 34)
                .background(PatchworkTheme.surface.opacity(0.94), in: Circle())
                .overlay(
                    Circle()
                        .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isUploadingTaskerPhoto)
        .accessibilityIdentifier("TaskerOnboarding1.taskerPhotoPicker")
        .accessibilityLabel(taskerCustomPhotoAssetId == nil ? "Upload custom tasker photo" : "Replace tasker photo")
    }

    private var activeCoverPhoto: TaskerPortfolioPhoto? {
        if let coverPhotoId,
           let selectedCover = portfolioPhotos.first(where: { $0.id == coverPhotoId }) {
            return selectedCover
        }
        return portfolioPhotos.first
    }

    private var discoverCardPreview: some View {
        VStack(spacing: 0) {
            TaskerPortfolioPhotoImage(photo: activeCoverPhoto, preferredVariant: .display) {
                ZStack {
                    PatchworkTheme.brandSoft
                    Image(systemName: "photo")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(PatchworkTheme.brand)
                }
            }
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.24)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .overlay(alignment: .bottomLeading) {
                    Text(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your name" : displayName)
                        .font(.patchworkCardTitle)
                        .foregroundStyle(.white)
                        .padding(18)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                PatchworkRemoteImage(
                    asset: displayedTaskerPhotoAsset,
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
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedCategoryName)
                            .font(.patchworkBody)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(reviewRateSummary)
                        .font(.patchworkCardTitle)
                        .foregroundStyle(PatchworkTheme.brand)
                }

                Label("\(serviceRadius) km radius", systemImage: "mappin")
                    .font(.footnote)
                    .foregroundStyle(PatchworkTheme.textSecondary)

                if !categoryBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(categoryBio)
                        .font(.patchworkBody)
                        .foregroundStyle(PatchworkTheme.textPrimary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Profile card preview")
        .accessibilityIdentifier("TaskerOnboarding4.discoverCardPreview")
    }

    private func switchTaskerPhotoToAccount() {
        taskerPhotoSource = "user"
        taskerCustomPhotoAssetId = nil
        customPhotoAsset = nil
        photoStatusMessage = nil
    }

    private func uploadTaskerPhoto(_ draft: PhotoDraft) async {
        isUploadingTaskerPhoto = true
        photoStatusMessage = nil
        photoSheet = nil
        defer {
            isUploadingTaskerPhoto = false
        }

        do {
            let uploadedAsset = try await uploadPhotoDraft(draft, purpose: .taskerPhoto)
            customPhotoAsset = uploadedAsset
            taskerCustomPhotoAssetId = uploadedAsset.id
            taskerPhotoSource = "custom"
            photoStatusMessage = nil
        } catch {
            photoStatusMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
    }

    private func addPortfolioDraft(_ draft: PhotoDraft) {
        isUploadingPortfolio = true
        portfolioStatusMessage = nil
        defer { isUploadingPortfolio = false }

        let remainingSlots = max(0, 10 - portfolioPhotos.count)
        if remainingSlots > 0 {
            portfolioPhotos.append(.draft(draft))
        }
        if coverPhotoId == nil {
            coverPhotoId = portfolioPhotos.first?.id
        }
        portfolioStatusMessage = SubscriptionFeedbackMessage(tone: .success, text: "Portfolio updated.")
        presentNextPortfolioCrop()
    }

    private func uploadPhotoDraft(_ draft: PhotoDraft, purpose: PhotoPurpose) async throws -> RemoteImageAsset {
        let uploadService = ImageAssetUploadService(client: sessionStore.client)
        return try await uploadService.uploadImage(data: draft.data, purpose: purpose.convexPurpose)
    }

    private func presentTaskerCropIfNeeded(_ image: UIImage?) {
        guard let image else {
            photoSheet = nil
            return
        }
        photoSheet = .taskerCrop(PhotoCropInput(image: image, purpose: .taskerPhoto))
    }

    private func startPortfolioCropQueue(_ images: [UIImage]) {
        let remainingSlots = max(0, 10 - portfolioPhotos.count)
        portfolioCropQueue = Array(images.prefix(remainingSlots))
        presentNextPortfolioCrop()
    }

    private func presentNextPortfolioCrop() {
        guard !portfolioCropQueue.isEmpty else {
            photoSheet = nil
            return
        }
        let image = portfolioCropQueue.removeFirst()
        photoSheet = .portfolioCrop(PhotoCropInput(image: image, purpose: .taskerCategoryPortfolio))
    }

    private var selectedCategoryName: String {
        guard let selectedCategoryId,
              let selectedCategory = categories.first(where: { $0.id == selectedCategoryId }) else {
            return "Choose"
        }
        return selectedCategory.name
    }

    private var reviewRateSummary: String {
        if rateType == "hourly" {
            return formattedPrice(hourlyRate, suffix: "/hr")
        }

        return formattedPrice(fixedRate, suffix: " flat")
    }

    private func formattedPrice(_ value: String, suffix: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = Double(trimmed) ?? 0
        return "\(amount.formatted(.currency(code: "USD")))\(suffix)"
    }
}

private struct TaskerProfileManageView: View {
    private enum PhotoSheet: Identifiable {
        case camera
        case gallery
        case crop(PhotoCropInput)

        var id: String {
            switch self {
            case .camera:
                return "camera"
            case .gallery:
                return "gallery"
            case .crop(let input):
                return "crop-\(input.id)"
            }
        }
    }

    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    @Binding var profileDisplayName: String
    @Binding var profileWebsiteLinks: [String]
    @Binding var profileSocialLinks: [String]
    @Binding var addCategorySheet: Bool
    let categories: [Category]
    let existingCategoryIDs: Set<ConvexID>
    let onSaveProfile: (String, [String], [String]) async throws -> Void
    let onRemoveCategory: (ConvexID) async throws -> Void
    let onAddCategory: (TaskerCategoryDraft) -> Void
    let onUpdateCategory: (TaskerCategoryDraft) async throws -> Void

    @State private var selectedCategoryID: ConvexID?
    @State private var feedbackMessage: SubscriptionFeedbackMessage?
    @State private var isSavingProfile = false
    @State private var showsTaskerPhotoOptions = false
    @State private var photoSheet: PhotoSheet?
    @State private var pendingTaskerPhotoAsset: RemoteImageAsset?
    @State private var taskerPhotoStatusMessage: SubscriptionFeedbackMessage?
    @State private var isUpdatingTaskerPhoto = false

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brandBright)

            ScrollView {
                VStack(spacing: 18) {
                    PatchworkSurfaceCard {
                        VStack(alignment: .leading, spacing: 18) {
                            PatchworkSectionIntro(
                                eyebrow: "Tasker profile",
                                title: "Keep your listing sharp",
                                message: "Update your display name here. Edit each category to control the bio, pricing, and service radius seekers actually see."
                            )

                            TextField("Display name", text: $profileDisplayName)
                                .patchworkInputFieldStyle()
                                .accessibilityIdentifier("TaskerProfile.displayNameField")

                            TaskerLinksEditor(
                                title: "Websites",
                                placeholder: "https://example.com",
                                systemImage: "globe",
                                links: $profileWebsiteLinks,
                                accessibilityPrefix: "TaskerProfile.websiteLinks"
                            )

                            TaskerLinksEditor(
                                title: "Social",
                                placeholder: "@yourhandle or profile link",
                                systemImage: "at",
                                links: $profileSocialLinks,
                                accessibilityPrefix: "TaskerProfile.socialLinks"
                            )

                            taskerPublicProfilePreview
                            taskerPhotoSourceControls

                            if let feedbackMessage {
                                PatchworkInlineStatusBanner(tone: feedbackMessage.tone, text: feedbackMessage.text)
                                    .accessibilityIdentifier("TaskerProfile.statusBanner")
                            }

                            Button(isSavingProfile ? "Saving..." : "Save") {
                                Task { await saveProfile() }
                            }
                                .buttonStyle(PatchworkPrimaryButtonStyle())
                                .disabled(isSavingProfile || profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .accessibilityIdentifier("TaskerProfile.saveButton")
                        }
                    }

                    PatchworkSurfaceCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("My Categories")
                                .font(.patchworkCardTitle)
                                .foregroundStyle(PatchworkTheme.textPrimary)

                            Button {
                                addCategorySheet = true
                            } label: {
                                ProfileLinkRowLabel(title: "Add Category")
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "TaskerProfile.categoryLibraryLink"))

                            ForEach(appState.taskerProfile?.categories ?? []) { category in
                                Button {
                                    selectedCategoryID = category.categoryId
                                } label: {
                                    HStack {
                                        categoryCoverThumbnail(for: category)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(category.categoryName)
                                                .font(.patchworkBodyStrong)
                                                .foregroundStyle(PatchworkTheme.textPrimary)
                                            Text(summaryLabel(for: category))
                                                .font(.patchworkCaption)
                                                .foregroundStyle(PatchworkTheme.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(PatchworkTheme.textTertiary)
                                            .accessibilityHidden(true)
                                    }
                                    .padding(16)
                                    .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(PatchworkTheme.stroke, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("TaskerProfile.category.\(category.categoryId)")
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $addCategorySheet) {
            NavigationStack {
                AddCategorySheet(
                    categories: categories,
                    existingCategoryIDs: existingCategoryIDs,
                    onAdd: onAddCategory
                )
            }
            .patchworkSheetChrome()
        }
        .sheet(
            isPresented: Binding(
                get: { selectedCategoryID != nil && selectedCategory != nil },
                set: { isPresented in
                    if !isPresented {
                        selectedCategoryID = nil
                    }
                }
            )
        ) {
            if let category = selectedCategory {
                NavigationStack {
                    EditableTaskerCategorySheet(
                        category: category,
                        onSave: onUpdateCategory,
                        onRemove: {
                            try await onRemoveCategory(category.categoryId)
                        }
                    )
                }
                .patchworkSheetChrome()
            }
        }
        .onChange(of: profileDisplayName) { _, _ in
            if feedbackMessage?.tone == .success {
                feedbackMessage = nil
            }
        }
        .confirmationDialog("Tasker photo", isPresented: $showsTaskerPhotoOptions, titleVisibility: .visible) {
            if CameraCaptureView.isCameraAvailable {
                Button("Take Photo") {
                    photoSheet = .camera
                }
            }
            Button("Choose from Gallery") {
                photoSheet = .gallery
            }
            if effectiveTaskerPhotoSource == "custom" {
                Button("Use Account Photo", role: .destructive) {
                    Task { await setTaskerPhotoToUserSource() }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $photoSheet) { sheet in
            switch sheet {
            case .camera:
                CameraCaptureView { image in
                    presentTaskerCropIfNeeded(image)
                }
            case .gallery:
                GalleryPickerView(selectionLimit: 1) { images in
                    presentTaskerCropIfNeeded(images.first)
                }
            case .crop(let input):
                PhotoCropEditor(input: input) {
                    photoSheet = nil
                } onConfirm: { draft in
                    Task { await uploadTaskerPhoto(draft) }
                }
            }
        }
    }

    private var effectiveTaskerPhotoSource: String {
        appState.taskerProfile?.photoSource ?? "user"
    }

    private var displayedTaskerPhotoAsset: RemoteImageAsset? {
        pendingTaskerPhotoAsset ?? appState.taskerProfile?.photoImage ?? appState.currentUser?.photoImage
    }

    private var taskerPublicProfilePreview: some View {
        HStack(spacing: 12) {
            PatchworkRemoteImage(
                asset: displayedTaskerPhotoAsset,
                preferredVariant: .display,
                contentMode: .fill
            ) {
                ZStack {
                    PatchworkTheme.brandSoft
                    Image(systemName: "person.crop.circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(PatchworkTheme.brand)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Public profile preview")
                    .font(.patchworkBodyStrong)
                    .foregroundStyle(PatchworkTheme.textPrimary)
                Text("This avatar appears on your Discover card.")
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
    }

    private var taskerPhotoSourceControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tasker avatar controls")
                        .font(.patchworkBodyStrong)
                        .foregroundStyle(PatchworkTheme.textPrimary)
                    if effectiveTaskerPhotoSource != "custom" {
                        Text("Using account photo.")
                            .font(.patchworkCaption)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    if effectiveTaskerPhotoSource == "custom" {
                        Button {
                            Task { await setTaskerPhotoToUserSource() }
                        } label: {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(PatchworkTheme.brand)
                                .frame(width: 34, height: 34)
                                .background(PatchworkTheme.surface.opacity(0.94), in: Circle())
                                .overlay(
                                    Circle()
                                        .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isUpdatingTaskerPhoto)
                        .accessibilityIdentifier("TaskerProfile.taskerPhotoUseAccountButton")
                        .accessibilityLabel("Use account photo")
                    }

                    Button {
                        showsTaskerPhotoOptions = true
                    } label: {
                        Image(systemName: effectiveTaskerPhotoSource == "custom" ? "pencil" : "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(PatchworkTheme.brand)
                            .frame(width: 34, height: 34)
                            .background(PatchworkTheme.surface.opacity(0.94), in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isUpdatingTaskerPhoto)
                    .accessibilityIdentifier("TaskerProfile.taskerPhotoPicker")
                    .accessibilityLabel(effectiveTaskerPhotoSource == "custom" ? "Replace custom tasker photo" : "Upload custom tasker photo")
                }
            }

            if isUpdatingTaskerPhoto {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Updating tasker photo...")
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                }
            } else if let taskerPhotoStatusMessage {
                PatchworkInlineStatusBanner(tone: taskerPhotoStatusMessage.tone, text: taskerPhotoStatusMessage.text)
                    .accessibilityIdentifier("TaskerProfile.taskerPhotoStatusBanner")
            }
        }
        .padding(14)
        .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
    }

    private func setTaskerPhotoToUserSource() async {
        isUpdatingTaskerPhoto = true
        taskerPhotoStatusMessage = nil
        defer { isUpdatingTaskerPhoto = false }

        do {
            let updatedProfile = try await sessionStore.client.mutation(
                "taskers:setTaskerPhoto",
                args: ["photoSource": "user"]
            ) as TaskerProfileSelf
            appState.taskerProfile = updatedProfile
            pendingTaskerPhotoAsset = nil
            taskerPhotoStatusMessage = SubscriptionFeedbackMessage(tone: .success, text: "Tasker photo now uses your account photo.")
        } catch {
            taskerPhotoStatusMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
    }

    private func uploadTaskerPhoto(_ draft: PhotoDraft) async {
        isUpdatingTaskerPhoto = true
        taskerPhotoStatusMessage = nil
        photoSheet = nil
        defer { isUpdatingTaskerPhoto = false }

        do {
            let uploadedAsset = try await uploadPhotoDraft(draft, purpose: .taskerPhoto)
            pendingTaskerPhotoAsset = uploadedAsset
            let updatedProfile = try await sessionStore.client.mutation(
                "taskers:setTaskerPhoto",
                args: [
                    "photoSource": "custom",
                    "photoAssetId": uploadedAsset.id,
                ]
            ) as TaskerProfileSelf
            appState.taskerProfile = updatedProfile
            pendingTaskerPhotoAsset = nil
            taskerPhotoStatusMessage = nil
        } catch {
            taskerPhotoStatusMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
    }

    private func uploadPhotoDraft(_ draft: PhotoDraft, purpose: PhotoPurpose) async throws -> RemoteImageAsset {
        let uploadService = ImageAssetUploadService(client: sessionStore.client)
        return try await uploadService.uploadImage(data: draft.data, purpose: purpose.convexPurpose)
    }

    private func presentTaskerCropIfNeeded(_ image: UIImage?) {
        guard let image else {
            photoSheet = nil
            return
        }
        photoSheet = .crop(PhotoCropInput(image: image, purpose: .taskerPhoto))
    }

    private func categoryCoverThumbnail(for category: TaskerManagedCategory) -> some View {
        PatchworkRemoteImage(
            asset: category.coverImage ?? category.portfolioImages?.first,
            preferredVariant: .thumb,
            contentMode: .fill
        ) {
            ZStack {
                PatchworkTheme.brandSoft
                Image(systemName: "photo")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PatchworkTheme.brand)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
    }

    private var selectedCategory: TaskerManagedCategory? {
        guard let selectedCategoryID else {
            return nil
        }

        return appState.taskerProfile?.categories.first(where: { $0.categoryId == selectedCategoryID })
    }

    private func saveProfile() async {
        let trimmedDisplayName = profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDisplayName.isEmpty else {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: "Display name is required.")
            return
        }

        isSavingProfile = true
        feedbackMessage = nil
        defer { isSavingProfile = false }

        do {
            try await onSaveProfile(trimmedDisplayName, profileWebsiteLinks, profileSocialLinks)
            feedbackMessage = SubscriptionFeedbackMessage(tone: .success, text: "Tasker profile updated.")
        } catch {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
    }

    private func summaryLabel(for category: TaskerManagedCategory) -> String {
        let rateTypeLabel = category.rateType.capitalized
        let priceLabel: String
        if category.rateType == "hourly", let hourlyRate = category.hourlyRate {
            priceLabel = "$\((Double(hourlyRate) / 100).formatted(.number.precision(.fractionLength(2))))/hr"
        } else if let fixedRate = category.fixedRate {
            priceLabel = "$\((Double(fixedRate) / 100).formatted(.number.precision(.fractionLength(2))))"
        } else {
            priceLabel = "Rate unavailable"
        }

        return "\(rateTypeLabel) • \(priceLabel) • \(category.serviceRadius) km"
    }
}

private struct CategoryServiceDetailsSection: View {
    private enum FallbackField: Hashable {
        case bio
        case hourlyRate
        case fixedRate
    }

    private let maxBioLength = 500

    let title: String
    let eyebrow: String?
    let message: String?
    @Binding var bio: String
    @Binding var rateType: String
    @Binding var hourlyRate: String
    @Binding var fixedRate: String
    @Binding var serviceRadius: Int
    var focusedField: FocusState<TaskerCreateFocusField?>.Binding? = nil
    let accessibilityPrefix: String

    var body: some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 18) {
                if let message {
                    PatchworkSectionIntro(
                        eyebrow: eyebrow,
                        title: title,
                        message: message
                    )
                } else {
                    Text(title)
                        .font(.patchworkCardTitle)
                        .foregroundStyle(PatchworkTheme.textPrimary)
                }

                bioField

                Picker("Rate type", selection: $rateType) {
                    Text("Hourly").tag("hourly")
                    Text("Fixed").tag("fixed")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("\(accessibilityPrefix).rateTypePicker")

                if rateType == "hourly" {
                    hourlyRateField
                } else {
                    fixedRateField
                }

                radiusControl
            }
        }
    }

    @ViewBuilder
    private var bioField: some View {
        let field = TextEditor(text: $bio)
            .patchworkTextEditorStyle(minHeight: 110)
            .onChange(of: bio) { _, newValue in
                if newValue.count > maxBioLength {
                    bio = String(newValue.prefix(maxBioLength))
                }
            }
            .accessibilityIdentifier("\(accessibilityPrefix).bioField")

        if let focusedField {
            VStack(alignment: .leading, spacing: 8) {
                field
                    .focused(focusedField, equals: .bio)
                    .simultaneousGesture(TapGesture().onEnded {
                        focusedField.wrappedValue = .bio
                    })
                bioCount
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                field
                bioCount
            }
        }
    }

    @ViewBuilder
    private var hourlyRateField: some View {
        let field = priceField(
            placeholder: "Hourly rate",
            text: $hourlyRate,
            accessibilityIdentifier: "\(accessibilityPrefix).hourlyRateField"
        )

        if let focusedField {
            field
                .focused(focusedField, equals: .hourlyRate)
                .simultaneousGesture(TapGesture().onEnded {
                    focusedField.wrappedValue = .hourlyRate
                })
        } else {
            field
        }
    }

    @ViewBuilder
    private var fixedRateField: some View {
        let field = priceField(
            placeholder: "Fixed rate",
            text: $fixedRate,
            accessibilityIdentifier: "\(accessibilityPrefix).fixedRateField"
        )

        if let focusedField {
            field
                .focused(focusedField, equals: .fixedRate)
                .simultaneousGesture(TapGesture().onEnded {
                    focusedField.wrappedValue = .fixedRate
                })
        } else {
            field
        }
    }

    private var bioCount: some View {
        Text("\(bio.count)/\(maxBioLength)")
            .font(.patchworkCaption)
            .foregroundStyle(bio.count >= maxBioLength ? PatchworkTheme.warning : PatchworkTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityIdentifier("\(accessibilityPrefix).bioCount")
    }

    private var radiusControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Service radius")
                    .font(.patchworkBodyStrong)
                    .foregroundStyle(PatchworkTheme.textPrimary)
                Spacer()
                Text("\(serviceRadius) km")
                    .font(.patchworkBodyStrong)
                    .foregroundStyle(PatchworkTheme.brand)
                    .accessibilityIdentifier("\(accessibilityPrefix).radiusValue")
            }

            HStack(spacing: 12) {
                radiusStepButton(
                    systemName: "minus",
                    action: { serviceRadius = max(1, serviceRadius - 1) },
                    accessibilityIdentifier: "\(accessibilityPrefix).radiusDecrementButton"
                )

                Slider(
                    value: Binding(
                        get: { Double(serviceRadius) },
                        set: { serviceRadius = Int($0.rounded()) }
                    ),
                    in: 1 ... 250,
                    step: 1
                )
                .tint(PatchworkTheme.brand)
                .accessibilityLabel("Service radius")
                .accessibilityValue("\(serviceRadius) kilometers")
                .accessibilityIdentifier("\(accessibilityPrefix).radiusStepper")

                radiusStepButton(
                    systemName: "plus",
                    action: { serviceRadius = min(250, serviceRadius + 1) },
                    accessibilityIdentifier: "\(accessibilityPrefix).radiusIncrementButton"
                )
            }

            HStack {
                Text("1 km")
                Spacer()
                Text("250 km")
            }
            .font(.patchworkCaption)
            .foregroundStyle(PatchworkTheme.textSecondary)
        }
        .padding(16)
        .background(PatchworkTheme.brandSoft.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
        )
    }

    private func priceField(
        placeholder: String,
        text: Binding<String>,
        accessibilityIdentifier: String
    ) -> some View {
        HStack(spacing: 10) {
            Text("$")
                .font(.patchworkBodyStrong)
                .foregroundStyle(PatchworkTheme.brand)
                .accessibilityHidden(true)

            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.patchworkBody)
                .foregroundStyle(PatchworkTheme.textPrimary)
                .accessibilityIdentifier(accessibilityIdentifier)
        }
        .padding(.horizontal, 16)
        .frame(height: PatchworkMetrics.fieldHeight)
        .background(
            PatchworkTheme.surface,
            in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
    }

    private func radiusStepButton(
        systemName: String,
        action: @escaping () -> Void,
        accessibilityIdentifier: String
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.bold))
        }
        .buttonStyle(PatchworkIconButtonStyle(
            size: 36,
            foreground: PatchworkTheme.brand,
            fill: PatchworkTheme.surface,
            stroke: PatchworkTheme.strokeStrong
        ))
        .accessibilityLabel(systemName == "minus" ? "Decrease service radius" : "Increase service radius")
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct TaskerPortfolioPhotoImage<Placeholder: View>: View {
    let photo: TaskerPortfolioPhoto?
    let preferredVariant: PatchworkImageCache.VariantPreference
    let placeholder: () -> Placeholder

    init(
        photo: TaskerPortfolioPhoto?,
        preferredVariant: PatchworkImageCache.VariantPreference = .display,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.photo = photo
        self.preferredVariant = preferredVariant
        self.placeholder = placeholder
    }

    var body: some View {
        if let draft = photo?.localDraft {
            Image(uiImage: draft.previewImage)
                .resizable()
                .scaledToFill()
        } else if let asset = photo?.remoteAsset {
            PatchworkRemoteImage(
                asset: asset,
                preferredVariant: preferredVariant,
                contentMode: .fill
            ) {
                placeholder()
            }
        } else {
            placeholder()
        }
    }
}

private struct TaskerCategoryPortfolioEditor: View {
    @Binding var portfolioPhotos: [TaskerPortfolioPhoto]
    @Binding var coverPhotoId: String?
    let isUploading: Bool
    let statusMessage: SubscriptionFeedbackMessage?
    let accessibilityPrefix: String
    let onAddPhotos: () -> Void

    @State private var selectedPhotoId: String?

    private let maxAssets = 10

    var body: some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Portfolio")
                        .font(.patchworkCardTitle)
                        .foregroundStyle(PatchworkTheme.textPrimary)
                    Spacer()
                    Text("\(portfolioPhotos.count)/\(maxAssets)")
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                }

                Button(action: onAddPhotos) {
                    Label(
                        portfolioPhotos.isEmpty ? "Add portfolio photos" : "Add more photos",
                        systemImage: "photo.on.rectangle"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PatchworkSecondaryButtonStyle())
                .disabled(isUploading || portfolioPhotos.count >= maxAssets)
                .accessibilityIdentifier("\(accessibilityPrefix).picker")

                if portfolioPhotos.isEmpty {
                    Text("Add up to 10 photos. Choose one 4:3 image as the cover.")
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                } else if let activePhoto {
                    VStack(alignment: .leading, spacing: 12) {
                        TaskerPortfolioPhotoImage(photo: activePhoto, preferredVariant: .display) {
                            PatchworkTheme.brandSoft
                        }
                        .aspectRatio(4.0 / 3.0, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(activePhoto.id == activeCoverPhotoId ? PatchworkTheme.brand : PatchworkTheme.stroke, lineWidth: activePhoto.id == activeCoverPhotoId ? 2 : 1)
                        )
                        .accessibilityLabel(activePhoto.id == activeCoverPhotoId ? "Selected cover portfolio photo" : "Selected portfolio photo")

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(portfolioPhotos) { photo in
                                    Button {
                                        selectedPhotoId = photo.id
                                    } label: {
                                        TaskerPortfolioThumbnail(
                                            photo: photo,
                                            isSelected: photo.id == activePhoto.id,
                                            isCover: photo.id == activeCoverPhotoId
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(photo.id == activeCoverPhotoId ? "Cover portfolio photo" : "Portfolio photo")
                                    .accessibilityIdentifier("\(accessibilityPrefix).thumbnail.\(photo.id)")
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        portfolioActions(for: activePhoto)
                    }
                }

                if isUploading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Uploading portfolio images...")
                            .font(.patchworkCaption)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                    }
                } else if let statusMessage {
                    PatchworkInlineStatusBanner(tone: statusMessage.tone, text: statusMessage.text)
                        .accessibilityIdentifier("\(accessibilityPrefix).status")
                }
            }
        }
    }

    private var activeCoverPhotoId: String? {
        coverPhotoId ?? portfolioPhotos.first?.id
    }

    private var activePhoto: TaskerPortfolioPhoto? {
        if let selectedPhotoId,
           let selectedPhoto = portfolioPhotos.first(where: { $0.id == selectedPhotoId }) {
            return selectedPhoto
        }
        if let activeCoverPhotoId,
           let coverPhoto = portfolioPhotos.first(where: { $0.id == activeCoverPhotoId }) {
            return coverPhoto
        }
        return portfolioPhotos.first
    }

    @ViewBuilder
    private func portfolioActions(for photo: TaskerPortfolioPhoto) -> some View {
        HStack(spacing: 10) {
            portfolioActionButton(
                systemImage: "chevron.left",
                label: "Move photo left",
                accessibilityIdentifier: "\(accessibilityPrefix).moveUp.\(photo.id)",
                isDisabled: indexForPhoto(photo) == 0
            ) {
                movePhoto(photo, direction: -1)
            }

            portfolioActionButton(
                systemImage: "chevron.right",
                label: "Move photo right",
                accessibilityIdentifier: "\(accessibilityPrefix).moveDown.\(photo.id)",
                isDisabled: indexForPhoto(photo) == portfolioPhotos.count - 1
            ) {
                movePhoto(photo, direction: 1)
            }

            portfolioActionButton(
                systemImage: photo.id == activeCoverPhotoId ? "checkmark.seal.fill" : "seal",
                label: photo.id == activeCoverPhotoId ? "Cover photo" : "Set as cover photo",
                accessibilityIdentifier: "\(accessibilityPrefix).setCover.\(photo.id)",
                foreground: photo.id == activeCoverPhotoId ? PatchworkTheme.brand : PatchworkTheme.textPrimary,
                stroke: photo.id == activeCoverPhotoId ? PatchworkTheme.brand.opacity(0.42) : PatchworkTheme.strokeStrong
            ) {
                coverPhotoId = photo.id
            }

            portfolioActionButton(
                systemImage: "trash",
                label: "Remove portfolio photo",
                accessibilityIdentifier: "\(accessibilityPrefix).remove.\(photo.id)",
                foreground: PatchworkTheme.danger,
                stroke: PatchworkTheme.danger.opacity(0.26),
                fill: PatchworkTheme.danger.opacity(0.10)
            ) {
                removePhoto(photo)
            }
        }
    }

    private func portfolioActionButton(
        systemImage: String,
        label: String,
        accessibilityIdentifier: String,
        foreground: Color = PatchworkTheme.textPrimary,
        stroke: Color = PatchworkTheme.strokeStrong,
        fill: Color = PatchworkTheme.surface,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    fill.opacity(0.92),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .accessibilityLabel(label)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func indexForPhoto(_ photo: TaskerPortfolioPhoto) -> Int {
        portfolioPhotos.firstIndex(where: { $0.id == photo.id }) ?? 0
    }

    private func movePhoto(_ photo: TaskerPortfolioPhoto, direction: Int) {
        guard let index = portfolioPhotos.firstIndex(where: { $0.id == photo.id }) else {
            return
        }
        let newIndex = index + direction
        guard portfolioPhotos.indices.contains(newIndex) else {
            return
        }
        portfolioPhotos.swapAt(index, newIndex)
        selectedPhotoId = photo.id
        if coverPhotoId == nil {
            coverPhotoId = portfolioPhotos.first?.id
        }
    }

    private func removePhoto(_ photo: TaskerPortfolioPhoto) {
        portfolioPhotos.removeAll { $0.id == photo.id }
        if coverPhotoId == photo.id {
            coverPhotoId = portfolioPhotos.first?.id
        }
        if selectedPhotoId == photo.id {
            selectedPhotoId = activeCoverPhotoId ?? portfolioPhotos.first?.id
        }
    }
}

private struct TaskerPortfolioThumbnail: View {
    let photo: TaskerPortfolioPhoto
    let isSelected: Bool
    let isCover: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TaskerPortfolioPhotoImage(photo: photo, preferredVariant: .thumb) {
                PatchworkTheme.brandSoft
            }
            .aspectRatio(4.0 / 3.0, contentMode: .fill)
            .frame(width: 78, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? PatchworkTheme.brand : PatchworkTheme.stroke, lineWidth: isSelected ? 2 : 1)
            )

            if isCover {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PatchworkTheme.brand)
                    .padding(5)
                    .background(PatchworkTheme.surface.opacity(0.92), in: Circle())
                    .padding(4)
            }
        }
    }
}

private struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss

    let categories: [Category]
    let existingCategoryIDs: Set<ConvexID>
    let onAdd: (TaskerCategoryDraft) -> Void

    @State private var selectedCategoryId: ConvexID?
    @State private var categoryBio = ""
    @State private var rateType = "hourly"
    @State private var hourlyRate = ""
    @State private var fixedRate = ""
    @State private var serviceRadius = 25
    @State private var portfolioPhotos: [TaskerPortfolioPhoto] = []
    @State private var coverPhotoId: String?
    @State private var showsPortfolioPhotoOptions = false
    @State private var portfolioPhotoSheet: PortfolioPhotoSheet?
    @State private var portfolioCropQueue: [UIImage] = []
    @State private var isUploadingPortfolio = false
    @State private var portfolioStatusMessage: SubscriptionFeedbackMessage?

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    PatchworkKeyboard.dismiss()
                }

            PatchworkBackdrop(tint: PatchworkTheme.accent)

            ScrollView {
                VStack(spacing: 18) {
                    PatchworkTopBar(title: "Add Category", onBack: { dismiss() })
                        .accessibilityIdentifier("AddCategorySheet.cancelButton")

                    PatchworkSectionIntro(
                        eyebrow: "Tasker profile",
                        title: "Add another service",
                        message: "Expand your listing with a new category, clear pricing, and service radius."
                    )

                    NavigationLink {
                        CategoriesView(
                            title: "Select Category",
                            selectedCategoryID: selectedCategoryId,
                            excludedCategoryIDs: existingCategoryIDs,
                            dismissOnSelect: true,
                            onSelect: { category in
                                selectedCategoryId = category.id
                            }
                        )
                    } label: {
                        HStack {
                            Text("Category")
                                .font(.patchworkCaption)
                                .foregroundStyle(PatchworkTheme.textSecondary)
                            Spacer()
                            Text(selectedCategoryName)
                                .font(.patchworkBody)
                                .foregroundStyle(PatchworkTheme.textPrimary)
                        }
                        .padding(16)
                        .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(PatchworkTheme.stroke, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("AddCategorySheet.categoryPicker")

                    CategoryServiceDetailsSection(
                        title: "Details",
                        eyebrow: nil,
                        message: nil,
                        bio: $categoryBio,
                        rateType: $rateType,
                        hourlyRate: $hourlyRate,
                        fixedRate: $fixedRate,
                        serviceRadius: $serviceRadius,
                        accessibilityPrefix: "AddCategorySheet"
                    )

                    TaskerCategoryPortfolioEditor(
                        portfolioPhotos: $portfolioPhotos,
                        coverPhotoId: $coverPhotoId,
                        isUploading: isUploadingPortfolio,
                        statusMessage: portfolioStatusMessage,
                        accessibilityPrefix: "AddCategorySheet.portfolio",
                        onAddPhotos: { showsPortfolioPhotoOptions = true }
                    )

                    Button("Add") {
                        guard let selectedCategoryId else { return }
                        onAdd(
                            TaskerCategoryDraft(
                                categoryId: selectedCategoryId,
                                categoryBio: categoryBio,
                                rateType: rateType,
                                hourlyRate: hourlyRate,
                                fixedRate: fixedRate,
                                serviceRadius: serviceRadius,
                                portfolioPhotos: portfolioPhotos,
                                coverPhotoId: coverPhotoId ?? portfolioPhotos.first?.id
                            )
                        )
                    }
                    .buttonStyle(PatchworkPrimaryButtonStyle())
                    .disabled(!canSubmit || isUploadingPortfolio)
                    .accessibilityIdentifier("AddCategorySheet.addButton")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
        .patchworkKeyboardDismissToolbar()
        .onAppear {
            resetSelectionIfNeeded()
        }
        .onChange(of: existingCategoryIDs) { _, _ in
            resetSelectionIfNeeded()
        }
        .confirmationDialog("Portfolio photos", isPresented: $showsPortfolioPhotoOptions, titleVisibility: .visible) {
            if CameraCaptureView.isCameraAvailable {
                Button("Take Photo") {
                    portfolioPhotoSheet = .camera
                }
            }
            Button("Choose from Gallery") {
                portfolioPhotoSheet = .gallery
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $portfolioPhotoSheet) { sheet in
            switch sheet {
            case .camera:
                CameraCaptureView { image in
                    startPortfolioCropQueue(image.map { [$0] } ?? [])
                }
            case .gallery:
                GalleryPickerView(selectionLimit: max(1, 10 - portfolioPhotos.count)) { images in
                    startPortfolioCropQueue(images)
                }
            case .crop(let input):
                PhotoCropEditor(input: input) {
                    portfolioCropQueue.removeAll()
                    portfolioPhotoSheet = nil
                } onConfirm: { draft in
                    addPortfolioDraft(draft)
                }
            }
        }
    }

    private var availableCategories: [Category] {
        categories.filter { !existingCategoryIDs.contains($0.id) }
    }

    private var hasValidSelection: Bool {
        guard let selectedCategoryId else {
            return false
        }
        return availableCategories.contains(where: { $0.id == selectedCategoryId })
    }

    private var selectedCategoryName: String {
        guard let selectedCategoryId,
              let selectedCategory = availableCategories.first(where: { $0.id == selectedCategoryId }) else {
            return "Choose"
        }
        return selectedCategory.name
    }

    private var canSubmit: Bool {
        guard hasValidSelection,
              !categoryBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        if rateType == "hourly" {
            return (Double(hourlyRate) ?? 0) > 0
        }
        return (Double(fixedRate) ?? 0) > 0
    }

    private func resetSelectionIfNeeded() {
        guard let selectedCategoryId else {
            return
        }

        if !availableCategories.contains(where: { $0.id == selectedCategoryId }) {
            self.selectedCategoryId = nil
        }
    }

    private func addPortfolioDraft(_ draft: PhotoDraft) {
        isUploadingPortfolio = true
        portfolioStatusMessage = nil
        defer { isUploadingPortfolio = false }

        let remainingSlots = max(0, 10 - portfolioPhotos.count)
        if remainingSlots > 0 {
            portfolioPhotos.append(.draft(draft))
        }
        if coverPhotoId == nil {
            coverPhotoId = portfolioPhotos.first?.id
        }
        portfolioStatusMessage = SubscriptionFeedbackMessage(tone: .success, text: "Portfolio updated.")
        presentNextPortfolioCrop()
    }

    private func startPortfolioCropQueue(_ images: [UIImage]) {
        let remainingSlots = max(0, 10 - portfolioPhotos.count)
        portfolioCropQueue = Array(images.prefix(remainingSlots))
        presentNextPortfolioCrop()
    }

    private func presentNextPortfolioCrop() {
        guard !portfolioCropQueue.isEmpty else {
            portfolioPhotoSheet = nil
            return
        }
        let image = portfolioCropQueue.removeFirst()
        portfolioPhotoSheet = .crop(PhotoCropInput(image: image, purpose: .taskerCategoryPortfolio))
    }
}

private struct EditableTaskerCategorySheet: View {
    @Environment(\.dismiss) private var dismiss

    let category: TaskerManagedCategory
    let onSave: (TaskerCategoryDraft) async throws -> Void
    let onRemove: () async throws -> Void

    @State private var categoryBio: String
    @State private var rateType: String
    @State private var hourlyRate: String
    @State private var fixedRate: String
    @State private var serviceRadius: Int
    @State private var portfolioPhotos: [TaskerPortfolioPhoto]
    @State private var coverPhotoId: String?
    @State private var feedbackMessage: SubscriptionFeedbackMessage?
    @State private var portfolioStatusMessage: SubscriptionFeedbackMessage?
    @State private var isSaving = false
    @State private var isRemoving = false
    @State private var isUploadingPortfolio = false
    @State private var showsPortfolioPhotoOptions = false
    @State private var portfolioPhotoSheet: PortfolioPhotoSheet?
    @State private var portfolioCropQueue: [UIImage] = []
    @State private var showsRemoveConfirmation = false

    init(
        category: TaskerManagedCategory,
        onSave: @escaping (TaskerCategoryDraft) async throws -> Void,
        onRemove: @escaping () async throws -> Void
    ) {
        self.category = category
        self.onSave = onSave
        self.onRemove = onRemove

        let draft = TaskerCategoryDraft(category: category)
        _categoryBio = State(initialValue: draft.categoryBio)
        _rateType = State(initialValue: draft.rateType)
        _hourlyRate = State(initialValue: draft.hourlyRate)
        _fixedRate = State(initialValue: draft.fixedRate)
        _serviceRadius = State(initialValue: draft.serviceRadius)
        _portfolioPhotos = State(initialValue: draft.portfolioPhotos)
        _coverPhotoId = State(initialValue: draft.coverPhotoId)
    }

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    PatchworkKeyboard.dismiss()
                }

            PatchworkBackdrop(tint: PatchworkTheme.accent)

            ScrollView {
                VStack(spacing: 18) {
                    PatchworkTopBar(title: category.categoryName, onBack: { dismiss() })
                        .accessibilityIdentifier("TaskerProfile.categoryCloseButton")

                    if let feedbackMessage {
                        PatchworkInlineStatusBanner(tone: feedbackMessage.tone, text: feedbackMessage.text)
                            .accessibilityIdentifier("TaskerProfile.categoryStatusBanner")
                    }

                    CategoryServiceDetailsSection(
                        title: "Public listing details",
                        eyebrow: "Category",
                        message: "This bio, rate, and radius drive what seekers see first for this service.",
                        bio: $categoryBio,
                        rateType: $rateType,
                        hourlyRate: $hourlyRate,
                        fixedRate: $fixedRate,
                        serviceRadius: $serviceRadius,
                        accessibilityPrefix: "TaskerProfileCategorySheet"
                    )

                    TaskerCategoryPortfolioEditor(
                        portfolioPhotos: $portfolioPhotos,
                        coverPhotoId: $coverPhotoId,
                        isUploading: isUploadingPortfolio,
                        statusMessage: portfolioStatusMessage,
                        accessibilityPrefix: "TaskerProfileCategorySheet.portfolio",
                        onAddPhotos: { showsPortfolioPhotoOptions = true }
                    )

                    PatchworkSurfaceCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Performance")
                                .font(.patchworkCardTitle)
                                .foregroundStyle(PatchworkTheme.textPrimary)
                            detailRow("Rating", value: ratingLabel)
                            detailRow("Reviews", value: countLabel(category.reviewCount))
                            detailRow("Completed Jobs", value: countLabel(category.completedJobs))
                        }
                    }

                    Button(isSaving ? "Saving..." : "Save Changes") {
                        Task { await saveChanges() }
                    }
                    .buttonStyle(PatchworkPrimaryButtonStyle())
                    .disabled(isSaving || isRemoving || isUploadingPortfolio || !canSubmit)
                    .accessibilityIdentifier("TaskerProfile.categorySaveButton")

                    Button("Remove Category", role: .destructive) {
                        showsRemoveConfirmation = true
                    }
                    .buttonStyle(PatchworkDestructiveButtonStyle())
                    .disabled(isSaving || isRemoving)
                    .accessibilityIdentifier("TaskerProfile.removeCategoryButton")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
        .patchworkKeyboardDismissToolbar()
        .confirmationDialog(
            "Remove \(category.categoryName)?",
            isPresented: $showsRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Category", role: .destructive) {
                Task { await removeCategory() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the service from your public tasker profile.")
        }
        .confirmationDialog("Portfolio photos", isPresented: $showsPortfolioPhotoOptions, titleVisibility: .visible) {
            if CameraCaptureView.isCameraAvailable {
                Button("Take Photo") {
                    portfolioPhotoSheet = .camera
                }
            }
            Button("Choose from Gallery") {
                portfolioPhotoSheet = .gallery
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $portfolioPhotoSheet) { sheet in
            switch sheet {
            case .camera:
                CameraCaptureView { image in
                    startPortfolioCropQueue(image.map { [$0] } ?? [])
                }
            case .gallery:
                GalleryPickerView(selectionLimit: max(1, 10 - portfolioPhotos.count)) { images in
                    startPortfolioCropQueue(images)
                }
            case .crop(let input):
                PhotoCropEditor(input: input) {
                    portfolioCropQueue.removeAll()
                    portfolioPhotoSheet = nil
                } onConfirm: { draft in
                    addPortfolioDraft(draft)
                }
            }
        }
    }

    private var canSubmit: Bool {
        guard !categoryBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        if rateType == "hourly" {
            return (Double(hourlyRate) ?? 0) > 0
        }
        return (Double(fixedRate) ?? 0) > 0
    }

    private func saveChanges() async {
        guard canSubmit else {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: "Enter a bio, price, and service radius before saving.")
            return
        }

        isSaving = true
        feedbackMessage = nil
        defer { isSaving = false }

        do {
            try await onSave(
                TaskerCategoryDraft(
                    categoryId: category.categoryId,
                    categoryBio: categoryBio.trimmingCharacters(in: .whitespacesAndNewlines),
                    rateType: rateType,
                    hourlyRate: hourlyRate.trimmingCharacters(in: .whitespacesAndNewlines),
                    fixedRate: fixedRate.trimmingCharacters(in: .whitespacesAndNewlines),
                    serviceRadius: serviceRadius,
                    portfolioPhotos: portfolioPhotos,
                    coverPhotoId: coverPhotoId ?? portfolioPhotos.first?.id
                )
            )
            dismiss()
        } catch {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
    }

    private func removeCategory() async {
        isRemoving = true
        feedbackMessage = nil
        defer { isRemoving = false }

        do {
            try await onRemove()
            dismiss()
        } catch {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
    }

    private func addPortfolioDraft(_ draft: PhotoDraft) {
        isUploadingPortfolio = true
        portfolioStatusMessage = nil
        defer { isUploadingPortfolio = false }

        let remainingSlots = max(0, 10 - portfolioPhotos.count)
        if remainingSlots > 0 {
            portfolioPhotos.append(.draft(draft))
        }
        if coverPhotoId == nil {
            coverPhotoId = portfolioPhotos.first?.id
        }
        portfolioStatusMessage = SubscriptionFeedbackMessage(tone: .success, text: "Portfolio updated.")
        presentNextPortfolioCrop()
    }

    private func startPortfolioCropQueue(_ images: [UIImage]) {
        let remainingSlots = max(0, 10 - portfolioPhotos.count)
        portfolioCropQueue = Array(images.prefix(remainingSlots))
        presentNextPortfolioCrop()
    }

    private func presentNextPortfolioCrop() {
        guard !portfolioCropQueue.isEmpty else {
            portfolioPhotoSheet = nil
            return
        }
        let image = portfolioCropQueue.removeFirst()
        portfolioPhotoSheet = .crop(PhotoCropInput(image: image, purpose: .taskerCategoryPortfolio))
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.patchworkBodyStrong)
                .foregroundStyle(PatchworkTheme.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }

    private var ratingLabel: String {
        guard let rating = category.rating else { return "Not rated" }
        return rating.formatted(.number.precision(.fractionLength(1)))
    }

    private func countLabel(_ value: Int?) -> String {
        guard let value else { return "Unavailable" }
        return value.formatted()
    }
}

private struct StepHeader: View {
    let currentStep: Int
    let totalSteps: Int

    init(currentStep: Int, totalSteps: Int = 3) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(1 ... max(totalSteps, 1), id: \.self) { value in
                Circle()
                    .fill(value <= currentStep ? PatchworkTheme.brand : PatchworkTheme.stroke)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text(value < currentStep ? "\u{2713}" : "\(value)")
                            .font(.caption.bold())
                            .foregroundStyle(value <= currentStep ? Color.white : PatchworkTheme.textSecondary)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
