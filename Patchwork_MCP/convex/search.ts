import { query } from "./_generated/server";
import { v } from "convex/values";
import { Doc } from "./_generated/dataModel";
import { taskerGeo } from "./geospatial";

const MAX_SERVICE_RADIUS_KM = 250;
const MAX_GEO_RESULTS = 100;

export const searchTaskers = query({
  args: {
    categorySlug: v.optional(v.string()),
    lat: v.number(),
    lng: v.number(),
    radiusKm: v.number(),
  },
  handler: async (ctx, args) => {
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
      limit: MAX_GEO_RESULTS,
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

      const taskerCategories = await ctx.db
        .query("taskerCategories")
        .withIndex("by_taskerProfile", (q) =>
          q.eq("taskerProfileId", profile._id)
        )
        .collect();

      let categoryData: Doc<"taskerCategories"> | null = null;
      let currentCategory: Doc<"categories"> | null = category;
      
      if (currentCategory) {
        categoryData = taskerCategories.find(
          (tc) => tc.categoryId === currentCategory!._id
        ) ?? null;
        if (!categoryData) {
          continue;
        }
      } else {
        categoryData = taskerCategories[0] ?? null;
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
