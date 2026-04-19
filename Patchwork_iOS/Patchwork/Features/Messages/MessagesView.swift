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
                                    NavigationLink {
                                        ChatView(conversationId: conversation.id)
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
            message: isSearchEmptyState ? "Try searching for a different name or message preview." : "Start a conversation from discovery or respond to a seeker to see your inbox come to life."
        )
        .frame(maxWidth: .infinity)
    }

    private func conversationRow(_ conversation: ConversationSummary) -> some View {
        let unread = unreadCount(for: conversation)
        let participantName = conversation.participantName ?? "Conversation"
        let preview = conversation.lastMessagePreview ?? "No messages yet"
        let timeLabel = conversationTimestampLabel(conversation.lastMessageAt)
        let roleLabel = activeRole == "tasker" ? "Tasker" : "Seeker"
        return HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: URL(string: conversation.participantPhotoUrl ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                PatchworkTheme.stroke
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

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss

    let conversationId: ConvexID

    @State private var messages: [ChatMessage] = []
    @State private var cursor: String?
    @State private var canLoadMore = false
    @State private var isLoading = false
    @State private var text = ""

    @State private var conversation: ConversationDetail?
    @State private var job: JobDetail?
    @State private var canReview = false

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

                if canLoadMore {
                    Button("Load older messages") {
                        Task { await loadMessages(loadMore: true) }
                    }
                    .buttonStyle(PatchworkSecondaryButtonStyle())
                    .padding(.horizontal, 20)
                    .accessibilityIdentifier("Chat.loadOlderButton")
                }

                if hasAcceptedProposal {
                    ChatAcceptedBanner(text: job?.status == "completed" ? "Job completed" : "Job in progress")
                        .padding(.horizontal, 20)
                        .accessibilityIdentifier("Chat.jobInProgressBanner")
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
                    .onChange(of: messages.last?.id) { _, lastMessageID in
                        guard let lastMessageID else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastMessageID, anchor: .bottom)
                        }
                    }
                }

                ChatActionBar(
                    canShowCompleteButton: canShowCompleteButton,
                    hasAcceptedProposal: hasAcceptedProposal,
                    onCompleteTap: { showCompleteConfirm = true },
                    onProposeTap: {
                        resetProposalForm()
                        showProposalForm = true
                    }
                )

                ChatComposerBar(
                    text: $text,
                    onSend: { Task { await send() } }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("Chat.screen.\(conversationId)")
        .task {
            await bootstrap()
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

            AsyncImage(url: URL(string: conversation?.participantPhotoUrl ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                PatchworkTheme.stroke
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
        }
        .padding(12)
        .background(PatchworkTheme.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(PatchworkTheme.stroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var hasAcceptedProposal: Bool {
        messages.contains(where: { $0.proposal?.status == "accepted" })
    }

    private var canShowCompleteButton: Bool {
        guard hasAcceptedProposal,
              let currentUser = appState.currentUser,
              let job else { return false }
        return job.status == "in_progress" && job.seekerId == currentUser.id
    }

    private func bootstrap() async {
        await appState.refreshAuthedData(client: sessionStore.client)
        await appState.loadConversation(client: sessionStore.client, conversationId: conversationId)
        conversation = appState.selectedConversation
        await markRead()
        await loadMessages(loadMore: false)
        await refreshJobState()
    }

    private func refreshJobState() async {
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
            appState.presentError(error)
        }
    }

    private func loadMessages(loadMore: Bool) async {
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
                messages = (result.page.reversed() + messages)
            } else {
                messages = result.page.reversed()
            }
            cursor = result.continueCursor.isEmpty ? nil : result.continueCursor
            canLoadMore = !result.isDone
        } catch {
            appState.presentError(error)
        }
    }

    private func send() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            _ = try await sessionStore.client.mutation(
                "messages:sendMessage",
                args: ["conversationId": conversationId, "content": trimmed]
            ) as ConvexID
            text = ""
            await loadMessages(loadMore: false)
        } catch {
            appState.presentError(error)
        }
    }

    private func submitProposal() async {
        guard let rateNumber = Double(proposalRate),
              !proposalDate.isEmpty,
              !proposalTime.isEmpty else { return }

        let cents = Int((rateNumber * 100).rounded())
        guard let startDateTime = ProposalDateTimeCodec.encode(date: proposalDate, time: proposalTime) else {
            appState.lastError = "Enter a valid proposal date and time."
            return
        }
        do {
            if let original = counteringProposal {
                _ = try await sessionStore.client.mutation(
                    "proposals:counterProposal",
                    args: [
                        "proposalId": original.id,
                        "rate": cents,
                        "rateType": proposalRateType,
                        "startDateTime": startDateTime,
                        "notes": proposalNotes,
                    ]
                ) as ConvexID
            } else {
                _ = try await sessionStore.client.mutation(
                    "proposals:sendProposal",
                    args: [
                        "conversationId": conversationId,
                        "rate": cents,
                        "rateType": proposalRateType,
                        "startDateTime": startDateTime,
                        "notes": proposalNotes,
                    ]
                ) as ConvexID
            }
            showProposalForm = false
            counteringProposal = nil
            await loadMessages(loadMore: false)
        } catch {
            appState.presentError(error)
        }
    }

    private func accept(proposal: ProposalPayload) async {
        do {
            struct JobCreateResult: Decodable {
                let jobId: ConvexID
            }
            _ = try await sessionStore.client.mutation("proposals:acceptProposal", args: ["proposalId": proposal.id]) as JobCreateResult
            await loadMessages(loadMore: false)
            await appState.loadConversation(client: sessionStore.client, conversationId: conversationId)
            conversation = appState.selectedConversation
            await refreshJobState()
        } catch {
            appState.presentError(error)
        }
    }

    private func decline(proposal: ProposalPayload) async {
        do {
            _ = try await sessionStore.client.mutation("proposals:declineProposal", args: ["proposalId": proposal.id]) as ConvexID
            await loadMessages(loadMore: false)
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

    private func markRead() async {
        do {
            struct ReadResult: Decodable {
                let success: Bool
            }
            _ = try await sessionStore.client.mutation(
                "conversations:markAsRead",
                args: ["conversationId": conversationId]
            ) as ReadResult
        } catch {
            appState.presentError(error)
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
                onAccept: { Task { await accept(proposal: proposal) } },
                onDecline: { Task { await decline(proposal: proposal) } },
                onCounter: {
                    primeCounterForm(proposal)
                    showProposalForm = true
                }
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
                isMine: isMyMessage(message)
            )
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
    let onAccept: () -> Void
    let onDecline: () -> Void
    let onCounter: () -> Void

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
        let amount = (Double(proposal.rate) / 100).formatted(.number.precision(.fractionLength(2)))
        return "$\(amount)/\(proposal.rateType)"
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

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(PatchworkTheme.success)
                .accessibilityHidden(true)
            Text(text)
                .font(.patchworkBodyStrong)
                .foregroundStyle(PatchworkTheme.success)
            Spacer()
        }
        .padding(14)
        .background(PatchworkTheme.success.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PatchworkTheme.success.opacity(0.24), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
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
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $text, axis: .vertical)
                .font(.patchworkBody)
                .foregroundStyle(PatchworkTheme.textPrimary)
                .lineLimit(1 ... 5)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(PatchworkTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityLabel("Message")
                .accessibilityIdentifier("Chat.messageField")

            Button("Send", systemImage: "arrow.up") {
                onSend()
            }
            .labelStyle(.iconOnly)
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(PatchworkTheme.heroGradient, in: Circle())
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

                            TextField("Rate", text: $rate)
                                .keyboardType(.decimalPad)
                                .patchworkInputFieldStyle()
                                .accessibilityLabel("Rate amount")
                                .accessibilityIdentifier("ProposalForm.rateField")

                            HStack(spacing: 12) {
                                TextField("Date (YYYY-MM-DD)", text: $date)
                                    .patchworkInputFieldStyle()
                                    .accessibilityLabel("Start date")
                                    .accessibilityIdentifier("ProposalForm.dateField")

                                TextField("Time (HH:MM)", text: $time)
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
        .patchworkKeyboardDismissToolbar()
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
        .patchworkKeyboardDismissToolbar()
    }
}
