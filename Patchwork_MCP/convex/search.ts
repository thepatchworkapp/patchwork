import { query } from "./_generated/server";
import { v } from "convex/values";
import { Doc } from "./_generated/dataModel";
import { taskerGeo } from "./geospatial";

const MAX_SERVICE_RADIUS_KM = 250;
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
  handler: async (ctx, args) => {
    const limit = Math.max(1, Math.min(args.limit ?? DEFAULT_GEO_RESULTS, MAX_GEO_RESULTS));

    // Coordinate validation
    if (args.lat < -90 || args.lat > 90) throw new Error("Latitude must be between -90 and 90");
    if (args.lng < -180 || args.lng > 180) throw new Error("Longitude must be between -180 and 180");
    if (args.radiusKm < 0 || args.radiusKm > 500) throw new Error("Search radius must be between 0 and 500 km");

    let category: Doc<"categories"> | null = null;
    if (args.categorySlug) {
      category = await ctx.db
        .query("categories")
        .withIndex("by_slug", (q) => q.eq("slug", args.categorySlug!))
        .first();
      
      if (!category) {
        return [];
      }
    }

    const maxDistanceMeters = (args.radiusKm + MAX_SERVICE_RADIUS_KM) * 1000;
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
      if (profile.ghostMode || !profile.isOnboarded) {
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
          .withIndex("by_taskerProfile", (q) =>
            q.eq("taskerProfileId", profile._id)
          )
          .filter((q) => q.eq(q.field("categoryId"), currentCategory!._id))
          .first();

        if (!categoryData) {
          continue;
        }
      } else {
        categoryData = await ctx.db
          .query("taskerCategories")
          .withIndex("by_taskerProfile", (q) =>
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

      const price = formatPrice(
        categoryData.rateType,
        categoryData.hourlyRate,
        categoryData.fixedRate
      );

      const avatarUrl = user.photo ? await ctx.storage.getUrl(user.photo) : null;
      const categoryPhotoStorageId = categoryData.photos?.[0];
      const categoryPhotoUrl = categoryPhotoStorageId
        ? await ctx.storage.getUrl(categoryPhotoStorageId)
        : null;

      const distanceKm = geoResult.distance / 1000;
      const maxOverlapDistance = args.radiusKm + categoryData.serviceRadius;
      if (distanceKm > maxOverlapDistance) {
        continue;
      }

      results.push({
        id: profile._id,
        userId: profile.userId,
        name: profile.displayName,
        category: currentCategory?.name || "",
        rating: categoryData.rating,
        reviews: categoryData.reviewCount,
        price,
        distance: formatDistance(distanceKm),
        verified: profile.verified,
        bio: categoryData.bio,
        completedJobs: categoryData.completedJobs,
        avatarUrl,
        categoryPhotoUrl,
      });
    }

    return results;
  },
});

function formatPrice(
  rateType: "hourly" | "fixed",
  hourlyRate: number | undefined,
  fixedRate: number | undefined
): string {
  if (rateType === "hourly" && hourlyRate) {
    const dollars = hourlyRate / 100;
    return `$${dollars}/hr`;
  }
  if (rateType === "fixed" && fixedRate) {
    const dollars = fixedRate / 100;
    return `$${dollars} flat`;
  }
  return "$0/hr";
}

function formatDistance(distanceKm: number): string {
  return `${distanceKm.toFixed(1)} km`;
}
