import { query } from "./_generated/server";
import { v } from "convex/values";

function getAdminEmailAllowlist(): Set<string> {
  // Support both ADMIN_EMAILS (comma-separated) and legacy ADMIN_EMAIL (single).
  const raw =
    process.env.ADMIN_EMAILS ||
    process.env.ADMIN_EMAIL ||
    "";
  const emails = raw
    .split(",")
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
  return new Set(emails);
}

const ADMIN_EMAILS = getAdminEmailAllowlist();

async function requireAdmin(ctx: any): Promise<boolean> {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) return false;
  return ADMIN_EMAILS.has((identity.email || "").toLowerCase());
}

export const listAllUsers = query({
  args: {
    cursor: v.optional(v.string()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    if (!(await requireAdmin(ctx))) {
      return { users: [], cursor: null };
    }

    const limit = args.limit ?? 50;
    const query_obj = ctx.db.query("users").order("desc");

    const getUsersBeforeCursor = async (cursor: string) => {
      return await query_obj
        .filter((q) => q.lt(q.field("_creationTime"), Number(cursor)))
        .take(limit + 1);
    };

    const users =
      args.cursor !== undefined
        ? await getUsersBeforeCursor(args.cursor)
        : await query_obj.take(limit + 1);

    const hasMore = users.length > limit;
    const result = hasMore ? users.slice(0, limit) : users;
    const nextCursor = hasMore ? result[result.length - 1]._creationTime.toString() : null;

    return {
      users: await Promise.all(
        result.map(async (user) => {
          const photoUrl = user.photo ? await ctx.storage.getUrl(user.photo) : null;
          return {
            _id: user._id,
            email: user.email,
            name: user.name,
            photo: user.photo,
            photoUrl,
            location: user.location,
            roles: user.roles,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt,
          };
        })
      ),
      cursor: nextCursor,
    };
  },
});

export const isAdmin = query({
  args: {},
  handler: async (ctx) => {
    return await requireAdmin(ctx);
  },
});

export const getUserDetail = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    if (!(await requireAdmin(ctx))) return null;

    const user = await ctx.db.get(args.userId);
    if (!user) return null;

    const userPhotoUrl = user.photo ? await ctx.storage.getUrl(user.photo) : null;

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
        .take(50);

      const categoriesWithNames = await Promise.all(
        taskerCategories.map(async (tc) => {
          const category = await ctx.db.get(tc.categoryId);
          const photoUrls = await Promise.all(
            // Schema caps this at 10; keep admin UI complete but bounded.
            (tc.photos ?? []).slice(0, 10).map(async (storageId) => (await ctx.storage.getUrl(storageId)) || null)
          );
          return {
            ...tc,
            categoryName: category?.name ?? "Unknown",
            categorySlug: category?.slug ?? "unknown",
            photoUrls: photoUrls.filter((u): u is string => !!u),
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
      userPhotoUrl,
      seekerProfile: seekerProfile ?? null,
      taskerProfile: taskerProfileWithCategories,
      jobsAsSeeker,
      jobsAsTasker,
      reviewsGiven: reviewsGivenEnriched,
      reviewsReceived: reviewsReceivedEnriched,
    };
  },
});
