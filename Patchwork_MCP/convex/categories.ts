import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const seedCategories = mutation({
  handler: async (ctx) => {
    const categories = [
      { name: "Plumbing", slug: "plumbing", icon: "wrench", sortOrder: 1 },
      { name: "Electrical", slug: "electrical", icon: "zap", sortOrder: 2 },
      { name: "Handyman", slug: "handyman", icon: "hammer", sortOrder: 3 },
      { name: "Cleaning", slug: "cleaning", icon: "sparkles", sortOrder: 4 },
      { name: "Moving", slug: "moving", icon: "truck", sortOrder: 5 },
      { name: "Painting", slug: "painting", icon: "paintbrush", sortOrder: 6 },
      { name: "Gardening", slug: "gardening", icon: "flower", sortOrder: 7 },
      { name: "Pest Control", slug: "pest-control", icon: "bug", sortOrder: 8 },
      { name: "Appliance Repair", slug: "appliance-repair", icon: "refrigerator", sortOrder: 9 },
      { name: "HVAC", slug: "hvac", icon: "thermometer", sortOrder: 10 },
      { name: "IT Support", slug: "it-support", icon: "laptop", sortOrder: 11 },
      { name: "Tutoring", slug: "tutoring", icon: "book", sortOrder: 12 },
      { name: "House Cleaning", slug: "house-cleaning", icon: "home", sortOrder: 13 },
      { name: "Lawn Care", slug: "lawn-care", icon: "trees", sortOrder: 14 },
      { name: "Furniture Assembly", slug: "furniture-assembly", icon: "sofa", sortOrder: 15 },
    ];

    for (const category of categories) {
      const existing = await ctx.db
        .query("categories")
        .withIndex("by_slug", (q) => q.eq("slug", category.slug))
        .first();

      if (!existing) {
        await ctx.db.insert("categories", {
          ...category,
          isActive: true,
        });
      }
    }
  },
});

export const listCategories = query({
  handler: async (ctx) => {
    return await ctx.db
      .query("categories")
      .withIndex("by_active", (q) => q.eq("isActive", true))
      .order("asc")
      .collect();
  },
});

export const getCategoryBySlug = query({
  args: { slug: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("categories")
      .withIndex("by_slug", (q) => q.eq("slug", args.slug))
      .first();
  },
});
