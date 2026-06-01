import { ConvexError, v } from "convex/values";
import { mutation, query, internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";
import { paginationOptsValidator } from "convex/server";
import {
  messagesDeltaValidator,
  messagesPageValidator,
  threadWatchValidator,
} from "../lib/convex/validators";
import { getAppUserOrNull, requireAppUser } from "./authHelpers";
import {
  getTaskerProfileImageAssetDto,
  getUserPhotoImageAssetDto,
} from "./imageAssetHelpers";
import { assertUsersCanMessage } from "./moderation";
import { Doc } from "./_generated/dataModel";

type SystemMessageType =
  | "proposal_sent"
  | "proposal_accepted"
  | "proposal_declined"
  | "proposal_countered"
  | "job_completed";

export const sendMessage = mutation({
  args: {
    conversationId: v.id("conversations"),
    clientMessageId: v.optional(v.string()),
    content: v.string(),
    attachments: v.optional(v.array(v.id("_storage"))),
  },
  returns: v.id("messages"),
  handler: async (ctx, args) => {
    const { user } = await requireAppUser(ctx);

    if (args.attachments && args.attachments.length > 3) {
      throw new ConvexError("Maximum 3 attachments allowed");
    }

    // Input validation
    if (args.content.length > 5000) throw new ConvexError("Message must be 5000 characters or less");
    if (args.content.trim().length === 0) throw new ConvexError("Message cannot be empty");

    const conversation = await ctx.db.get(args.conversationId);
    if (!conversation) throw new ConvexError("Conversation not found");

    if (conversation.seekerId !== user._id && conversation.taskerId !== user._id) {
      throw new ConvexError("Not a participant in this conversation");
    }

    const recipientId = conversation.seekerId === user._id
      ? conversation.taskerId
      : conversation.seekerId;
    await assertUsersCanMessage(ctx, user._id, recipientId);

    const now = Date.now();

    const messageId = await ctx.db.insert("messages", {
      conversationId: args.conversationId,
      senderId: user._id,
      clientMessageId: args.clientMessageId,
      type: "text",
      content: args.content,
      attachments: args.attachments,
      createdAt: now,
      updatedAt: now,
    });

    const isSeeker = conversation.seekerId === user._id;
    const currentUnreadCount = isSeeker
      ? conversation.taskerUnreadCount || 0
      : conversation.seekerUnreadCount || 0;

    await ctx.db.patch(args.conversationId, {
      lastMessageAt: now,
      lastMessageId: messageId,
      lastMessagePreview: args.content.substring(0, 100),
      lastMessageSenderId: user._id,
      [isSeeker ? "taskerUnreadCount" : "seekerUnreadCount"]: currentUnreadCount + 1,
      updatedAt: now,
    });

    if (await hasActivePushToken(ctx, recipientId)) {
      await ctx.scheduler.runAfter(0, internal.notifications.sendChatNotification, {
        recipientId,
        senderId: user._id,
        conversationId: args.conversationId,
        messageId,
        title: user.name || "Patchwork",
        body: args.content,
      });
    }

    return messageId;
  },
});

export const sendProposalMessage = internalMutation({
  args: {
    conversationId: v.id("conversations"),
    senderId: v.id("users"),
    proposalId: v.id("proposals"),
    content: v.string(),
  },
  returns: v.id("messages"),
  handler: async (ctx, args) => {
    const conversation = await ctx.db.get(args.conversationId);
    if (!conversation) throw new ConvexError("Conversation not found");

    const isSeeker = conversation.seekerId === args.senderId;
    const recipientId = isSeeker ? conversation.taskerId : conversation.seekerId;
    await assertUsersCanMessage(ctx, args.senderId, recipientId);

    const now = Date.now();
    const messageId = await ctx.db.insert("messages", {
      conversationId: args.conversationId,
      senderId: args.senderId,
      type: "proposal",
      content: args.content,
      proposalId: args.proposalId,
      createdAt: now,
      updatedAt: now,
    });

    const currentUnreadCount = isSeeker
      ? conversation.taskerUnreadCount || 0
      : conversation.seekerUnreadCount || 0;

    await ctx.db.patch(args.conversationId, {
      lastMessageAt: now,
      lastMessageId: messageId,
      lastMessagePreview: "New Proposal",
      lastMessageSenderId: args.senderId,
      [isSeeker ? "taskerUnreadCount" : "seekerUnreadCount"]: currentUnreadCount + 1,
      updatedAt: now,
    });

    if (await hasActivePushToken(ctx, recipientId)) {
      const sender = await ctx.db.get(args.senderId);
      await ctx.scheduler.runAfter(0, internal.notifications.sendChatNotification, {
        recipientId,
        senderId: args.senderId,
        conversationId: args.conversationId,
        messageId,
        title: sender?.name || "Patchwork",
        body: args.content === "Counter proposal sent" ? "New counter proposal" : "New proposal",
      });
    }

    return messageId;
  },
});

export const listMessages = query({
  args: {
    conversationId: v.id("conversations"),
    paginationOpts: paginationOptsValidator,
  },
  returns: messagesPageValidator,
  handler: async (ctx, args) => {
    const session = await getAppUserOrNull(ctx);
    if (!session) {
      return { page: [], isDone: true, continueCursor: "" };
    }
    const { user } = session;

    const conversation = await ctx.db.get(args.conversationId);
    if (
      !conversation ||
      (conversation.seekerId !== user._id && conversation.taskerId !== user._id)
    ) {
      return { page: [], isDone: true, continueCursor: "" };
    }

    const messages = await ctx.db
      .query("messages")
      .withIndex("by_conversation_time", (q) =>
        q.eq("conversationId", args.conversationId)
      )
      .order("desc")
      .paginate(args.paginationOpts);

    const pageWithProposals = await hydrateMessages(ctx, messages.page);

    return {
      page: pageWithProposals,
      isDone: messages.isDone,
      continueCursor: messages.continueCursor,
    };
  },
});

export const listMessagesSince = query({
  args: {
    conversationId: v.id("conversations"),
    afterCreatedAt: v.optional(v.number()),
    afterMessageId: v.optional(v.id("messages")),
    since: v.optional(v.number()),
    limit: v.optional(v.number()),
  },
  returns: messagesDeltaValidator,
  handler: async (ctx, args) => {
    const cursor = messageCursor(args);
    const empty = {
      messages: [],
      hasMore: false,
      latestCursor: cursor.afterCreatedAt,
      latestMessageId: null,
      latestMessageAt: null,
    };
    const participant = await getParticipantConversation(ctx, args.conversationId);
    if (!participant) return empty;

    const limit = normalizeRealtimeLimit(args.limit);
    const rows = await ctx.db
      .query("messages")
      .withIndex("by_conversation_time", (q) => {
        const scoped = q.eq("conversationId", args.conversationId);
        return cursor.afterMessageId
          ? scoped.gte("createdAt", cursor.afterCreatedAt)
          : scoped.gt("createdAt", cursor.afterCreatedAt);
      })
      .order("asc")
      .take(limit + 101);

    const filteredRows = rows.filter((message) => isMessageAfterCursor(message, cursor));
    const messages = filteredRows.slice(0, limit);
    const hydrated = await hydrateMessages(ctx, messages);
    const latestMessage = messages.at(-1);
    const latestMessageId = latestMessageIdAtCursor(messages);

    return {
      messages: hydrated,
      hasMore: filteredRows.length > limit,
      latestCursor: latestMessage?.createdAt ?? cursor.afterCreatedAt,
      latestMessageId,
      latestMessageAt: latestMessage?.createdAt ?? null,
    };
  },
});

export const watchThread = query({
  args: {
    conversationId: v.id("conversations"),
    afterCreatedAt: v.optional(v.number()),
    afterMessageId: v.optional(v.id("messages")),
    since: v.optional(v.number()),
    limit: v.optional(v.number()),
  },
  returns: threadWatchValidator,
  handler: async (ctx, args) => {
    const cursor = messageCursor(args);
    const empty = {
      conversation: null,
      messages: [],
      hasMore: false,
      latestCursor: cursor.afterCreatedAt,
      latestMessageId: null,
      latestMessageAt: null,
      latestProposalUpdatedAt: null,
      latestProposal: null,
    };
    const participant = await getParticipantConversation(ctx, args.conversationId);
    if (!participant) return empty;

    const limit = normalizeRealtimeLimit(args.limit);
    const rows = await ctx.db
      .query("messages")
      .withIndex("by_conversation_time", (q) => {
        const scoped = q.eq("conversationId", args.conversationId);
        return cursor.afterMessageId
          ? scoped.gte("createdAt", cursor.afterCreatedAt)
          : scoped.gt("createdAt", cursor.afterCreatedAt);
      })
      .order("asc")
      .take(limit + 101);
    const filteredRows = rows.filter((message) => isMessageAfterCursor(message, cursor));
    const messages = filteredRows.slice(0, limit);
    const hydrated = await hydrateMessages(ctx, messages);
    const latestMessage = messages.at(-1);
    const latestMessageId = latestMessageIdAtCursor(messages);

    const latestProposal = await ctx.db
      .query("proposals")
      .withIndex("by_conversation_updatedAt", (q) =>
        q.eq("conversationId", args.conversationId).gt("updatedAt", cursor.afterCreatedAt)
      )
      .order("desc")
      .first();
    const conversation = await serializeConversationForUser(
      ctx,
      participant.conversation,
      participant.user._id
    );

    return {
      conversation,
      messages: hydrated,
      hasMore: filteredRows.length > limit,
      latestCursor: Math.max(
        latestMessage?.createdAt ?? cursor.afterCreatedAt,
        latestProposal?.updatedAt ?? cursor.afterCreatedAt
      ),
      latestMessageId,
      latestMessageAt: latestMessage?.createdAt ?? null,
      latestProposalUpdatedAt: latestProposal?.updatedAt ?? null,
      latestProposal: latestProposal ? serializeProposal(latestProposal) : null,
    };
  },
});

export const sendSystemMessage = internalMutation({
  args: {
    conversationId: v.id("conversations"),
    proposalId: v.optional(v.id("proposals")),
    systemType: v.union(
      v.literal("proposal_sent"),
      v.literal("proposal_accepted"),
      v.literal("proposal_declined"),
      v.literal("proposal_countered"),
      v.literal("job_completed")
    ),
  },
  returns: v.id("messages"),
  handler: async (ctx, args) => {
    const systemTypeMessages: Record<SystemMessageType, string> = {
      proposal_sent: "A proposal was sent",
      proposal_accepted: "The proposal was accepted",
      proposal_declined: "The proposal was declined",
      proposal_countered: "A counter proposal was sent",
      job_completed: "The job was marked as completed",
    };

    const content = systemTypeMessages[args.systemType];
    const now = Date.now();

    const conversation = await ctx.db.get(args.conversationId);
    if (!conversation) throw new ConvexError("Conversation not found");

    await assertUsersCanMessage(ctx, conversation.seekerId, conversation.taskerId);

    const messageId = await ctx.db.insert("messages", {
      conversationId: args.conversationId,
      senderId: conversation.seekerId,
      type: "system",
      content,
      proposalId: args.proposalId,
      createdAt: now,
      updatedAt: now,
    });

    return messageId;
  },
});

async function hasActivePushToken(ctx: any, userId: any) {
  const user = await ctx.db.get(userId);
  if (!user || user.settings?.notificationsEnabled === false) {
    return false;
  }

  const tokens = await ctx.db
    .query("pushTokens")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .take(MAX_PUSH_TOKEN_LOOKUP);

  return tokens.some((token: any) => !token.disabledAt);
}

const MAX_PUSH_TOKEN_LOOKUP = 20;

function normalizeRealtimeLimit(limit: number | undefined) {
  if (limit === undefined) return 50;
  if (!Number.isInteger(limit) || limit < 1) {
    throw new ConvexError("Limit must be a positive integer");
  }
  return Math.min(limit, 100);
}

function messageCursor(args: {
  afterCreatedAt?: number;
  afterMessageId?: Doc<"messages">["_id"];
  since?: number;
}) {
  return {
    afterCreatedAt: args.afterCreatedAt ?? args.since ?? 0,
    afterMessageId: args.afterMessageId,
  };
}

function isMessageAfterCursor(
  message: Doc<"messages">,
  cursor: ReturnType<typeof messageCursor>
) {
  if (message.createdAt > cursor.afterCreatedAt) return true;
  if (message.createdAt < cursor.afterCreatedAt) return false;
  if (!cursor.afterMessageId) return false;
  return String(message._id) > String(cursor.afterMessageId);
}

function latestMessageIdAtCursor(messages: Doc<"messages">[]) {
  const latestCreatedAt = messages.at(-1)?.createdAt;
  if (latestCreatedAt === undefined) return null;
  return messages
    .filter((message) => message.createdAt === latestCreatedAt)
    .map((message) => String(message._id))
    .sort()
    .at(-1) as Doc<"messages">["_id"];
}

async function getParticipantConversation(
  ctx: any,
  conversationId: Doc<"conversations">["_id"]
) {
  const session = await getAppUserOrNull(ctx);
  if (!session) return null;

  const conversation = await ctx.db.get(conversationId);
  if (
    !conversation ||
    (conversation.seekerId !== session.user._id &&
      conversation.taskerId !== session.user._id)
  ) {
    return null;
  }
  return { user: session.user, conversation };
}

async function serializeConversationForUser(
  ctx: any,
  conversation: Doc<"conversations">,
  userId: Doc<"users">["_id"]
) {
  const [seeker, tasker] = await Promise.all([
    ctx.db.get(conversation.seekerId),
    ctx.db.get(conversation.taskerId),
  ]);
  const taskerProfile = tasker
    ? await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q: any) => q.eq("userId", tasker._id))
      .unique()
    : null;

  const seekerPhotoUrl = seeker?.photo ? await ctx.storage.getUrl(seeker.photo) : null;
  const taskerPhotoUrl = tasker?.photo ? await ctx.storage.getUrl(tasker.photo) : null;
  const seekerImage = seeker ? await getUserPhotoImageAssetDto(ctx, seeker, true) : null;
  const taskerImage = tasker
    ? taskerProfile
      ? await getTaskerProfileImageAssetDto(ctx, tasker, taskerProfile, true)
      : await getUserPhotoImageAssetDto(ctx, tasker, true)
    : null;
  const participantName = conversation.seekerId === userId
    ? tasker?.name ?? "Tasker"
    : seeker?.name ?? "Seeker";
  const participantPhotoUrl = conversation.seekerId === userId
    ? taskerPhotoUrl
    : seekerPhotoUrl;
  const participantImage = conversation.seekerId === userId
    ? taskerImage
    : seekerImage;

  return {
    ...conversation,
    seekerName: seeker?.name ?? "Seeker",
    taskerName: tasker?.name ?? "Tasker",
    seekerPhotoUrl,
    taskerPhotoUrl,
    seekerImage,
    taskerImage,
    participantName,
    participantPhotoUrl,
    participantImage,
  };
}

async function hydrateMessages(ctx: any, messages: Doc<"messages">[]) {
  return await Promise.all(
    messages.map(async (msg) => {
      const proposal = msg.proposalId ? await ctx.db.get(msg.proposalId) : null;
      return {
        _id: msg._id,
        conversationId: msg.conversationId,
        senderId: msg.senderId,
        clientMessageId: msg.clientMessageId,
        type: msg.type,
        content: msg.content,
        proposalId: msg.proposalId,
        proposal: proposal ? serializeProposal(proposal) : null,
        attachments: msg.attachments,
        readAt: msg.readAt,
        createdAt: msg.createdAt,
        updatedAt: msg.updatedAt,
      };
    })
  );
}

function serializeProposal(proposal: Doc<"proposals">) {
  return {
    _id: proposal._id,
    conversationId: proposal.conversationId,
    senderId: proposal.senderId,
    receiverId: proposal.receiverId,
    clientProposalId: proposal.clientProposalId,
    jobRequestId: proposal.jobRequestId,
    rate: proposal.rate,
    rateType: proposal.rateType,
    startDateTime: proposal.startDateTime,
    notes: proposal.notes,
    status: proposal.status,
    previousProposalId: proposal.previousProposalId,
    counterProposalId: proposal.counterProposalId,
    createdAt: proposal.createdAt,
    updatedAt: proposal.updatedAt,
    expiresAt: proposal.expiresAt,
  };
}
