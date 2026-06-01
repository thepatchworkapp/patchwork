import EventKit
import SwiftUI

struct MessagesView: View {
    private enum MainLayout {
        static let horizontalGutter: CGFloat = 20
        static let topRhythm: CGFloat = 16
        static let cardGap: CGFloat = 8
        static let bottomPadding: CGFloat = 20
        static let controlSpacing: CGFloat = 14
    }

    private struct ConversationRoute: Hashable, Identifiable {
        let id: ConvexID
    }

    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    @State private var activeRole = "seeker"
    @State private var searchText = ""
    @State private var conversationRoute: ConversationRoute?
    private let usesVisualPreview = ProcessInfo.processInfo.arguments.contains("PATCHWORK_UI_EMPTY_TABS")

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: activeRole == "tasker" ? PatchworkTheme.accent : PatchworkTheme.brand)

            VStack(spacing: 0) {
                topControls

                if isTaskerLocked {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            lockedTaskerState
                        }
                        .padding(.horizontal, MainLayout.horizontalGutter)
                        .padding(.top, MainLayout.topRhythm)
                        .padding(.bottom, MainLayout.bottomPadding)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    if filteredConversations.isEmpty {
                        emptyState
                            .padding(.horizontal, MainLayout.horizontalGutter)
                            .padding(.top, MainLayout.topRhythm)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 14) {
                                ForEach(filteredConversations) { conversation in
                                    Button {
                                        conversationRoute = ConversationRoute(id: conversation.id)
                                    } label: {
                                        conversationRow(conversation)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("Messages.row.\(conversation.id)")
                                }
                            }
                            .padding(.horizontal, MainLayout.horizontalGutter)
                            .padding(.top, MainLayout.cardGap)
                            .padding(.bottom, MainLayout.bottomPadding)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            activeRole = appState.conversationRole
            guard !usesVisualPreview else {
                return
            }
            await appState.refreshConversations(client: sessionStore.client, role: activeRole)
            if let conversationId = appState.selectedConversation?.id {
                conversationRoute = ConversationRoute(id: conversationId)
            }
        }
        .onChange(of: activeRole) { _, role in
            guard !usesVisualPreview else {
                return
            }
            Task { await appState.refreshConversations(client: sessionStore.client, role: role) }
        }
        .onChange(of: appState.selectedConversation?.id) { _, conversationId in
            conversationRoute = conversationId.map(ConversationRoute.init(id:))
        }
        .onAppear {
            guard !usesVisualPreview else {
                return
            }
            Task { await appState.refreshConversations(client: sessionStore.client, role: activeRole) }
        }
        .navigationDestination(item: $conversationRoute) { route in
            ChatView(conversationId: route.id)
        }
    }

    private func unreadCount(for conversation: ConversationSummary) -> Int {
        activeRole == "tasker" ? (conversation.taskerUnreadCount ?? 0) : (conversation.seekerUnreadCount ?? 0)
    }

    private var filteredConversations: [ConversationSummary] {
        guard !searchText.isEmpty else { return appState.conversations }
        return appState.conversations.filter { convo in
            let name = convo.participantName ?? "Conversation"
            let preview = convo.lastMessagePreview ?? ""
            return name.localizedStandardContains(searchText) || preview.localizedStandardContains(searchText)
        }
    }

    private var isTaskerLocked: Bool {
        activeRole == "tasker" && appState.currentUser?.roles?.isTasker != true
    }

    private var topControls: some View {
        PatchworkSurfaceCard {
            VStack(alignment: .leading, spacing: MainLayout.controlSpacing) {
                roleTabs
                searchField
                    .disabled(isTaskerLocked)
                    .opacity(isTaskerLocked ? 0.65 : 1)
            }
        }
        .padding(.horizontal, MainLayout.horizontalGutter)
        .padding(.top, MainLayout.topRhythm)
    }

    private var roleTabs: some View {
        HStack(spacing: 0) {
            tabButton(title: "Seeker", value: "seeker", locked: false)
            tabButton(title: "Tasker", value: "tasker", locked: appState.currentUser?.roles?.isTasker != true)
        }
        .padding(6)
        .background(
            PatchworkTheme.surface.opacity(0.9),
            in: RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PatchworkMetrics.controlRadius, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
    }

    private func tabButton(title: String, value: String, locked: Bool) -> some View {
        let isSelected = activeRole == value
        return Button {
            activeRole = value
        } label: {
            HStack(spacing: 6) {
                Image(systemName: value == "tasker" ? "briefcase.fill" : "person.2.fill")
                    .font(.caption)

                HStack(spacing: 4) {
                    Text(title)
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                    }
                }
                .font(.patchworkBodyStrong)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .foregroundStyle(isSelected ? PatchworkTheme.surface : PatchworkTheme.textSecondary)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(PatchworkTheme.heroGradient) : AnyShapeStyle(Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) messages")
        .accessibilityValue(locked ? "Locked" : (isSelected ? "Selected" : ""))
        .accessibilityHint(locked ? "Switch to tasker mode from your profile to open this inbox." : "Shows your \(title.lowercased()) conversations.")
        .accessibilityIdentifier("Messages.roleTab.\(value)")
    }

    private var searchField: some View {
        PatchworkSearchField(placeholder: "Search conversations...", text: $searchText, isEnabled: !isTaskerLocked)
    }

    private var lockedTaskerState: some View {
        PatchworkEmptyStateCard(
            systemImage: "lock.shield.fill",
            title: "Open your tasker inbox",
            message: "Enable tasker mode to receive seeker messages, proposals, and active job updates.",
            actionTitle: "Go to Profile",
            action: {
                appState.selectedTab = .profile
            }
        )
    }

    private var emptyState: some View {
        let isSearchEmptyState = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !appState.conversations.isEmpty
        return PatchworkEmptyStateCard(
            systemImage: isSearchEmptyState ? "magnifyingglass" : "bubble.left.and.bubble.right.fill",
            title: isSearchEmptyState ? "No matching conversations" : "No conversations yet",
            message: emptyStateMessage(isSearchEmptyState: isSearchEmptyState)
        )
        .frame(maxWidth: .infinity)
    }

    private func emptyStateMessage(isSearchEmptyState: Bool) -> String {
        if isSearchEmptyState {
            return "Try searching for a different name or message preview."
        }
        if activeRole == "tasker" {
            return "New seeker questions, proposals, and job updates will appear here."
        }
        return "Start a conversation from discovery to see your inbox come to life."
    }

    private func conversationRow(_ conversation: ConversationSummary) -> some View {
        let unread = unreadCount(for: conversation)
        let participantName = conversation.participantName ?? "Conversation"
        let preview = conversation.lastMessagePreview ?? "No messages yet"
        let timeLabel = conversationTimestampLabel(conversation.lastMessageAt)
        let roleLabel = activeRole == "tasker" ? "Tasker" : "Seeker"
        return HStack(alignment: .top, spacing: 12) {
            PatchworkRemoteImage(
                asset: conversation.participantImage,
                legacyURL: conversation.participantPhotoUrl,
                preferredVariant: .thumb,
                contentMode: .fill
            ) {
                conversationAvatarPlaceholder(name: participantName)
            }
            .frame(width: 54, height: 54)
            .clipShape(.rect(cornerRadius: 14))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(participantName)
                        .font(unread > 0 ? .patchworkBodyStrong : .patchworkBody)
                        .foregroundStyle(PatchworkTheme.textPrimary)
                    Spacer()
                    Text(timeLabel)
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                }

                Text(preview)
                    .lineLimit(1)
                    .font(.patchworkBody)
                    .foregroundStyle(unread > 0 ? PatchworkTheme.textPrimary : PatchworkTheme.textSecondary)
                    .padding(.bottom, 6)

                HStack(spacing: 8) {
                    PatchworkPill(
                        title: activeRole == "tasker" ? "Tasker" : "Seeker",
                        foreground: PatchworkTheme.brand,
                        fill: PatchworkTheme.brandSoft
                    )

                    if conversation.jobId != nil {
                        PatchworkPill(title: "Job linked", foreground: PatchworkTheme.success)
                    }
                }
            }

            if unread > 0 {
                Text("\(unread)")
                    .font(.patchworkCaption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(PatchworkTheme.danger, in: Capsule())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PatchworkTheme.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(unread > 0 ? PatchworkTheme.strokeStrong : PatchworkTheme.stroke, lineWidth: 1)
        )
        .shadow(color: PatchworkTheme.brand.opacity(0.06), radius: 16, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(participantName)
        .accessibilityValue([
            preview,
            timeLabel.isEmpty ? nil : "Updated \(timeLabel)",
            unread > 0 ? "\(unread) unread message\(unread == 1 ? "" : "s")" : "No unread messages",
            "\(roleLabel) conversation",
            conversation.jobId != nil ? "Job linked" : nil,
        ].compactMap { $0 }.joined(separator: ", "))
    }

    private func conversationAvatarPlaceholder(name: String) -> some View {
        ZStack {
            PatchworkTheme.brandSoft
            Text(String(name.prefix(1)).uppercased())
                .font(.title3.weight(.bold))
                .foregroundStyle(PatchworkTheme.brand)
        }
    }

    private func conversationTimestampLabel(_ millis: Int?) -> String {
        guard let millis else {
            return ""
        }

        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        let now = Date()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let minutesAgo = Int(now.timeIntervalSince(date) / 60)
            if minutesAgo < 1 {
                return "Now"
            }
            if minutesAgo < 60 {
                return "\(minutesAgo)m"
            }
            return date.formatted(date: .omitted, time: .shortened)
        }

        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day,
           daysAgo < 7 {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }

        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

private enum ChatSafetyAction: String, Identifiable {
    case block
    case unblock
    case report
    case blockAndReport

    var id: String { rawValue }
}

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore
    @Environment(RealtimeChatClient.self) private var realtimeChatClient
    @Environment(ChatLocalStore.self) private var chatLocalStore
    @Environment(\.dismiss) private var dismiss

    let conversationId: ConvexID

    @AppStorage("Patchwork.dismissedAcceptedProposalIds") private var dismissedAcceptedProposalIdsStorage = ""
    @State private var messages: [ChatMessage] = []
    @State private var cursor: String?
    @State private var canLoadMore = false
    @State private var isLoading = false
    @State private var text = ""
    @FocusState private var isComposerFocused: Bool

    @State private var conversation: ConversationDetail?
    @State private var job: JobDetail?
    @State private var canReview = false
    @State private var safetyStatus: ModerationBlockStatus?
    @State private var pendingSafetyConfirmation: ChatSafetyAction?
    @State private var reportSheetAction: ChatSafetyAction?
    @State private var safetyFeedbackMessage: SubscriptionFeedbackMessage?
    @State private var calendarFeedbackMessage: SubscriptionFeedbackMessage?
    @State private var isAddingToCalendar = false

    @State private var showProposalForm = false
    @State private var counteringProposal: ProposalPayload?
    @State private var proposalRate = ""
    @State private var proposalRateType = "hourly"
    @State private var proposalDate = ""
    @State private var proposalTime = ""
    @State private var proposalNotes = ""

    @State private var showReviewForm = false
    @State private var showCompleteConfirm = false
    @State private var reviewRating = 0
    @State private var reviewText = ""

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.accent)

            VStack(spacing: 12) {
                chatHeader
                    .padding(.horizontal, 16)

                if let safetyFeedbackMessage {
                    PatchworkInlineStatusBanner(tone: safetyFeedbackMessage.tone, text: safetyFeedbackMessage.text)
                        .padding(.horizontal, 20)
                        .accessibilityIdentifier("Chat.safetyStatusBanner")
                }

                if let blockMessage = blockStateMessage {
                    PatchworkInlineStatusBanner(tone: .warning, text: blockMessage)
                        .padding(.horizontal, 20)
                        .accessibilityIdentifier("Chat.blockedBanner")
                }

                if canLoadMore {
                    Button("Load older messages") {
                        Task { await loadMessages(loadMore: true) }
                    }
                    .buttonStyle(PatchworkSecondaryButtonStyle())
                    .padding(.horizontal, 20)
                    .accessibilityIdentifier("Chat.loadOlderButton")
                }

                if let acceptedProposalForBanner = acceptedProposal,
                   !dismissedAcceptedProposalIds.contains(acceptedProposalForBanner.id) {
                    ChatAcceptedBanner(
                        text: job?.status == "completed" ? "Job completed" : "Job in progress",
                        canAddToCalendar: true,
                        isAddingToCalendar: isAddingToCalendar,
                        onAddToCalendar: { Task { await addAcceptedProposalToCalendar() } },
                        onDismiss: {
                            dismissAcceptedProposalBanner(id: acceptedProposalForBanner.id)
                        }
                    )
                        .padding(.horizontal, 20)
                        .accessibilityIdentifier("Chat.jobInProgressBanner")
                }

                if let calendarFeedbackMessage {
                    PatchworkInlineStatusBanner(tone: calendarFeedbackMessage.tone, text: calendarFeedbackMessage.text)
                        .padding(.horizontal, 20)
                        .accessibilityIdentifier("Chat.calendarStatusBanner")
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                chatRow(for: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 12)
                    }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .contentShape(Rectangle())
                    .simultaneousGesture(TapGesture().onEnded {
                        isComposerFocused = false
                    })
                    .accessibilityIdentifier("Chat.messageScroll")
                    .onChange(of: messages.last?.id) { _, lastMessageID in
                        guard let lastMessageID else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastMessageID, anchor: .bottom)
                        }
                    }
                }

                if !isConversationBlocked {
                    ChatActionBar(
                        canShowCompleteButton: canShowCompleteButton,
                        hasAcceptedProposal: hasAcceptedProposal,
                        onCompleteTap: { showCompleteConfirm = true },
                        onProposeTap: {
                            resetProposalForm()
                            showProposalForm = true
                        }
                    )
                }

                ChatComposerBar(
                    text: $text,
                    isFocused: $isComposerFocused,
                    isDisabled: isConversationBlocked,
                    onSend: { Task { await send() } }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("Chat.screen.\(conversationId)")
        .task(id: conversationId) {
            reloadMessagesFromLocalStore(surfaceErrors: false)
            startRealtimeSubscription()
            await bootstrap()
        }
        .onDisappear {
            realtimeChatClient.stopThreadSubscription(conversationId: conversationId)
        }
        .sheet(isPresented: $showProposalForm) {
            ProposalFormSheet(
                isCounter: counteringProposal != nil,
                rate: $proposalRate,
                rateType: $proposalRateType,
                date: $proposalDate,
                time: $proposalTime,
                notes: $proposalNotes,
                onCancel: {
                    showProposalForm = false
                    counteringProposal = nil
                },
                onSubmit: { Task { await submitProposal() } }
            )
            .patchworkSheetChrome()
        }
        .sheet(isPresented: $showReviewForm) {
            ReviewFormSheet(
                rating: $reviewRating,
                text: $reviewText,
                onSubmit: { Task { await submitReview() } }
            )
            .patchworkSheetChrome()
        }
        .sheet(isPresented: $showCompleteConfirm) {
            CompleteJobSheet(
                onCancel: { showCompleteConfirm = false },
                onConfirm: {
                    showCompleteConfirm = false
                    Task { await completeJob() }
                }
            )
            .patchworkSheetChrome(detents: [.height(320)])
        }
        .sheet(item: $reportSheetAction) { action in
            ChatReportSheet(
                action: action,
                participantName: conversation?.participantName ?? "this user",
                onSubmit: { reason in
                    try await submitReport(reason: reason, shouldBlock: action == .blockAndReport)
                }
            )
            .patchworkSheetChrome()
        }
        .confirmationDialog(
            safetyConfirmationTitle,
            isPresented: Binding(
                get: { pendingSafetyConfirmation != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingSafetyConfirmation = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if pendingSafetyConfirmation == .block {
                Button("Block User", role: .destructive) {
                    Task { await blockParticipant() }
                }
            } else if pendingSafetyConfirmation == .unblock {
                Button("Unblock", role: .destructive) {
                    Task { await unblockParticipant() }
                }
            }
            Button("Cancel", role: .cancel) {
                pendingSafetyConfirmation = nil
            }
        } message: {
            Text(safetyConfirmationMessage)
        }
    }

    private var chatHeader: some View {
        HStack(spacing: 12) {
            Button("Messages", systemImage: "chevron.left") {
                appState.selectedConversation = nil
                dismiss()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(PatchworkIconButtonStyle(fill: PatchworkTheme.surface.opacity(0.9)))
            .accessibilityLabel("Back to messages")
            .accessibilityIdentifier("Chat.backButton")

            PatchworkRemoteImage(
                asset: conversation?.participantImage,
                legacyURL: conversation?.participantPhotoUrl,
                preferredVariant: .thumb,
                contentMode: .fill
            ) {
                chatAvatarPlaceholder
            }
            .frame(width: 44, height: 44)
            .clipShape(.rect(cornerRadius: 14))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(conversation?.participantName ?? "Chat")
                    .font(.patchworkBodyStrong)
                    .foregroundStyle(PatchworkTheme.textPrimary)
                Text(hasAcceptedProposal ? "Active conversation" : "Direct messages")
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textSecondary)
            }

            Spacer()

            if otherUserId != nil {
                Menu {
                    Menu("User Actions") {
                        if safetyStatus?.currentUserBlockedOther == true {
                            Button {
                                pendingSafetyConfirmation = .unblock
                            } label: {
                                Label("Unblock", systemImage: "hand.raised.slash")
                            }
                        } else {
                            Button(role: .destructive) {
                                pendingSafetyConfirmation = .block
                            } label: {
                                Label("Block User", systemImage: "hand.raised.fill")
                            }
                        }

                        Button {
                            reportSheetAction = .report
                        } label: {
                            Label("Report User", systemImage: "exclamationmark.bubble")
                        }

                        if safetyStatus?.currentUserBlockedOther != true {
                            Button(role: .destructive) {
                                reportSheetAction = .blockAndReport
                            } label: {
                                Label("Block & Report", systemImage: "exclamationmark.shield")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(PatchworkTheme.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(PatchworkTheme.surfaceMuted, in: Circle())
                }
                .accessibilityLabel("User actions")
                .accessibilityIdentifier("Chat.userActionsMenu")
            }
        }
        .padding(12)
        .background(PatchworkTheme.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
        .accessibilityIdentifier("Chat.header")
    }

    private var chatAvatarPlaceholder: some View {
        let name = conversation?.participantName ?? "Chat"
        return ZStack {
            PatchworkTheme.brandSoft
            Text(String(name.prefix(1)).uppercased())
                .font(.headline.weight(.bold))
                .foregroundStyle(PatchworkTheme.brand)
        }
    }

    private var otherUserId: ConvexID? {
        guard let conversation,
              let currentUserId = appState.currentUser?.id else { return nil }
        if conversation.seekerId == currentUserId {
            return conversation.taskerId
        }
        if conversation.taskerId == currentUserId {
            return conversation.seekerId
        }
        return nil
    }

    private var isConversationBlocked: Bool {
        safetyStatus?.isBlocked == true
    }

    private var blockStateMessage: String? {
        guard let safetyStatus, safetyStatus.isBlocked else { return nil }
        if safetyStatus.currentUserBlockedOther {
            return "You blocked this user. Unblock them to send new messages."
        }
        return "This conversation is unavailable."
    }

    private var safetyConfirmationTitle: String {
        switch pendingSafetyConfirmation {
        case .block:
            return "Block \(conversation?.participantName ?? "user")?"
        case .unblock:
            return "Unblock \(conversation?.participantName ?? "user")?"
        default:
            return "User Actions"
        }
    }

    private var safetyConfirmationMessage: String {
        switch pendingSafetyConfirmation {
        case .block:
            return "You will no longer be able to send messages to each other. You can unblock them from your profile."
        case .unblock:
            return "This will allow messages between you and this user again."
        default:
            return ""
        }
    }

    private var hasAcceptedProposal: Bool {
        acceptedProposal != nil
    }

    private var acceptedProposal: ProposalPayload? {
        messages.reversed().compactMap(\.proposal).first { $0.status == "accepted" }
    }

    private var dismissedAcceptedProposalIds: Set<ConvexID> {
        Set(dismissedAcceptedProposalIdsStorage.split(separator: "\n").map(String.init))
    }

    private func dismissAcceptedProposalBanner(id: ConvexID) {
        var dismissedIds = dismissedAcceptedProposalIds
        dismissedIds.insert(id)
        dismissedAcceptedProposalIdsStorage = dismissedIds.sorted().joined(separator: "\n")
    }

    private var canShowCompleteButton: Bool {
        guard hasAcceptedProposal,
              let currentUser = appState.currentUser,
              let job else { return false }
        return job.status == "in_progress" && job.seekerId == currentUser.id
    }

    private func bootstrap() async {
        if appState.currentUser == nil {
            _ = await appState.refreshCurrentUser(client: sessionStore.client)
        }
        await refreshConversationDetail(surfaceErrors: true)
        await loadSafetyStatus()
        await markRead(surfaceErrors: true)
        reloadMessagesFromLocalStore(surfaceErrors: false)
        await loadMessages(loadMore: false, surfaceErrors: true)
        await syncMessagesSince(surfaceErrors: false)
        await refreshJobState(surfaceErrors: true)
    }

    private func refreshOpenConversation(surfaceErrors: Bool) async {
        await refreshConversationDetail(surfaceErrors: surfaceErrors)
        await syncMessagesSince(surfaceErrors: surfaceErrors)
        await markRead(surfaceErrors: false)
        await refreshJobState(surfaceErrors: surfaceErrors)
    }

    private func refreshConversationDetail(surfaceErrors: Bool) async {
        do {
            conversation = try await PatchworkAPI(client: sessionStore.client).conversations.get(
                conversationId: conversationId
            )
        } catch {
            if surfaceErrors {
                appState.presentError(error, prefix: "Failed to load conversation")
            }
        }
    }

    private func loadSafetyStatus() async {
        do {
            safetyStatus = try await sessionStore.client.query(
                "moderation:getConversationSafetyStatus",
                args: ["conversationId": conversationId]
            )
        } catch {
            appState.presentError(error)
        }
    }

    private func refreshJobState(surfaceErrors: Bool = true) async {
        guard let conversation else { return }
        do {
            if let jobId = conversation.jobId {
                let currentTimeMs = Int(Date().timeIntervalSince1970 * 1000)
                async let jobCall: JobDetail? = sessionStore.client.query("jobs:getJob", args: ["jobId": jobId])
                async let canReviewCall: Bool = sessionStore.client.query(
                    "reviews:canReview",
                    args: ["jobId": jobId, "currentTimeMs": currentTimeMs]
                )
                job = try await jobCall
                canReview = try await canReviewCall
            }
        } catch {
            guard surfaceErrors else {
                return
            }
            appState.presentError(error)
        }
    }

    private func loadMessages(loadMore: Bool, surfaceErrors: Bool = true) async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let optionsObject: [String: Any] = [
                "numItems": 25,
                "cursor": loadMore ? ((cursor as Any?) ?? NSNull()) : NSNull(),
            ]
            let result: MessagesPage = try await sessionStore.client.query(
                "messages:listMessages",
                args: [
                    "conversationId": conversationId,
                    "paginationOpts": optionsObject,
                ]
            )

            if loadMore {
                cacheMessages(result.page)
            } else {
                cacheMessages(result.page)
            }
            reloadMessagesFromLocalStore(surfaceErrors: surfaceErrors)
            cursor = result.continueCursor.isEmpty ? nil : result.continueCursor
            canLoadMore = !result.isDone
        } catch {
            guard surfaceErrors else {
                return
            }
            appState.presentError(error)
        }
    }

    private func syncMessagesSince(surfaceErrors: Bool) async {
        do {
            let cursor = try chatLocalStore.newestCursor(for: conversationId)
            let since = Int(cursor ?? "0") ?? 0
            var nextSince = since
            var hasMore = true

            while hasMore {
                let result: MessagesSinceResponse = try await sessionStore.client.query(
                    "messages:listMessagesSince",
                    args: [
                        "conversationId": conversationId,
                        "afterCreatedAt": nextSince,
                        "limit": 100,
                    ]
                )
                let nextCursor = try chatLocalStore.apply(messagesSince: result, conversationId: conversationId)
                reloadMessagesFromLocalStore(surfaceErrors: surfaceErrors)
                hasMore = result.hasMore
                let updatedSince = Int(nextCursor ?? String(nextSince)) ?? nextSince
                guard updatedSince > nextSince else {
                    break
                }
                nextSince = updatedSince
            }
        } catch {
            guard surfaceErrors else {
                return
            }
            appState.presentError(error)
        }
    }

    private func startRealtimeSubscription() {
        let currentCursor = (try? chatLocalStore.newestCursor(for: conversationId))
            .flatMap { Int($0) } ?? 0
        realtimeChatClient.subscribeToThread(
            conversationId: conversationId,
            afterCreatedAt: currentCursor,
            onUpdate: { delta in
                do {
                    try chatLocalStore.apply(threadDelta: delta, conversationId: conversationId)
                    reloadMessagesFromLocalStore(surfaceErrors: false)
                    if delta.messages.contains(where: { $0.senderId != appState.currentUser?.id }) {
                        Task { await markRead(surfaceErrors: false) }
                    }
                    if delta.latestProposal != nil {
                        Task {
                            await refreshConversationDetail(surfaceErrors: false)
                            await refreshJobState(surfaceErrors: false)
                        }
                    }
                } catch {
                    appState.presentError(error)
                }
            }
        )
    }

    private func cacheMessages(_ incomingMessages: [ChatMessage]) {
        let proposals = incomingMessages.compactMap { message in
            message.proposal.map {
                LocalProposal.Snapshot(proposal: $0, conversationId: message.conversationId ?? conversationId)
            }
        }
        let localMessages = incomingMessages.map {
            LocalMessage.Snapshot(message: $0, conversationId: conversationId)
        }
        _ = try? chatLocalStore.apply(
            delta: ChatLocalStore.Delta(messages: localMessages, proposals: proposals),
            conversationId: conversationId
        )
    }

    private func reloadMessagesFromLocalStore(surfaceErrors: Bool) {
        do {
            let cachedMessages = try chatLocalStore.chatMessages(conversationId: conversationId)
            guard cachedMessages != messages else { return }
            messages = cachedMessages
        } catch {
            guard surfaceErrors else {
                return
            }
            appState.presentError(error)
        }
    }

    private func send() async {
        guard !isConversationBlocked else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let currentUserId = appState.currentUser?.id else { return }
        let clientMessageId = UUID().uuidString
        let now = Int(Date().timeIntervalSince1970 * 1000)
        do {
            try chatLocalStore.upsertOptimisticMessage(
                LocalMessage.Snapshot(
                    conversationId: conversationId,
                    clientMessageId: clientMessageId,
                    senderId: currentUserId,
                    content: trimmed,
                    createdAt: now,
                    updatedAt: now,
                    isOptimistic: true,
                    localStatus: "sending"
                )
            )
            reloadMessagesFromLocalStore(surfaceErrors: true)
            text = ""
            isComposerFocused = false
            _ = try await sessionStore.client.mutation(
                "messages:sendMessage",
                args: [
                    "conversationId": conversationId,
                    "clientMessageId": clientMessageId,
                    "content": trimmed,
                ]
            ) as ConvexID
            await syncMessagesSince(surfaceErrors: false)
            await markRead()
        } catch {
            try? chatLocalStore.markMessageFailed(clientMessageId: clientMessageId)
            reloadMessagesFromLocalStore(surfaceErrors: false)
            appState.presentError(error)
        }
    }

    private func blockParticipant() async {
        pendingSafetyConfirmation = nil
        guard let otherUserId else { return }
        do {
            safetyStatus = try await sessionStore.client.mutation(
                "moderation:blockUser",
                args: [
                    "blockedUserId": otherUserId,
                    "conversationId": conversationId,
                ]
            )
            text = ""
            safetyFeedbackMessage = SubscriptionFeedbackMessage(tone: .success, text: "User blocked.")
            await appState.refreshBlockedUsers(client: sessionStore.client)
        } catch {
            appState.presentError(error)
        }
    }

    private func unblockParticipant() async {
        pendingSafetyConfirmation = nil
        guard let otherUserId else { return }
        do {
            safetyStatus = try await sessionStore.client.mutation(
                "moderation:unblockUser",
                args: ["blockedUserId": otherUserId]
            )
            safetyFeedbackMessage = SubscriptionFeedbackMessage(tone: .success, text: "User unblocked.")
            await appState.refreshBlockedUsers(client: sessionStore.client)
        } catch {
            appState.presentError(error)
        }
    }

    private func submitReport(reason: String, shouldBlock: Bool) async throws {
        guard let otherUserId else { return }
        struct ReportResult: Decodable {
            let reportId: ConvexID
            let blockId: ConvexID?
        }

        _ = try await sessionStore.client.mutation(
            "moderation:reportUser",
            args: [
                "reportedUserId": otherUserId,
                "conversationId": conversationId,
                "reason": reason,
                "block": shouldBlock,
            ]
        ) as ReportResult

        if shouldBlock {
            await loadSafetyStatus()
            text = ""
            await appState.refreshBlockedUsers(client: sessionStore.client)
        }

        safetyFeedbackMessage = SubscriptionFeedbackMessage(
            tone: .success,
            text: "Thanks for the report. Our team will review it."
        )
    }

    private func submitProposal() async {
        guard let rateNumber = Double(proposalRate),
              !proposalDate.isEmpty,
              !proposalTime.isEmpty else { return }
        guard let currentUserId = appState.currentUser?.id,
              let receiverId = otherUserId else { return }

        let cents = Int((rateNumber * 100).rounded())
        guard let startDateTime = ProposalDateTimeCodec.encode(date: proposalDate, time: proposalTime) else {
            appState.lastError = "Enter a valid proposal date and time."
            return
        }
        let originalProposalId = counteringProposal?.id
        let notes = proposalNotes
        let clientProposalId = UUID().uuidString
        let now = Int(Date().timeIntervalSince1970 * 1000)
        do {
            try insertOptimisticProposalPreview(
                clientProposalId: clientProposalId,
                senderId: currentUserId,
                receiverId: receiverId,
                rate: cents,
                rateType: proposalRateType,
                startDateTime: startDateTime,
                notes: notes,
                previousProposalId: originalProposalId,
                createdAt: now
            )
            reloadMessagesFromLocalStore(surfaceErrors: true)
            showProposalForm = false
            counteringProposal = nil

            try await sendProposalMutation(
                originalProposalId: originalProposalId,
                clientProposalId: clientProposalId,
                rate: cents,
                rateType: proposalRateType,
                startDateTime: startDateTime,
                notes: notes
            )
            await syncMessagesSince(surfaceErrors: false)
        } catch {
            try? chatLocalStore.markProposalMessageFailed(clientProposalId: clientProposalId)
            reloadMessagesFromLocalStore(surfaceErrors: false)
            appState.presentError(error)
        }
    }

    private func insertOptimisticProposalPreview(
        clientProposalId: String,
        senderId: ConvexID,
        receiverId: ConvexID,
        rate: Int,
        rateType: String,
        startDateTime: String,
        notes: String,
        previousProposalId: ConvexID?,
        createdAt: Int
    ) throws {
        try chatLocalStore.upsertOptimisticProposal(
            LocalProposal.Snapshot(
                conversationId: conversationId,
                clientProposalId: clientProposalId,
                senderId: senderId,
                receiverId: receiverId,
                rate: rate,
                rateType: rateType,
                startDateTime: startDateTime,
                notes: notes,
                status: "pending",
                previousProposalId: previousProposalId,
                createdAt: createdAt,
                updatedAt: createdAt,
                isOptimistic: true
            )
        )
        try chatLocalStore.upsertOptimisticMessage(
            LocalMessage.Snapshot(
                conversationId: conversationId,
                senderId: senderId,
                type: "proposal",
                content: previousProposalId == nil ? "Proposal sent" : "Counter proposal sent",
                clientProposalId: clientProposalId,
                createdAt: createdAt,
                updatedAt: createdAt,
                isOptimistic: true,
                localStatus: "sending"
            )
        )
    }

    private func sendProposalMutation(
        originalProposalId: ConvexID?,
        clientProposalId: String,
        rate: Int,
        rateType: String,
        startDateTime: String,
        notes: String
    ) async throws {
        if let originalProposalId {
            _ = try await sessionStore.client.mutation(
                "proposals:counterProposal",
                args: [
                    "proposalId": originalProposalId,
                    "clientProposalId": clientProposalId,
                    "rate": rate,
                    "rateType": rateType,
                    "startDateTime": startDateTime,
                    "notes": notes,
                ]
            ) as ConvexID
        } else {
            _ = try await sessionStore.client.mutation(
                "proposals:sendProposal",
                args: [
                    "conversationId": conversationId,
                    "clientProposalId": clientProposalId,
                    "rate": rate,
                    "rateType": rateType,
                    "startDateTime": startDateTime,
                    "notes": notes,
                ]
            ) as ConvexID
        }
    }

    private func accept(proposal: ProposalPayload) async {
        do {
            struct JobCreateResult: Decodable {
                let jobId: ConvexID
            }
            _ = try await sessionStore.client.mutation("proposals:acceptProposal", args: ["proposalId": proposal.id]) as JobCreateResult
            await syncMessagesSince(surfaceErrors: false)
            await refreshConversationDetail(surfaceErrors: true)
            await refreshJobState()
        } catch {
            appState.presentError(error)
        }
    }

    private func decline(proposal: ProposalPayload) async {
        do {
            _ = try await sessionStore.client.mutation("proposals:declineProposal", args: ["proposalId": proposal.id]) as ConvexID
            await syncMessagesSince(surfaceErrors: false)
        } catch {
            appState.presentError(error)
        }
    }

    private func completeJob() async {
        guard let job else { return }
        do {
            struct JobCompleteResult: Decodable {
                let jobId: ConvexID
            }
            _ = try await sessionStore.client.mutation("jobs:completeJob", args: ["jobId": job.id]) as JobCompleteResult
            await appState.refreshJobs(client: sessionStore.client, statusGroup: appState.jobsStatusGroup)
            await refreshJobState()
            if canReview {
                showReviewForm = true
            }
        } catch {
            appState.presentError(error)
        }
    }

    private func submitReview() async {
        guard let job,
              reviewRating > 0,
              reviewText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 else {
            return
        }

        do {
            _ = try await sessionStore.client.mutation(
                "reviews:createReview",
                args: [
                    "jobId": job.id,
                    "rating": reviewRating,
                    "text": reviewText,
                ]
            ) as ConvexID
            showReviewForm = false
            reviewRating = 0
            reviewText = ""
            await appState.refreshJobs(client: sessionStore.client, statusGroup: appState.jobsStatusGroup)
            await refreshJobState()
        } catch {
            appState.presentError(error)
        }
    }

    private func markRead(surfaceErrors: Bool = true) async {
        do {
            struct ReadResult: Decodable {
                let success: Bool
            }
            _ = try await sessionStore.client.mutation(
                "conversations:markAsRead",
                args: ["conversationId": conversationId]
            ) as ReadResult
            await appState.refreshConversations(
                client: sessionStore.client,
                role: appState.conversationRole,
                surfaceErrors: false
            )
        } catch {
            guard surfaceErrors else {
                return
            }
            appState.presentError(error)
        }
    }

    private func addAcceptedProposalToCalendar() async {
        guard !isAddingToCalendar,
              let acceptedProposal else {
            return
        }

        isAddingToCalendar = true
        calendarFeedbackMessage = nil
        defer { isAddingToCalendar = false }

        do {
            try await PatchworkCalendarWriter.addProposalEvent(
                proposal: acceptedProposal,
                conversation: conversation,
                job: job
            )
            calendarFeedbackMessage = SubscriptionFeedbackMessage(tone: .success, text: "Added to Calendar.")
        } catch {
            calendarFeedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
    }

    private func isMyMessage(_ message: ChatMessage) -> Bool {
        message.senderId == appState.currentUser?.id
    }

    @ViewBuilder
    private func chatRow(for message: ChatMessage) -> some View {
        if message.type == "proposal", let proposal = message.proposal {
            ProposalMessageCard(
                proposal: proposal,
                isMine: isMyMessage(message),
                localStatus: message.localStatus,
                onAccept: { Task { await accept(proposal: proposal) } },
                onDecline: { Task { await decline(proposal: proposal) } },
                onCounter: {
                    primeCounterForm(proposal)
                    showProposalForm = true
                },
                onRetry: { Task { await retryProposal(message: message) } }
            )
        } else if message.type == "system" {
            Text(message.content)
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        } else {
            ChatMessageRow(
                text: message.content,
                time: timeLabel(message.createdAt),
                isMine: isMyMessage(message),
                localStatus: message.localStatus,
                onRetry: { Task { await retry(message: message) } }
            )
        }
    }

    private func retry(message: ChatMessage) async {
        guard message.localStatus == "failed" else { return }
        text = message.content
        await send()
    }

    private func retryProposal(message: ChatMessage) async {
        guard message.localStatus == "failed",
              let proposal = message.proposal,
              let clientProposalId = proposal.clientProposalId else { return }

        do {
            try chatLocalStore.markProposalMessageSending(clientProposalId: clientProposalId)
            reloadMessagesFromLocalStore(surfaceErrors: false)
            try await sendProposalMutation(
                originalProposalId: proposal.previousProposalId,
                clientProposalId: clientProposalId,
                rate: proposal.rate,
                rateType: proposal.rateType,
                startDateTime: proposal.startDateTime,
                notes: proposal.notes ?? ""
            )
            await syncMessagesSince(surfaceErrors: false)
        } catch {
            try? chatLocalStore.markProposalMessageFailed(clientProposalId: clientProposalId)
            reloadMessagesFromLocalStore(surfaceErrors: false)
            appState.presentError(error)
        }
    }

    private func timeLabel(_ millis: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func primeCounterForm(_ proposal: ProposalPayload) {
        counteringProposal = proposal
        proposalRate = (Double(proposal.rate) / 100).formatted(.number.precision(.fractionLength(2)))
        proposalRateType = proposal.rateType
        if let fields = ProposalDateTimeCodec.formFields(from: proposal.startDateTime) {
            proposalDate = fields.date
            proposalTime = fields.time
        } else {
            proposalDate = ""
            proposalTime = ""
        }
        proposalNotes = proposal.notes ?? ""
    }

    private func resetProposalForm() {
        counteringProposal = nil
        proposalRate = ""
        proposalRateType = "hourly"
        proposalDate = ""
        proposalTime = ""
        proposalNotes = ""
    }
}

private struct ProposalMessageCard: View {
    @Environment(AppState.self) private var appState

    let proposal: ProposalPayload
    let isMine: Bool
    let localStatus: String?
    let onAccept: () -> Void
    let onDecline: () -> Void
    let onCounter: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(rateLabel)
                    .font(.patchworkCardTitle)
                    .foregroundStyle(PatchworkTheme.textPrimary)
                Spacer()
                proposalStatus
            }

            Text(scheduleLabel)
                .font(.patchworkCaption)
                .foregroundStyle(PatchworkTheme.textSecondary)

            if let notes = proposal.notes, !notes.isEmpty {
                Text(notes)
                    .font(.patchworkBody)
                    .foregroundStyle(PatchworkTheme.textPrimary)
            }

            if canActOnProposal {
                HStack(spacing: 8) {
                    actionButton(title: "Decline", identifier: "Chat.proposal.declineButton", action: onDecline)
                        .buttonStyle(PatchworkDestructiveButtonStyle())

                    actionButton(title: "Counter", identifier: "Chat.proposal.counterButton", action: onCounter)
                        .buttonStyle(
                            PatchworkSecondaryButtonStyle(
                                foreground: PatchworkTheme.brand,
                                stroke: PatchworkTheme.brand.opacity(0.26),
                                fill: PatchworkTheme.surface
                            )
                        )

                    actionButton(title: "Accept", identifier: "Chat.proposal.acceptButton", action: onAccept)
                        .buttonStyle(PatchworkPrimaryButtonStyle())
                }
                .accessibilityIdentifier("Chat.proposalActions")
            }

            if localStatus == "sending" {
                Text("Sending...")
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textSecondary)
            } else if localStatus == "failed" {
                Button("Failed - Retry", action: onRetry)
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.danger)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Chat.proposal.retryButton")
            }
        }
        .padding(16)
        .background(
            (isMine ? PatchworkTheme.brandSoft : PatchworkTheme.surface.opacity(0.92)),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Proposal")
        .accessibilityValue([
            rateLabel,
            scheduleLabel,
            proposal.notes?.isEmpty == false ? proposal.notes : nil,
            "Status \(proposal.status)",
        ].compactMap { $0 }.joined(separator: ", "))
        .accessibilityIdentifier("Chat.proposal.\(proposal.id)")
    }

    private var canActOnProposal: Bool {
        guard proposal.status == "pending", !isMine else { return false }
        return proposal.receiverId == appState.currentUser?.id
    }

    @ViewBuilder
    private var proposalStatus: some View {
        switch proposal.status {
        case "accepted":
            PatchworkPill(title: "Accepted", foreground: PatchworkTheme.success)
        case "declined":
            PatchworkPill(title: "Declined", foreground: PatchworkTheme.textSecondary)
        case "countered":
            PatchworkPill(title: "Countered", foreground: PatchworkTheme.brand)
        default:
            PatchworkPill(title: "Pending", foreground: PatchworkTheme.warning)
        }
    }

    private func actionButton(
        title: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }

    private var rateLabel: String {
        "\(PatchworkCurrency.formatted(cents: proposal.rate))/\(proposal.rateType)"
    }

    private var scheduleLabel: String {
        guard let proposalDate else {
            return "Schedule unavailable"
        }
        return "\(proposalDate.formatted(date: .abbreviated, time: .omitted)) at \(proposalDate.formatted(date: .omitted, time: .shortened))"
    }

    private var proposalDate: Date? {
        ProposalDateTimeCodec.parse(proposal.startDateTime)
    }
}

private enum ProposalDateTimeCodec {
    static func encode(date: String, time: String) -> String? {
        let trimmedDate = date.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTime = time.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let day = dateFormatter.date(from: trimmedDate),
              let clock = timeFormatter.date(from: trimmedTime) else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: clock)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = 0
        components.timeZone = .current

        guard let composedDate = calendar.date(from: components) else {
            return nil
        }

        return internetDateTimeFormatter.string(from: composedDate)
    }

    static func parse(_ value: String) -> Date? {
        if let parsed = fractionalDateTimeFormatter.date(from: value) {
            return parsed
        }
        return internetDateTimeFormatter.date(from: value)
    }

    static func formFields(from value: String) -> (date: String, time: String)? {
        guard let parsed = parse(value) else {
            return nil
        }
        return (dateFormatter.string(from: parsed), timeFormatter.string(from: parsed))
    }

    static func formDate(from value: String) -> Date? {
        dateFormatter.date(from: value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func formTime(from value: String) -> Date? {
        timeFormatter.date(from: value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func formDateString(from date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func formTimeString(from date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private static let calendar = Calendar(identifier: .gregorian)

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let fractionalDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let internetDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct ChatAcceptedBanner: View {
    let text: String
    let canAddToCalendar: Bool
    let isAddingToCalendar: Bool
    let onAddToCalendar: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(PatchworkTheme.success)
                    .accessibilityHidden(true)
                Text(text)
                    .font(.patchworkBodyStrong)
                    .foregroundStyle(PatchworkTheme.success)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.patchworkCaption.weight(.bold))
                        .foregroundStyle(PatchworkTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(PatchworkTheme.surface.opacity(0.8), in: Circle())
                        .overlay(Circle().stroke(PatchworkTheme.stroke, lineWidth: 1))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss job status banner")
                .accessibilityIdentifier("Chat.dismissJobInProgressBanner")
            }

            if canAddToCalendar {
                Button {
                    onAddToCalendar()
                } label: {
                    Label(isAddingToCalendar ? "Adding..." : "Add to Calendar", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PatchworkSecondaryButtonStyle())
                .disabled(isAddingToCalendar)
                .accessibilityIdentifier("Chat.addToCalendarButton")
            }
        }
        .padding(14)
        .background(PatchworkTheme.success.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PatchworkTheme.success.opacity(0.24), lineWidth: 1)
        )
    }
}

private enum PatchworkCalendarError: LocalizedError {
    case accessDenied
    case missingStartDate
    case missingCalendar

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access is required to add this job."
        case .missingStartDate:
            return "This proposal does not have a valid start date."
        case .missingCalendar:
            return "No writable calendar is available on this device."
        }
    }
}

private enum PatchworkCalendarWriter {
    static func addProposalEvent(
        proposal: ProposalPayload,
        conversation: ConversationDetail?,
        job: JobDetail?
    ) async throws {
        let eventStore = EKEventStore()
        let hasAccess: Bool
        if #available(iOS 17.0, *) {
            hasAccess = try await eventStore.requestFullAccessToEvents()
        } else {
            hasAccess = try await eventStore.requestAccess(to: .event)
        }
        guard hasAccess else {
            throw PatchworkCalendarError.accessDenied
        }
        guard let startDate = ProposalDateTimeCodec.parse(proposal.startDateTime) else {
            throw PatchworkCalendarError.missingStartDate
        }
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw PatchworkCalendarError.missingCalendar
        }

        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = calendarTitle(conversation: conversation, job: job)
        event.startDate = startDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate)
            ?? startDate.addingTimeInterval(60 * 60)
        event.notes = calendarNotes(proposal: proposal, conversation: conversation, job: job)

        try eventStore.save(event, span: .thisEvent)
    }

    private static func calendarTitle(conversation: ConversationDetail?, job: JobDetail?) -> String {
        if let categoryName = job?.categoryName.trimmingCharacters(in: .whitespacesAndNewlines),
           !categoryName.isEmpty {
            return "Patchwork: \(categoryName)"
        }
        if let participantName = conversation?.participantName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !participantName.isEmpty {
            return "Patchwork job with \(participantName)"
        }
        return "Patchwork job"
    }

    private static func calendarNotes(
        proposal: ProposalPayload,
        conversation: ConversationDetail?,
        job: JobDetail?
    ) -> String {
        var lines: [String] = []
        if let participantName = conversation?.participantName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !participantName.isEmpty {
            lines.append("Conversation: \(participantName)")
        }
        let amount = PatchworkCurrency.formatted(cents: proposal.rate)
        lines.append("Rate: \(amount) \(proposal.rateType)")
        if let notes = proposal.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            lines.append("")
            lines.append(notes)
        } else if let jobNotes = job?.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !jobNotes.isEmpty {
            lines.append("")
            lines.append(jobNotes)
        }
        return lines.joined(separator: "\n")
    }
}

private struct ChatActionBar: View {
    let canShowCompleteButton: Bool
    let hasAcceptedProposal: Bool
    let onCompleteTap: () -> Void
    let onProposeTap: () -> Void

    var body: some View {
        if canShowCompleteButton {
            actionButton(
                title: "Complete Job",
                identifier: "Chat.completeJobButton",
                style: .primary,
                action: onCompleteTap
            )
        } else if !hasAcceptedProposal {
            actionButton(
                title: "Propose terms",
                identifier: "Chat.proposeTermsButton",
                style: .secondary,
                action: onProposeTap
            )
        }
    }

    private enum ActionStyle {
        case primary
        case secondary
    }

    @ViewBuilder
    private func actionButton(
        title: String,
        identifier: String,
        style: ActionStyle,
        action: @escaping () -> Void
    ) -> some View {
        let button = Button(title, action: action)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
        .padding(.horizontal, 20)

        switch style {
        case .primary:
            button.buttonStyle(PatchworkPrimaryButtonStyle())
        case .secondary:
            button.buttonStyle(PatchworkSecondaryButtonStyle())
        }
    }
}

private struct ChatComposerBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let isDisabled: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField(isDisabled ? "Messaging unavailable" : "Type a message...", text: $text, axis: .vertical)
                .font(.patchworkBody)
                .foregroundStyle(isDisabled ? PatchworkTheme.textSecondary : PatchworkTheme.textPrimary)
                .lineLimit(1 ... 5)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .disabled(isDisabled)
                .focused($isFocused)
                .accessibilityLabel("Message")
                .accessibilityIdentifier("Chat.messageField")

            Button("Send", systemImage: "arrow.up") {
                onSend()
            }
            .labelStyle(.iconOnly)
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(PatchworkTheme.heroGradient, in: Circle())
            .opacity(isDisabled ? 0.45 : 1)
            .buttonStyle(.plain)
            .disabled(isDisabled || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Send message")
            .accessibilityHint("Sends your message to this conversation.")
            .accessibilityIdentifier("Chat.sendButton")
        }
        .padding(12)
        .background(PatchworkTheme.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
    }
}

private struct ChatMessageRow: View {
    let text: String
    let time: String
    let isMine: Bool
    let localStatus: String?
    let onRetry: () -> Void

    var body: some View {
        HStack {
            if isMine { Spacer() }
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.patchworkBody)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        isMine ? PatchworkTheme.heroGradient : LinearGradient(colors: [PatchworkTheme.surface.opacity(0.96), PatchworkTheme.surfaceMuted], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .foregroundStyle(isMine ? .white : PatchworkTheme.textPrimary)
                Text(time)
                    .font(.patchworkCaption)
                    .foregroundStyle(PatchworkTheme.textSecondary)
                if localStatus == "sending" {
                    Text("Sending...")
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.textSecondary)
                } else if localStatus == "failed" {
                    Button("Failed - Retry", action: onRetry)
                        .font(.patchworkCaption)
                        .foregroundStyle(PatchworkTheme.danger)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("Chat.messageRetryButton")
                }
            }
            if !isMine { Spacer() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isMine ? "You" : "Message")
        .accessibilityValue("\(text), sent at \(time)")
    }
}

private struct CompleteJobSheet: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            PatchworkBackdrop(tint: PatchworkTheme.accent)

            PatchworkSurfaceCard {
                VStack(alignment: .leading, spacing: 20) {
                    PatchworkSectionIntro(
                        eyebrow: "Job Status",
                        title: "Complete Job",
                        message: "Mark this job as completed once both sides agree the work is done."
                    )

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            onCancel()
                        }
                        .buttonStyle(PatchworkSecondaryButtonStyle())
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Cancel completion")
                        .accessibilityIdentifier("Chat.completeJob.cancelButton")

                        Button("Complete Job") {
                            onConfirm()
                        }
                        .buttonStyle(PatchworkPrimaryButtonStyle())
                        .frame(maxWidth: .infinity)
                        .accessibilityHint("Marks this job as complete.")
                        .accessibilityIdentifier("Chat.completeJob.confirmButton")
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct ChatReportSheet: View {
    @Environment(\.dismiss) private var dismiss

    let action: ChatSafetyAction
    let participantName: String
    let onSubmit: (String) async throws -> Void

    @State private var reportText = ""
    @State private var feedbackMessage: SubscriptionFeedbackMessage?
    @State private var isSubmitting = false

    private let minReportLength = 100
    private let maxReportLength = 4000

    private var trimmedReportText: String {
        reportText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var title: String {
        action == .blockAndReport ? "Block & Report" : "Report User"
    }

    private var submitTitle: String {
        if isSubmitting {
            return "Sending..."
        }
        return action == .blockAndReport ? "Block & Report" : "Submit Report"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PatchworkSectionIntro(
                    eyebrow: "Safety",
                    title: title,
                    message: "Tell us what happened with \(participantName)."
                )

                if let feedbackMessage {
                    PatchworkInlineStatusBanner(tone: feedbackMessage.tone, text: feedbackMessage.text)
                        .accessibilityIdentifier("Chat.reportStatusBanner")
                }

                TextEditor(text: $reportText)
                    .patchworkTextEditorStyle(minHeight: 170)
                    .onChange(of: reportText) { _, newValue in
                        if newValue.count > maxReportLength {
                            reportText = String(newValue.prefix(maxReportLength))
                        }
                    }
                    .accessibilityLabel("Report details")
                    .accessibilityIdentifier("Chat.reportTextField")

                Text("\(trimmedReportText.count)/\(minReportLength) minimum")
                    .font(.patchworkCaption)
                    .foregroundStyle(trimmedReportText.count >= minReportLength ? PatchworkTheme.success : PatchworkTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityIdentifier("Chat.reportCharacterCount")

                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(PatchworkSecondaryButtonStyle())
                    .disabled(isSubmitting)

                    Button(submitTitle) {
                        Task { await submit() }
                    }
                    .buttonStyle(PatchworkPrimaryButtonStyle())
                    .disabled(isSubmitting || trimmedReportText.count < minReportLength)
                    .accessibilityIdentifier("Chat.submitReportButton")
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }

    private func submit() async {
        guard trimmedReportText.count >= minReportLength else {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: "Report must be at least \(minReportLength) characters.")
            return
        }

        isSubmitting = true
        feedbackMessage = nil
        defer { isSubmitting = false }

        do {
            try await onSubmit(trimmedReportText)
            feedbackMessage = SubscriptionFeedbackMessage(tone: .success, text: "Thanks for the report. Our team will review it.")
            try? await Task.sleep(nanoseconds: 600_000_000)
            dismiss()
        } catch {
            feedbackMessage = SubscriptionFeedbackMessage(tone: .error, text: error.localizedDescription)
        }
    }
}

private struct ProposalFormSheet: View {
    let isCounter: Bool
    @Binding var rate: String
    @Binding var rateType: String
    @Binding var date: String
    @Binding var time: String
    @Binding var notes: String
    let onCancel: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    PatchworkKeyboard.dismiss()
                }

            PatchworkBackdrop(tint: PatchworkTheme.brand)

            ScrollView {
                VStack(spacing: 18) {
                    PatchworkTopBar(title: isCounter ? "Counter Proposal" : "Propose Terms", onBack: onCancel)
                        .accessibilityIdentifier("ProposalForm.cancelButton")

                    PatchworkSurfaceCard {
                        VStack(alignment: .leading, spacing: 18) {
                            PatchworkSectionIntro(
                                eyebrow: isCounter ? "Counter offer" : "Proposal",
                                title: "Set clear terms",
                                message: "Use one clean proposal path with explicit pricing and start time."
                            )

                            Picker("Type", selection: $rateType) {
                                Text("Hourly").tag("hourly")
                                Text("Flat").tag("flat")
                            }
                            .pickerStyle(.segmented)
                            .accessibilityLabel("Rate type")
                            .accessibilityIdentifier("ProposalForm.rateType")

                            HStack(spacing: 8) {
                                Text("$")
                                    .font(.patchworkBody.weight(.semibold))
                                    .foregroundStyle(PatchworkTheme.textSecondary)
                                    .accessibilityHidden(true)

                                TextField("Rate", text: $rate)
                                    .keyboardType(.decimalPad)
                                    .accessibilityLabel("Rate amount")
                                    .accessibilityIdentifier("ProposalForm.rateField")
                            }
                            .patchworkInputFieldStyle()

                            VStack(spacing: 12) {
                                DatePicker("Date", selection: proposalDateBinding, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .patchworkInputFieldStyle()
                                    .accessibilityLabel("Start date")
                                    .accessibilityIdentifier("ProposalForm.dateField")

                                DatePicker("Time", selection: proposalTimeBinding, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                                    .patchworkInputFieldStyle()
                                    .accessibilityLabel("Start time")
                                    .accessibilityIdentifier("ProposalForm.timeField")
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes")
                                    .font(.patchworkCaption)
                                    .foregroundStyle(PatchworkTheme.textSecondary)
                                TextEditor(text: $notes)
                                    .patchworkTextEditorStyle(minHeight: 120)
                                    .accessibilityLabel("Proposal notes")
                                    .accessibilityIdentifier("ProposalForm.notesField")
                            }

                            Button(isCounter ? "Send Counter" : "Send") {
                                onSubmit()
                            }
                            .buttonStyle(PatchworkPrimaryButtonStyle())
                            .disabled(rate.isEmpty || date.isEmpty || time.isEmpty)
                            .accessibilityLabel(isCounter ? "Send counter proposal" : "Send proposal")
                            .accessibilityIdentifier("ProposalForm.submitButton")
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
        .onAppear(perform: initializePickerDefaults)
    }

    private var proposalDateBinding: Binding<Date> {
        Binding(
            get: { ProposalDateTimeCodec.formDate(from: date) ?? Date() },
            set: { date = ProposalDateTimeCodec.formDateString(from: $0) }
        )
    }

    private var proposalTimeBinding: Binding<Date> {
        Binding(
            get: { ProposalDateTimeCodec.formTime(from: time) ?? Date() },
            set: { time = ProposalDateTimeCodec.formTimeString(from: $0) }
        )
    }

    private func initializePickerDefaults() {
        let now = Date()
        if date.isEmpty {
            date = ProposalDateTimeCodec.formDateString(from: now)
        }
        if time.isEmpty {
            time = ProposalDateTimeCodec.formTimeString(from: now)
        }
    }
}

private struct ReviewFormSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var rating: Int
    @Binding var text: String
    let onSubmit: () -> Void

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
                    PatchworkTopBar(title: "Leave Review", onBack: { dismiss() })
                        .accessibilityIdentifier("ReviewForm.skipButton")

                    PatchworkSurfaceCard {
                        VStack(alignment: .leading, spacing: 18) {
                            PatchworkSectionIntro(
                                eyebrow: "Completed Job",
                                title: "Leave a thoughtful review",
                                message: "Only rate once both sides agree the work is fully complete."
                            )

                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .font(.patchworkCaption)
                                    .foregroundStyle(PatchworkTheme.warning)
                                Text("Only rate once you agree the job has been completed.")
                                    .font(.patchworkCaption)
                                    .foregroundStyle(PatchworkTheme.warning)
                            }
                            .padding(10)
                            .background(PatchworkTheme.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                            HStack(spacing: 10) {
                                ForEach(1 ... 5, id: \.self) { star in
                                    Button {
                                        rating = star
                                    } label: {
                                        Label("\(star) star", systemImage: star <= rating ? "star.fill" : "star")
                                            .labelStyle(.iconOnly)
                                            .font(.title3)
                                            .foregroundStyle(.yellow)
                                            .frame(maxWidth: .infinity, minHeight: 48)
                                            .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                                }
                            }

                            TextEditor(text: $text)
                                .patchworkTextEditorStyle(minHeight: 140)
                                .accessibilityLabel("Review details")
                                .accessibilityIdentifier("ReviewForm.textField")

                            Button("Submit") {
                                onSubmit()
                            }
                            .buttonStyle(PatchworkPrimaryButtonStyle())
                            .disabled(rating == 0 || text.trimmingCharacters(in: .whitespacesAndNewlines).count < 10)
                            .accessibilityLabel("Submit review")
                            .accessibilityIdentifier("ReviewForm.submitButton")
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
    }
}
