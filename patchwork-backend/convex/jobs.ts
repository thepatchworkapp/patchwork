import { ConvexError, v } from "convex/values";
import { internalMutation, mutation, query } from "./_generated/server";
import { Doc } from "./_generated/dataModel";
import { jobValidator, listedJobValidator } from "../lib/convex/validators";
import { getAppUserOrNull, requireAppUser } from "./authHelpers";
import {
  getTaskerProfileImageAssetDto,
  getUserPhotoImageAssetDto,
} from "./imageAssetHelpers";

type JobStatus = "pending" | "in_progress" | "completed" | "cancelled" | "disputed";
type JobRole = "seeker" | "tasker";

const normalizeLimit = (limit?: number) => Math.max(1, Math.min(limit ?? 50, 100));

const statusesForArgs = (args: { status?: JobStatus; statusGroup?: "active" | "completed" }) => {
  if (args.status) return [args.status];
  if (args.statusGroup === "active") return ["pending", "in_progress"] satisfies JobStatus[];
  if (args.statusGroup === "completed") return ["completed"] satisfies JobStatus[];
  return null;
};

const compareJobsByRecency = (a: Doc<"jobs">, b: Doc<"jobs">) => {
  if (b.updatedAt !== a.updatedAt) return b.updatedAt - a.updatedAt;
  if (b._creationTime !== a._creationTime) return b._creationTime - a._creationTime;
  return String(b._id).localeCompare(String(a._id));
};

const dedupeSortAndLimitJobs = (jobs: Doc<"jobs">[], limit: number) => {
  const jobMap = new Map<string, Doc<"jobs">>();
  for (const job of jobs) {
    jobMap.set(job._id, job);
  }

  return Array.from(jobMap.values()).sort(compareJobsByRecency).slice(0, limit);
};

export const createJob = internalMutation({
  args: { proposalId: v.id("proposals") },
  returns: v.id("jobs"),
  handler: async (ctx, args) => {
    const proposal = await ctx.db.get(args.proposalId);
    if (!proposal) throw new ConvexError("Proposal not found");

    const conversation = await ctx.db.get(proposal.conversationId);
    if (!conversation) throw new ConvexError("Conversation not found");

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
      if (!fallbackCategory) throw new ConvexError("No categories available");
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
  returns: v.union(jobValidator, v.null()),
  handler: async (ctx, args) => {
    const session = await getAppUserOrNull(ctx);
    if (!session) return null;
    const { user } = session;

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
  returns: v.array(listedJobValidator),
  handler: async (ctx, args) => {
    const session = await getAppUserOrNull(ctx);
    if (!session) return [];
    const { user } = session;

    const limit = normalizeLimit(args.limit);
    const statuses = statusesForArgs(args);

    const listJobsForRole = async (role: JobRole) => {
      if (!statuses) {
        if (role === "seeker") {
          return await ctx.db
            .query("jobs")
            .withIndex("by_seeker_updated", (q) => q.eq("seekerId", user._id))
            .order("desc")
            .take(limit);
        }

        return await ctx.db
          .query("jobs")
          .withIndex("by_tasker_updated", (q) => q.eq("taskerId", user._id))
          .order("desc")
          .take(limit);
      }

      const results = await Promise.all(
        statuses.map(async (status) => {
          if (role === "seeker") {
            return await ctx.db
              .query("jobs")
              .withIndex("by_seeker_status_updated", (q) =>
                q.eq("seekerId", user._id).eq("status", status)
              )
              .order("desc")
              .take(limit);
          }

          return await ctx.db
            .query("jobs")
            .withIndex("by_tasker_status_updated", (q) =>
              q.eq("taskerId", user._id).eq("status", status)
            )
            .order("desc")
            .take(limit);
        })
      );

      return results.flat();
    };

    const [seekerJobs, taskerJobs] = await Promise.all([
      listJobsForRole("seeker"),
      listJobsForRole("tasker"),
    ]);
    const page = dedupeSortAndLimitJobs([...seekerJobs, ...taskerJobs], limit);

    return await Promise.all(
      page.map(async (job) => {
        const counterpartyId = job.seekerId === user._id ? job.taskerId : job.seekerId;
        const counterparty = await ctx.db.get(counterpartyId);
        const counterpartyPhotoUrl = counterparty?.photo
          ? await ctx.storage.getUrl(counterparty.photo)
          : null;
        let counterpartyImage = counterparty
          ? await getUserPhotoImageAssetDto(ctx, counterparty, true)
          : null;
        if (counterparty && counterpartyId === job.taskerId) {
          const taskerProfile = await ctx.db
            .query("taskerProfiles")
            .withIndex("by_userId", (q) => q.eq("userId", counterpartyId))
            .unique();
          if (taskerProfile) {
            counterpartyImage = await getTaskerProfileImageAssetDto(
              ctx,
              counterparty,
              taskerProfile,
              true
            );
          }
        }

        return {
          ...job,
          counterpartyName: counterparty?.name ?? "Tasker",
          counterpartyPhotoUrl,
          counterpartyImage,
        };
      })
    );
  },
});

export const completeJob = mutation({
  args: { jobId: v.id("jobs") },
  returns: v.object({ jobId: v.id("jobs") }),
  handler: async (ctx, args) => {
    const { user } = await requireAppUser(ctx);

    const job = await ctx.db.get(args.jobId);
    if (!job) throw new ConvexError("Job not found");

    if (job.seekerId !== user._id) {
      throw new ConvexError("Only seeker can complete job");
    }

    if (job.status !== "in_progress") {
      throw new ConvexError("Job must be in_progress to complete");
    }

    await ctx.db.patch(args.jobId, {
      status: "completed",
      completedDate: new Date().toISOString(),
      updatedAt: Date.now(),
    });

    return { jobId: args.jobId };
  },
});
