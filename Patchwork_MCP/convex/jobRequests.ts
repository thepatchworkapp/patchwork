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

    // 4. Create job request with timestamps
    const now = Date.now();
    const jobRequestId = await ctx.db.insert("jobRequests", {
      seekerId: user._id,
      categoryId: args.categoryId,
      categoryName: args.categoryName,
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
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return null;

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    if (!user) return null;

    return await ctx.db
      .query("jobRequests")
      .withIndex("by_seeker", (q) => q.eq("seekerId", user._id))
      .order("desc")
      .collect();
  },
});
