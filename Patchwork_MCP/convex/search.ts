import { query } from "./_generated/server";
import { v } from "convex/values";
import { Doc } from "./_generated/dataModel";

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

    const taskerProfiles = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_ghostMode", (q) => q.eq("ghostMode", false))
      .collect();

    const results = [];

    for (const profile of taskerProfiles) {
      if (!profile.isOnboarded) {
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
      }

      const price = formatPrice(
        categoryData.rateType,
        categoryData.hourlyRate,
        categoryData.fixedRate
      );

      results.push({
        id: profile._id,
        userId: profile.userId,
        name: profile.displayName,
        category: currentCategory?.name || "",
        rating: categoryData.rating,
        reviews: categoryData.reviewCount,
        price,
        distance: "0.0 km",
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
