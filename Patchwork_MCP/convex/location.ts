import { internalMutation, mutation } from "./_generated/server";
import { v } from "convex/values";
import { taskerGeo } from "./geospatial";

/**
 * Calculates the Haversine distance between two coordinates in meters
 */
function haversineDistance(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number {
  const R = 6371e3;
  const φ1 = (lat1 * Math.PI) / 180;
  const φ2 = (lat2 * Math.PI) / 180;
  const Δφ = ((lat2 - lat1) * Math.PI) / 180;
  const Δλ = ((lng2 - lng1) * Math.PI) / 180;

  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
}

export const updateUserLocation = mutation({
  args: {
    lat: v.number(),
    lng: v.number(),
    source: v.union(
      v.literal("manual"),
      v.literal("gps"),
      v.literal("network")
    ),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    if (!user) throw new Error("User not found");

    // Coordinate validation
    if (args.lat < -90 || args.lat > 90) throw new Error("Latitude must be between -90 and 90");
    if (args.lng < -180 || args.lng > 180) throw new Error("Longitude must be between -180 and 180");

    const currentCoords = user.location.coordinates;
    if (currentCoords) {
      const distance = haversineDistance(
        currentCoords.lat,
        currentCoords.lng,
        args.lat,
        args.lng
      );

      if (distance < 500) {
        return {
          updated: false,
          reason: "threshold",
          distance,
        };
      }
    }

    await ctx.db.patch(user._id, {
      location: {
        ...user.location,
        coordinates: {
          lat: args.lat,
          lng: args.lng,
        },
      },
      updatedAt: Date.now(),
    });

    return {
      updated: true,
      distance: currentCoords
        ? haversineDistance(currentCoords.lat, currentCoords.lng, args.lat, args.lng)
        : null,
    };
  },
});

export const updateTaskerLocation = mutation({
  args: {
    lat: v.number(),
    lng: v.number(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    if (!user) throw new Error("User not found");

    // Coordinate validation
    if (args.lat < -90 || args.lat > 90) throw new Error("Latitude must be between -90 and 90");
    if (args.lng < -180 || args.lng > 180) throw new Error("Longitude must be between -180 and 180");

    const taskerProfile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();
    if (!taskerProfile) throw new Error("Tasker profile not found");

    const currentLocation = taskerProfile.location;
    if (currentLocation) {
      const distance = haversineDistance(
        currentLocation.lat,
        currentLocation.lng,
        args.lat,
        args.lng
      );

      if (distance < 500) {
        return {
          updated: false,
          reason: "threshold",
          distance,
        };
      }
    }

    await ctx.db.patch(taskerProfile._id, {
      location: {
        lat: args.lat,
        lng: args.lng,
      },
      updatedAt: Date.now(),
    });

    const primaryCategory = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile", (q) =>
        q.eq("taskerProfileId", taskerProfile._id)
      )
      .first();

    if (primaryCategory) {
      await taskerGeo.insert(
        ctx,
        taskerProfile._id,
        {
          latitude: args.lat,
          longitude: args.lng,
        },
        {
          categoryId: primaryCategory.categoryId,
        }
      );
    }

    return {
      updated: true,
      distance: currentLocation
        ? haversineDistance(currentLocation.lat, currentLocation.lng, args.lat, args.lng)
        : null,
    };
  },
});

export const syncTaskerGeo = internalMutation({
  args: {
    userId: v.id("users"),
    lat: v.number(),
    lng: v.number(),
  },
  handler: async (ctx, args) => {
    const taskerProfile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .first();
    if (!taskerProfile) return;

    await ctx.db.patch(taskerProfile._id, {
      location: { lat: args.lat, lng: args.lng },
      updatedAt: Date.now(),
    });

    const primaryCategory = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile", (q) =>
        q.eq("taskerProfileId", taskerProfile._id)
      )
      .first();

    if (primaryCategory) {
      await taskerGeo.insert(
        ctx,
        taskerProfile._id,
        { latitude: args.lat, longitude: args.lng },
        { categoryId: primaryCategory.categoryId }
      );
    }
  },
});
