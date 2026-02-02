import { v } from "convex/values";
import { mutation, query, internalMutation } from "./_generated/server";
import { paginationOptsValidator } from "convex/server";

type SystemMessageType =
  | "proposal_sent"
  | "proposal_accepted"
  | "proposal_declined"
  | "proposal_countered"
  | "job_completed";

export const sendMessage = mutation({
  args: {
    conversationId: v.id("conversations"),
    content: v.string(),
    attachments: v.optional(v.array(v.id("_storage"))),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    if (!user) throw new Error("User not found");

    if (args.attachments && args.attachments.length > 3) {
      throw new Error("Maximum 3 attachments allowed");
    }

    const conversation = await ctx.db.get(args.conversationId);
    if (!conversation) throw new Error("Conversation not found");

    const now = Date.now();

    const messageId = await ctx.db.insert("messages", {
      conversationId: args.conversationId,
      senderId: user._id,
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
  handler: async (ctx, args) => {
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

    const conversation = await ctx.db.get(args.conversationId);
    if (!conversation) throw new Error("Conversation not found");

    const isSeeker = conversation.seekerId === args.senderId;
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

    return messageId;
  },
});

export const listMessages = query({
  args: {
    conversationId: v.id("conversations"),
    paginationOpts: v.optional(paginationOptsValidator),
  },
  handler: async (ctx, args) => {
    const messages = await ctx.db
      .query("messages")
      .withIndex("by_conversation_time", (q) =>
        q.eq("conversationId", args.conversationId)
      )
      .order("desc")
      .collect();
    
    const paginationOpts = args.paginationOpts ?? { numItems: 25 };
    const numItems = paginationOpts.numItems;
    const cursor = 'cursor' in paginationOpts ? paginationOpts.cursor : null;
    
    let startIndex = 0;
    if (cursor !== null) {
      const cursorIndex = messages.findIndex((m) => m._id === cursor);
      startIndex = cursorIndex >= 0 ? cursorIndex + 1 : messages.length;
    }
    
    const page = messages.slice(startIndex, startIndex + numItems);
    const isDone = startIndex + numItems >= messages.length;
    const continueCursor = isDone ? undefined : page[page.length - 1]?._id;
    
    const pageWithProposals = await Promise.all(
      page.map(async (msg) => {
        if (msg.proposalId) {
          const proposal = await ctx.db.get(msg.proposalId);
          return { ...msg, proposal };
        }
        return { ...msg, proposal: null };
      })
    );

    return {
      page: pageWithProposals,
      isDone,
      continueCursor,
    };
  },
});

export const sendSystemMessage = internalMutation({
  args: {
    conversationId: v.id("conversations"),
    systemType: v.union(
      v.literal("proposal_sent"),
      v.literal("proposal_accepted"),
      v.literal("proposal_declined"),
      v.literal("proposal_countered"),
      v.literal("job_completed")
    ),
  },
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
    if (!conversation) throw new Error("Conversation not found");

    const messageId = await ctx.db.insert("messages", {
      conversationId: args.conversationId,
      senderId: conversation.seekerId,
      type: "system",
      content,
      createdAt: now,
      updatedAt: now,
    });

    return messageId;
  },
});
