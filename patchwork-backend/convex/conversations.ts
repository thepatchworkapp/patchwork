import { ConvexError, v } from "convex/values";
import { mutation, query } from "./_generated/server";
import { internal } from "./_generated/api";
import { conversationValidator } from "../lib/convex/validators";
import { getAppUserOrNull, requireAppUser } from "./authHelpers";
import {
  getTaskerProfileImageAssetDto,
  getUserPhotoImageAssetDto,
} from "./imageAssetHelpers";
import { assertUsersCanMessage } from "./moderation";

export const startConversation = mutation({
  args: {
    taskerId: v.id("users"),
    initialMessage: v.optional(v.string()),
  },
  returns: v.id("conversations"),
  handler: async (ctx, args) => {
    const { user } = await requireAppUser(ctx);

    if (user._id === args.taskerId) {
      throw new ConvexError("Cannot start conversation with yourself");
    }

    const taskerUser = await ctx.db.get(args.taskerId);
    if (!taskerUser) throw new ConvexError("User not found");

    await assertUsersCanMessage(ctx, user._id, args.taskerId);

    // Input validation
    if (args.initialMessage && args.initialMessage.length > 5000) {
      throw new ConvexError("Initial message must be 5000 characters or less");
    }

    const existingConversation = await ctx.db
      .query("conversations")
      .withIndex("by_participants", (q) =>
        q.eq("seekerId", user._id).eq("taskerId", args.taskerId)
      )
      .unique();

    if (existingConversation) {
      return existingConversation._id;
    }

    const now = Date.now();

    const conversationId = await ctx.db.insert("conversations", {
      seekerId: user._id,
      taskerId: args.taskerId,
      lastMessageAt: now,
      seekerUnreadCount: 0,
      taskerUnreadCount: args.initialMessage ? 1 : 0,
      createdAt: now,
      updatedAt: now,
      lastMessagePreview: args.initialMessage,
      lastMessageSenderId: args.initialMessage ? user._id : undefined,
    });

    if (args.initialMessage) {
      const messageId = await ctx.db.insert("messages", {
        conversationId,
        senderId: user._id,
        type: "text",
        content: args.initialMessage,
        createdAt: now,
        updatedAt: now,
      });

      await ctx.db.patch(conversationId, {
        lastMessageId: messageId,
      });

      if (await hasActivePushToken(ctx, args.taskerId)) {
        await ctx.scheduler.runAfter(0, internal.notifications.sendChatNotification, {
          recipientId: args.taskerId,
          senderId: user._id,
          conversationId,
          messageId,
          title: user.name || "Patchwork",
          body: args.initialMessage,
        });
      }
    }

    return conversationId;
  },
});

export const listConversations = query({
  args: {
    role: v.optional(v.union(v.literal("seeker"), v.literal("tasker"))),
    limit: v.optional(v.number()),
  },
  returns: v.array(conversationValidator),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return [];

    const session = await getAppUserOrNull(ctx);
    if (!session) return [];
    const { user } = session;

    const limit = Math.max(1, Math.min(args.limit ?? 50, 100));

    const enrichConversation = async (
      conversation: {
        _id: any;
        seekerId: any;
        taskerId: any;
        lastMessageAt: number;
        lastMessageId?: any;
        lastMessagePreview?: string;
        lastMessageSenderId?: any;
        seekerUnreadCount: number;
        taskerUnreadCount: number;
        seekerLastReadAt?: number;
        taskerLastReadAt?: number;
        createdAt: number;
        updatedAt: number;
      },
      roleHint?: "seeker" | "tasker"
    ) => {
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

      const participantName = roleHint === "seeker"
        ? tasker?.name ?? "Tasker"
        : roleHint === "tasker"
          ? seeker?.name ?? "Seeker"
          : null;

      const participantPhotoUrl = roleHint === "seeker"
        ? taskerPhotoUrl
        : roleHint === "tasker"
          ? seekerPhotoUrl
          : null;
      const participantImage = roleHint === "seeker"
        ? taskerImage
        : roleHint === "tasker"
          ? seekerImage
          : null;

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
    };

    if (args.role === "seeker") {
      const rows = await ctx.db
        .query("conversations")
        .withIndex("by_seeker_lastMessage", (q) => q.eq("seekerId", user._id))
        .order("desc")
        .take(limit);

      return await Promise.all(rows.map((row) => enrichConversation(row, "seeker")));
    }

    if (args.role === "tasker") {
      const rows = await ctx.db
        .query("conversations")
        .withIndex("by_tasker_lastMessage", (q) => q.eq("taskerId", user._id))
        .order("desc")
        .take(limit);
      const visibleRows = await filterTaskerInboxRows(ctx, rows);

      return await Promise.all(visibleRows.map((row) => enrichConversation(row, "tasker")));
    }

    const asSeekerConversations = await ctx.db
      .query("conversations")
      .withIndex("by_seeker_lastMessage", (q) => q.eq("seekerId", user._id))
      .order("desc")
      .take(limit);

    const asTaskerConversations = await ctx.db
      .query("conversations")
      .withIndex("by_tasker_lastMessage", (q) => q.eq("taskerId", user._id))
      .order("desc")
      .take(limit);

    const visibleAsTaskerConversations = await filterTaskerInboxRows(ctx, asTaskerConversations);

    const allConversations = [...asSeekerConversations, ...visibleAsTaskerConversations];

    allConversations.sort((a, b) => b.lastMessageAt - a.lastMessageAt);

    const topConversations = allConversations.slice(0, limit);
    return await Promise.all(topConversations.map((row) => enrichConversation(row)));
  },
});

export const getConversation = query({
  args: {
    conversationId: v.id("conversations"),
  },
  returns: v.union(conversationValidator, v.null()),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return null;

    const session = await getAppUserOrNull(ctx);
    if (!session) return null;
    const { user } = session;

    const conversation = await ctx.db.get(args.conversationId);
    if (
      !conversation ||
      (conversation.seekerId !== user._id && conversation.taskerId !== user._id)
    ) {
      return null;
    }

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
    const participantName = conversation.seekerId === user._id
      ? tasker?.name ?? "Tasker"
      : seeker?.name ?? "Seeker";
    const participantPhotoUrl = conversation.seekerId === user._id
      ? taskerPhotoUrl
      : seekerPhotoUrl;
    const participantImage = conversation.seekerId === user._id
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
  },
});

export const markAsRead = mutation({
  args: {
    conversationId: v.id("conversations"),
  },
  returns: v.object({ success: v.boolean() }),
  handler: async (ctx, args) => {
    const { user } = await requireAppUser(ctx);

    const conversation = await ctx.db.get(args.conversationId);
    if (!conversation) throw new ConvexError("Conversation not found");

    const now = Date.now();

    if (conversation.seekerId === user._id) {
      await ctx.db.patch(args.conversationId, {
        seekerUnreadCount: 0,
        seekerLastReadAt: now,
        updatedAt: now,
      });
    } else if (conversation.taskerId === user._id) {
      await ctx.db.patch(args.conversationId, {
        taskerUnreadCount: 0,
        taskerLastReadAt: now,
        updatedAt: now,
      });
    } else {
      throw new ConvexError("Not a participant in this conversation");
    }

    return { success: true };
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

async function filterTaskerInboxRows<
  T extends {
    _id: any;
    lastMessageId?: any;
  },
>(ctx: any, rows: T[]): Promise<T[]> {
  const visibleRows: T[] = [];

  for (const row of rows) {
    if (await hasTaskerVisibleActivity(ctx, row)) {
      visibleRows.push(row);
    }
  }

  return visibleRows;
}

async function hasTaskerVisibleActivity(
  ctx: any,
  conversation: {
    _id: any;
    lastMessageId?: any;
  }
): Promise<boolean> {
  if (conversation.lastMessageId) {
    return true;
  }

  const proposal = await ctx.db
    .query("proposals")
    .withIndex("by_conversation", (q: any) => q.eq("conversationId", conversation._id))
    .first();

  return proposal !== null;
}

const MAX_PUSH_TOKEN_LOOKUP = 20;
