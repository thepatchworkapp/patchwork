import { ConvexError, v } from "convex/values";
import { internalQuery, internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";

const MAX_TEST_QUERY_ROWS = 200;

async function findUserByEmail(ctx: any, email: string) {
  return await ctx.db
    .query("users")
    .withIndex("by_email", (q: any) => q.eq("email", email))
    .first();
}

async function ensureSeekerProfile(ctx: any, userId: string) {
  const seekerProfile = await ctx.db
    .query("seekerProfiles")
    .withIndex("by_userId", (q: any) => q.eq("userId", userId))
    .first();

  if (seekerProfile) {
    return seekerProfile;
  }

  const seekerProfileId = await ctx.db.insert("seekerProfiles", {
    userId,
    jobsPosted: 0,
    completedJobs: 0,
    rating: 0,
    ratingCount: 0,
    updatedAt: Date.now(),
  });

  return await ctx.db.get(seekerProfileId);
}

async function ensureConversationRecord(ctx: any, seekerId: string, taskerId: string) {
  const existing = await ctx.db
    .query("conversations")
    .withIndex("by_participants", (q: any) => q.eq("seekerId", seekerId).eq("taskerId", taskerId))
    .first();

  if (existing) {
    return existing;
  }

  const now = Date.now();
  const conversationId = await ctx.db.insert("conversations", {
    seekerId,
    taskerId,
    seekerUnreadCount: 0,
    taskerUnreadCount: 0,
    lastMessageAt: now,
    createdAt: now,
    updatedAt: now,
  });

  return await ctx.db.get(conversationId);
}

export const getOtp = internalQuery({
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

export const seedOtp = internalMutation({
  args: { email: v.string(), otp: v.string() },
  handler: async (ctx, args) => {
    await ctx.db.insert("otps", { 
      email: args.email, 
      otp: args.otp,
      createdAt: Date.now() 
    });
  },
});

export const getUserId = internalQuery({
  args: { email: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();
    return user?._id;
  },
});

export const getTaskerProfileByEmail = internalQuery({
  args: { email: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();

    if (!user) {
      return null;
    }

    const taskerProfile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!taskerProfile) {
      return null;
    }

    const taskerCategories = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile_category", (q) => q.eq("taskerProfileId", taskerProfile._id))
      .take(20);

    return {
      _id: taskerProfile._id,
      taskerProfileId: taskerProfile._id,
      displayName: taskerProfile.displayName,
      categories: taskerCategories.map((category) => ({
        _id: category._id,
        taskerProfileId: category.taskerProfileId,
        userId: category.userId,
        categoryId: category.categoryId,
        bio: category.bio,
        photos: category.photos,
        portfolioAssetIds: category.portfolioAssetIds,
        coverAssetId: category.coverAssetId,
        rateType: category.rateType,
        hourlyRate: category.hourlyRate,
        fixedRate: category.fixedRate,
        serviceRadius: category.serviceRadius,
        rating: category.rating,
        reviewCount: category.reviewCount,
        completedJobs: category.completedJobs,
        createdAt: category.createdAt,
        updatedAt: category.updatedAt,
      })),
      subscriptionPlan: taskerProfile.subscriptionPlan,
      subscriptionStatus: taskerProfile.subscriptionStatus,
      subscriptionEndsAt: taskerProfile.subscriptionEndsAt,
      ghostMode: taskerProfile.ghostMode,
    };
  },
});

export const getConversationByEmails = internalQuery({
  args: {
    seekerEmail: v.string(),
    taskerEmail: v.string(),
  },
  handler: async (ctx, args) => {
    const seeker = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.seekerEmail))
      .first();
    const tasker = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.taskerEmail))
      .first();

    if (!seeker || !tasker) {
      return null;
    }

    const conversation = await ctx.db
      .query("conversations")
      .withIndex("by_participants", (q) => q.eq("seekerId", seeker._id).eq("taskerId", tasker._id))
      .first();

    if (!conversation) {
      return null;
    }

    return {
      conversationId: conversation._id,
      jobId: conversation.jobId,
      lastMessagePreview: conversation.lastMessagePreview,
    };
  },
});

export const getLatestProposalByEmails = internalQuery({
  args: {
    seekerEmail: v.string(),
    taskerEmail: v.string(),
  },
  handler: async (ctx, args) => {
    const seeker = await findUserByEmail(ctx, args.seekerEmail);
    const tasker = await findUserByEmail(ctx, args.taskerEmail);

    if (!seeker || !tasker) {
      return null;
    }

    const conversation = await ctx.db
      .query("conversations")
      .withIndex("by_participants", (q) => q.eq("seekerId", seeker._id).eq("taskerId", tasker._id))
      .first();

    if (!conversation) {
      return null;
    }

    const proposals = await ctx.db
      .query("proposals")
      .withIndex("by_conversation", (q) => q.eq("conversationId", conversation._id))
      .take(MAX_TEST_QUERY_ROWS);

    const latestProposal = proposals.sort((a, b) => b.updatedAt - a.updatedAt)[0];
    if (!latestProposal) {
      return null;
    }

    return {
      proposalId: latestProposal._id,
      conversationId: conversation._id,
      status: latestProposal.status,
      rate: latestProposal.rate,
      rateType: latestProposal.rateType,
      startDateTime: latestProposal.startDateTime,
      notes: latestProposal.notes,
    };
  },
});

export const getJobById = internalQuery({
  args: { jobId: v.id("jobs") },
  handler: async (ctx, args) => {
    const job = await ctx.db.get(args.jobId);
    if (!job) {
      return null;
    }

    return {
      jobId: job._id,
      status: job.status,
      completedDate: job.completedDate,
      seekerReviewId: job.seekerReviewId,
      taskerReviewId: job.taskerReviewId,
      seekerId: job.seekerId,
      taskerId: job.taskerId,
      updatedAt: job.updatedAt,
    };
  },
});

export const getReviewByJobAndReviewer = internalQuery({
  args: {
    jobId: v.id("jobs"),
    reviewerEmail: v.string(),
  },
  handler: async (ctx, args) => {
    const reviewer = await findUserByEmail(ctx, args.reviewerEmail);
    if (!reviewer) {
      return null;
    }

    const review = await ctx.db
      .query("reviews")
      .withIndex("by_job_reviewer", (q) =>
        q.eq("jobId", args.jobId).eq("reviewerId", reviewer._id)
      )
      .first();

    if (!review) {
      return null;
    }

    return {
      reviewId: review._id,
      rating: review.rating,
      text: review.text,
      reviewerId: review.reviewerId,
      revieweeId: review.revieweeId,
      createdAt: review.createdAt,
    };
  },
});

export const ensureDiscoverableTasker = internalMutation({
  args: {
    email: v.string(),
    name: v.string(),
    displayName: v.string(),
    city: v.string(),
    province: v.string(),
    lat: v.number(),
    lng: v.number(),
    categorySlug: v.string(),
    categoryName: v.optional(v.string()),
    categoryBio: v.string(),
    rateType: v.union(v.literal("hourly"), v.literal("fixed")),
    hourlyRate: v.optional(v.number()),
    fixedRate: v.optional(v.number()),
    serviceRadius: v.number(),
    verified: v.optional(v.boolean()),
    subscriptionPlan: v.optional(v.literal("tasker")),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const subscriptionPlan = args.subscriptionPlan ?? "tasker";

    let category = await ctx.db
      .query("categories")
      .withIndex("by_slug", (q) => q.eq("slug", args.categorySlug))
      .first();

    if (!category) {
      category = await ctx.db.insert("categories", {
        name: args.categoryName ?? args.categorySlug
          .split("-")
          .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
          .join(" "),
        slug: args.categorySlug,
        isActive: true,
      }).then((categoryId) => ctx.db.get(categoryId));
    }

    if (!category) {
      throw new ConvexError("Category could not be created");
    }

    let user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();

    if (!user) {
      const userId = await ctx.db.insert("users", {
        authId: `testing|${args.email}`,
        email: args.email,
        emailVerified: true,
        name: args.name,
        location: {
          city: args.city,
          province: args.province,
          coordinates: {
            lat: args.lat,
            lng: args.lng,
          },
        },
        roles: {
          isSeeker: true,
          isTasker: true,
        },
        settings: {
          notificationsEnabled: true,
          locationEnabled: true,
        },
        createdAt: now,
        updatedAt: now,
      });
      user = await ctx.db.get(userId);
    } else {
      await ctx.db.patch(user._id, {
        name: args.name,
        location: {
          city: args.city,
          province: args.province,
          coordinates: {
            lat: args.lat,
            lng: args.lng,
          },
        },
        roles: {
          ...user.roles,
          isTasker: true,
        },
        settings: {
          ...user.settings,
          locationEnabled: true,
        },
        updatedAt: now,
      });
      user = await ctx.db.get(user._id);
    }

    if (!user) {
      throw new ConvexError("User could not be created");
    }

    const seekerProfile = await ctx.db
      .query("seekerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!seekerProfile) {
      await ctx.db.insert("seekerProfiles", {
        userId: user._id,
        jobsPosted: 0,
        completedJobs: 0,
        rating: 0,
        ratingCount: 0,
        updatedAt: now,
      });
    }

    let taskerProfile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!taskerProfile) {
      const taskerProfileId = await ctx.db.insert("taskerProfiles", {
        userId: user._id,
        displayName: args.displayName,
        bio: args.categoryBio,
        isOnboarded: true,
        rating: 0,
        reviewCount: 0,
        completedJobs: 0,
        verified: args.verified ?? false,
        subscriptionPlan,
        subscriptionStatus: "active",
        ghostMode: false,
        location: {
          lat: args.lat,
          lng: args.lng,
        },
        createdAt: now,
        updatedAt: now,
      });
      taskerProfile = await ctx.db.get(taskerProfileId);
    } else {
      await ctx.db.patch(taskerProfile._id, {
        displayName: args.displayName,
        bio: args.categoryBio,
        isOnboarded: true,
        verified: args.verified ?? taskerProfile.verified,
        subscriptionPlan,
        subscriptionStatus: "active",
        subscriptionEndsAt: undefined,
        ghostMode: false,
        location: {
          lat: args.lat,
          lng: args.lng,
        },
        updatedAt: now,
      });
      taskerProfile = await ctx.db.get(taskerProfile._id);
    }

    if (!taskerProfile) {
      throw new ConvexError("Tasker profile could not be created");
    }

    const existingCategory = await ctx.db
      .query("taskerCategories")
      .withIndex("by_taskerProfile_category", (q) =>
        q.eq("taskerProfileId", taskerProfile._id).eq("categoryId", category!._id)
      )
      .first();

    if (!existingCategory) {
      await ctx.db.insert("taskerCategories", {
        taskerProfileId: taskerProfile._id,
        userId: user._id,
        categoryId: category._id,
        bio: args.categoryBio,
        photos: [],
        rateType: args.rateType,
        hourlyRate: args.hourlyRate,
        fixedRate: args.fixedRate,
        serviceRadius: args.serviceRadius,
        rating: 0,
        reviewCount: 0,
        completedJobs: 0,
        createdAt: now,
        updatedAt: now,
      });
    }

    await ctx.runMutation(internal.location.syncTaskerGeo, {
      userId: user._id,
      lat: args.lat,
      lng: args.lng,
    });

    return {
      userId: user._id,
      taskerProfileId: taskerProfile._id,
      categoryId: category._id,
      displayName: args.displayName,
    };
  },
});

export const ensurePendingProposalBetweenEmails = internalMutation({
  args: {
    seekerEmail: v.string(),
    taskerEmail: v.string(),
    taskerName: v.string(),
    taskerDisplayName: v.string(),
    city: v.string(),
    province: v.string(),
    lat: v.number(),
    lng: v.number(),
    categorySlug: v.string(),
    categoryName: v.optional(v.string()),
    categoryBio: v.string(),
    rate: v.number(),
    rateType: v.union(v.literal("hourly"), v.literal("flat")),
    startDateTime: v.string(),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const seeker = await findUserByEmail(ctx, args.seekerEmail);
    if (!seeker) {
      throw new ConvexError("Seeker not found");
    }

    await ensureSeekerProfile(ctx, seeker._id);

    await ctx.runMutation(internal.testing.ensureDiscoverableTasker, {
      email: args.taskerEmail,
      name: args.taskerName,
      displayName: args.taskerDisplayName,
      city: args.city,
      province: args.province,
      lat: args.lat,
      lng: args.lng,
      categorySlug: args.categorySlug,
      categoryName: args.categoryName,
      categoryBio: args.categoryBio,
      rateType: "hourly",
      hourlyRate: args.rate,
      serviceRadius: 25,
      verified: true,
      subscriptionPlan: "tasker",
    });

    const tasker = await findUserByEmail(ctx, args.taskerEmail);
    if (!tasker) {
      throw new ConvexError("Tasker not found");
    }

    const conversation = await ensureConversationRecord(ctx, seeker._id, tasker._id);
    if (!conversation) {
      throw new ConvexError("Conversation not found");
    }

    const existingProposal = await ctx.db
      .query("proposals")
      .withIndex("by_conversation", (q) => q.eq("conversationId", conversation._id))
      .take(MAX_TEST_QUERY_ROWS)
      .then((rows) => rows.sort((a, b) => b.updatedAt - a.updatedAt)[0] ?? null);

    if (existingProposal?.status === "pending") {
      return {
        conversationId: conversation._id,
        proposalId: existingProposal._id,
        status: existingProposal.status,
      };
    }

    const now = Date.now();
    const proposalId = await ctx.db.insert("proposals", {
      conversationId: conversation._id,
      senderId: tasker._id,
      receiverId: seeker._id,
      rate: args.rate,
      rateType: args.rateType,
      startDateTime: args.startDateTime,
      notes: args.notes,
      status: "pending",
      createdAt: now,
      updatedAt: now,
    });

    await ctx.runMutation(internal.messages.sendProposalMessage, {
      conversationId: conversation._id,
      senderId: tasker._id,
      proposalId,
      content: "Proposal sent",
    });

    await ctx.runMutation(internal.messages.sendSystemMessage, {
      conversationId: conversation._id,
      systemType: "proposal_sent",
    });

    return {
      conversationId: conversation._id,
      proposalId,
      status: "pending",
    };
  },
});

export const ensureAcceptedJobBetweenEmails = internalMutation({
  args: {
    seekerEmail: v.string(),
    taskerEmail: v.string(),
    taskerName: v.string(),
    taskerDisplayName: v.string(),
    city: v.string(),
    province: v.string(),
    lat: v.number(),
    lng: v.number(),
    categorySlug: v.string(),
    categoryName: v.optional(v.string()),
    categoryBio: v.string(),
    rate: v.number(),
    rateType: v.union(v.literal("hourly"), v.literal("flat")),
    startDateTime: v.string(),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const proposalSeed = await ctx.runMutation(internal.testing.ensurePendingProposalBetweenEmails, args);
    const proposalId = proposalSeed.proposalId;

    const proposal = await ctx.db.get(proposalId);
    if (!proposal) {
      throw new ConvexError("Proposal not found after seed");
    }

    const conversation = await ctx.db.get(proposal.conversationId);
    if (!conversation) {
      throw new ConvexError("Conversation not found after proposal seed");
    }

    if (conversation.jobId) {
      const existingJob = await ctx.db.get(conversation.jobId);
      if (existingJob) {
        if (proposal.status !== "accepted") {
          await ctx.db.patch(proposalId, {
            status: "accepted",
            updatedAt: Date.now(),
          });
        }

        return {
          conversationId: conversation._id,
          proposalId,
          jobId: existingJob._id,
          status: existingJob.status,
        };
      }
    }

    if (proposal.status !== "accepted") {
      await ctx.db.patch(proposalId, {
        status: "accepted",
        updatedAt: Date.now(),
      });
    }

    const jobId = await ctx.runMutation(internal.jobs.createJob, { proposalId });

    await ctx.runMutation(internal.messages.sendSystemMessage, {
      conversationId: conversation._id,
      systemType: "proposal_accepted",
    });

    return {
      conversationId: conversation._id,
      proposalId,
      jobId,
      status: "in_progress",
    };
  },
});

export const ensureCompletedJobBetweenEmails = internalMutation({
  args: {
    seekerEmail: v.string(),
    taskerEmail: v.string(),
    taskerName: v.string(),
    taskerDisplayName: v.string(),
    city: v.string(),
    province: v.string(),
    lat: v.number(),
    lng: v.number(),
    categorySlug: v.string(),
    categoryName: v.optional(v.string()),
    categoryBio: v.string(),
    rate: v.number(),
    rateType: v.union(v.literal("hourly"), v.literal("flat")),
    startDateTime: v.string(),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const acceptedSeed = await ctx.runMutation(internal.testing.ensureAcceptedJobBetweenEmails, args);
    const jobId = acceptedSeed.jobId;
    const job = await ctx.db.get(jobId);
    if (!job) {
      throw new ConvexError("Accepted job not found");
    }

    if (job.status !== "completed") {
      await ctx.db.patch(jobId, {
        status: "completed",
        completedDate: new Date().toISOString(),
        updatedAt: Date.now(),
      });
    }

    return {
      conversationId: acceptedSeed.conversationId,
      proposalId: acceptedSeed.proposalId,
      jobId,
      status: "completed",
    };
  },
});

export const ensureConversationBetweenEmails = internalMutation({
  args: {
    seekerEmail: v.string(),
    seekerName: v.string(),
    taskerEmail: v.string(),
    city: v.string(),
    province: v.string(),
    lat: v.number(),
    lng: v.number(),
    initialMessage: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    let seeker = await findUserByEmail(ctx, args.seekerEmail);
    const now = Date.now();

    if (!seeker) {
      const seekerId = await ctx.db.insert("users", {
        authId: `testing|${args.seekerEmail}`,
        email: args.seekerEmail,
        emailVerified: true,
        name: args.seekerName,
        location: {
          city: args.city,
          province: args.province,
          coordinates: {
            lat: args.lat,
            lng: args.lng,
          },
        },
        roles: {
          isSeeker: true,
          isTasker: false,
        },
        settings: {
          notificationsEnabled: true,
          locationEnabled: true,
        },
        createdAt: now,
        updatedAt: now,
      });
      seeker = await ctx.db.get(seekerId);
    }

    if (!seeker) {
      throw new ConvexError("Seeker could not be created");
    }

    await ensureSeekerProfile(ctx, seeker._id);

    const tasker = await findUserByEmail(ctx, args.taskerEmail);
    if (!tasker) {
      throw new ConvexError("Tasker not found");
    }

    const conversation = await ensureConversationRecord(ctx, seeker._id, tasker._id);
    if (!conversation) {
      throw new ConvexError("Conversation not found");
    }

    const existingMessages = await ctx.db
      .query("messages")
      .withIndex("by_conversation", (q) => q.eq("conversationId", conversation._id))
      .take(1);

    if (existingMessages.length === 0) {
      const messageId = await ctx.db.insert("messages", {
        conversationId: conversation._id,
        senderId: seeker._id,
        type: "text",
        content: args.initialMessage ?? "Hi, I’d like help with a cleaning job.",
        createdAt: now,
        updatedAt: now,
      });

      await ctx.db.patch(conversation._id, {
        lastMessageAt: now,
        lastMessageId: messageId,
        lastMessagePreview: args.initialMessage ?? "Hi, I’d like help with a cleaning job.",
        lastMessageSenderId: seeker._id,
        taskerUnreadCount: 1,
        updatedAt: now,
      });
    }

    return {
      conversationId: conversation._id,
      seekerId: seeker._id,
      taskerId: tasker._id,
    };
  },
});

export const forceCreateConversation = internalMutation({
  args: { seekerEmail: v.string(), taskerEmail: v.string() },
  handler: async (ctx, args) => {
    const seeker = await ctx.db.query("users").withIndex("by_email", q => q.eq("email", args.seekerEmail)).first();
    const tasker = await ctx.db.query("users").withIndex("by_email", q => q.eq("email", args.taskerEmail)).first();
    
    if (!seeker || !tasker) throw new ConvexError("Users not found");
    
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

export const forceMakeTasker = internalMutation({
  args: { email: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();
    
    if (!user) throw new ConvexError("User not found");
    
    await ctx.db.patch(user._id, {
      roles: {
        isSeeker: user.roles.isSeeker,
        isTasker: true,
      }
    });
  }
});

export const deleteTestUser = internalMutation({
  args: { email: v.string() },
  handler: async (ctx, args) => {
    // Auth check removed for E2E testing
    
    if (!args.email.includes("@test.com") && !args.email.startsWith("e2e_")) {
      throw new ConvexError("Can only delete test users (@test.com or e2e_ prefix)");
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

export const deleteByEmailPrefix = internalMutation({
  args: { prefix: v.string() },
  handler: async (ctx, args) => {
    // Auth check removed for E2E testing
    
    if (!args.prefix.includes("@test.com") && !args.prefix.startsWith("e2e_")) {
      throw new ConvexError("Can only delete test users (@test.com or e2e_ prefix)");
    }
    
    const users = await ctx.db.query("users").take(MAX_TEST_QUERY_ROWS);
    const toDelete = users.filter((u) => u.email.includes(args.prefix));
    
    let deletedCount = 0;
    for (const user of toDelete) {
      await ctx.db.delete(user._id);
      deletedCount++;
    }
    
    return { deletedCount };
  },
});

export const ensureCategoryExists = internalMutation({
  args: { name: v.string() },
  handler: async (ctx, args) => {
    // Auth check removed for E2E testing
    
    const existing = await ctx.db
      .query("categories")
      .withIndex("by_name", (q) => q.eq("name", args.name))
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

export const cleanupConversations = internalMutation({
  args: { userEmail: v.string() },
  handler: async (ctx, args) => {
    // Auth check removed for E2E testing
    
    if (!args.userEmail.includes("@test.com") && !args.userEmail.startsWith("e2e_")) {
      throw new ConvexError("Can only cleanup test users (@test.com or e2e_ prefix)");
    }
    
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.userEmail))
      .first();
    
    if (!user) return { conversationsDeleted: 0, messagesDeleted: 0, proposalsDeleted: 0, jobsDeleted: 0 };
    
    const [conversationsAsSeeker, conversationsAsTasker] = await Promise.all([
      ctx.db
        .query("conversations")
        .withIndex("by_seeker", (q) => q.eq("seekerId", user._id))
        .take(MAX_TEST_QUERY_ROWS),
      ctx.db
        .query("conversations")
        .withIndex("by_tasker", (q) => q.eq("taskerId", user._id))
        .take(MAX_TEST_QUERY_ROWS),
    ]);
    const conversations = Array.from(
      new Map(
        [...conversationsAsSeeker, ...conversationsAsTasker].map((conversation) => [
          conversation._id,
          conversation,
        ])
      ).values()
    );
    
    let conversationsDeleted = 0;
    let messagesDeleted = 0;
    let proposalsDeleted = 0;
    let jobsDeleted = 0;
    
    for (const conv of conversations) {
      const messages = await ctx.db
        .query("messages")
        .withIndex("by_conversation", (q) => q.eq("conversationId", conv._id))
        .take(MAX_TEST_QUERY_ROWS);
      
      for (const msg of messages) {
        await ctx.db.delete(msg._id);
        messagesDeleted++;
      }
      
      const proposals = await ctx.db
        .query("proposals")
        .withIndex("by_conversation", (q) => q.eq("conversationId", conv._id))
        .take(MAX_TEST_QUERY_ROWS);
      
      for (const prop of proposals) {
        await ctx.db.delete(prop._id);
        proposalsDeleted++;
      }
      
      const [jobsAsSeeker, jobsAsTasker] = await Promise.all([
        ctx.db
          .query("jobs")
          .withIndex("by_seeker", (q) => q.eq("seekerId", user._id))
          .take(MAX_TEST_QUERY_ROWS),
        ctx.db
          .query("jobs")
          .withIndex("by_tasker", (q) => q.eq("taskerId", user._id))
          .take(MAX_TEST_QUERY_ROWS),
      ]);
      const linkedJobs = Array.from(
        new Map([...jobsAsSeeker, ...jobsAsTasker].map((job) => [job._id, job])).values(),
      );
      
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

export const setTaskerLocationByEmail = internalMutation({
  args: {
    email: v.string(),
    lat: v.number(),
    lng: v.number(),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();

    if (!user) throw new ConvexError("User not found");

    await ctx.db.patch(user._id, {
      location: {
        ...user.location,
        coordinates: {
          lat: args.lat,
          lng: args.lng,
        },
      },
      settings: {
        ...user.settings,
        locationEnabled: true,
      },
      updatedAt: Date.now(),
    });

    await ctx.runMutation(internal.location.syncTaskerGeo, {
      userId: user._id,
      lat: args.lat,
      lng: args.lng,
    });

    return { updated: true, userId: user._id };
  },
});

export const expireTaskerSubscription = internalMutation({
  args: { email: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();

    if (!user) throw new ConvexError("User not found");

    const taskerProfile = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .first();

    if (!taskerProfile) throw new ConvexError("Tasker profile not found");

    await ctx.db.patch(taskerProfile._id, {
      subscriptionStatus: "cancel_at_period_end",
      subscriptionEndsAt: Date.now() - 1_000,
      ghostMode: false,
      updatedAt: Date.now(),
    });

    return { expired: true, taskerProfileId: taskerProfile._id };
  },
});
