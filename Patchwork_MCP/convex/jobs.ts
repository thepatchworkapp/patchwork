import { v } from "convex/values";
import { internalMutation, query } from "./_generated/server";

export const createJob = internalMutation({
  args: { proposalId: v.id("proposals") },
  handler: async (ctx, args) => {
    const proposal = await ctx.db.get(args.proposalId);
    if (!proposal) throw new Error("Proposal not found");

    const conversation = await ctx.db.get(proposal.conversationId);
    if (!conversation) throw new Error("Conversation not found");

    const category = await ctx.db.query("categories").first();
    if (!category) throw new Error("No categories available");

    const jobId = await ctx.db.insert("jobs", {
      seekerId: proposal.receiverId,
      taskerId: proposal.senderId,
      proposalId: args.proposalId,
      categoryId: category._id,
      categoryName: category.name,
      description: proposal.notes || "Job from proposal",
      rate: proposal.rate,
      rateType: proposal.rateType,
      startDate: proposal.startDateTime,
      status: "pending",
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await ctx.db.patch(conversation._id, {
      jobId,
      updatedAt: Date.now(),
    });

    return jobId;
  },
});

export const getJob = query({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, args) => {
    const job = await ctx.db.get(args.jobId);
    return job;
  },
});

export const listJobs = query({
  args: {
    status: v.optional(v.union(
      v.literal("pending"),
      v.literal("in_progress"),
      v.literal("completed"),
      v.literal("cancelled"),
      v.literal("disputed")
    )),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return [];

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();

    if (!user) return [];

    let query = ctx.db.query("jobs");

    // Get jobs where user is seeker or tasker
    const seekerJobs = await ctx.db
      .query("jobs")
      .withIndex("by_seeker_status", (q) =>
        args.status
          ? q.eq("seekerId", user._id).eq("status", args.status)
          : q.eq("seekerId", user._id)
      )
      .collect();

    const taskerJobs = await ctx.db
      .query("jobs")
      .withIndex("by_tasker_status", (q) =>
        args.status
          ? q.eq("taskerId", user._id).eq("status", args.status)
          : q.eq("taskerId", user._id)
      )
      .collect();

    // Combine and deduplicate
    const jobMap = new Map();
    for (const job of seekerJobs) {
      jobMap.set(job._id, job);
    }
    for (const job of taskerJobs) {
      jobMap.set(job._id, job);
    }

    return Array.from(jobMap.values());
  },
});
