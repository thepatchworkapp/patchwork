import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

/**
 * Internal function to update profile rating after review submission
 * Updates either taskerProfiles or seekerProfiles depending on who was reviewed
 */
async function updateProfileRating(
  ctx: any,
  revieweeId: string,
  rating: number,
  isTaskerReview: boolean
) {
  // Determine which profile table to update
  const profileTable = isTaskerReview ? "taskerProfiles" : "seekerProfiles";
  const countField = isTaskerReview ? "reviewCount" : "ratingCount";

  const profile = await ctx.db
    .query(profileTable)
    .withIndex("by_userId", (q: any) => q.eq("userId", revieweeId))
    .first();

  if (!profile) {
    throw new Error(`${profileTable} not found for user`);
  }

  const oldRating = profile.rating;
  const oldCount = profile[countField];

  // Calculate weighted average: (oldRating * oldCount + newRating) / (oldCount + 1)
  const newRating = (oldRating * oldCount + rating) / (oldCount + 1);

  // Clamp rating to 0-5 range (should never exceed, but safety check)
  const clampedRating = Math.max(0, Math.min(5, newRating));

  // Update profile atomically
  await ctx.db.patch(profile._id, {
    rating: clampedRating,
    [countField]: oldCount + 1,
    updatedAt: Date.now(),
  });
}

/**
 * Create a review for a completed job
 * Validates: job completed, caller is participant, not already reviewed, rating 1-5, text >= 10 chars
 * Updates job with review reference and aggregates rating to profile
 */
export const createReview = mutation({
  args: {
    jobId: v.id("jobs"),
    rating: v.number(),
    text: v.string(),
  },
  handler: async (ctx, args) => {
    // 1. Auth check
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();

    if (!user) throw new Error("User not found");

    // 2. Validate rating range
    if (args.rating < 1 || args.rating > 5) {
      throw new Error("Rating must be between 1 and 5");
    }

    // Validate rating is a whole number
    if (!Number.isInteger(args.rating)) {
      throw new Error("Rating must be a whole number");
    }

    // 3. Validate text length
    if (args.text.trim().length < 10) {
      throw new Error("Review text must be at least 10 characters");
    }

    if (args.text.length > 5000) {
      throw new Error("Review text must be 5000 characters or less");
    }

    // 4. Get job and validate it exists and is completed
    const job = await ctx.db.get(args.jobId);
    if (!job) throw new Error("Job not found");

    if (job.status !== "completed") {
      throw new Error("Can only review completed jobs");
    }

    // 5. Validate caller is a participant
    const isSeeker = job.seekerId === user._id;
    const isTasker = job.taskerId === user._id;

    if (!isSeeker && !isTasker) {
      throw new Error("Only job participants can leave reviews");
    }

    // 6. Check if already reviewed
    const existingReview = await ctx.db
      .query("reviews")
      .withIndex("by_job_reviewer", (q) =>
        q.eq("jobId", args.jobId).eq("reviewerId", user._id)
      )
      .first();

    if (existingReview) {
      throw new Error("You have already reviewed this job");
    }

    // 7. Validate 30-day window (if completedDate exists)
    if (job.completedDate) {
      const thirtyDaysInMs = 30 * 24 * 60 * 60 * 1000;
      const now = Date.now();
      const completedDate =
        typeof job.completedDate === "string"
          ? new Date(job.completedDate).getTime()
          : job.completedDate;

      if (now - completedDate > thirtyDaysInMs) {
        throw new Error("Review window has expired (30 days)");
      }
    }

    // 8. Determine reviewee (who is being reviewed)
    const revieweeId = isSeeker ? job.taskerId : job.seekerId;

    // 9. Insert review
    const reviewId = await ctx.db.insert("reviews", {
      jobId: args.jobId,
      reviewerId: user._id,
      revieweeId,
      rating: args.rating,
      text: args.text.trim(),
      createdAt: Date.now(),
    });

    // 10. Update job with review reference
    if (isSeeker) {
      await ctx.db.patch(args.jobId, {
        seekerReviewId: reviewId,
        updatedAt: Date.now(),
      });
    } else {
      await ctx.db.patch(args.jobId, {
        taskerReviewId: reviewId,
        updatedAt: Date.now(),
      });
    }

    // 11. Update profile rating atomically
    // If seeker is reviewing → update tasker profile
    // If tasker is reviewing → update seeker profile
    const isTaskerBeingReviewed = isSeeker;
    await updateProfileRating(
      ctx,
      revieweeId,
      args.rating,
      isTaskerBeingReviewed
    );

    return reviewId;
  },
});

/**
 * Get reviews for a job (blind review: only returns if both parties have submitted)
 */
export const getJobReviews = query({
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
    if (!job) return null;

    // Only job participants can view reviews
    if (job.seekerId !== user._id && job.taskerId !== user._id) {
      return null;
    }

    // Blind review: only show reviews if both parties have submitted
    if (!job.seekerReviewId || !job.taskerReviewId) {
      return null;
    }

    const reviews = await ctx.db
      .query("reviews")
      .withIndex("by_job", (q) => q.eq("jobId", args.jobId))
      .take(2);

    return reviews;
  },
});

/**
 * Get all reviews for a specific user (as reviewee)
 */
export const getUserReviews = query({
  args: {
    userId: v.id("users"),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const limit = Math.max(1, Math.min(args.limit ?? 50, 100));

    const reviews = await ctx.db
      .query("reviews")
      .withIndex("by_reviewee", (q) => q.eq("revieweeId", args.userId))
      .order("desc")
      .take(limit);

    return reviews;
  },
});

/**
 * Check if current user can review a job
 */
export const canReview = query({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return false;

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();

    if (!user) return false;

    const job = await ctx.db.get(args.jobId);
    if (!job || job.status !== "completed") return false;

    // Check if user is a participant
    const isParticipant =
      job.seekerId === user._id || job.taskerId === user._id;
    if (!isParticipant) return false;

    // Check if already reviewed
    const existingReview = await ctx.db
      .query("reviews")
      .withIndex("by_job_reviewer", (q) =>
        q.eq("jobId", args.jobId).eq("reviewerId", user._id)
      )
      .first();

    if (existingReview) return false;

    // Check 30-day window
    if (job.completedDate) {
      const thirtyDaysInMs = 30 * 24 * 60 * 60 * 1000;
      const now = Date.now();
      const completedDate =
        typeof job.completedDate === "string"
          ? new Date(job.completedDate).getTime()
          : job.completedDate;

      if (now - completedDate > thirtyDaysInMs) return false;
    }

    return true;
  },
});
