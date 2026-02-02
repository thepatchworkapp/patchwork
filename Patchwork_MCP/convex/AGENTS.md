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

## File Storage Pattern

```typescript
// files.ts
export const generateUploadUrl = mutation({
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
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

## Common Pitfalls

1. **Using email instead of tokenIdentifier** - Auth lookup must use `identity.tokenIdentifier`
2. **Forgetting timestamps** - Every insert/update needs `createdAt`/`updatedAt`
3. **Throwing in queries** - Queries return null, mutations throw
4. **Missing index** - All filtered queries need `.withIndex()`
5. **Editing _generated/** - These files are auto-generated, edit source modules instead

## Run Commands

```bash
npx convex dev          # Start Convex in dev mode
npm run test            # Run backend tests
npm run test:run        # Run tests once (CI)
```
