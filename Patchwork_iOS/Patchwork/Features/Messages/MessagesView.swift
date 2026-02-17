import SwiftUI

struct MessagesView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

    @State private var activeRole = "seeker"

    var body: some View {
        VStack(spacing: 0) {
            Picker("Role", selection: $activeRole) {
                Text("Seeker").tag("seeker")
                Text("Tasker").tag("tasker")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .accessibilityIdentifier("Messages.roleTabs")

            if activeRole == "tasker", appState.currentUser?.roles?.isTasker != true {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Become a Tasker")
                        .font(.title3.bold())
                    Text("Enable tasker mode to receive incoming job requests and send proposals.")
                        .foregroundStyle(.secondary)
                    Button("Continue") {
                        appState.selectedTab = .profile
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("Messages.taskerSignupContinueButton")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            } else {
                List(appState.conversations) { conversation in
                    NavigationLink {
                        ChatView(conversationId: conversation.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conversation.participantName ?? "Conversation")
                                    .font(.headline)
                                Text(conversation.lastMessagePreview ?? "No messages yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if unreadCount(for: conversation) > 0 {
                                Text("\(unreadCount(for: conversation))")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.indigo, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .accessibilityIdentifier("Messages.row.\(conversation.id)")
                }
            }
        }
        .navigationTitle("Messages")
        .task {
            activeRole = appState.conversationRole
            await appState.refreshConversations(client: sessionStore.client, role: activeRole)
        }
        .onChange(of: activeRole) { _, role in
            Task { await appState.refreshConversations(client: sessionStore.client, role: role) }
        }
    }

    private func unreadCount(for conversation: ConversationSummary) -> Int {
        activeRole == "tasker" ? (conversation.taskerUnreadCount ?? 0) : (conversation.seekerUnreadCount ?? 0)
    }
}

private struct PaginationOptions: Codable {
    let numItems: Int
    let cursor: String?
    let id: Int
}

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(SessionStore.self) private var sessionStore

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
        VStack(spacing: 0) {
            if canLoadMore {
                Button("Load older messages") {
                    Task { await loadMessages(loadMore: true) }
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
                .accessibilityIdentifier("Chat.loadOlderButton")
            }

            if hasAcceptedProposal {
                ChatAcceptedBanner(text: job?.status == "completed" ? "Job completed" : "Job in progress")
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("Chat.jobInProgressBanner")
            }

            List(messages) { message in
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
                    .listRowSeparator(.hidden)
                } else if message.type == "system" {
                    Text(message.content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowSeparator(.hidden)
                } else {
                    ChatMessageRow(
                        text: message.content,
                        time: timeLabel(message.createdAt),
                        isMine: isMyMessage(message)
                    )
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)

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
        }
        .navigationTitle(conversation?.participantName ?? "Chat")
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
        }
        .sheet(isPresented: $showReviewForm) {
            ReviewFormSheet(
                rating: $reviewRating,
                text: $reviewText,
                onSubmit: { Task { await submitReview() } }
            )
        }
        .sheet(isPresented: $showCompleteConfirm) {
            CompleteJobSheet(
                onCancel: { showCompleteConfirm = false },
                onConfirm: {
                    showCompleteConfirm = false
                    Task { await completeJob() }
                }
            )
        }
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
                async let jobCall: JobDetail? = sessionStore.client.query("jobs:getJob", args: ["jobId": jobId])
                async let canReviewCall: Bool = sessionStore.client.query("reviews:canReview", args: ["jobId": jobId])
                job = try await jobCall
                canReview = try await canReviewCall
            }
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func loadMessages(loadMore: Bool) async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let options = PaginationOptions(numItems: 25, cursor: loadMore ? cursor : nil, id: Int.random(in: 1000 ... 9999))
            let data = try JSONEncoder().encode(options)
            let optionsObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
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
            appState.lastError = error.localizedDescription
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
            appState.lastError = error.localizedDescription
        }
    }

    private func submitProposal() async {
        guard let rateNumber = Double(proposalRate),
              !proposalDate.isEmpty,
              !proposalTime.isEmpty else { return }

        let cents = Int((rateNumber * 100).rounded())
        let startDateTime = "\(proposalDate)T\(proposalTime)"
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
            appState.lastError = error.localizedDescription
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
            appState.lastError = error.localizedDescription
        }
    }

    private func decline(proposal: ProposalPayload) async {
        do {
            _ = try await sessionStore.client.mutation("proposals:declineProposal", args: ["proposalId": proposal.id]) as ConvexID
            await loadMessages(loadMore: false)
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func completeJob() async {
        guard let job else { return }
        do {
            struct JobCompleteResult: Decodable {
                let jobId: ConvexID
            }
            _ = try await sessionStore.client.mutation("jobs:completeJob", args: ["jobId": job.id]) as JobCompleteResult
            await refreshJobState()
            if canReview {
                showReviewForm = true
            }
        } catch {
            appState.lastError = error.localizedDescription
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
            await refreshJobState()
        } catch {
            appState.lastError = error.localizedDescription
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
            appState.lastError = error.localizedDescription
        }
    }

    private func isMyMessage(_ message: ChatMessage) -> Bool {
        message.senderId == appState.currentUser?.id
    }

    private func timeLabel(_ millis: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func primeCounterForm(_ proposal: ProposalPayload) {
        counteringProposal = proposal
        proposalRate = String(format: "%.2f", Double(proposal.rate) / 100)
        proposalRateType = proposal.rateType
        let parts = proposal.startDateTime.split(separator: "T", maxSplits: 1).map(String.init)
        proposalDate = parts.first ?? ""
        proposalTime = parts.count > 1 ? String(parts[1].prefix(5)) : ""
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
                Text("$\(String(format: "%.2f", Double(proposal.rate) / 100))/\(proposal.rateType)")
                    .font(.headline)
                Spacer()
                proposalStatus
            }

            Text("\(startDateLabel) at \(startTimeLabel)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let notes = proposal.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
            }

            if canActOnProposal {
                HStack {
                    Button("Decline", action: onDecline)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("Chat.proposal.declineButton")
                    Button("Counter", action: onCounter)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("Chat.proposal.counterButton")
                    Button("Accept", action: onAccept)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("Chat.proposal.acceptButton")
                }
                .accessibilityIdentifier("Chat.proposalActions")
            }
        }
        .padding(12)
        .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
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
            statusPill(title: "Accepted", color: .green)
        case "declined":
            statusPill(title: "Declined", color: .secondary)
        case "countered":
            statusPill(title: "Countered", color: .secondary)
        default:
            statusPill(title: "Pending", color: .orange)
        }
    }

    private func statusPill(title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var startDateLabel: String {
        proposalDate?.formatted(date: .abbreviated, time: .omitted) ?? proposal.startDateTime
    }

    private var startTimeLabel: String {
        proposalDate?.formatted(date: .omitted, time: .shortened) ?? "TBD"
    }

    private var proposalDate: Date? {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        if let parsed = parser.date(from: proposal.startDateTime) {
            return parsed
        }

        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return fallback.date(from: proposal.startDateTime)
    }
}

private struct ChatAcceptedBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.green)
            Spacer()
        }
        .padding(10)
        .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct ChatActionBar: View {
    let canShowCompleteButton: Bool
    let hasAcceptedProposal: Bool
    let onCompleteTap: () -> Void
    let onProposeTap: () -> Void

    var body: some View {
        if canShowCompleteButton {
            Button("Complete Job") {
                onCompleteTap()
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            .accessibilityIdentifier("Chat.completeJobButton")
        } else if !hasAcceptedProposal {
            Button("Propose terms") {
                onProposeTap()
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            .accessibilityIdentifier("Chat.proposeTermsButton")
        }
    }
}

private struct ChatComposerBar: View {
    @Binding var text: String
    let onSend: () -> Void

    var body: some View {
        HStack {
            Button {
            } label: {
                Image(systemName: "paperclip")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("Chat.attachmentButton")

            TextField("Type a message...", text: $text)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("Chat.messageField")
            Button("Send") {
                onSend()
            }
            .buttonStyle(.borderedProminent)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("Chat.sendButton")
        }
        .padding()
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
                    .padding(10)
                    .background(isMine ? Color.indigo : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(isMine ? .white : .primary)
                Text(time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !isMine { Spacer() }
        }
    }
}

private struct CompleteJobSheet: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Are you sure you want to mark this job as completed?")
                    .font(.body)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("Chat.completeJob.cancelButton")

                    Button("Complete Job") {
                        onConfirm()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("Chat.completeJob.confirmButton")
                }
            }
            .padding(20)
            .navigationTitle("Complete Job")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(220)])
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
        NavigationStack {
            Form {
                Section("Rate") {
                    Picker("Type", selection: $rateType) {
                        Text("Hourly").tag("hourly")
                        Text("Flat").tag("flat")
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("ProposalForm.rateType")

                    TextField("Rate", text: $rate)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("ProposalForm.rateField")
                }

                Section("Start") {
                    TextField("Date (YYYY-MM-DD)", text: $date)
                        .accessibilityIdentifier("ProposalForm.dateField")
                    TextField("Time (HH:MM)", text: $time)
                        .accessibilityIdentifier("ProposalForm.timeField")
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .accessibilityIdentifier("ProposalForm.notesField")
                }
            }
            .navigationTitle(isCounter ? "Counter Proposal" : "Propose Terms")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("ProposalForm.cancelButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isCounter ? "Send Counter" : "Send") {
                        onSubmit()
                    }
                    .disabled(rate.isEmpty || date.isEmpty || time.isEmpty)
                    .accessibilityIdentifier("ProposalForm.submitButton")
                }
            }
        }
    }
}

private struct ReviewFormSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var rating: Int
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Rating") {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("Only rate once you agree the job has been completed.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                    HStack {
                        ForEach(1 ... 5, id: \.self) { star in
                            Button {
                                rating = star
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .foregroundStyle(.yellow)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Review") {
                    TextEditor(text: $text)
                        .frame(minHeight: 120)
                        .accessibilityIdentifier("ReviewForm.textField")
                }
            }
            .navigationTitle("Review Job")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") {
                        dismiss()
                    }
                    .accessibilityIdentifier("ReviewForm.skipButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        onSubmit()
                    }
                    .disabled(rating == 0 || text.trimmingCharacters(in: .whitespacesAndNewlines).count < 10)
                    .accessibilityIdentifier("ReviewForm.submitButton")
                }
            }
        }
    }
}
