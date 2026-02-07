# Patchwork MCP - AI Agent Guidelines

> Mobile-first service marketplace (TaskRabbit-like) built with React + Convex + Better Auth

## Quick Reference

| Aspect | Value |
|--------|-------|
| **Stack** | React 18 + Vite 6 + Convex 1.31 + Better Auth |
| **Styling** | Tailwind CSS v4.1.3 (oklch colors) |
| **Components** | Radix UI (shadcn/ui) + custom patchwork/ |
| **Testing** | Vitest + convex-test (node environment) |
| **Auth** | Google OAuth + Email OTP via @convex-dev/better-auth |
| **Local Dev** | http://localhost:5173 |
| **Convex** | `https://<deployment>.convex.cloud` (queries) / `https://<deployment>.convex.site` (HTTP actions) |

## Project Structure

```
Patchwork_MCP/
├── convex/           # Backend (mutations, queries, schema)
│   └── __tests__/    # Backend tests with convex-test (85 tests)
├── src/
│   ├── screens/      # 38 screen components (non-router navigation)
│   ├── components/
│   │   ├── ui/       # shadcn/ui components (48 files)
│   │   └── patchwork/ # Custom app components (10 files)
│   ├── hooks/        # Custom hooks (useUserLocation, useChat)
│   └── styles/       # Tailwind + global CSS
├── tests/ui/         # Browser-based UI tests (Playwright)
└── .sisyphus/        # Work plans and tracking
```

## Critical Conventions

### 1. Navigation Pattern (NON-STANDARD)

This app does NOT use React Router. Navigation is callback-based:

```tsx
// CORRECT: All screens receive navigation callbacks
function Screen({ onNavigate, onBack }) {
  return <Button onClick={() => onNavigate("home")}>Go Home</Button>
}

// Screen names are strings, not routes
// See App.tsx for the screen state machine
```

### 1.5 Auth Readiness (Better Auth + Convex)

Gate redirects and `getCurrentUser` on Convex auth readiness:

```tsx
import { useConvexAuth } from "convex/react";

const { isAuthenticated: convexAuth, isLoading: convexAuthLoading } = useConvexAuth();
const convexUser = useQuery(api.users.getCurrentUser, convexAuth ? {} : "skip");

if (authLoading || convexAuthLoading) return;
```

### 2. Convex Backend Patterns

```typescript
// ALWAYS check auth first in mutations
export const myMutation = mutation({
  args: { ... },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");
    
    // Lookup user by authId
    const user = await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
    
    // Always include timestamps
    return ctx.db.insert("table", {
      ...data,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });
  }
});

// Queries return null (not throw) when data missing
export const myQuery = query({
  handler: async (ctx) => {
    const data = await ctx.db.query("table").first();
    return data; // null if not found
  }
});
```

### 3. Testing Pattern

```typescript
// convex/__tests__/*.test.ts
import { convexTest } from "convex-test";
import schema from "../schema";

// REQUIRED: Module mapping for convex-test
const modules: Record<string, () => Promise<any>> = {
  "../users.ts": async () => usersModule,
  "../categories.ts": async () => categoriesModule,
  // ... all backend modules
};

test("authenticated mutation", async () => {
  const t = convexTest(schema, modules);
  const asUser = t.withIdentity({
    tokenIdentifier: "google|123",
    email: "test@example.com",
  });
  
  const result = await asUser.mutation(api.users.createProfile, args);
});
```

### 4. Component Import Pattern

```tsx
// ALWAYS import from patchwork/ for app components
import { AppBar } from "@/components/patchwork/AppBar";
import { Button } from "@/components/patchwork/Button";
import { BottomNav } from "@/components/patchwork/BottomNav";

// Use ui/ for shadcn primitives
import { Dialog } from "@/components/ui/dialog";
```

### 5. Layout Structure (Screens)

```tsx
// Standard screen layout
<div className="min-h-screen bg-neutral-50 pb-20">
  <AppBar ... />
  <div className="px-4 py-6">
    {/* Content */}
  </div>
  <BottomNav activeTab="home" onNavigate={onNavigate} />
</div>
```

### 6. Location Pattern (HomeSwipe/Browse)

When using `useUserLocation`, request location on mount to avoid a skipped search query:

```tsx
useEffect(() => {
  if (!location && !isLoading && !error) {
    requestLocation();
  }
}, [location, isLoading, error, requestLocation]);
```

### 7. Subscription Pattern (Mock Payment Bypass)

Subscriptions bypass real payment processing (RevenueCat will be used for mobile production):

```typescript
// Subscribe to a plan (no payment required in dev)
const updateSubscription = useMutation(api.taskers.updateSubscriptionPlan);
await updateSubscription({ plan: "premium" }); // or "basic"

// Toggle ghost mode (requires active subscription)
const setGhostMode = useMutation(api.taskers.setGhostMode);
await setGhostMode({ ghostMode: true });
```

**Key behaviors:**
- `updateSubscriptionPlan` sets ghostMode to false (user becomes visible)
- `updateSubscriptionPlan` generates 6-digit `premiumPin` for Premium subscribers
- `setGhostMode` throws error if `subscriptionPlan === "none"`
- App.tsx syncs `subscriptionPlan` state from `getTaskerProfile` query

## Type Safety Rules

**NEVER use:**
- `as any`
- `@ts-ignore`
- `@ts-expect-error`
- Empty catch blocks `catch(e) {}`

**ALWAYS:**
- Define proper TypeScript interfaces
- Handle loading and error states
- Validate Convex query results before use

## File Upload Pattern

```typescript
// Frontend
const generateUploadUrl = useMutation(api.files.generateUploadUrl);
const uploadUrl = await generateUploadUrl();
const response = await fetch(uploadUrl, { method: "POST", body: file });
const { storageId } = await response.json();

// Backend (convex/files.ts)
export const generateUploadUrl = mutation({
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");
    return ctx.storage.generateUploadUrl();
  }
});
```

## Schema Conventions

```typescript
// convex/schema.ts patterns

// Nested objects for related fields
location: v.object({
  city: v.string(),
  province: v.string(),
}),

// Union for enums
status: v.union(v.literal("pending"), v.literal("active")),

// Index naming: by_<field>
.index("by_userId", ["userId"])
.index("by_authId", ["authId"])
```

## Known Anti-Patterns to Avoid

1. **Chat.tsx** has 38+ useState calls - DO NOT add more state here
2. **Profile.tsx** is 664 lines - Extract before adding features
3. **Hardcoded colors** throughout - Use CSS variables from index.css
4. **No error boundaries** - Add try/catch for Convex queries
5. **`.collect()` in Convex queries** - See `convex/AGENTS.md` Scaling Rules. Use `.take(n)` or `.paginate()`
6. **Client-side filtering of query results** - Always pass filter args to server. See `src/screens/AGENTS.md`

## Cross-Cutting Concerns (Known Gaps)

### ~~Category Source-of-Truth Mismatch~~ — RESOLVED

Backend is now the single source of truth. `categories` table has `emoji` and `group` fields. All frontend screens (`TaskerOnboarding1`, `CategorySelection`, `AddCategory`, `HomeSwipe`, `Home`, `HomeUnified`, `Categories`) fetch from `api.categories.listCategories`. Run `seedCategories` to populate 57 categories across 10 groups.

### ~~Rate Type Enum Mismatch~~ — RESOLVED

`TaskerOnboarding2.tsx` resolves `rateType="both"` to `"hourly"` before passing to `onNext`. Both hourly and fixed rate values are still sent — `rateType` just determines the primary display type.

### ~~Geospatial Data Not Wired End-to-End~~ — RESOLVED

`users.updateLocation` now schedules `internal.location.syncTaskerGeo` when the user is a tasker. This updates `taskerProfiles.location` and inserts into the geospatial index without requiring the UI to call a separate endpoint.

### Mobile Subscription Lifecycle (Future)

For mobile, minimize active Convex subscriptions to preserve battery/network:
- Tie subscription lifecycle to screen visibility (pause when backgrounded)
- Consider `usePaginatedQuery` over `useQuery` for large lists
- Debounce location updates to avoid subscription churn
- RevenueCat webhooks should call existing `updateSubscriptionPlan` / `setGhostMode` mutations

### ~~Auth/Authorization Gaps~~ — RESOLVED

All query endpoints now enforce ownership checks. `messages.listMessages`, `conversations.getConversation`, `jobs.getJob`, `reviews.getJobReviews` verify the caller is a participant. `sendMessage` rejects non-participants. `admin.listAllUsers` and `admin.getUserDetail` require admin email. Public endpoints (`getUserReviews`, `getTaskerById`, `searchTaskers`, categories, files) are intentionally open for browsing/discovery. See `convex/AGENTS.md` for full matrix.

## Recent Design Decisions

### Subscription System (Feb 2026)
- **Decision**: Mock payment bypass instead of Stripe integration
- **Rationale**: Real payments will use RevenueCat for mobile app; no need to integrate Stripe for web-only dev
- **Implementation**: `updateSubscriptionPlan` and `setGhostMode` mutations in `convex/taskers.ts`
- **Future**: Add RevenueCat webhook to call same mutations after payment verification

### Search & Discovery (Feb 2026)
- **Decision**: Service area overlap matching (`seekerRadius + taskerServiceRadius`)
- **Rationale**: Fair to both parties - seeker defines how far they'll travel, tasker defines service area
- **Implementation**: `convex/search.ts` with `searchTaskers` query
- **Note**: Using simple bounding box filter, not full geospatial component (sufficient for MVP)

## Build & Test Commands

```bash
npm run dev        # Start Vite dev server
npm run build      # Build to build/ directory
npm run test       # Run Vitest in watch mode
npm run test:run   # Run tests once
npx convex dev     # Start Convex backend
```

Notes:
- Vitest is scoped to `convex/__tests__/**` and excludes `tests/ui/**` (Playwright)

## Environment Variables

Required in `.env.local`:
```
CONVEX_DEPLOYMENT=dev:<deployment-name>
VITE_CONVEX_URL=https://<deployment>.convex.cloud
VITE_CONVEX_SITE_URL=https://<deployment>.convex.site
BETTER_AUTH_SECRET=<32+ chars>
GOOGLE_CLIENT_ID=<oauth>
GOOGLE_CLIENT_SECRET=<oauth>
```

## See Also

- `convex/AGENTS.md` - Backend-specific patterns
- `src/screens/AGENTS.md` - Screen component patterns
- `src/components/patchwork/AGENTS.md` - Custom component patterns
