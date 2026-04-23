import SafariServices
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

private struct ProfileAccountSection: View {
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

    let user: CurrentUser?
    let taskerProfile: TaskerProfileSelf?
    let onOpenMenu: () -> Void

    @State private var showsPhotoOptions = false
    @State private var photoSheet: PhotoSheet?
    @State private var pendingPreviewImage: UIImage?
    @State private var pendingPhotoAsset: RemoteImageAsset?
    @State private var isUploadingPhoto = false
    @State private var photoStatusMessage: SubscriptionFeedbackMessage?

    var body: some View {
        PatchworkSurfaceCard {
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    ProfileMenuButton(action: onOpenMenu)
                }

                avatar
                profilePhotoControls

                VStack(spacing: 8) {
                    Text(user?.name ?? "Signed in")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(PatchworkTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Label(locationLabel, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(PatchworkTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 10) {
                    if user?.roles?.isSeeker == true {
                        roleBadge(
                            "Seeker",
                            foreground: PatchworkTheme.success,
                            background: PatchworkTheme.success.opacity(0.14),
                            stroke: PatchworkTheme.success.opacity(0.4),
                            accessibilityIdentifier: "Profile.seekerPill"
                        )
                    }
                    taskerRoleBadge
                }
                .frame(maxWidth: .infinity)

                profileStatsRow
            }
            .frame(maxWidth: .infinity)
        }
        .confirmationDialog("Profile photo", isPresented: $showsPhotoOptions, titleVisibility: .visible) {
            if CameraCaptureView.isCameraAvailable {
                Button("Take Photo") {
                    photoSheet = .camera
                }
            }
            Button("Choose from Gallery") {
                photoSheet = .gallery
            }
            if hasProfilePhoto {
                Button("Remove Photo", role: .destructive) {
                    Task { await removeProfilePhoto() }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $photoSheet) { sheet in
            switch sheet {
            case .camera:
                CameraCaptureView { image in
                    presentCropIfNeeded(image)
                }
            case .gallery:
                GalleryPickerView(selectionLimit: 1) { images in
                    presentCropIfNeeded(images.first)
                }
            case .crop(let input):
                PhotoCropEditor(input: input) {
                    photoSheet = nil
                } onConfirm: { draft in
                    Task { await uploadProfilePhoto(draft) }
                }
            }
        }
    }

    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            AvatarPhotoControl(
                localImage: pendingPreviewImage,
                remoteAsset: displayedPhotoAsset,
                size: 108,
                isBusy: isUploadingPhoto,
                accessibilityIdentifier: "Profile.photoPicker",
                action: { showsPhotoOptions = true }
            ) {
                avatarFallback
            }
            .overlay(
                Circle()
                    .stroke(PatchworkTheme.brand.opacity(0.85), lineWidth: 5)
                    .padding(4)
            )

            if taskerProfile?.verified == true {
                ZStack {
                    Circle()
                        .fill(PatchworkTheme.brand)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 32, height: 32)
                .offset(x: 4, y: 4)
            }
        }
    }

    private var avatarFallback: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [PatchworkTheme.brandSoft, PatchworkTheme.surfaceMuted],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(initial)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(PatchworkTheme.brand)
        }
    }

    private var displayedPhotoAsset: RemoteImageAsset? {
        pendingPhotoAsset ?? user?.photoImage
    }

    private var hasProfilePhoto: Bool {
        user?.photoImage != nil || pendingPhotoAsset != nil
    }

    private var profilePhotoControls: some View {
        VStack(spacing: 10) {
            if isUploadingPhoto {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(PatchworkTheme.brand)
                    Text("Uploading photo...")
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let photoStatusMessage {
                PatchworkInlineStatusBanner(tone: photoStatusMessage.tone, text: photoStatusMessage.text)
                    .accessibilityIdentifier("Profile.photoStatusBanner")
            }
        }
    }

    private func uploadProfilePhoto(_ draft: PhotoDraft) async {
        isUploadingPhoto = true
        photoStatusMessage = nil
        pendingPreviewImage = draft.previewImage
        photoSheet = nil
        defer {
            isUploadingPhoto = false
        }

        do {
            let uploadedAsset = try await uploadPhotoDraft(draft, purpose: .userPhoto)
            pendingPhotoAsset = uploadedAsset
            let updatedUser = try await sessionStore.client.mutation(
                "users:updateProfilePhoto",
                args: ["photoAssetId": uploadedAsset.id]
            ) as CurrentUser
            appState.currentUser = updatedUser
            pendingPreviewImage = nil
            pendingPhotoAsset = nil
            photoStatusMessage = SubscriptionFeedbackMessage(tone: .success, text: "Profile photo updated.")
        } catch {
            photoStatusMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
    }

    private func removeProfilePhoto() async {
        isUploadingPhoto = true
        photoStatusMessage = nil
        defer { isUploadingPhoto = false }

        do {
            let updatedUser = try await sessionStore.client.mutation(
                "users:updateProfilePhoto",
                args: ["photoAssetId": NSNull()]
            ) as CurrentUser
            appState.currentUser = updatedUser
            pendingPreviewImage = nil
            pendingPhotoAsset = nil
            photoStatusMessage = SubscriptionFeedbackMessage(tone: .success, text: "Profile photo removed.")
        } catch {
            photoStatusMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
    }

    private func uploadPhotoDraft(_ draft: PhotoDraft, purpose: PhotoPurpose) async throws -> RemoteImageAsset {
        let uploadService = ImageAssetUploadService(client: sessionStore.client)
        return try await uploadService.uploadImage(data: draft.data, purpose: purpose.convexPurpose)
    }

    private func presentCropIfNeeded(_ image: UIImage?) {
        guard let image else {
            photoSheet = nil
            return
        }
        photoSheet = .crop(PhotoCropInput(image: image, purpose: .userPhoto))
    }

    private func roleBadge(
        _ title: String,
        foreground: Color,
        background: Color,
        stroke: Color,
        accessibilityIdentifier: String
    ) -> some View {
        Text(title)
            .font(.patchworkBodyStrong)
            .foregroundStyle(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(background, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(stroke, lineWidth: 1)
            )
            .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var taskerRoleBadge: some View {
        let style: (foreground: Color, background: Color, stroke: Color) = {
            guard let taskerProfile else {
                return (
                    PatchworkTheme.textSecondary,
                    PatchworkTheme.surfaceMuted,
                    PatchworkTheme.stroke
                )
            }

            guard taskerProfile.hasActiveSubscription == true else {
                return (
                    PatchworkTheme.textSecondary,
                    PatchworkTheme.surfaceMuted,
                    PatchworkTheme.stroke
                )
            }

            if taskerProfile.ghostMode == true {
                return (
                    PatchworkTheme.brand,
                    PatchworkTheme.brandSoft.opacity(0.95),
                    PatchworkTheme.strokeStrong
                )
            }

            return (
                PatchworkTheme.success,
                PatchworkTheme.success.opacity(0.14),
                PatchworkTheme.success.opacity(0.4)
            )
        }()

        return roleBadge(
            "Tasker",
            foreground: style.foreground,
            background: style.background,
            stroke: style.stroke,
            accessibilityIdentifier: "Profile.taskerPill"
        )
    }

    private var profileStatsRow: some View {
        HStack(spacing: 0) {
            statColumn(
                title: "Rating",
                value: ratingValue,
                icon: "star.fill",
                tint: PatchworkTheme.ratingStar,
                isUnlocked: taskerProfile != nil
            )

            Rectangle()
                .fill(PatchworkTheme.stroke)
                .frame(width: 1)
                .padding(.vertical, 8)
                .padding(.horizontal, 18)

            statColumn(
                title: "Completed jobs",
                value: completedJobsValue,
                icon: "checkmark.circle",
                tint: PatchworkTheme.brand,
                isUnlocked: taskerProfile != nil
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [
                    PatchworkTheme.brandSoft.opacity(0.42),
                    PatchworkTheme.surfaceMuted
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func statColumn(
        title: String,
        value: String,
        icon: String,
        tint: Color,
        isUnlocked: Bool
    ) -> some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                }

            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(PatchworkTheme.textPrimary)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(PatchworkTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(isUnlocked ? 1 : 0.45)
        .overlay(alignment: .topTrailing) {
            if !isUnlocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PatchworkTheme.brand)
                    .frame(width: 28, height: 28)
                    .background(PatchworkTheme.surface.opacity(0.96), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(PatchworkTheme.stroke, lineWidth: 1)
                    )
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("\(title): \(value)")
        .accessibilityValue(isUnlocked ? "Unlocked" : "Locked")
    }

    private var ratingValue: String {
        guard let rating = taskerProfile?.rating else {
            return "--"
        }
        return rating.formatted(.number.precision(.fractionLength(1)))
    }

    private var completedJobsValue: String {
        guard let completedJobs = taskerProfile?.completedJobs else {
            return "--"
        }
        return completedJobs.formatted()
    }

    private var locationLabel: String {
        let city = user?.location?.city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let province = user?.location?.province?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if city.isEmpty, province.isEmpty {
            return "Location not set"
        }
        if city.isEmpty {
            return province
        }
        if province.isEmpty {
            return city
        }
        return "\(city), \(province)"
    }

    private var initial: String {
        String((user?.name ?? "?").prefix(1)).uppercased()
    }
}

private struct ProfileMenuButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Menu", systemImage: "line.3.horizontal")
                .labelStyle(.iconOnly)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PatchworkTheme.brand)
                .frame(width: 44, height: 44)
                .background(PatchworkTheme.brandSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PatchworkTheme.strokeStrong, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open settings menu")
        .accessibilityIdentifier("Profile.menuButton")
    }
}

private struct ProfileTaskerSection: View {
    @Environment(AppState.self) private var appState
    @Environment(RevenueCatManager.self) private var revenueCatManager
    @Environment(SessionStore.self) private var sessionStore

    let userName: String?
    let taskerProfile: TaskerProfileSelf?

    @State private var ghostModeValue = false
    @State private var isUpdating = false
    @State private var feedbackMessage: SubscriptionFeedbackMessage?
    @State private var isShowingSubscriptions = false
    @State private var didAutoPresentBillingPreview = false

    var body: some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tasker Workspace")
                    .font(.patchworkCardTitle)
                    .foregroundStyle(PatchworkTheme.textPrimary)

                if let taskerProfile {
                    if taskerProfile.displayName != userName {
                        Text("Listed as: \(taskerProfile.displayName)")
                            .font(.patchworkCaption)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                    }

                    accessSummaryCard(taskerProfile)
                    discoverabilityControls(for: taskerProfile)
                } else {
                    Text("Finish tasker onboarding to manage your profile, availability, and discoverability.")
                        .font(.patchworkBody)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                NavigationLink {
                    TaskerOnboardingView()
                } label: {
                    ProfileLinkRowLabel(title: taskerProfile == nil ? "Complete Tasker Setup" : "Manage Tasker Profile")
                }
                .buttonStyle(.plain)
                .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "Profile.taskerOnboardingLink"))

                if let taskerProfile {
                    let billingTitle = effectiveHasActiveAccess(for: taskerProfile)
                        ? "Billing & access"
                        : "Unlock tasker mode"

                    Button {
                        isShowingSubscriptions = true
                    } label: {
                        ProfileLinkRowLabel(title: billingTitle)
                    }
                    .buttonStyle(.plain)
                    .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "Profile.visibilitySubscriptionLink"))
                }
            }
        }
        .task(id: taskerGhostModeRefreshKey) {
            ghostModeValue = effectiveGhostMode(for: taskerProfile)
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("PATCHWORK_UI_TASKER_BILLING_PREVIEW_UNPAID"),
                  !didAutoPresentBillingPreview else {
                return
            }

            didAutoPresentBillingPreview = true
            isShowingSubscriptions = true
        }
        .sheet(isPresented: $isShowingSubscriptions) {
            TaskerBillingSheet()
                .patchworkSheetChrome(detents: [.large])
        }
    }

    private func discoverabilityControls(for profile: TaskerProfileSelf) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ghost Mode")
                        .font(.patchworkBodyStrong)
                        .foregroundStyle(PatchworkTheme.textPrimary)

                    Text(ghostModeDescription(for: profile))
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Toggle("", isOn: ghostModeBinding(for: profile))
                    .labelsHidden()
                    .disabled(isUpdating || !canToggleGhostMode(for: profile))
                    .tint(PatchworkTheme.brand)
                    .accessibilityLabel("Ghost Mode")
                    .accessibilityValue(ghostModeValue ? "On" : "Off")
            }

            if let feedbackMessage, feedbackMessage.tone == .error {
                PatchworkInlineStatusBanner(tone: feedbackMessage.tone, text: feedbackMessage.text)
                    .accessibilityIdentifier("Profile.ghostModeBanner")
            }

            if !canToggleGhostMode(for: profile) {
                Text("Activate paid tasker access to change this setting.")
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textSecondary)
            }
        }
        .padding(14)
        .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func accessSummaryCard(_ profile: TaskerProfileSelf) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(planTitle(for: profile))
                    .font(.patchworkBodyStrong)
                    .foregroundStyle(planTitleColor(for: profile))
                Text(planDescription(for: profile))
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if shouldShowStatusBadge(for: profile) {
                statusBadge(for: profile)
            }
        }
        .padding(14)
        .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func ghostModeBinding(for profile: TaskerProfileSelf) -> Binding<Bool> {
        Binding(
            get: { effectiveGhostMode(for: profile) },
            set: { newValue in
                guard canToggleGhostMode(for: profile), !isUpdating else {
                    ghostModeValue = effectiveGhostMode(for: profile)
                    return
                }

                ghostModeValue = newValue
                Task { await setGhostMode(newValue) }
            }
        )
    }

    private var taskerGhostModeRefreshKey: String {
        let rawGhostMode = taskerProfile?.ghostMode == true ? "on" : "off"
        let hasActiveSubscription = taskerProfile?.hasActiveSubscription == true ? "active" : "inactive"
        let subscriptionStatus = taskerProfile?.subscriptionStatus ?? "none"
        return "\(rawGhostMode)|\(hasActiveSubscription)|\(subscriptionStatus)"
    }

    private func canToggleGhostMode(for profile: TaskerProfileSelf) -> Bool {
        profile.hasActiveSubscription == true
    }

    private func effectiveGhostMode(for profile: TaskerProfileSelf?) -> Bool {
        guard let profile else {
            return true
        }

        if canToggleGhostMode(for: profile) {
            return profile.ghostMode
        }

        return true
    }

    private func ghostModeDescription(for profile: TaskerProfileSelf) -> String {
        if !canToggleGhostMode(for: profile) {
            return "Your profile stays hidden from search until you activate paid tasker access."
        }

        return ghostModeValue
            ? "Your profile is hidden from search."
            : "Your profile will appear in search."
    }

    private func backendConfirmedPlans(for taskerProfile: TaskerProfileSelf) -> [SubscriptionPlanChoice] {
        guard taskerProfile.hasActiveSubscription == true else {
            return []
        }

        let rawAccessTypes = taskerProfile.subscriptionActiveAccessTypes ?? []
        let mappedAccessTypes = rawAccessTypes.compactMap { planChoice(forBackendAccessType: $0) }
        if !mappedAccessTypes.isEmpty {
            return mappedAccessTypes
        }

        if let fallbackPlan = planChoice(forBackendAccessType: taskerProfile.subscriptionAccessType) {
            return [fallbackPlan]
        }

        return []
    }

    private func backendConfirmedPlan(for taskerProfile: TaskerProfileSelf) -> SubscriptionPlanChoice? {
        let confirmedPlans = backendConfirmedPlans(for: taskerProfile)
        if confirmedPlans.contains(.lifetime) {
            return .lifetime
        }
        if confirmedPlans.contains(.subscription) {
            return .subscription
        }
        return nil
    }

    private func planChoice(forBackendAccessType accessType: String?) -> SubscriptionPlanChoice? {
        switch accessType {
        case "lifetime":
            return .lifetime
        case "subscription":
            return .subscription
        default:
            return nil
        }
    }

    private func statusBadge(for taskerProfile: TaskerProfileSelf) -> some View {
        if hasStoreAccessPendingBackend(for: taskerProfile) {
            return Text("Confirming")
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.brand)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(PatchworkTheme.brand.opacity(0.12), in: Capsule())
        }

        let status = taskerProfile.subscriptionStatus ?? "inactive"
        let title: String
        let foreground: Color
        let background: Color

        switch status {
        case "active":
            title = "Subscribed"
            foreground = PatchworkTheme.brand
            background = PatchworkTheme.brand.opacity(0.12)
        case "cancel_at_period_end":
            title = "Ending soon"
            foreground = PatchworkTheme.warning
            background = PatchworkTheme.warning.opacity(0.14)
        case "expired":
            title = "Expired"
            foreground = PatchworkTheme.textSecondary
            background = PatchworkTheme.stroke
        default:
            title = "Inactive"
            foreground = PatchworkTheme.textSecondary
            background = PatchworkTheme.stroke
        }

        return Text(title)
            .font(.patchworkCaption)
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
    }

    private func shouldShowStatusBadge(for taskerProfile: TaskerProfileSelf) -> Bool {
        hasStoreAccessPendingBackend(for: taskerProfile) || taskerProfile.subscriptionStatus != "active"
    }

    private func planTitle(for taskerProfile: TaskerProfileSelf) -> String {
        if hasStoreAccessPendingBackend(for: taskerProfile) {
            return "Purchase detected"
        }

        let confirmedPlans = backendConfirmedPlans(for: taskerProfile)
        let confirmedPlan = backendConfirmedPlan(for: taskerProfile)

        if taskerProfile.subscriptionStatus == "active" {
            if confirmedPlans.count > 1 {
                return "Tasker access active"
            }

            switch confirmedPlan {
            case .lifetime:
                return "Founders Club"
            case .subscription:
                return "Subscribed"
            default:
                return "Tasker access active"
            }
        }

        switch taskerProfile.subscriptionPlan {
        case "tasker":
            if confirmedPlans.count > 1 {
                return "Tasker access"
            }

            switch confirmedPlan {
            case .lifetime:
                return "Founders Club"
            case .subscription:
                return "Subscribe"
            default:
                return "Tasker access"
            }
        default:
            return taskerProfile.subscriptionStatus == "expired" ? "Subscription expired" : "No active plan"
        }
    }

    private func planTitleColor(for taskerProfile: TaskerProfileSelf) -> Color {
        if hasStoreAccessPendingBackend(for: taskerProfile) {
            return PatchworkTheme.brand
        }

        switch taskerProfile.subscriptionStatus ?? "inactive" {
        case "active":
            return PatchworkTheme.brand
        case "cancel_at_period_end":
            return PatchworkTheme.warning
        case "expired":
            return PatchworkTheme.textSecondary
        default:
            return PatchworkTheme.textPrimary
        }
    }

    private func planDescription(for taskerProfile: TaskerProfileSelf) -> String {
        if hasStoreAccessPendingBackend(for: taskerProfile) {
            return "Your App Store purchase was detected. Patchwork is still finishing account sync."
        }

        let confirmedPlans = backendConfirmedPlans(for: taskerProfile)
        let confirmedPlan = backendConfirmedPlan(for: taskerProfile)
        let status = taskerProfile.subscriptionStatus ?? "inactive"

        switch status {
        case "active":
            if confirmedPlans.count > 1 {
                return "Multiple App Store billing products are active on this account. Patchwork is using the broadest access level while keeping restores and renewals available."
            }

            if confirmedPlan == .lifetime {
                return "Founders Club is active on this account."
            }
            return "Your subscription is active on this account."
        case "cancel_at_period_end":
            if let endsAt = taskerProfile.subscriptionEndsAt {
                return "Access remains active until \(formattedMonthDayYear(endsAt))."
            }
            return "Cancellation is scheduled for the end of the current term."
        case "expired":
            return "Your paid tasker access has ended."
        default:
            return "Activate paid tasker access to be listed as a tasker."
        }
    }

    private func effectiveHasActiveAccess(for profile: TaskerProfileSelf) -> Bool {
        profile.hasActiveSubscription == true || revenueCatManager.storeState.hasAccess
    }

    private func hasStoreAccessPendingBackend(for profile: TaskerProfileSelf) -> Bool {
        revenueCatManager.storeState.hasAccess && profile.hasActiveSubscription != true
    }

    private func formattedMonthDayYear(_ millis: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        return date.formatted(.dateTime.month(.wide).day().year())
    }

    private func setGhostMode(_ enabled: Bool) async {
        isUpdating = true
        defer { isUpdating = false }

        do {
            let updatedProfile = try await sessionStore.client.mutation("taskers:setGhostMode", args: ["ghostMode": enabled]) as TaskerProfileSelf
            appState.taskerProfile = updatedProfile
            ghostModeValue = effectiveGhostMode(for: updatedProfile)
            await appState.refreshAuthedData(client: sessionStore.client, surfaceErrors: false)
            feedbackMessage = nil
        } catch {
            ghostModeValue = effectiveGhostMode(for: appState.taskerProfile)
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
    }
}

private struct ProfileSidebarMenu: View {
    let userName: String?
    let onClose: () -> Void
    let onOpenFavourites: () -> Void
    let onOpenBlocked: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Settings")
                    .font(.patchworkSectionTitle)
                    .foregroundStyle(PatchworkTheme.textPrimary)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PatchworkTheme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(PatchworkTheme.surfaceMuted, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close settings")
            }

            if let userName, !userName.isEmpty {
                Text(userName)
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textSecondary)
            }

            Button(action: onOpenFavourites) {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PatchworkTheme.brand)
                        .frame(width: 42, height: 42)
                        .background(PatchworkTheme.brandSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Favourites")
                            .font(.patchworkBodyStrong)
                            .foregroundStyle(PatchworkTheme.textPrimary)
                        Text("Saved taskers")
                            .font(.patchworkCaption)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PatchworkTheme.textTertiary)
                        .accessibilityHidden(true)
                }
                .padding(16)
                .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PatchworkTheme.stroke, lineWidth: 1)
                )
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Profile.sidebarFavouritesButton")
            .accessibilityLabel("Open favourites")

            Button(action: onOpenBlocked) {
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PatchworkTheme.danger)
                        .frame(width: 42, height: 42)
                        .background(PatchworkTheme.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Blocked")
                            .font(.patchworkBodyStrong)
                            .foregroundStyle(PatchworkTheme.textPrimary)
                        Text("Blocked users")
                            .font(.patchworkCaption)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PatchworkTheme.textTertiary)
                        .accessibilityHidden(true)
                }
                .padding(16)
                .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PatchworkTheme.stroke, lineWidth: 1)
                )
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Profile.sidebarBlockedButton")
            .accessibilityLabel("Open blocked users")

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 292)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(PatchworkTheme.surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 28, y: 18)
    }
}

private struct FavouriteTaskersPanel: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    private let usesVisualPreview = ProcessInfo.processInfo.arguments.contains("PATCHWORK_UI_EMPTY_TABS")

    let onClose: () -> Void

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brand)

            VStack(spacing: 0) {
                PatchworkSurfaceCard {
                    HStack(spacing: 14) {
                        Button(action: onClose) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(PatchworkTheme.textPrimary)
                                .frame(width: 50, height: 50)
                                .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(PatchworkTheme.stroke, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back to settings")
                        .accessibilityIdentifier("Profile.favouritesBackButton")

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Favourites")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(PatchworkTheme.textPrimary)

                            Text(favouritesSubtitle)
                                .font(.patchworkCaption)
                                .foregroundStyle(PatchworkTheme.textSecondary)
                        }

                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                ScrollView {
                    VStack(spacing: 14) {
                        if appState.favouriteTaskers.isEmpty {
                            PatchworkEmptyStateCard(
                                systemImage: "heart.slash",
                                title: "No favourites yet",
                                message: "Saved taskers will appear here once you start favouriting providers."
                            )
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("Profile.favouritesEmptyState")
                        } else {
                            ForEach(appState.favouriteTaskers) { tasker in
                                favouriteTaskerRow(tasker)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
        }
        .task {
            guard !usesVisualPreview else {
                return
            }
            await appState.refreshFavouriteTaskers(client: sessionStore.client)
        }
    }

    private var favouritesSubtitle: String {
        let count = appState.favouriteTaskers.count
        if count == 0 {
            return "Saved taskers will appear here"
        }
        return count == 1 ? "1 saved tasker" : "\(count) saved taskers"
    }

    private func favouriteTaskerRow(_ tasker: TaskerSummary) -> some View {
        PatchworkSurfaceCard {
            HStack(alignment: .top, spacing: 14) {
                favouriteAvatar(for: tasker)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(tasker.displayName)
                            .font(.patchworkBodyStrong)
                            .foregroundStyle(PatchworkTheme.textPrimary)

                        if tasker.verified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(PatchworkTheme.success)
                                .accessibilityHidden(true)
                        }
                    }

                    if let categoryName = tasker.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !categoryName.isEmpty {
                        Text(categoryName)
                            .font(.patchworkCaption)
                            .foregroundStyle(PatchworkTheme.textSecondary)
                    }

                    HStack(spacing: 12) {
                        summaryPill(
                            icon: "star.fill",
                            text: tasker.averageRating?.formatted(.number.precision(.fractionLength(1))) ?? "New",
                            tint: PatchworkTheme.ratingStar
                        )

                        summaryPill(
                            icon: "checkmark.circle",
                            text: tasker.completedJobs?.formatted() ?? "0",
                            tint: PatchworkTheme.brand
                        )

                        if let rateLabel = tasker.rateLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !rateLabel.isEmpty {
                            Text(rateLabel)
                                .font(.patchworkCaption)
                                .foregroundStyle(PatchworkTheme.brand)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .accessibilityIdentifier("Profile.favouriteTasker.\(tasker.id)")
        .accessibilityElement(children: .combine)
    }

    private func favouriteAvatar(for tasker: TaskerSummary) -> some View {
        PatchworkRemoteImage(
            asset: tasker.avatarImage,
            legacyURL: tasker.avatarUrl,
            preferredVariant: .display,
            contentMode: .fill
        ) {
            avatarPlaceholder(for: tasker)
        }
        .frame(width: 58, height: 58)
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
        .accessibilityHidden(true)
    }

    private func avatarPlaceholder(for tasker: TaskerSummary) -> some View {
        ZStack {
            PatchworkTheme.brandSoft
            Text(String(tasker.displayName.prefix(1)).uppercased())
                .font(.title3.weight(.bold))
                .foregroundStyle(PatchworkTheme.brand)
        }
    }

    private func summaryPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.textPrimary)
        }
    }
}

private struct BlockedUsersPanel: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    private let usesVisualPreview = ProcessInfo.processInfo.arguments.contains("PATCHWORK_UI_EMPTY_TABS")

    let onClose: () -> Void

    @State private var unblockingUserIds: Set<ConvexID> = []

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.danger)

            VStack(spacing: 0) {
                PatchworkSurfaceCard {
                    HStack(spacing: 14) {
                        Button(action: onClose) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(PatchworkTheme.textPrimary)
                                .frame(width: 50, height: 50)
                                .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(PatchworkTheme.stroke, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back to settings")
                        .accessibilityIdentifier("Profile.blockedBackButton")

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Blocked")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(PatchworkTheme.textPrimary)

                            Text(blockedSubtitle)
                                .font(.patchworkCaption)
                                .foregroundStyle(PatchworkTheme.textSecondary)
                        }

                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                ScrollView {
                    VStack(spacing: 14) {
                        if appState.blockedUsers.isEmpty {
                            PatchworkEmptyStateCard(
                                systemImage: "hand.raised.slash",
                                title: "No blocked users",
                                message: "People you block from chat will appear here."
                            )
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("Profile.blockedEmptyState")
                        } else {
                            ForEach(appState.blockedUsers) { blockedUser in
                                blockedUserRow(blockedUser)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
        }
        .task {
            guard !usesVisualPreview else {
                return
            }
            await appState.refreshBlockedUsers(client: sessionStore.client)
        }
    }

    private var blockedSubtitle: String {
        let count = appState.blockedUsers.count
        if count == 0 {
            return "Blocked users will appear here"
        }
        return count == 1 ? "1 blocked user" : "\(count) blocked users"
    }

    private func blockedUserRow(_ blockedUser: BlockedUserSummary) -> some View {
        PatchworkSurfaceCard {
            HStack(alignment: .center, spacing: 14) {
                blockedAvatar(for: blockedUser)

                VStack(alignment: .leading, spacing: 4) {
                    Text(blockedUser.name)
                        .font(.patchworkBodyStrong)
                        .foregroundStyle(PatchworkTheme.textPrimary)

                    Text("Blocked \(blockedDateLabel(blockedUser.createdAt))")
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                }

                Spacer(minLength: 0)

                Button {
                    Task { await unblock(blockedUser) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PatchworkTheme.textSecondary)
                        .frame(width: 38, height: 38)
                        .background(PatchworkTheme.surfaceMuted, in: Circle())
                        .overlay(Circle().stroke(PatchworkTheme.stroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(unblockingUserIds.contains(blockedUser.blockedUserId))
                .accessibilityLabel("Unblock \(blockedUser.name)")
                .accessibilityIdentifier("Profile.unblockUser.\(blockedUser.blockedUserId)")
            }
        }
        .accessibilityIdentifier("Profile.blockedUser.\(blockedUser.blockedUserId)")
    }

    private func blockedAvatar(for blockedUser: BlockedUserSummary) -> some View {
        PatchworkRemoteImage(
            asset: blockedUser.photoImage,
            legacyURL: blockedUser.photoUrl,
            preferredVariant: .thumb,
            contentMode: .fill
        ) {
            ZStack {
                PatchworkTheme.surfaceMuted
                Text(String(blockedUser.name.prefix(1)).uppercased())
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PatchworkTheme.danger)
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
        .accessibilityHidden(true)
    }

    private func blockedDateLabel(_ millis: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private func unblock(_ blockedUser: BlockedUserSummary) async {
        guard !unblockingUserIds.contains(blockedUser.blockedUserId) else { return }
        unblockingUserIds.insert(blockedUser.blockedUserId)
        defer { unblockingUserIds.remove(blockedUser.blockedUserId) }

        do {
            _ = try await sessionStore.client.mutation(
                "moderation:unblockUser",
                args: ["blockedUserId": blockedUser.blockedUserId]
            ) as ModerationBlockStatus
            await appState.refreshBlockedUsers(client: sessionStore.client)
        } catch {
            appState.presentError(error)
        }
    }
}

private struct ProfileSupportSection: View {
    let onSignOut: () async -> Void
    let onDeleteAccount: () async throws -> Void

    @State private var isShowingDeleteConfirmation = false
    @State private var deleteConfirmationText = ""
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?

    private var canConfirmAccountDeletion: Bool {
        deleteConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "delete"
    }

    var body: some View {
        PatchworkSurfaceCard {
            VStack(spacing: 14) {
                NavigationLink {
                    HelpView()
                } label: {
                    ProfileLinkRowLabel(title: "Help & Support")
                }
                .buttonStyle(.plain)
                .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "Profile.helpLink"))

                Button("Sign Out", role: .destructive) {
                    Task {
                        await onSignOut()
                    }
                }
                .buttonStyle(PatchworkDestructiveButtonStyle())
                .accessibilityIdentifier("Profile.signOutButton")

                Button(isDeletingAccount ? "Deleting..." : "Delete Account", role: .destructive) {
                    deleteConfirmationText = ""
                    deleteAccountError = nil
                    isShowingDeleteConfirmation = true
                }
                .buttonStyle(PatchworkDestructiveButtonStyle())
                .disabled(isDeletingAccount)
                .accessibilityIdentifier("Profile.deleteAccountButton")

                if let deleteAccountError {
                    PatchworkInlineStatusBanner(tone: .error, text: deleteAccountError)
                    .accessibilityIdentifier("Profile.deleteAccountError")
                }
            }
        }
        .alert("Delete Account", isPresented: $isShowingDeleteConfirmation) {
            TextField("Type delete", text: $deleteConfirmationText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Delete Account", role: .destructive) {
                Task { await deleteAccount() }
            }
            .disabled(!canConfirmAccountDeletion || isDeletingAccount)

            Button("Cancel", role: .cancel) {
                deleteConfirmationText = ""
            }
        } message: {
            Text("This removes your account information and uploaded profile photos. Completed jobs and message threads are retained for transaction history. If you have an active App Store subscription, billing continues until you cancel it with Apple.")
        }
    }

    private func deleteAccount() async {
        guard canConfirmAccountDeletion, !isDeletingAccount else {
            return
        }

        isDeletingAccount = true
        deleteAccountError = nil
        defer { isDeletingAccount = false }

        do {
            try await onDeleteAccount()
        } catch {
            deleteAccountError = error.localizedDescription
        }
    }
}

private struct ProfileLinkRowStyle: ViewModifier {
    let accessibilityIdentifier: String

    func body(content: Content) -> some View {
        content
            .font(.patchworkBodyStrong)
            .foregroundStyle(PatchworkTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PatchworkTheme.stroke, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct ProfileLinkRowLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 12)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PatchworkTheme.textTertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct TaskerOnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var step = 1
    @State private var displayName = ""
    @State private var selectedCategoryId: ConvexID?

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

    @State private var profileDisplayName = ""
    @State private var addCategorySheet = false

    var body: some View {
        Group {
            if let profile = appState.taskerProfile, step < 5 {
                TaskerProfileManageView(
                    profileDisplayName: $profileDisplayName,
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
                }
            } else {
                TaskerCreateFlowView(
                    step: $step,
                    displayName: $displayName,
                    selectedCategoryId: $selectedCategoryId,
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
                    onSubmit: { Task { await createProfile() } },
                    onSubscribe: { isShowingSubscriptions = true },
                    onDone: { dismiss() }
                )
            }
        }
        .navigationTitle("Tasker Setup")
        .sheet(isPresented: $isShowingSubscriptions) {
            TaskerBillingSheet()
                .patchworkSheetChrome(detents: [.large])
        }
        .task {
            await appState.refreshAuthedData(client: sessionStore.client)
        }
    }

    private func createProfile() async {
        guard let selectedCategoryId else { return }

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

            step = 5
            Task { @MainActor in
                await Task.yield()
                guard step == 5 else { return }
                isShowingSubscriptions = true
            }
            Task {
                await appState.refreshAuthedData(client: sessionStore.client, surfaceErrors: false)
            }
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func updateTaskerProfile(displayName: String) async throws {
        let updatedProfile = try await sessionStore.client.mutation(
            "taskers:updateTaskerProfile",
            args: [
                "displayName": displayName,
            ]
        ) as TaskerProfileSelf
        appState.taskerProfile = updatedProfile
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
    case bio
    case hourlyRate
    case fixedRate
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
    @FocusState private var focusedField: TaskerCreateFocusField?

    private var canCompleteSetup: Bool {
        acceptedTerms && hasValidRate && !isUploadingTaskerPhoto && !isUploadingPortfolio
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
        .patchworkKeyboardDismissToolbar()
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
                StepHeader(currentStep: min(step, 4), totalSteps: 4)
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
        if step >= 5 {
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

                    NavigationLink {
                        CategoriesView(
                            title: "Select Primary Category",
                            selectedCategoryID: selectedCategoryId,
                            dismissOnSelect: true,
                            onSelect: { category in
                                selectedCategoryId = category.id
                            }
                        )
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
                    accessibilityPrefix: "TaskerOnboarding2"
                )

                HStack(spacing: 12) {
                    Button("Back") { step = 1 }
                        .buttonStyle(PatchworkSecondaryButtonStyle())
                        .accessibilityIdentifier("TaskerOnboarding2.backButton")

                    Button("Continue") { step = 3 }
                        .buttonStyle(PatchworkPrimaryButtonStyle())
                        .disabled(categoryBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasValidRate)
                        .accessibilityIdentifier("TaskerOnboarding2.continueButton")
                }
            }
        case 3:
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
                    accessibilityPrefix: "TaskerOnboarding3.portfolio",
                    onAddPhotos: { showsPortfolioPhotoOptions = true }
                )

                HStack(spacing: 12) {
                    Button("Back") { step = 2 }
                        .buttonStyle(PatchworkSecondaryButtonStyle())
                        .accessibilityIdentifier("TaskerOnboarding3.backButton")

                    Button("Continue") { step = 4 }
                        .buttonStyle(PatchworkPrimaryButtonStyle())
                        .disabled(isUploadingPortfolio)
                        .accessibilityIdentifier("TaskerOnboarding3.continueButton")
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
                    .accessibilityIdentifier("TaskerOnboarding4.acceptTermsToggle")

                    HStack(spacing: 12) {
                        Button("Back") { step = 3 }
                            .buttonStyle(PatchworkSecondaryButtonStyle())
                            .accessibilityIdentifier("TaskerOnboarding4.backButton")

                        Button("Complete Setup", action: onSubmit)
                            .buttonStyle(PatchworkPrimaryButtonStyle())
                            .disabled(!canCompleteSetup)
                            .accessibilityIdentifier("TaskerOnboarding4.completeButton")
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

                VStack(alignment: .leading, spacing: 4) {
                    Text(taskerPhotoSource == "custom" ? "Using custom tasker photo." : "Using account profile photo.")
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                    if taskerPhotoSource == "user", accountPhotoImage == nil {
                        Text("No account avatar set yet.")
                            .font(.patchworkCaption)
                            .foregroundStyle(PatchworkTheme.warning)
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
            photoStatusMessage = SubscriptionFeedbackMessage(tone: .success, text: "Tasker photo uploaded.")
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
    @Binding var addCategorySheet: Bool
    let categories: [Category]
    let existingCategoryIDs: Set<ConvexID>
    let onSaveProfile: (String) async throws -> Void
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
                    Text(effectiveTaskerPhotoSource == "custom" ? "Using custom photo." : "Using account photo.")
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
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
            taskerPhotoStatusMessage = SubscriptionFeedbackMessage(tone: .success, text: "Tasker photo updated.")
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
            try await onSaveProfile(trimmedDisplayName)
            feedbackMessage = SubscriptionFeedbackMessage(tone: .success, text: "Display name updated.")
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

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
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
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(portfolioPhotos) { photo in
                            VStack(alignment: .leading, spacing: 8) {
                                TaskerPortfolioPhotoImage(photo: photo, preferredVariant: .display) {
                                    PatchworkTheme.brandSoft
                                }
                                .aspectRatio(4.0 / 3.0, contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(photo.id == activeCoverPhotoId ? PatchworkTheme.brand : PatchworkTheme.stroke, lineWidth: photo.id == activeCoverPhotoId ? 2 : 1)
                                )

                                HStack(spacing: 6) {
                                    Button("Up") {
                                        movePhoto(photo, direction: -1)
                                    }
                                    .buttonStyle(PatchworkSecondaryButtonStyle())
                                    .disabled(indexForPhoto(photo) == 0)
                                    .accessibilityIdentifier("\(accessibilityPrefix).moveUp.\(photo.id)")

                                    Button("Down") {
                                        movePhoto(photo, direction: 1)
                                    }
                                    .buttonStyle(PatchworkSecondaryButtonStyle())
                                    .disabled(indexForPhoto(photo) == portfolioPhotos.count - 1)
                                    .accessibilityIdentifier("\(accessibilityPrefix).moveDown.\(photo.id)")
                                }

                                HStack(spacing: 6) {
                                    Button(photo.id == activeCoverPhotoId ? "Cover 4:3" : "Set 4:3 Cover") {
                                        coverPhotoId = photo.id
                                    }
                                    .buttonStyle(PatchworkSecondaryButtonStyle())
                                    .accessibilityIdentifier("\(accessibilityPrefix).setCover.\(photo.id)")

                                    Button("Remove", role: .destructive) {
                                        removePhoto(photo)
                                    }
                                    .buttonStyle(PatchworkSecondaryButtonStyle())
                                    .accessibilityIdentifier("\(accessibilityPrefix).remove.\(photo.id)")
                                }
                            }
                        }
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
        if coverPhotoId == nil {
            coverPhotoId = portfolioPhotos.first?.id
        }
    }

    private func removePhoto(_ photo: TaskerPortfolioPhoto) {
        portfolioPhotos.removeAll { $0.id == photo.id }
        if coverPhotoId == photo.id {
            coverPhotoId = portfolioPhotos.first?.id
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

private struct HelpView: View {
    @State private var legalDocument: LegalDocument?

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.accent)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PatchworkSectionIntro(
                        eyebrow: "Support",
                        title: "Help",
                        message: "Review Patchwork's policies or send feedback directly from the app."
                    )

                    PatchworkSurfaceCard {
                        VStack(spacing: 14) {
                            Button {
                                legalDocument = .terms
                            } label: {
                                ProfileLinkRowLabel(title: "Terms of Service")
                            }
                            .buttonStyle(.plain)
                            .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "Help.termsLink"))

                            Button {
                                legalDocument = .privacy
                            } label: {
                                ProfileLinkRowLabel(title: "Privacy Policy")
                            }
                            .buttonStyle(.plain)
                            .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "Help.privacyLink"))

                            NavigationLink {
                                FeedbackView()
                            } label: {
                                ProfileLinkRowLabel(title: "Send Feedback")
                            }
                            .buttonStyle(.plain)
                            .modifier(ProfileLinkRowStyle(accessibilityIdentifier: "Help.feedbackLink"))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Help")
        .sheet(item: $legalDocument) { document in
            LegalDocumentView(document: document)
        }
        .accessibilityIdentifier("Help.list")
    }
}

private enum LegalDocument: String, Identifiable {
    case privacy
    case terms

    var id: String { rawValue }

    var url: URL {
        switch self {
        case .privacy:
            return URL(string: "https://ddga.ltd/patchwork/privacy")!
        case .terms:
            return URL(string: "https://ddga.ltd/patchwork/terms")!
        }
    }
}

private struct LegalDocumentView: UIViewControllerRepresentable {
    let document: LegalDocument

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: document.url)
        controller.preferredControlTintColor = UIColor(PatchworkTheme.brand)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private struct FeedbackView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var message = ""
    @State private var feedbackMessage: SubscriptionFeedbackMessage?
    @State private var isSubmitting = false

    private let maxFeedbackLength = 2000

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.brandBright)

            ScrollView {
                VStack(spacing: 18) {
                    PatchworkSurfaceCard {
                        VStack(alignment: .leading, spacing: 18) {
                            PatchworkSectionIntro(
                                eyebrow: "Support",
                                title: "Send Feedback",
                                message: "Share product feedback, bugs, or rough edges in your own words."
                            )

                            if let feedbackMessage {
                                PatchworkInlineStatusBanner(tone: feedbackMessage.tone, text: feedbackMessage.text)
                                    .accessibilityIdentifier("Feedback.statusBanner")
                            }

                            TextEditor(text: $message)
                                .patchworkTextEditorStyle(minHeight: 160)
                                .onChange(of: message) { _, newValue in
                                    if newValue.count > maxFeedbackLength {
                                        message = String(newValue.prefix(maxFeedbackLength))
                                    }
                                }
                                .accessibilityIdentifier("Feedback.messageField")

                            Text("\(message.count)/\(maxFeedbackLength)")
                                .font(.patchworkCaption)
                                .foregroundStyle(message.count >= maxFeedbackLength ? PatchworkTheme.warning : PatchworkTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .accessibilityIdentifier("Feedback.messageCount")

                            Button(isSubmitting ? "Sending..." : "Send Feedback") {
                                Task { await submitFeedback() }
                            }
                            .buttonStyle(PatchworkPrimaryButtonStyle())
                            .disabled(isSubmitting || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("Feedback.submitButton")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Feedback")
    }

    private func submitFeedback() async {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: "Enter your feedback before sending.")
            return
        }

        isSubmitting = true
        feedbackMessage = nil
        defer { isSubmitting = false }

        do {
            _ = try await sessionStore.client.mutation("feedback:submit", args: ["message": trimmedMessage]) as ConvexID
            feedbackMessage = SubscriptionFeedbackMessage(tone: .success, text: "Feedback sent. Thank you.")
            try? await Task.sleep(nanoseconds: 500_000_000)
            dismiss()
        } catch {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
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
