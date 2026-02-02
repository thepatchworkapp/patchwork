import { v } from "convex/values";
import { mutation } from "./_generated/server";
import { internal } from "./_generated/api";
import { Id } from "./_generated/dataModel";

export const sendProposal = mutation({
  args: {
    conversationId: v.id("conversations"),
    rate: v.number(),
    rateType: v.union(v.literal("hourly"), v.literal("flat")),
    startDateTime: v.string(),
    notes: v.optional(v.string()),
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

    const receiverId =
      conversation.seekerId === user._id
        ? conversation.taskerId
        : conversation.seekerId;

    const now = Date.now();

    const proposalId = await ctx.db.insert("proposals", {
      conversationId: args.conversationId,
      senderId: user._id,
      receiverId,
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

    return proposalId;
  },
});

export const acceptProposal = mutation({
  args: {
    proposalId: v.id("proposals"),
  },
  handler: async (ctx, args): Promise<{ jobId: Id<"jobs"> }> => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    if (!user) throw new Error("User not found");

    const proposal = await ctx.db.get(args.proposalId);
    if (!proposal) throw new Error("Proposal not found");

    if (proposal.receiverId !== user._id) {
      throw new Error("Only the proposal receiver can accept");
    }

    if (proposal.status !== "pending") {
      throw new Error("Proposal is not in pending status");
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
      systemType: "proposal_accepted",
    });

    return { jobId };
  },
});

export const declineProposal = mutation({
  args: {
    proposalId: v.id("proposals"),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    if (!user) throw new Error("User not found");

    const proposal = await ctx.db.get(args.proposalId);
    if (!proposal) throw new Error("Proposal not found");

    if (proposal.receiverId !== user._id) {
      throw new Error("Only the proposal receiver can decline");
    }

    const now = Date.now();

    await ctx.db.patch(args.proposalId, {
      status: "declined",
      updatedAt: now,
    });

    await ctx.runMutation(internal.messages.sendSystemMessage, {
      conversationId: proposal.conversationId,
      systemType: "proposal_declined",
    });

    return args.proposalId;
  },
});

export const counterProposal = mutation({
  args: {
    proposalId: v.id("proposals"),
    rate: v.number(),
    rateType: v.union(v.literal("hourly"), v.literal("flat")),
    startDateTime: v.string(),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    if (!user) throw new Error("User not found");

    const originalProposal = await ctx.db.get(args.proposalId);
    if (!originalProposal) throw new Error("Proposal not found");

    if (originalProposal.receiverId !== user._id) {
      throw new Error("Only the proposal receiver can counter");
    }

    const now = Date.now();

    await ctx.db.patch(args.proposalId, {
      status: "countered",
      updatedAt: now,
    });

    const counterProposalId = await ctx.db.insert("proposals", {
      conversationId: originalProposal.conversationId,
      senderId: user._id,
      receiverId: originalProposal.senderId,
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

    return counterProposalId;
  },
});
