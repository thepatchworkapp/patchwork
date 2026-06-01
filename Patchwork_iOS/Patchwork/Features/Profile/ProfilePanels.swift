import SwiftUI

struct ProfileSidebarMenu: View {
    let userName: String?
    let onClose: () -> Void
    let onOpenFavourites: () -> Void
    let onOpenNotifications: () -> Void
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

            Button(action: onOpenNotifications) {
                HStack(spacing: 12) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PatchworkTheme.brand)
                        .frame(width: 42, height: 42)
                        .background(PatchworkTheme.brandSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications")
                            .font(.patchworkBodyStrong)
                            .foregroundStyle(PatchworkTheme.textPrimary)
                        Text("System settings")
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
            .accessibilityIdentifier("Profile.sidebarNotificationsButton")
            .accessibilityLabel("Open notification settings")

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


struct FavouriteTaskersPanel: View {
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


struct BlockedUsersPanel: View {
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
