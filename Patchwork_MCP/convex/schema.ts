// convex/schema.ts
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  users: defineTable({
    authId: v.string(),
    email: v.string(),
    emailVerified: v.boolean(),
    name: v.string(),
    photo: v.optional(v.id("_storage")),
    location: v.object({
      city: v.string(),
      province: v.string(),
      coordinates: v.optional(v.object({
        lat: v.number(),
        lng: v.number(),
      })),
    }),
    roles: v.object({
      isSeeker: v.boolean(),
      isTasker: v.boolean(),
    }),
    settings: v.object({
      notificationsEnabled: v.boolean(),
      locationEnabled: v.boolean(),
    }),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_authId", ["authId"])
    .index("by_email", ["email"]),

  seekerProfiles: defineTable({
    userId: v.id("users"),
    jobsPosted: v.number(),
    completedJobs: v.number(),
    rating: v.number(),
    ratingCount: v.number(),
    favouriteTaskers: v.array(v.id("users")),
    updatedAt: v.number(),
  }).index("by_userId", ["userId"]),

  /**
   * Tasker's main profile
   */
  taskerProfiles: defineTable({
    userId: v.id("users"),

    // Display
    displayName: v.string(),
    bio: v.optional(v.string()),
    isOnboarded: v.boolean(),

    // Stats (aggregated across all categories)
    rating: v.number(),
    reviewCount: v.number(),
    completedJobs: v.number(),
    responseTime: v.optional(v.string()), // e.g., "< 1 hour"

    // Verification
    verified: v.boolean(),

    // Subscription state
    subscriptionPlan: v.union(
      v.literal("none"),
      v.literal("basic"),
      v.literal("premium")
    ),
    ghostMode: v.boolean(), // true = not discoverable

    // Premium features
    premiumPin: v.optional(v.string()), // Unique searchable PIN
    foundersBadge: v.optional(
      v.object({
        categoryId: v.id("categories"),
        awardedAt: v.number(),
      })
    ),

    // Location for search
    location: v.optional(
      v.object({
        lat: v.number(),
        lng: v.number(),
      })
    ),
    geoPoint: v.optional(v.string()), // for @get-convex/geospatial

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_userId", ["userId"])
    .index("by_ghostMode", ["ghostMode"])
    .index("by_premiumPin", ["premiumPin"])
    .index("by_location", ["location.lat", "location.lng"]),

  /**
   * Tasker's category-specific settings
   */
  taskerCategories: defineTable({
    taskerProfileId: v.id("taskerProfiles"),
    userId: v.id("users"),
    categoryId: v.id("categories"),

    // Category-specific profile
    bio: v.string(),
    photos: v.array(v.id("_storage")), // Up to 10

    // Pricing
    rateType: v.union(v.literal("hourly"), v.literal("fixed")),
    hourlyRate: v.optional(v.number()), // cents
    fixedRate: v.optional(v.number()), // cents

    // Service area
    serviceRadius: v.number(), // km (1-250)

    // Category-specific stats
    rating: v.number(),
    reviewCount: v.number(),
    completedJobs: v.number(),

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_taskerProfile", ["taskerProfileId"])
    .index("by_userId", ["userId"])
    .index("by_category", ["categoryId"]),

  /**
    * Service categories (seed data)
    */
  categories: defineTable({
    name: v.string(),
    slug: v.string(),
    icon: v.optional(v.string()),
    emoji: v.optional(v.string()),
    group: v.optional(v.string()),
    description: v.optional(v.string()),
    isActive: v.boolean(),
    sortOrder: v.optional(v.number()),
  })
    .index("by_slug", ["slug"])
    .index("by_active", ["isActive"]),

  // ============================================
  // MESSAGING
  // ============================================

  /**
   * Conversation between seeker and tasker
   */
  conversations: defineTable({
    seekerId: v.id("users"),
    taskerId: v.id("users"),

    // Optional linkage
    jobRequestId: v.optional(v.id("jobRequests")),
    jobId: v.optional(v.id("jobs")),

    // Tracking
    lastMessageAt: v.number(),
    lastMessageId: v.optional(v.id("messages")),
    lastMessagePreview: v.optional(v.string()),
    lastMessageSenderId: v.optional(v.id("users")),
    seekerUnreadCount: v.number(),
    taskerUnreadCount: v.number(),
    seekerLastReadAt: v.optional(v.number()),
    taskerLastReadAt: v.optional(v.number()),

    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_seeker", ["seekerId"])
    .index("by_tasker", ["taskerId"])
    .index("by_participants", ["seekerId", "taskerId"])
    .index("by_lastMessage", ["lastMessageAt"])
    .index("by_seeker_lastMessage", ["seekerId", "lastMessageAt"])
    .index("by_tasker_lastMessage", ["taskerId", "lastMessageAt"]),

  /**
   * Individual message in a conversation
   */
  messages: defineTable({
    conversationId: v.id("conversations"),
    senderId: v.id("users"),

    // Content
    type: v.union(
      v.literal("text"),
      v.literal("proposal"),
      v.literal("system")
    ),
    content: v.string(),

    // If type === "proposal"
    proposalId: v.optional(v.id("proposals")),

    // Attachments
    attachments: v.optional(v.array(v.id("_storage"))),

    // Read tracking
    readAt: v.optional(v.number()),

    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_conversation", ["conversationId"])
    .index("by_conversation_time", ["conversationId", "createdAt"])
    .index("by_sender", ["senderId"]),

  // ============================================
  // PROPOSALS
  // ============================================

  /**
   * Job proposal (sent in conversation)
   */
  proposals: defineTable({
    conversationId: v.id("conversations"),
    senderId: v.id("users"),
    receiverId: v.id("users"),

    // Optional linkage
    jobRequestId: v.optional(v.id("jobRequests")),

    // Terms
    rate: v.number(), // cents
    rateType: v.union(v.literal("hourly"), v.literal("flat")),
    startDateTime: v.string(), // ISO datetime
    notes: v.optional(v.string()),

    // Status
    status: v.union(
      v.literal("pending"),
      v.literal("accepted"),
      v.literal("declined"),
      v.literal("countered"),
      v.literal("expired")
    ),

    // Counter proposal chain
    previousProposalId: v.optional(v.id("proposals")),
    counterProposalId: v.optional(v.id("proposals")),

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
    expiresAt: v.optional(v.number()),
  })
    .index("by_conversation", ["conversationId"])
    .index("by_sender", ["senderId"])
    .index("by_receiver", ["receiverId"])
    .index("by_status", ["status"]),

  // ============================================
  // JOBS
  // ============================================

  /**
   * Accepted job (from proposal)
   */
  jobs: defineTable({
    // Participants
    seekerId: v.id("users"),
    taskerId: v.id("users"),

    // Origin
    requestId: v.optional(v.id("jobRequests")),
    proposalId: v.id("proposals"),

    // Details
    categoryId: v.id("categories"),
    categoryName: v.string(),
    description: v.string(),

    // Pricing
    rate: v.number(), // cents
    rateType: v.union(v.literal("hourly"), v.literal("flat")),

    // Scheduling
    startDate: v.string(), // ISO datetime
    completedDate: v.optional(v.string()),

    // Notes
    notes: v.optional(v.string()),

    // Status
    status: v.union(
      v.literal("pending"),
      v.literal("in_progress"),
      v.literal("completed"),
      v.literal("cancelled"),
      v.literal("disputed")
    ),

    // Reviews
    seekerReviewId: v.optional(v.id("reviews")),
    taskerReviewId: v.optional(v.id("reviews")),

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
     .index("by_seeker", ["seekerId"])
     .index("by_tasker", ["taskerId"])
     .index("by_status", ["status"])
     .index("by_seeker_status", ["seekerId", "status"])
     .index("by_tasker_status", ["taskerId", "status"]),

   /**
    * Review for a completed job (bidirectional)
    */
   reviews: defineTable({
     jobId: v.id("jobs"),
     reviewerId: v.id("users"),
     revieweeId: v.id("users"),
     rating: v.number(), // 1-5, validated in mutation
     text: v.string(),
     createdAt: v.number(),
   })
     .index("by_job_reviewer", ["jobId", "reviewerId"]) // Unique constraint
     .index("by_job", ["jobId"])
     .index("by_reviewer", ["reviewerId"])
     .index("by_reviewee", ["revieweeId"]),

   // ============================================
   // JOB REQUESTS
   // ============================================

  /**
   * Job request posted by seeker
   */
  jobRequests: defineTable({
    seekerId: v.id("users"),
    categoryId: v.id("categories"),
    categoryName: v.string(),
    description: v.string(),

    // Photos
    photos: v.optional(v.array(v.id("_storage"))),

    // Location
    location: v.object({
      address: v.string(),
      city: v.string(),
      province: v.string(),
      coordinates: v.optional(v.object({
        lat: v.number(),
        lng: v.number(),
      })),
      searchRadius: v.number(), // km
    }),
    geoPoint: v.optional(v.string()), // for @get-convex/geospatial

    // Timing
    timing: v.object({
      type: v.union(v.literal("asap"), v.literal("specific_date"), v.literal("flexible")),
      specificDate: v.optional(v.string()), // ISO date
      specificTime: v.optional(v.string()), // HH:mm format
    }),

    // Budget
    budget: v.optional(v.object({
      min: v.number(), // cents
      max: v.number(), // cents
    })),

    // Status
    status: v.union(
      v.literal("open"),
      v.literal("in_progress"),
      v.literal("completed"),
      v.literal("cancelled")
    ),

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_seeker", ["seekerId"])
    .index("by_status", ["status"])
    .index("by_category", ["categoryId"])
    .index("by_created", ["createdAt"])
    .index("by_location", ["location.coordinates.lat", "location.coordinates.lng"])
    .index("by_seeker_status", ["seekerId", "status"]),

  otps: defineTable({
    email: v.string(),
    otp: v.string(),
    createdAt: v.number(),
  }).index("by_email", ["email"]),

  adminOtps: defineTable({
    email: v.string(),
    otpHash: v.string(),
    createdAt: v.number(),
    expiresAt: v.number(),
    verifyAttempts: v.number(),
  }).index("by_email", ["email"]),
});
