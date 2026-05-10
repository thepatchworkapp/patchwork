import { mutation } from "./_generated/server";
import { ConvexError, v } from "convex/values";
import { requireAppUser } from "./authHelpers";

const MAX_SEARCH_TERM_LENGTH = 120;

function dayKeyFromTimestamp(timestamp: number): string {
  return new Date(timestamp).toISOString().slice(0, 10);
}

function normalizeSearchTerm(term: string): string {
  return term
    .trim()
    .replace(/\s+/g, " ")
    .toLowerCase();
}

const analyticsRecordResultValidator = v.object({
  recorded: v.boolean(),
  reason: v.optional(v.string()),
});

export const recordDiscoverCategorySelection = mutation({
  args: {
    categorySlug: v.string(),
  },
  returns: analyticsRecordResultValidator,
  handler: async (ctx, args) => {
    const { user } = await requireAppUser(ctx);
    const slug = args.categorySlug.trim();
    if (!slug) {
      throw new ConvexError("Category slug is required");
    }

    const category = await ctx.db
      .query("categories")
      .withIndex("by_slug", (q) => q.eq("slug", slug))
      .unique();

    if (!category) {
      throw new ConvexError("Category not found");
    }
    if (!category.isActive) {
      return { recorded: false, reason: "inactive_category" };
    }

    const now = Date.now();
    const dayKey = dayKeyFromTimestamp(now);
    const existingUserView = await ctx.db
      .query("discoverCategoryUserDailyViews")
      .withIndex("by_user_category_day", (q) =>
        q.eq("userId", user._id).eq("categoryId", category._id).eq("dayKey", dayKey)
      )
      .unique();

    if (existingUserView) {
      return { recorded: false, reason: "already_recorded_today" };
    }

    await ctx.db.insert("discoverCategoryUserDailyViews", {
      userId: user._id,
      categoryId: category._id,
      dayKey,
      createdAt: now,
    });

    const existingDailyBucket = await ctx.db
      .query("discoverCategoryDailyViews")
      .withIndex("by_category_day", (q) => q.eq("categoryId", category._id).eq("dayKey", dayKey))
      .unique();

    if (existingDailyBucket) {
      await ctx.db.patch(existingDailyBucket._id, {
        categorySlug: category.slug,
        categoryName: category.name,
        viewCount: existingDailyBucket.viewCount + 1,
        uniqueUserCount: existingDailyBucket.uniqueUserCount + 1,
        updatedAt: now,
      });
    } else {
      await ctx.db.insert("discoverCategoryDailyViews", {
        categoryId: category._id,
        categorySlug: category.slug,
        categoryName: category.name,
        dayKey,
        viewCount: 1,
        uniqueUserCount: 1,
        createdAt: now,
        updatedAt: now,
      });
    }

    return { recorded: true };
  },
});

export const recordDiscoverCategorySearchSubmit = mutation({
  args: {
    term: v.string(),
  },
  returns: analyticsRecordResultValidator,
  handler: async (ctx, args) => {
    await requireAppUser(ctx);

    const displayTerm = args.term.trim().replace(/\s+/g, " ").slice(0, MAX_SEARCH_TERM_LENGTH);
    if (!displayTerm) {
      throw new ConvexError("Search term is required");
    }

    const normalizedTerm = normalizeSearchTerm(displayTerm);
    if (!normalizedTerm) {
      throw new ConvexError("Search term is required");
    }

    const now = Date.now();
    const dayKey = dayKeyFromTimestamp(now);
    const existingDailyTerm = await ctx.db
      .query("discoverCategorySearchDailyTerms")
      .withIndex("by_term_day", (q) => q.eq("normalizedTerm", normalizedTerm).eq("dayKey", dayKey))
      .unique();

    if (existingDailyTerm) {
      await ctx.db.patch(existingDailyTerm._id, {
        displayTerm,
        searchCount: existingDailyTerm.searchCount + 1,
        updatedAt: now,
      });
    } else {
      await ctx.db.insert("discoverCategorySearchDailyTerms", {
        normalizedTerm,
        displayTerm,
        dayKey,
        searchCount: 1,
        createdAt: now,
        updatedAt: now,
      });
    }

    return { recorded: true };
  },
});

