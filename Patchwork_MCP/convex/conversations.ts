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
      throw new Error("Conversation already exists");
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
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return [];

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    if (!user) return [];

    const asSeekerConversations = await ctx.db
      .query("conversations")
      .withIndex("by_seeker_lastMessage", (q) => q.eq("seekerId", user._id))
      .order("desc")
      .collect();

    const asTaskerConversations = await ctx.db
      .query("conversations")
      .withIndex("by_tasker_lastMessage", (q) => q.eq("taskerId", user._id))
      .order("desc")
      .collect();

    const allConversations = [...asSeekerConversations, ...asTaskerConversations];

    allConversations.sort((a, b) => b.lastMessageAt - a.lastMessageAt);

    return allConversations;
  },
});

export const getConversation = query({
  args: {
    conversationId: v.id("conversations"),
  },
  handler: async (ctx, args) => {
    const conversation = await ctx.db.get(args.conversationId);
    return conversation;
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
