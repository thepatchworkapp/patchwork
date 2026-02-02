import { query } from "./_generated/server";
import { v } from "convex/values";

export const listAllUsers = query({
  args: {
    cursor: v.optional(v.string()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const limit = args.limit ?? 50;
    const query_obj = ctx.db.query("users").order("desc");

    let users;
    if (args.cursor !== undefined) {
      const cursorTime = parseInt(args.cursor);
      users = await query_obj.filter((q) => q.lt(q.field("_creationTime"), cursorTime)).take(limit + 1);
    } else {
      users = await query_obj.take(limit + 1);
    }

    const hasMore = users.length > limit;
    const result = hasMore ? users.slice(0, limit) : users;
    const nextCursor = hasMore ? result[result.length - 1]._creationTime.toString() : null;

    return {
      users: result.map((user) => ({
        _id: user._id,
        email: user.email,
        name: user.name,
        photo: user.photo,
        location: user.location,
        roles: user.roles,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      })),
      cursor: nextCursor,
    };
  },
});

export const getUserDetail = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) return null;

    const seekerProfile = await ctx.db
      .query("seekerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .first();

    const taskerProfile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .first();

    let taskerProfileWithCategories = null;
    if (taskerProfile) {
      const taskerCategories = await ctx.db
        .query("taskerCategories")
        .withIndex("by_taskerProfile", (q) => q.eq("taskerProfileId", taskerProfile._id))
        .collect();

      const categoriesWithNames = await Promise.all(
        taskerCategories.map(async (tc) => {
          const category = await ctx.db.get(tc.categoryId);
          return {
            ...tc,
            categoryName: category?.name ?? "Unknown",
            categorySlug: category?.slug ?? "unknown",
          };
        })
      );

      taskerProfileWithCategories = {
        ...taskerProfile,
        categories: categoriesWithNames,
      };
    }

    const jobsAsSeeker = await ctx.db
      .query("jobs")
      .withIndex("by_seeker", (q) => q.eq("seekerId", args.userId))
      .order("desc")
      .take(20);

    const jobsAsTasker = await ctx.db
      .query("jobs")
      .withIndex("by_tasker", (q) => q.eq("taskerId", args.userId))
      .order("desc")
      .take(20);

    const reviewsGiven = await ctx.db
      .query("reviews")
      .withIndex("by_reviewer", (q) => q.eq("reviewerId", args.userId))
      .order("desc")
      .take(20);

    const reviewsReceived = await ctx.db
      .query("reviews")
      .withIndex("by_reviewee", (q) => q.eq("revieweeId", args.userId))
      .order("desc")
      .take(20);

    const reviewsGivenEnriched = await Promise.all(
      reviewsGiven.map(async (r) => {
        const reviewee = await ctx.db.get(r.revieweeId);
        return {
          ...r,
          revieweeName: reviewee?.name ?? "Unknown",
        };
      })
    );

    const reviewsReceivedEnriched = await Promise.all(
      reviewsReceived.map(async (r) => {
        const reviewer = await ctx.db.get(r.reviewerId);
        return {
          ...r,
          reviewerName: reviewer?.name ?? "Unknown",
        };
      })
    );

    return {
      user,
      seekerProfile: seekerProfile ?? null,
      taskerProfile: taskerProfileWithCategories,
      jobsAsSeeker,
      jobsAsTasker,
      reviewsGiven: reviewsGivenEnriched,
      reviewsReceived: reviewsReceivedEnriched,
    };
  },
});
