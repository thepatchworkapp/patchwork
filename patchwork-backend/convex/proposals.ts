import { ConvexError, v } from "convex/values";
import { mutation } from "./_generated/server";
import { internal } from "./_generated/api";
import { Id } from "./_generated/dataModel";
import { requireAppUser } from "./authHelpers";
import { assertUsersCanMessage } from "./moderation";

export const sendProposal = mutation({
  args: {
    conversationId: v.id("conversations"),
    clientProposalId: v.optional(v.string()),
    rate: v.number(),
    rateType: v.union(v.literal("hourly"), v.literal("flat")),
    startDateTime: v.string(),
    notes: v.optional(v.string()),
  },
  returns: v.id("proposals"),
  handler: async (ctx, args) => {
    const { user } = await requireAppUser(ctx);

    // Input validation
    if (args.rate < 1 || args.rate > 100000000) throw new ConvexError("Rate must be between 1 and 1,000,000 (in cents)");
    if (args.startDateTime.length > 200) throw new ConvexError("Start date/time must be 200 characters or less");
    if (args.notes && args.notes.length > 2000) throw new ConvexError("Notes must be 2000 characters or less");

    const conversation = await ctx.db.get(args.conversationId);
    if (!conversation) throw new ConvexError("Conversation not found");

    // Verify caller is a participant in this conversation
    if (conversation.seekerId !== user._id && conversation.taskerId !== user._id) {
      throw new ConvexError("Not a participant in this conversation");
    }

    const receiverId =
      conversation.seekerId === user._id
        ? conversation.taskerId
        : conversation.seekerId;
    await assertUsersCanMessage(ctx, user._id, receiverId);

    const now = Date.now();

    const proposalId = await ctx.db.insert("proposals", {
      conversationId: args.conversationId,
      senderId: user._id,
      receiverId,
      clientProposalId: args.clientProposalId,
      jobRequestId: conversation.jobRequestId,
      rate: args.rate,
      rateType: args.rateType,
      startDateTime: args.startDateTime,
      notes: args.notes,
      status: "pending",
      createdAt: now,
      updatedAt: now,
    });

    await ctx.runMutation(internal.messages.sendProposalMessage, {
      conversationId: args.conversationId,
      senderId: user._id,
      proposalId,
      content: "Proposal sent",
    });

    await ctx.runMutation(internal.messages.sendSystemMessage, {
      conversationId: args.conversationId,
      proposalId,
      systemType: "proposal_sent",
    });

    return proposalId;
  },
});

export const acceptProposal = mutation({
  args: {
    proposalId: v.id("proposals"),
  },
  returns: v.object({ jobId: v.id("jobs") }),
  handler: async (ctx, args): Promise<{ jobId: Id<"jobs"> }> => {
    const { user } = await requireAppUser(ctx);

    const proposal = await ctx.db.get(args.proposalId);
    if (!proposal) throw new ConvexError("Proposal not found");

    if (proposal.receiverId !== user._id) {
      throw new ConvexError("Only the proposal receiver can accept");
    }
    await assertUsersCanMessage(ctx, user._id, proposal.senderId);

    if (proposal.status !== "pending") {
      throw new ConvexError("Proposal is not in pending status");
    }

    const now = Date.now();

    await ctx.db.patch(args.proposalId, {
      status: "accepted",
      updatedAt: now,
    });

    const jobId = (await ctx.runMutation(internal.jobs.createJob, {
      proposalId: args.proposalId,
    })) as Id<"jobs">;

    await ctx.runMutation(internal.messages.sendSystemMessage, {
      conversationId: proposal.conversationId,
      proposalId: args.proposalId,
      systemType: "proposal_accepted",
    });

    if (await hasActivePushToken(ctx, proposal.senderId)) {
      await ctx.scheduler.runAfter(0, internal.notifications.sendChatNotification, {
        recipientId: proposal.senderId,
        senderId: user._id,
        conversationId: proposal.conversationId,
        title: user.name || "Patchwork",
        body: "Proposal accepted",
      });
    }

    return { jobId };
  },
});

export const declineProposal = mutation({
  args: {
    proposalId: v.id("proposals"),
  },
  returns: v.id("proposals"),
  handler: async (ctx, args) => {
    const { user } = await requireAppUser(ctx);

    const proposal = await ctx.db.get(args.proposalId);
    if (!proposal) throw new ConvexError("Proposal not found");

    if (proposal.receiverId !== user._id) {
      throw new ConvexError("Only the proposal receiver can decline");
    }
    await assertUsersCanMessage(ctx, user._id, proposal.senderId);

    const now = Date.now();

    await ctx.db.patch(args.proposalId, {
      status: "declined",
      updatedAt: now,
    });

    await ctx.runMutation(internal.messages.sendSystemMessage, {
      conversationId: proposal.conversationId,
      proposalId: args.proposalId,
      systemType: "proposal_declined",
    });

    if (await hasActivePushToken(ctx, proposal.senderId)) {
      await ctx.scheduler.runAfter(0, internal.notifications.sendChatNotification, {
        recipientId: proposal.senderId,
        senderId: user._id,
        conversationId: proposal.conversationId,
        title: user.name || "Patchwork",
        body: "Proposal declined",
      });
    }

    return args.proposalId;
  },
});

export const counterProposal = mutation({
  args: {
    proposalId: v.id("proposals"),
    clientProposalId: v.optional(v.string()),
    rate: v.number(),
    rateType: v.union(v.literal("hourly"), v.literal("flat")),
    startDateTime: v.string(),
    notes: v.optional(v.string()),
  },
  returns: v.id("proposals"),
  handler: async (ctx, args) => {
    const { user } = await requireAppUser(ctx);

    // Input validation
    if (args.rate < 1 || args.rate > 100000000) throw new ConvexError("Rate must be between 1 and 1,000,000 (in cents)");
    if (args.startDateTime.length > 200) throw new ConvexError("Start date/time must be 200 characters or less");
    if (args.notes && args.notes.length > 2000) throw new ConvexError("Notes must be 2000 characters or less");

    const originalProposal = await ctx.db.get(args.proposalId);
    if (!originalProposal) throw new ConvexError("Proposal not found");

    if (originalProposal.receiverId !== user._id) {
      throw new ConvexError("Only the proposal receiver can counter");
    }
    await assertUsersCanMessage(ctx, user._id, originalProposal.senderId);

    const now = Date.now();

    await ctx.db.patch(args.proposalId, {
      status: "countered",
      updatedAt: now,
    });

    const counterProposalId = await ctx.db.insert("proposals", {
      conversationId: originalProposal.conversationId,
      senderId: user._id,
      receiverId: originalProposal.senderId,
      clientProposalId: args.clientProposalId,
      jobRequestId: originalProposal.jobRequestId,
      rate: args.rate,
      rateType: args.rateType,
      startDateTime: args.startDateTime,
      notes: args.notes,
      status: "pending",
      previousProposalId: args.proposalId,
      createdAt: now,
      updatedAt: now,
    });

    await ctx.db.patch(args.proposalId, {
      counterProposalId,
      updatedAt: now,
    });

    await ctx.runMutation(internal.messages.sendProposalMessage, {
      conversationId: originalProposal.conversationId,
      senderId: user._id,
      proposalId: counterProposalId,
      content: "Counter proposal sent",
    });

    await ctx.runMutation(internal.messages.sendSystemMessage, {
      conversationId: originalProposal.conversationId,
      proposalId: args.proposalId,
      systemType: "proposal_countered",
    });

    return counterProposalId;
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
