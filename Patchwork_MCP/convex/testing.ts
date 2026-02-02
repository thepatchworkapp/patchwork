import { v } from "convex/values";
import { query, mutation } from "./_generated/server";

export const getOtp = query({
  args: { email: v.string() },
  handler: async (ctx, args) => {
    const otpRecord = await ctx.db
      .query("otps")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .order("desc")
      .first();
    return otpRecord?.otp;
  },
});

export const seedOtp = mutation({
  args: { email: v.string(), otp: v.string() },
  handler: async (ctx, args) => {
    await ctx.db.insert("otps", { 
      email: args.email, 
      otp: args.otp,
      createdAt: Date.now() 
    });
  },
});

export const getUserId = query({
  args: { email: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();
    return user?._id;
  },
});

export const forceCreateConversation = mutation({
  args: { seekerEmail: v.string(), taskerEmail: v.string() },
  handler: async (ctx, args) => {
    const seeker = await ctx.db.query("users").withIndex("by_email", q => q.eq("email", args.seekerEmail)).first();
    const tasker = await ctx.db.query("users").withIndex("by_email", q => q.eq("email", args.taskerEmail)).first();
    
    if (!seeker || !tasker) throw new Error("Users not found");
    
    const existing = await ctx.db.query("conversations")
      .withIndex("by_participants", q => q.eq("seekerId", seeker._id).eq("taskerId", tasker._id))
      .first();
      
    if (existing) return existing._id;
    
    return await ctx.db.insert("conversations", {
      seekerId: seeker._id,
      taskerId: tasker._id,
      seekerUnreadCount: 0,
      taskerUnreadCount: 0,
      lastMessageAt: Date.now(),
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });
  }
});

export const forceMakeTasker = mutation({
  args: { email: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();
    
    if (!user) throw new Error("User not found");
    
    await ctx.db.patch(user._id, {
      roles: {
        isSeeker: user.roles.isSeeker,
        isTasker: true,
      }
    });
  }
});

export const deleteTestUser = mutation({
  args: { email: v.string() },
  handler: async (ctx, args) => {
    // Auth check removed for E2E testing
    
    if (!args.email.includes("@test.com") && !args.email.startsWith("e2e_")) {
      throw new Error("Can only delete test users (@test.com or e2e_ prefix)");
    }
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();
    
    if (!user) return { deleted: false, userId: null };
    
    await ctx.db.delete(user._id);
    
    return { deleted: true, userId: user._id };
  },
});

export const deleteByEmailPrefix = mutation({
  args: { prefix: v.string() },
  handler: async (ctx, args) => {
    // Auth check removed for E2E testing
    
    if (!args.prefix.includes("@test.com") && !args.prefix.startsWith("e2e_")) {
      throw new Error("Can only delete test users (@test.com or e2e_ prefix)");
    }
    
    const users = await ctx.db.query("users").collect();
    const toDelete = users.filter((u) => u.email.includes(args.prefix));
    
    let deletedCount = 0;
    for (const user of toDelete) {
      await ctx.db.delete(user._id);
      deletedCount++;
    }
    
    return { deletedCount };
  },
});

export const ensureCategoryExists = mutation({
  args: { name: v.string() },
  handler: async (ctx, args) => {
    // Auth check removed for E2E testing
    
    const existing = await ctx.db
      .query("categories")
      .filter((q) => q.eq(q.field("name"), args.name))
      .first();
    
    if (existing) return { created: false, categoryId: existing._id };
    
    const categoryId = await ctx.db.insert("categories", {
      name: args.name,
      slug: args.name.toLowerCase().replace(/\s+/g, "-"),
      isActive: true,
    });
    
    return { created: true, categoryId };
  },
});

export const cleanupConversations = mutation({
  args: { userEmail: v.string() },
  handler: async (ctx, args) => {
    // Auth check removed for E2E testing
    
    if (!args.userEmail.includes("@test.com") && !args.userEmail.startsWith("e2e_")) {
      throw new Error("Can only cleanup test users (@test.com or e2e_ prefix)");
    }
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.userEmail))
      .first();
    
    if (!user) return { conversationsDeleted: 0, messagesDeleted: 0, proposalsDeleted: 0, jobsDeleted: 0 };
    
    const conversations = await ctx.db
      .query("conversations")
      .filter((q) => q.or(q.eq(q.field("seekerId"), user._id), q.eq(q.field("taskerId"), user._id)))
      .collect();
    
    let conversationsDeleted = 0;
    let messagesDeleted = 0;
    let proposalsDeleted = 0;
    let jobsDeleted = 0;
    
    for (const conv of conversations) {
      const messages = await ctx.db
        .query("messages")
        .withIndex("by_conversation", (q) => q.eq("conversationId", conv._id))
        .collect();
      
      for (const msg of messages) {
        await ctx.db.delete(msg._id);
        messagesDeleted++;
      }
      
      const proposals = await ctx.db
        .query("proposals")
        .withIndex("by_conversation", (q) => q.eq("conversationId", conv._id))
        .collect();
      
      for (const prop of proposals) {
        await ctx.db.delete(prop._id);
        proposalsDeleted++;
      }
      
      const jobs = await ctx.db.query("jobs").collect();
      const linkedJobs = jobs.filter((j) => j.seekerId === user._id || j.taskerId === user._id);
      
      for (const job of linkedJobs) {
        await ctx.db.delete(job._id);
        jobsDeleted++;
      }
      
      await ctx.db.delete(conv._id);
      conversationsDeleted++;
    }
    
    return { conversationsDeleted, messagesDeleted, proposalsDeleted, jobsDeleted };
  },
});
