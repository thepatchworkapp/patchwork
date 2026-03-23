import { ConvexError, v } from "convex/values";
import { mutation, query, internalMutation } from "./_generated/server";
import { paginationOptsValidator } from "convex/server";
import { messagesPageValidator } from "../lib/convex/validators";

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
  returns: v.id("messages"),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    if (!user) throw new ConvexError("User not found");

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
  returns: v.id("messages"),
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
    if (!conversation) throw new ConvexError("Conversation not found");

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
    paginationOpts: paginationOptsValidator,
  },
  returns: messagesPageValidator,
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      return { page: [], isDone: true, continueCursor: "" };
    }

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    if (!user) {
      return { page: [], isDone: true, continueCursor: "" };
    }

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

    const pageWithProposals = await Promise.all(
      messages.page.map(async (msg) => {
        if (msg.proposalId) {
          const proposal = await ctx.db.get(msg.proposalId);
          return {
            _id: msg._id,
            conversationId: msg.conversationId,
            senderId: msg.senderId,
            type: msg.type,
            content: msg.content,
            proposalId: msg.proposalId,
            proposal: proposal
              ? {
                  _id: proposal._id,
                  conversationId: proposal.conversationId,
                  senderId: proposal.senderId,
                  receiverId: proposal.receiverId,
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
                }
              : null,
            attachments: msg.attachments,
            readAt: msg.readAt,
            createdAt: msg.createdAt,
            updatedAt: msg.updatedAt,
          };
        }
        return {
          _id: msg._id,
          conversationId: msg.conversationId,
          senderId: msg.senderId,
          type: msg.type,
          content: msg.content,
          proposalId: msg.proposalId,
          proposal: null,
          attachments: msg.attachments,
          readAt: msg.readAt,
          createdAt: msg.createdAt,
          updatedAt: msg.updatedAt,
        };
      })
    );

    return {
      page: pageWithProposals,
      isDone: messages.isDone,
      continueCursor: messages.continueCursor,
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
