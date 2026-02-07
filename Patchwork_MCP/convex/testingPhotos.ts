import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

export const checkUserPhotos = query({
  args: { email: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();
    
    if (!user) return null;
    
    const taskerProfile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();
    
    if (!taskerProfile) {
      return {
        userId: user._id,
        email: user.email,
        name: user.name,
        userPhoto: user.photo || null,
        hasUserPhoto: !!user.photo,
        isTasker: false,
        categoryPhotos: [],
        hasCategoryPhotos: false
      };
    }
    
    const taskerCategories = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile", (q) => q.eq("taskerProfileId", taskerProfile._id))
      .take(10);
    
    const allCategoryPhotos = taskerCategories.flatMap(tc => tc.photos || []);
    
    return {
      userId: user._id,
      email: user.email,
      name: user.name,
      userPhoto: user.photo || null,
      hasUserPhoto: !!user.photo,
      isTasker: true,
      taskerProfileId: taskerProfile._id,
      categoryPhotos: allCategoryPhotos,
      hasCategoryPhotos: allCategoryPhotos.length > 0,
      categoryCount: taskerCategories.length
    };
  }
});

export const forceUpdateUserPhoto = mutation({
  args: {
    email: v.string(),
    photoStorageId: v.id("_storage")
  },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();
    
    if (!user) throw new Error(`User not found: ${args.email}`);
    
    await ctx.db.patch(user._id, {
      photo: args.photoStorageId,
      updatedAt: Date.now()
    });
    
    return { userId: user._id, photoId: args.photoStorageId };
  }
});
