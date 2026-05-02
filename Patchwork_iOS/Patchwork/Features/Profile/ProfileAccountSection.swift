import CoreLocation
import SwiftUI
import UIKit

struct ProfileAccountSection: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.openURL) private var openURL

    let user: CurrentUser?
    let taskerProfile: TaskerProfileSelf?
    let onOpenMenu: () -> Void

    @StateObject private var photoFlow = SingleImagePhotoFlowCoordinator(purpose: .userPhoto)
    @State private var pendingPreviewImage: UIImage?
    @State private var pendingPhotoAsset: RemoteImageAsset?
    @State private var isUploadingPhoto = false
    @State private var photoStatusMessage: SubscriptionFeedbackMessage?
    @State private var isShowingProfileEditor = false

    var body: some View {
        accountContent
        .confirmationDialog("Profile photo", isPresented: $photoFlow.showsPhotoOptions, titleVisibility: .visible) {
            if CameraCaptureView.isCameraAvailable {
                Button("Take Photo") {
                    photoFlow.selectCamera()
                }
            }
            Button("Choose from Gallery") {
                photoFlow.selectGallery()
            }
            if hasProfilePhoto {
                Button("Remove Photo", role: .destructive) {
                    Task { await removeProfilePhoto() }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $photoFlow.activeSheet) { sheet in
            switch sheet {
            case .camera:
                CameraCaptureView { image in
                    photoFlow.presentCrop(for: image)
                }
            case .gallery:
                GalleryPickerView(selectionLimit: photoFlow.selectionLimit) { images in
                    photoFlow.presentCrop(for: images.first)
                }
            case .crop(let input):
                PhotoCropEditor(input: input) {
                    photoFlow.cancelCrop()
                } onConfirm: { draft in
                    photoFlow.confirmCrop(draft)
                    Task { await uploadProfilePhoto(draft) }
                }
            }
        }
        .sheet(isPresented: $isShowingProfileEditor) {
            ProfileAccountEditSheet(user: user) { updatedUser in
                appState.currentUser = updatedUser
            }
            .patchworkSheetChrome(detents: [.medium])
        }
    }

    @ViewBuilder
    private var accountContent: some View {
        if taskerProfile == nil {
            preTaskerAccountContent
        } else {
            taskerAccountContent
        }
    }

    private var preTaskerAccountContent: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 18) {
                avatar
                    .padding(.top, 30)
                profilePhotoControls

                VStack(spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(user?.name ?? "Signed in")
                            .font(.system(size: 29, weight: .bold, design: .rounded))
                            .foregroundStyle(PatchworkTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)

                        Button {
                            isShowingProfileEditor = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(PatchworkTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit seeker profile")
                        .accessibilityIdentifier("Profile.editProfileButton")
                    }
                    .frame(maxWidth: .infinity)

                    Label(locationLabel, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(PatchworkTheme.textSecondary)

                    roleBadge(
                        "Seeker",
                        foreground: PatchworkTheme.success,
                        background: PatchworkTheme.success.opacity(0.14),
                        stroke: PatchworkTheme.success.opacity(0.25),
                        accessibilityIdentifier: "Profile.seekerPill"
                    )
                    .padding(.top, 6)
                }

                preTaskerSettingsCard
            }
            .frame(maxWidth: .infinity)

            HStack {
                Spacer(minLength: 0)
                ProfileMenuButton(action: onOpenMenu)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var taskerAccountContent: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 12) {
                avatar
                    .padding(.top, 12)
                profilePhotoControls

                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(user?.name ?? "Signed in")
                            .font(.system(size: 29, weight: .bold, design: .rounded))
                            .foregroundStyle(PatchworkTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)

                        Button {
                            isShowingProfileEditor = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(PatchworkTheme.brand)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit seeker profile")
                        .accessibilityIdentifier("Profile.editProfileButton")
                    }
                    .frame(maxWidth: .infinity)

                    Label(locationLabel, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(PatchworkTheme.textSecondary)
                }

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

            HStack {
                Spacer(minLength: 0)
                ProfileMenuButton(action: onOpenMenu)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var preTaskerSettingsCard: some View {
        PatchworkSurfaceCard {
            VStack(spacing: 0) {
                preTaskerSettingsRow(
                    title: "Seeker profile",
                    systemImage: "person.fill",
                    accessibilityIdentifier: "Profile.seekerProfileRow"
                ) {
                    isShowingProfileEditor = true
                }

                Divider()
                    .padding(.leading, 66)

                preTaskerSettingsRow(
                    title: "Notifications",
                    systemImage: "bell.fill",
                    accessibilityIdentifier: "Profile.notificationsRow"
                ) {
                    openNotificationSettings()
                }
            }
        }
    }

    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            AvatarPhotoControl(
                localImage: pendingPreviewImage,
                remoteAsset: displayedPhotoAsset,
                size: 124,
                isBusy: isUploadingPhoto,
                accessibilityIdentifier: "Profile.photoPicker",
                action: { photoFlow.showOptions() }
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

    private func preTaskerSettingsRow(
        title: String,
        systemImage: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 18) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PatchworkTheme.brand)
                    .frame(width: 44, height: 44)
                    .background(PatchworkTheme.brandSoft.opacity(0.86), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .accessibilityHidden(true)

                Text(title)
                    .font(.patchworkBodyStrong)
                    .foregroundStyle(PatchworkTheme.textPrimary)

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PatchworkTheme.textTertiary)
                    .accessibilityHidden(true)
            }
            .frame(height: 62)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func openNotificationSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        openURL(settingsURL)
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
        _ = photoFlow.takePendingDraft()
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
            guard taskerProfile != nil else {
                return (
                    PatchworkTheme.textSecondary,
                    PatchworkTheme.surfaceMuted,
                    PatchworkTheme.stroke
                )
            }

            return (
                PatchworkTheme.brand,
                PatchworkTheme.brandSoft.opacity(0.95),
                PatchworkTheme.strokeStrong
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
                title: "Jobs",
                value: completedJobsValue,
                icon: "checkmark.circle",
                tint: PatchworkTheme.brand,
                isUnlocked: taskerProfile != nil
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.12))
                .frame(width: 38, height: 38)
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

private struct ProfileAccountEditSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore
    @Environment(LocationManager.self) private var locationManager
    @Environment(\.dismiss) private var dismiss

    let user: CurrentUser?
    let onSaved: (CurrentUser) -> Void

    @State private var name: String
    @State private var city: String
    @State private var province: String
    @State private var isSaving = false
    @State private var statusMessage: SubscriptionFeedbackMessage?

    init(user: CurrentUser?, onSaved: @escaping (CurrentUser) -> Void) {
        self.user = user
        self.onSaved = onSaved
        _name = State(initialValue: user?.name ?? "")
        _city = State(initialValue: user?.location?.city ?? "")
        _province = State(initialValue: user?.location?.province ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                PatchworkSectionIntro(
                    eyebrow: "Account",
                    title: "Edit profile",
                    message: "Update the hometown we use when live location is unavailable."
                )

                VStack(spacing: 12) {
                    TextField("Full name", text: $name)
                        .patchworkInputFieldStyle()
                        .textContentType(.name)
                        .accessibilityIdentifier("ProfileEdit.nameField")

                    TextField("Hometown", text: $city)
                        .patchworkInputFieldStyle()
                        .textContentType(.addressCity)
                        .accessibilityIdentifier("ProfileEdit.cityField")

                    TextField("Province", text: $province)
                        .patchworkInputFieldStyle()
                        .textInputAutocapitalization(.characters)
                        .accessibilityIdentifier("ProfileEdit.provinceField")
                }

                if let statusMessage {
                    PatchworkInlineStatusBanner(tone: statusMessage.tone, text: statusMessage.text)
                        .accessibilityIdentifier("ProfileEdit.statusBanner")
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || !isValid)
                    .accessibilityIdentifier("ProfileEdit.saveButton")
                }
            }
        }
    }

    private var isValid: Bool {
        !trimmedName.isEmpty && !trimmedCity.isEmpty && !trimmedProvince.isEmpty
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedCity: String {
        city.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedProvince: String {
        province.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() async {
        guard isValid, !isSaving else { return }
        isSaving = true
        statusMessage = nil
        defer { isSaving = false }

        do {
            let updatedUser = try await PatchworkAPI(client: sessionStore.client).users.updateProfile(
                name: trimmedName,
                city: trimmedCity,
                province: trimmedProvince
            )
            onSaved(updatedUser)
            appState.currentUser = updatedUser
            await resyncPreferredLocation()
            dismiss()
        } catch {
            statusMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
    }

    private func resyncPreferredLocation() async {
        if let coordinate = await currentDeviceCoordinateIfAllowed() {
            await syncLocation(coordinate, source: "gps")
            return
        }

        if let coordinate = await locationManager.geocode(city: trimmedCity, province: trimmedProvince) {
            await syncLocation(coordinate, source: "manual")
        }
    }

    private func currentDeviceCoordinateIfAllowed() async -> CLLocationCoordinate2D? {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return await locationManager.requestCurrentCoordinate()
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        case .authorizedWhenInUse:
            return await locationManager.requestCurrentCoordinate()
#endif
        default:
            return nil
        }
    }

    private func syncLocation(_ coordinate: CLLocationCoordinate2D, source: String) async {
        let didSync = await appState.syncLocation(
            client: sessionStore.client,
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            source: source
        )
        guard didSync, let currentUser = appState.currentUser else {
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
                coordinates: Coordinates(lat: coordinate.latitude, lng: coordinate.longitude)
            ),
            settings: UserSettings(
                notificationsEnabled: currentUser.settings?.notificationsEnabled,
                locationEnabled: true
            ),
            createdAt: currentUser.createdAt,
            photoImage: currentUser.photoImage
        )
        LocationSyncCache.store(coordinate, for: currentUser.id)
    }
}
