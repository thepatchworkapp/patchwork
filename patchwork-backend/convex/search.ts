import { query } from "./_generated/server";
import { ConvexError, v } from "convex/values";
import { Doc } from "./_generated/dataModel";
import { taskerGeo } from "./geospatial";
import { buildTaskerSummaryDto } from "../lib/convex/dtoTaskers";
import { getEffectiveGhostMode, hasActiveSubscription } from "../lib/convex/subscriptionState";
import { searchTaskerResultValidator } from "../lib/convex/validators";
import { getAppUserOrNull } from "./authHelpers";

const MAX_GEO_RESULTS = 100;
const DEFAULT_GEO_RESULTS = 50;

export const searchTaskers = query({
  args: {
    categorySlug: v.optional(v.string()),
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

    let category: Doc<"categories"> | null = null;
    if (args.categorySlug) {
      category = await ctx.db
        .query("categories")
        .withIndex("by_slug", (q) => q.eq("slug", args.categorySlug!))
        .unique();
      
      if (!category) {
        return [];
      }
    }

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
      let currentCategory: Doc<"categories"> | null = category;
      
      if (currentCategory) {
        categoryData = await ctx.db
          .query("taskerCategories")
          .withIndex("by_taskerProfile_category", (q) =>
            q.eq("taskerProfileId", profile._id).eq("categoryId", currentCategory!._id)
          )
          .unique();

        if (!categoryData) {
          continue;
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
        if (!currentCategory) {
          continue;
        }
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

function formatDistance(distanceKm: number): string {
  return `${distanceKm.toFixed(1)} km`;
}
