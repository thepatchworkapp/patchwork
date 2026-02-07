import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

export const startConversation = mutation({
  args: {
    taskerId: v.id("users"),
    initialMessage: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    if (!user) throw new Error("User not found");

    if (user._id === args.taskerId) {
      throw new Error("Cannot start conversation with yourself");
    }

    const existingConversation = await ctx.db
      .query("conversations")
      .withIndex("by_participants", (q) =>
        q.eq("seekerId", user._id).eq("taskerId", args.taskerId)
      )
      .first();

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
    }

    return conversationId;
  },
});

export const listConversations = query({
  args: {
    role: v.optional(v.union(v.literal("seeker"), v.literal("tasker"))),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return [];

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    if (!user) return [];

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

      const seekerPhotoUrl = seeker?.photo ? await ctx.storage.getUrl(seeker.photo) : null;
      const taskerPhotoUrl = tasker?.photo ? await ctx.storage.getUrl(tasker.photo) : null;

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

      return {
        ...conversation,
        seekerName: seeker?.name ?? "Seeker",
        taskerName: tasker?.name ?? "Tasker",
        seekerPhotoUrl,
        taskerPhotoUrl,
        participantName,
        participantPhotoUrl,
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

      return await Promise.all(rows.map((row) => enrichConversation(row, "tasker")));
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

    const allConversations = [...asSeekerConversations, ...asTaskerConversations];

    allConversations.sort((a, b) => b.lastMessageAt - a.lastMessageAt);

    const topConversations = allConversations.slice(0, limit);
    return await Promise.all(topConversations.map((row) => enrichConversation(row)));
  },
});

export const getConversation = query({
  args: {
    conversationId: v.id("conversations"),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return null;

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    if (!user) return null;

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

    const seekerPhotoUrl = seeker?.photo ? await ctx.storage.getUrl(seeker.photo) : null;
    const taskerPhotoUrl = tasker?.photo ? await ctx.storage.getUrl(tasker.photo) : null;
    const participantName = conversation.seekerId === user._id
      ? tasker?.name ?? "Tasker"
      : seeker?.name ?? "Seeker";
    const participantPhotoUrl = conversation.seekerId === user._id
      ? taskerPhotoUrl
      : seekerPhotoUrl;

    return {
      ...conversation,
      seekerName: seeker?.name ?? "Seeker",
      taskerName: tasker?.name ?? "Tasker",
      seekerPhotoUrl,
      taskerPhotoUrl,
      participantName,
      participantPhotoUrl,
    };
  },
});

export const markAsRead = mutation({
  args: {
    conversationId: v.id("conversations"),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    if (!user) throw new Error("User not found");

    const conversation = await ctx.db.get(args.conversationId);
    if (!conversation) throw new Error("Conversation not found");

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
      throw new Error("Not a participant in this conversation");
    }

    return { success: true };
  },
});
