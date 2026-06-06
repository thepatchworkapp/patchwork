import { query } from "./_generated/server";
import { ConvexError, v } from "convex/values";
import { Doc } from "./_generated/dataModel";
import { taskerGeo } from "./geospatial";
import { buildTaskerSummaryDto } from "../lib/convex/dtoTaskers";
import { getEffectiveGhostMode, hasActivePremiumPinAccess, hasActiveSubscription } from "../lib/convex/subscriptionState";
import { searchTaskerResultValidator } from "../lib/convex/validators";
import { getAppUserOrNull } from "./authHelpers";

const MAX_GEO_RESULTS = 100;
const DEFAULT_GEO_RESULTS = 50;

export const searchTaskers = query({
  args: {
    categorySlug: v.optional(v.string()),
    categorySlugs: v.optional(v.array(v.string())),
    lat: v.number(),
    lng: v.number(),
    radiusKm: v.number(),
    limit: v.optional(v.number()),
    excludeUserId: v.optional(v.id("users")),
  },
  returns: v.array(searchTaskerResultValidator),
  handler: async (ctx, args) => {
    const session = await getAppUserOrNull(ctx);
    const includeUrls = !!session;
    const limit = Math.max(1, Math.min(args.limit ?? DEFAULT_GEO_RESULTS, MAX_GEO_RESULTS));

    // Coordinate validation
    if (args.lat < -90 || args.lat > 90) throw new ConvexError("Latitude must be between -90 and 90");
    if (args.lng < -180 || args.lng > 180) throw new ConvexError("Longitude must be between -180 and 180");
    if (args.radiusKm < 0 || args.radiusKm > 500) throw new ConvexError("Search radius must be between 0 and 500 km");

    const requestedCategorySlugs = Array.from(
      new Set([
        ...(args.categorySlugs ?? []),
        ...(args.categorySlug ? [args.categorySlug] : []),
      ].map((slug) => slug.trim()).filter((slug) => slug.length > 0))
    );
    if (args.categorySlugs !== undefined && requestedCategorySlugs.length === 0 && !args.categorySlug?.trim()) {
      return [];
    }

    const categories: Doc<"categories">[] = [];
    for (const categorySlug of requestedCategorySlugs) {
      const category = await ctx.db
        .query("categories")
        .withIndex("by_slug", (q) => q.eq("slug", categorySlug))
        .unique();

      if (!category?.isActive) {
        return [];
      }
      categories.push(category);
    }
    const categoryIds = new Set(categories.map((category) => category._id));

    const maxDistanceMeters = args.radiusKm * 1000;
    const nearbyTaskers = await taskerGeo.nearest(ctx, {
      point: {
        latitude: args.lat,
        longitude: args.lng,
      },
      limit,
      maxDistance: maxDistanceMeters,
    });

    const results = [];

    for (const geoResult of nearbyTaskers) {
      const profile = await ctx.db.get(geoResult.key);
      if (!profile) {
        continue;
      }
      if (!profile.location || !profile.locationCheckedInAt) {
        continue;
      }
      if (!profile.isOnboarded || !hasActiveSubscription(profile) || getEffectiveGhostMode(profile)) {
        continue;
      }

      // Exclude the current user's own tasker profile
      if (args.excludeUserId && profile.userId === args.excludeUserId) {
        continue;
      }

      const user = await ctx.db.get(profile.userId);
      if (!user) {
        continue;
      }

      let categoryData: Doc<"taskerCategories"> | null = null;
      let currentCategory: Doc<"categories"> | null = categories[0] ?? null;
      
      if (categoryIds.size > 0) {
        // Preserve the old by_taskerProfile_category scan order while avoiding
        // loading every category row for this profile.
        const categoriesByIndexOrder = [...categories].sort((a, b) =>
          a._id < b._id ? -1 : a._id > b._id ? 1 : 0
        );

        for (const category of categoriesByIndexOrder) {
          const candidate = await ctx.db
            .query("taskerCategories")
            .withIndex("by_taskerProfile_category", (q) =>
              q.eq("taskerProfileId", profile._id).eq("categoryId", category._id)
            )
            .first();

          if (candidate) {
            categoryData = candidate;
            currentCategory = category;
            break;
          }
        }
      } else {
        categoryData = await ctx.db
          .query("taskerCategories")
          .withIndex("by_taskerProfile_category", (q) =>
            q.eq("taskerProfileId", profile._id)
          )
          .first();

        if (!categoryData) {
          continue;
        }
        currentCategory = await ctx.db.get(categoryData.categoryId);
        if (!currentCategory?.isActive) {
          continue;
        }
      }
      if (!categoryData || !currentCategory) {
        continue;
      }

      const distanceKm = geoResult.distance / 1000;
      if (distanceKm > args.radiusKm || distanceKm > categoryData.serviceRadius) {
        continue;
      }

      results.push(await buildTaskerSummaryDto(ctx, {
        profile,
        user,
        category: currentCategory,
        categoryData,
        distance: formatDistance(distanceKm),
        completedJobs: categoryData.completedJobs,
        includeUrls,
      }));
    }

    return results;
  },
});

export const searchTaskerByPremiumPin = query({
  args: {
    pin: v.string(),
    excludeUserId: v.optional(v.id("users")),
  },
  returns: v.array(searchTaskerResultValidator),
  handler: async (ctx, args) => {
    const normalizedPin = args.pin.trim().toUpperCase();
    if (!/^[0-9A-Z]{8}$/.test(normalizedPin)) {
      return [];
    }

    const profile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_premiumPin", (q) => q.eq("premiumPin", normalizedPin))
      .first();

    if (!profile) {
      return [];
    }
    if (args.excludeUserId && profile.userId === args.excludeUserId) {
      return [];
    }
    if (
      !profile.isOnboarded ||
      !hasActivePremiumPinAccess(profile) ||
      getEffectiveGhostMode(profile) ||
      profile.premiumPin !== normalizedPin
    ) {
      return [];
    }

    const user = await ctx.db.get(profile.userId);
    if (!user) {
      return [];
    }

    const categoryData = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile_category", (q) =>
        q.eq("taskerProfileId", profile._id)
      )
      .first();
    if (!categoryData) {
      return [];
    }

    const category = await ctx.db.get(categoryData.categoryId);
    if (!category?.isActive) {
      return [];
    }

    const session = await getAppUserOrNull(ctx);
    return [
      await buildTaskerSummaryDto(ctx, {
        profile,
        user,
        category,
        categoryData,
        distance: "Premium match",
        completedJobs: categoryData.completedJobs,
        includeUrls: !!session,
      }),
    ];
  },
});

function formatDistance(distanceKm: number): string {
  return `${distanceKm.toFixed(1)} km`;
}
