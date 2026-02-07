import { v } from "convex/values";
import { internalMutation, mutation, query } from "./_generated/server";

type JobStatus = "pending" | "in_progress" | "completed" | "cancelled" | "disputed";

export const createJob = internalMutation({
  args: { proposalId: v.id("proposals") },
  handler: async (ctx, args) => {
    const proposal = await ctx.db.get(args.proposalId);
    if (!proposal) throw new Error("Proposal not found");

    const conversation = await ctx.db.get(proposal.conversationId);
    if (!conversation) throw new Error("Conversation not found");

    let categoryId = null;
    let categoryName = "General";
    let description = proposal.notes || "Job from proposal";

    const jobRequestId = proposal.jobRequestId ?? conversation.jobRequestId;
    if (jobRequestId) {
      const jobRequest = await ctx.db.get(jobRequestId);
      if (jobRequest) {
        categoryId = jobRequest.categoryId;
        categoryName = jobRequest.categoryName;
        description = jobRequest.description;
      }
    }

    if (!categoryId) {
      const fallbackCategory = await ctx.db.query("categories").first();
      if (!fallbackCategory) throw new Error("No categories available");
      categoryId = fallbackCategory._id;
      categoryName = fallbackCategory.name;
    }

    const jobId = await ctx.db.insert("jobs", {
      seekerId: proposal.receiverId,
      taskerId: proposal.senderId,
      requestId: jobRequestId,
      proposalId: args.proposalId,
      categoryId,
      categoryName,
      description,
      rate: proposal.rate,
      rateType: proposal.rateType,
      startDate: proposal.startDateTime,
      status: "in_progress",
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
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return null;

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    if (!user) return null;

    const job = await ctx.db.get(args.jobId);
    if (!job || (job.seekerId !== user._id && job.taskerId !== user._id)) {
      return null;
    }

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
    statusGroup: v.optional(v.union(v.literal("active"), v.literal("completed"))),
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

    const statuses: JobStatus[] | null = args.status
      ? [args.status]
      : args.statusGroup === "active"
        ? ["pending", "in_progress"]
        : args.statusGroup === "completed"
          ? ["completed"]
          : null;

    const getSeekerJobs = async () => {
      if (!statuses) {
        return await ctx.db
          .query("jobs")
          .withIndex("by_seeker_status", (q) => q.eq("seekerId", user._id))
          .order("desc")
          .take(limit);
      }

      const results = await Promise.all(
        statuses.map(async (status) => {
          return await ctx.db
            .query("jobs")
            .withIndex("by_seeker_status", (q) =>
              q.eq("seekerId", user._id).eq("status", status as JobStatus)
            )
            .order("desc")
            .take(limit);
        })
      );

      return results.flat();
    };

    const getTaskerJobs = async () => {
      if (!statuses) {
        return await ctx.db
          .query("jobs")
          .withIndex("by_tasker_status", (q) => q.eq("taskerId", user._id))
          .order("desc")
          .take(limit);
      }

      const results = await Promise.all(
        statuses.map(async (status) => {
          return await ctx.db
            .query("jobs")
            .withIndex("by_tasker_status", (q) =>
              q.eq("taskerId", user._id).eq("status", status as JobStatus)
            )
            .order("desc")
            .take(limit);
        })
      );

      return results.flat();
    };

    // Get jobs where user is seeker or tasker
    const seekerJobs = await getSeekerJobs();
    const taskerJobs = await getTaskerJobs();

    // Combine and deduplicate
    const jobMap = new Map();
    for (const job of seekerJobs) {
      jobMap.set(job._id, job);
    }
    for (const job of taskerJobs) {
      jobMap.set(job._id, job);
    }

    const sortedJobs = Array.from(jobMap.values()).sort((a, b) => b.updatedAt - a.updatedAt);

    return await Promise.all(
      sortedJobs.map(async (job) => {
        const counterpartyId = job.seekerId === user._id ? job.taskerId : job.seekerId;
        const counterparty = await ctx.db.get(counterpartyId);
        const counterpartyPhotoUrl = counterparty?.photo
          ? await ctx.storage.getUrl(counterparty.photo)
          : null;

        return {
          ...job,
          counterpartyName: counterparty?.name ?? "Tasker",
          counterpartyPhotoUrl,
        };
      })
    );
  },
});

export const completeJob = mutation({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    if (!user) throw new Error("User not found");

    const job = await ctx.db.get(args.jobId);
    if (!job) throw new Error("Job not found");

    if (job.seekerId !== user._id) {
      throw new Error("Only seeker can complete job");
    }

    if (job.status !== "in_progress") {
      throw new Error("Job must be in_progress to complete");
    }

    await ctx.db.patch(args.jobId, {
      status: "completed",
      completedDate: new Date().toISOString(),
      updatedAt: Date.now(),
    });

    return { jobId: args.jobId };
  },
});
