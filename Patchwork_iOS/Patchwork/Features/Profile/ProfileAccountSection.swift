import SwiftUI
import UIKit

struct ProfileAccountSection: View {
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
