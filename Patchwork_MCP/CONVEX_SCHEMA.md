# Patchwork Convex Schema

> **Database Schema Definitions for Convex**  
> Copy to `convex/schema.ts` and adapt as needed

Note: Better Auth manages its own auth tables via the Convex component. Do not duplicate those tables here.

---

## Complete Schema

```typescript
// convex/schema.ts
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  // ============================================
  // USERS & PROFILES
  // ============================================

  /**
   * Core user record - created on signup
   */
  users: defineTable({
    // Auth linkage (from Better Auth)
    authId: v.string(),
    email: v.string(),
    emailVerified: v.boolean(),

    // Profile
    name: v.string(),
    photo: v.optional(v.id("_storage")), // Convex file storage ID (derive URL on read)

    // Location
    location: v.object({
      city: v.string(),
      province: v.string(),
      coordinates: v.optional(
        v.object({
          lat: v.number(),
          lng: v.number(),
        })
      ),
    }),

    // Roles
    roles: v.object({
      isSeeker: v.boolean(), // Always true
      isTasker: v.boolean(), // True after tasker onboarding
    }),

    // Settings
    settings: v.object({
      notificationsEnabled: v.boolean(),
      locationEnabled: v.boolean(),
    }),

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_authId", ["authId"])
    .index("by_email", ["email"]),

  /**
   * Seeker-specific profile data
   */
  seekerProfiles: defineTable({
    userId: v.id("users"),

    // Stats
    jobsPosted: v.number(),
    completedJobs: v.number(),
    rating: v.number(), // Aggregate 1-5
    ratingCount: v.number(),

    // Preferences
    favouriteTaskers: v.array(v.id("users")),

    updatedAt: v.number(),
  }).index("by_userId", ["userId"]),

  /**
   * Tasker-specific profile data
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
   * Saved addresses for seekers
   */
  addresses: defineTable({
    userId: v.id("users"),
    label: v.string(), // "Home", "Work", etc.
    address: v.string(),
    city: v.string(),
    province: v.string(),
    postalCode: v.string(),
    coordinates: v.object({
      lat: v.number(),
      lng: v.number(),
    }),
    isDefault: v.boolean(),
    createdAt: v.number(),
    updatedAt: v.number(),
  }).index("by_userId", ["userId"]),

  // ============================================
  // CATEGORIES
  // ============================================

  /**
   * Service categories (seed data)
   */
  categories: defineTable({
    name: v.string(),
    slug: v.string(), // URL-safe identifier
    icon: v.optional(v.string()), // Lucide icon name
    description: v.optional(v.string()),
    isActive: v.boolean(),
    sortOrder: v.optional(v.number()),
  })
    .index("by_slug", ["slug"])
    .index("by_active", ["isActive"]),

  // ============================================
  // JOB REQUESTS
  // ============================================

  /**
   * Job request posted by seeker
   */
  jobRequests: defineTable({
    seekerId: v.id("users"),
    categoryId: v.id("categories"),
    categoryName: v.string(), // Denormalized for queries

    // Description
    description: v.string(),
    photos: v.optional(v.array(v.id("_storage"))),

    // Location
    location: v.object({
      address: v.optional(v.string()),
      city: v.string(),
      province: v.string(),
      coordinates: v.object({
        lat: v.number(),
        lng: v.number(),
      }),
      searchRadius: v.number(), // km
    }),
    geoPoint: v.optional(v.string()), // for @get-convex/geospatial

    // Timing
    timing: v.object({
      type: v.union(
        v.literal("flexible"),
        v.literal("within_48h"),
        v.literal("this_week"),
        v.literal("specific")
      ),
      specificDate: v.optional(v.string()), // ISO date
      specificTime: v.optional(v.string()), // HH:mm
    }),

    // Budget
    budget: v.optional(
      v.object({
        min: v.number(), // cents
        max: v.number(), // cents
      })
    ),

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

  // ============================================
  // JOBS (BOOKED/ACTIVE)
  // ============================================

  /**
   * Active or completed job (created from accepted proposal)
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
    rateType: v.union(v.literal("hourly"), v.literal("fixed")),

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
  // REVIEWS
  // ============================================

  /**
   * Review left after job completion
   */
  reviews: defineTable({
    jobId: v.id("jobs"),

    // Participants
    reviewerId: v.id("users"),
    revieweeId: v.id("users"),
    reviewerRole: v.union(v.literal("seeker"), v.literal("tasker")),

    // Review content
    rating: v.number(), // 1-5
    text: v.string(),

    // Category context
    categoryId: v.id("categories"),
    categoryName: v.string(),

    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_job", ["jobId"])
    .index("by_reviewee", ["revieweeId"])
    .index("by_reviewee_category", ["revieweeId", "categoryId"])
    .index("by_reviewer", ["reviewerId"]),

  // ============================================
  // SUBSCRIPTIONS
  // ============================================

  /**
   * Subscription record
   */
  subscriptions: defineTable({
    userId: v.id("users"),
    taskerProfileId: v.id("taskerProfiles"),

    // Plan
    plan: v.union(v.literal("basic"), v.literal("premium")),

    // Status
    status: v.union(
      v.literal("active"),
      v.literal("cancelled"),
      v.literal("past_due"),
      v.literal("expired")
    ),

    // Billing period
    currentPeriodStart: v.number(),
    currentPeriodEnd: v.number(),
    cancelAtPeriodEnd: v.boolean(),

    // Stripe integration
    stripeCustomerId: v.optional(v.string()),
    stripeSubscriptionId: v.optional(v.string()),

    // Timestamps
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_userId", ["userId"])
    .index("by_taskerProfile", ["taskerProfileId"])
    .index("by_stripeSubscription", ["stripeSubscriptionId"])
    .index("by_status", ["status"]),
});
```

---

## Schema Notes

### Indexes

Each table has indexes for efficient querying:

| Table | Key Indexes |
|-------|-------------|
| `users` | `by_authId` (auth lookup), `by_email` |
| `taskerProfiles` | `by_ghostMode` (search filtering), `by_premiumPin`, `by_location` |
| `taskerCategories` | `by_category` (search by category) |
| `conversations` | `by_participants` (find existing conversation), `by_seeker_lastMessage`, `by_tasker_lastMessage` |
| `messages` | `by_conversation_time` (ordered messages), `by_sender` |
| `jobRequests` | `by_seeker_status`, `by_location` |
| `jobs` | `by_seeker_status`, `by_tasker_status` (filtered lists) |

### Denormalization

Some fields are denormalized for query performance:

- `jobRequests.categoryName` - Avoid join for category name
- `jobs.categoryName` - Same reason
- `reviews.categoryName` - Same reason

### File Storage

Photos and attachments use Convex's built-in file storage:

```typescript
// Store files as v.id("_storage")
photos: v.array(v.id("_storage"))

// Upload flow:
// 1. Client calls mutation to get upload URL
// 2. Client uploads file directly to storage
// 3. Client calls mutation with storage ID to link to record
```

### Timestamps

All timestamps are `v.number()` representing Unix epoch milliseconds:

```typescript
createdAt: Date.now(),
updatedAt: Date.now(),
```

### Money

All monetary values are stored in **cents** as integers:

```typescript
rate: 8500,      // $85.00
budget: {
  min: 10000,    // $100.00
  max: 15000,    // $150.00
}
```

---

## Seed Data

### Categories

```typescript
// convex/seed.ts
import { mutation } from "./_generated/server";

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
```

Run seed: `npx convex run seed:seedCategories`

---

## Relationship Diagram

```
users
  │
  ├── 1:1 ── seekerProfiles
  │
  ├── 1:1 ── taskerProfiles
  │            │
  │            └── 1:N ── taskerCategories ── N:1 ── categories
  │
  ├── 1:N ── addresses
  │
  ├── 1:N ── jobRequests ── N:1 ── categories
  │
  ├── N:N ── conversations (as seeker or tasker)
  │            │
  │            └── 1:N ── messages
  │            └── 1:N ── proposals
  │
  ├── N:N ── jobs (as seeker or tasker)
  │            │
  │            └── 1:2 ── reviews (seeker review + tasker review)
  │
  └── 1:N ── subscriptions
```

---

## Validation Helpers

```typescript
// convex/lib/validators.ts
import { v } from "convex/values";

// Reusable validators
export const coordinates = v.object({
  lat: v.number(),
  lng: v.number(),
});

export const rateType = v.union(v.literal("hourly"), v.literal("fixed"));

export const subscriptionPlan = v.union(
  v.literal("none"),
  v.literal("basic"),
  v.literal("premium")
);

export const jobStatus = v.union(
  v.literal("pending"),
  v.literal("in_progress"),
  v.literal("completed"),
  v.literal("cancelled"),
  v.literal("disputed")
);

export const proposalStatus = v.union(
  v.literal("pending"),
  v.literal("accepted"),
  v.literal("declined"),
  v.literal("countered"),
  v.literal("expired")
);
```
