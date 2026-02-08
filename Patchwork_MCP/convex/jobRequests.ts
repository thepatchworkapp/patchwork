import { v } from "convex/values";
import { mutation, query } from "./_generated/server";
import { Id } from "./_generated/dataModel";

export const createJobRequest = mutation({
  args: {
    categoryId: v.id("categories"),
    categoryName: v.string(),
    description: v.string(),
    location: v.object({
      address: v.string(),
      city: v.string(),
      province: v.string(),
      coordinates: v.optional(v.object({
        lat: v.number(),
        lng: v.number(),
      })),
      searchRadius: v.number(),
    }),
    timing: v.object({
      type: v.union(v.literal("asap"), v.literal("specific_date"), v.literal("flexible")),
      specificDate: v.optional(v.string()),
      specificTime: v.optional(v.string()),
    }),
    budget: v.optional(v.object({
      min: v.number(),
      max: v.number(),
    })),
    photos: v.optional(v.array(v.id("_storage"))),
  },
  handler: async (ctx, args) => {
    // 1. Check auth
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    // 2. Lookup user by authId
    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    if (!user) throw new Error("User not found");

    // 3. Validate required fields
    if (!args.description.trim()) {
      throw new Error("Description is required");
    }
    if (!args.location.address.trim()) {
      throw new Error("Address is required");
    }
    if (!args.location.city.trim()) {
      throw new Error("City is required");
    }

    // Look up category name server-side (don't trust client-supplied name)
    const category = await ctx.db.get(args.categoryId);
    if (!category) throw new Error("Category not found");
    const resolvedCategoryName = category.name;

    // Input validation
    if (args.description.length > 5000) throw new Error("Description must be 5000 characters or less");
    if (args.location.address.length > 500) throw new Error("Address must be 500 characters or less");
    if (args.location.city.length > 100) throw new Error("City must be 100 characters or less");
    if (args.location.province.length > 100) throw new Error("Province must be 100 characters or less");
    if (args.location.searchRadius < 0 || args.location.searchRadius > 500) throw new Error("Search radius must be between 0 and 500 km");
    if (args.location.coordinates) {
      if (args.location.coordinates.lat < -90 || args.location.coordinates.lat > 90) throw new Error("Latitude must be between -90 and 90");
      if (args.location.coordinates.lng < -180 || args.location.coordinates.lng > 180) throw new Error("Longitude must be between -180 and 180");
    }
    if (args.budget) {
      if (args.budget.min < 0) throw new Error("Budget minimum cannot be negative");
      if (args.budget.max < 0) throw new Error("Budget maximum cannot be negative");
      if (args.budget.min > args.budget.max) throw new Error("Budget minimum cannot exceed maximum");
    }
    if (args.photos && args.photos.length > 10) throw new Error("Maximum 10 photos allowed");

    // 4. Create job request with timestamps
    const now = Date.now();
    const jobRequestId = await ctx.db.insert("jobRequests", {
      seekerId: user._id,
      categoryId: args.categoryId,
      categoryName: resolvedCategoryName,
      description: args.description,
      location: args.location,
      timing: args.timing,
      budget: args.budget,
      photos: args.photos,
      status: "open",
      createdAt: now,
      updatedAt: now,
    });

    return jobRequestId;
  },
});

export const listMyJobRequests = query({
  args: {
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return null;

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    if (!user) return null;

    const limit = Math.max(1, Math.min(args.limit ?? 50, 100));

    return await ctx.db
      .query("jobRequests")
      .withIndex("by_seeker", (q) => q.eq("seekerId", user._id))
      .order("desc")
      .take(limit);
  },
});
