# Convex Backend - AI Agent Guidelines

> Backend mutations, queries, schema, and authentication for Patchwork

## File Overview

| File | Purpose |
|------|---------|
| `schema.ts` | Data model definition with tables and indexes |
| `users.ts` | User CRUD and profile management |
| `taskers.ts` | Tasker profiles and category management |
| `categories.ts` | Service category queries and seeding |
| `files.ts` | File upload/download via Convex storage |
| `auth.ts` | Better Auth integration setup |
| `auth.config.ts` | Auth provider configuration |
| `http.ts` | HTTP router for auth endpoints |
| `convex.config.ts` | Convex app config with better-auth plugin |
| `_generated/` | Auto-generated types - DO NOT EDIT |
| `testing.ts` | Internal test utilities (OTP seeding, cleanup) - `internalMutation`/`internalQuery` only |
| `testingPhotos.ts` | Internal photo test utilities - `internalMutation`/`internalQuery` only |
| `testingTasker.ts` | Internal tasker test utilities - `internalMutation`/`internalQuery` only |

## Mutation Pattern (ALWAYS FOLLOW)

```typescript
export const myMutation = mutation({
  args: {
    field: v.string(),
    optionalField: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    // 1. ALWAYS check auth first
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");
    
    // 2. Lookup user by authId (NOT email)
    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    if (!user) throw new Error("User not found");
    
    // 3. ALWAYS include timestamps
    const id = await ctx.db.insert("tableName", {
      ...args,
      userId: user._id,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });
    
    return id;
  },
});
```

## Query Pattern

```typescript
export const myQuery = query({
  args: {
    id: v.optional(v.id("tableName")),
  },
  handler: async (ctx, args) => {
    // Queries can check auth but don't require it
    const identity = await ctx.auth.getUserIdentity();
    
    // RETURN NULL, don't throw errors for missing data
    if (!args.id) return null;
    
    const data = await ctx.db.get(args.id);
    return data; // null if not found
  },
});
```

## Schema Conventions

```typescript
// NESTED OBJECTS for related fields
location: v.object({
  city: v.string(),
  province: v.string(),
  coordinates: v.optional(v.object({
    lat: v.number(),
    lng: v.number(),
  })),
}),

// UNION TYPES for enums (not string)
status: v.union(
  v.literal("pending"),
  v.literal("active"),
  v.literal("completed")
),

// FOREIGN KEYS use v.id()
userId: v.id("users"),

// INDEX NAMING: by_<field> or by_<field1>_<field2>
.index("by_userId", ["userId"])
.index("by_authId", ["authId"])
.index("by_active", ["isActive"])
```

## Auth Identity Object

```typescript
const identity = await ctx.auth.getUserIdentity();
// identity.tokenIdentifier: "google|123" or "email|abc@..."
// identity.email: "user@example.com"
// identity.emailVerified: boolean

// Lookup pattern: ALWAYS use tokenIdentifier as authId
const user = await ctx.db
  .query("users")
  .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
  .first();
```

## Testing Pattern

```typescript
// __tests__/mymodule.test.ts
import { convexTest } from "convex-test";
import { expect, test, describe } from "vitest";
import { api } from "../_generated/api";
import schema from "../schema";

// CRITICAL: Module mapping required
import * as usersModule from "../users";
import * as categoriesModule from "../categories";

const modules: Record<string, () => Promise<any>> = {
  "../users.ts": async () => usersModule,
  "../categories.ts": async () => categoriesModule,
  // Add ALL modules used by the test
};

describe("myModule", () => {
  test("unauthenticated throws", async () => {
    const t = convexTest(schema, modules);
    await expect(
      t.mutation(api.users.createProfile, { ... })
    ).rejects.toThrow("Unauthorized");
  });

  test("authenticated works", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity({
      tokenIdentifier: "google|test123",
      email: "test@example.com",
    });
    
    const result = await asUser.mutation(api.users.createProfile, { ... });
    expect(result).toBeDefined();
    
    // Verify with query
    const user = await asUser.query(api.users.getCurrentUser);
    expect(user?.email).toBe("test@example.com");
  });
});
```

## Error Handling

| Context | Pattern |
|---------|---------|
| Mutation - no auth | `throw new Error("Unauthorized")` |
| Mutation - no user | `throw new Error("User not found")` |
| Mutation - duplicate | `throw new Error("Already exists")` |
| Query - no data | `return null` (NOT throw) |

## Input Validation (All Mutations)

All mutations validate inputs beyond Convex schema types. Add validation after auth/user lookup, before database writes:

```typescript
// String length limits
if (args.name.length > 100) throw new Error("Name must be 100 characters or less");
if (args.description.length > 5000) throw new Error("Description must be 5000 characters or less");

// Numeric bounds
if (args.rate < 1 || args.rate > 100000000) throw new Error("Rate out of range");
if (args.serviceRadius < 1 || args.serviceRadius > 250) throw new Error("Service radius out of range");
if (!Number.isInteger(args.rating)) throw new Error("Rating must be a whole number");

// Coordinate validation
if (args.lat < -90 || args.lat > 90) throw new Error("Latitude must be between -90 and 90");
if (args.lng < -180 || args.lng > 180) throw new Error("Longitude must be between -180 and 180");
```

**Server-side resolution**: Never trust client-supplied derived values. `createJobRequest` resolves `categoryName` from `categoryId` server-side; the client-supplied value is ignored.

## File Storage Pattern

```typescript
// files.ts
// Allowed types: image/jpeg, image/png, image/webp, image/gif, image/heic, image/heif
// Max size: 5 MB
export const generateUploadUrl = mutation({
  args: {
    contentType: v.string(),
    fileSize: v.number(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
    // Validates contentType against allowlist and fileSize <= 5MB
    return await ctx.storage.generateUploadUrl();
  },
});

export const getUrl = query({
  args: { storageId: v.id("_storage") },
  handler: async (ctx, { storageId }) => {
    return await ctx.storage.getUrl(storageId);
  },
});
```

## Seed Data Pattern

```typescript
export const seedCategories = mutation({
  args: {},
  handler: async (ctx) => {
    const existing = await ctx.db.query("categories").first();
    if (existing) return { seeded: false, count: 0 };
    
    const categories = [
      { name: "Cleaning", slug: "cleaning", ... },
      // ...
    ];
    
    for (const cat of categories) {
      await ctx.db.insert("categories", {
        ...cat,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });
    }
    
    return { seeded: true, count: categories.length };
  },
});
```

## Convex Scaling Rules (CRITICAL)

These rules are non-negotiable. Violating them will cause production outages at scale.

### Rule 1: NEVER Use `.collect()` in Production Queries

`.collect()` loads **every matching document into memory**. At 1K+ rows this breaks Convex's 8MB function size limit. At 100+ rows it's already wasteful.

```typescript
// FORBIDDEN — will OOM at scale
const allJobs = await ctx.db.query("jobs").withIndex("by_userId", q => q.eq("userId", userId)).collect();
const active = allJobs.filter(j => j.status === "active"); // client-side filtering of full table

// CORRECT — bounded server-side query
const activeJobs = await ctx.db
  .query("jobs")
  .withIndex("by_userId_status", q => q.eq("userId", userId).eq("status", "active"))
  .take(50);
```

**Only exception**: `convex/testing.ts` cleanup utilities (test-only, not production paths).

### Rule 2: Use `.take(n)` for Bounded Lists, `.paginate()` for Infinite Scroll

| Pattern | When to Use | Example |
|---------|-------------|---------|
| `.take(n)` | Fixed-size lists, dashboards, "top N" | Job lists, review lists, category lists |
| `.paginate()` | Infinite scroll / load-more UI | Chat messages (uses `paginationOptsValidator`) |
| `.first()` | Single document lookup | User profile, current job |

```typescript
// .take() pattern — most queries
export const listJobs = query({
  args: { limit: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const limit = Math.max(1, Math.min(args.limit ?? 25, 100)); // Bounded!
    return ctx.db.query("jobs").withIndex("by_userId", ...).take(limit);
  },
});

// .paginate() pattern — chat/messages only
export const listMessages = query({
  args: { conversationId: v.id("conversations"), paginationOpts: paginationOptsValidator },
  handler: async (ctx, args) => {
    return ctx.db
      .query("messages")
      .withIndex("by_conversationId", q => q.eq("conversationId", args.conversationId))
      .order("desc")
      .paginate(args.paginationOpts);
  },
});
```

### Rule 3: Always Bound `limit` Arguments

Never trust client-provided limits. Always clamp:

```typescript
const limit = Math.max(1, Math.min(args.limit ?? DEFAULT, MAX));
```

Current defaults across the codebase:

| Query | Default | Max |
|-------|---------|-----|
| `listJobs` | 25 | 100 |
| `listConversations` | 50 | 100 |
| `listMyJobRequests` | 25 | 100 |
| `getUserReviews` | 10 | 50 |
| `getJobReviews` | 2 (fixed) | — |
| `listCategories` | 200 (fixed) | — |

### Rule 4: Server-Side Filtering Over Client-Side Filtering

If a query accepts a filter parameter (status, role, category), apply it **in the query handler**, not in the UI component.

```typescript
// CORRECT — server filters by role
export const listConversations = query({
  args: { role: v.optional(v.union(v.literal("seeker"), v.literal("tasker"))) },
  handler: async (ctx, args) => {
    let q = ctx.db.query("conversations").withIndex("by_userId", ...);
    // Filter in handler, not in React component
    if (args.role === "seeker") q = q.filter(q => q.eq(q.field("seekerId"), userId));
    return q.take(50);
  },
});

// FORBIDDEN — fetching all then filtering in React
const allConversations = useQuery(api.conversations.listConversations);
const filtered = allConversations?.filter(c => c.seekerId === currentUser._id); // NO
```

### Rule 5: Avoid N+1 Queries

When building lists that need related data, prefer targeted single lookups over loading entire related tables.

```typescript
// BAD — loads ALL taskerCategories for each profile
for (const profile of profiles) {
  const allCats = await ctx.db.query("taskerCategories").withIndex("by_taskerId", ...).collect();
  const match = allCats.find(tc => tc.categoryId === targetCategory);
}

// GOOD — targeted lookup per profile
for (const profile of profiles) {
  const match = await ctx.db.query("taskerCategories")
    .withIndex("by_taskerId_categoryId", q => q.eq("taskerId", profile._id).eq("categoryId", targetCategory))
    .first();
}
```

## Future Considerations (Tech Debt & Gaps)

### 1. Summary/Cold Tables Pattern (NOT YET IMPLEMENTED)

For the hottest read paths (TBD which), create small read-optimized summary tables synced via cron batches. Dashboards/lists read from cold tables instead of hot ones.

**When to implement**: When any single query is called >100x/sec or when Convex dashboard shows read contention on a table.

**Pattern**:
```
Hot table (jobs) → Cron batch (every 5min) → Cold table (jobsSummary)
Dashboard reads from jobsSummary instead of jobs
```

### ~~2. Geospatial Wiring Gap~~ — RESOLVED

`users.updateLocation` now schedules `internal.location.syncTaskerGeo` when the user is a tasker. This updates `taskerProfiles.location` and the geospatial index without requiring the UI to call a separate endpoint.

### ~~2. Auth/Authorization Gaps~~ — RESOLVED

All query endpoints now enforce ownership checks. Non-participants get `null`/empty results (queries) or errors (mutations).

| Endpoint | Check |
|----------|-------|
| `messages.listMessages` | Auth + conversation participant |
| `messages.sendMessage` | Auth + conversation participant |
| `conversations.getConversation` | Auth + conversation participant |
| `jobs.getJob` | Auth + job seeker/tasker |
| `reviews.getJobReviews` | Auth + job participant |
| `admin.listAllUsers` | Auth + admin email |
| `admin.getUserDetail` | Auth + admin email |
| `proposals.sendProposal` | Auth + conversation participant |

Intentionally public: `getUserReviews`, `getTaskerById`, `searchTaskers`, `listCategories`, `getCategoryBySlug`, `files.getUrl`.

### ~~3. `usePaginatedQuery` Not Wired in Chat UI~~ — RESOLVED

`useChat` hook uses `usePaginatedQuery` with `initialNumItems: 25`. Chat.tsx has a "Load more" button wired to `loadMoreMessages`.

### ~~4. Category Source-of-Truth Mismatch~~ — RESOLVED

Backend is now the single source of truth. `categories` table has `emoji` and `group` fields. All 7 frontend screens fetch from `api.categories.listCategories`. Run `seedCategories` to populate 57 categories across 10 groups.

### ~~5. Rate Type Enum Mismatch~~ — RESOLVED

`TaskerOnboarding2.tsx` resolves `rateType="both"` to `"hourly"` before passing to `onNext`.

## Common Pitfalls

1. **Using email instead of tokenIdentifier** - Auth lookup must use `identity.tokenIdentifier`
2. **Forgetting timestamps** - Every insert/update needs `createdAt`/`updatedAt`
3. **Throwing in queries** - Queries return null, mutations throw
4. **Missing index** - All filtered queries need `.withIndex()`
5. **Editing _generated/** - These files are auto-generated, edit source modules instead
6. **Using `.collect()` without bounds** - See Scaling Rules above. Use `.take(n)` or `.paginate()`
7. **Client-side filtering** - Always filter server-side. See Rule 4 above

## Run Commands

```bash
npx convex dev          # Start Convex in dev mode
npm run test            # Run backend tests
npm run test:run        # Run tests once (CI)
```
