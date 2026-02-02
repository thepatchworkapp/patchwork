# Patchwork Implementation Plan

> **Convex + Better Auth Backend Implementation Guide**  
> Step-by-step guide to building the Patchwork backend

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Phase 1: Project Setup](#phase-1-project-setup)
3. [Phase 2: Authentication](#phase-2-authentication)
4. [Phase 3: Core Data Layer](#phase-3-core-data-layer)
5. [Phase 4: Real-time Messaging](#phase-4-real-time-messaging)
6. [Phase 5: Proposals & Jobs](#phase-5-proposals--jobs)
7. [Phase 6: Search & Discovery](#phase-6-search--discovery)
8. [Phase 7: Payments & Subscriptions](#phase-7-payments--subscriptions)
9. [Phase 8: Frontend Integration](#phase-8-frontend-integration)
10. [Deployment](#deployment)

---

## Prerequisites

### Required Tools
- Node.js 18+
- npm or pnpm
- Convex account (https://convex.dev)
- Stripe account (for payments)
- OAuth credentials (Google, Apple)

### Version Requirements
- Convex 1.25.0+
- better-auth 1.4.9 (pinned)

### Tech Stack
| Layer | Technology |
|-------|------------|
| Database & Backend | Convex |
| Authentication | better-auth + Convex plugin |
| Payments | Stripe |
| Frontend | React + Vite (existing) |
| Mobile (future) | React Native / Expo |

---

## Phase 0: Environment & Repo Hygiene

### 0.1 Add Environment Templates

Create `.env.example` so onboarding is consistent:

```bash
# Convex
CONVEX_DEPLOYMENT=dev:your-project-name
VITE_CONVEX_URL=http://localhost:3000

# Better Auth
BETTER_AUTH_SECRET=your-random-secret-32-chars-min
BETTER_AUTH_URL=http://localhost:3000
VITE_BETTER_AUTH_URL=http://localhost:3000

# OAuth Providers
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
APPLE_CLIENT_ID=your-apple-client-id
APPLE_CLIENT_SECRET=your-apple-client-secret

# Stripe (Phase 7)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRICE_BASIC=price_...
STRIPE_PRICE_PREMIUM=price_...
APP_URL=http://localhost:3000
```

### 0.2 Add Basic Validation Helpers

Create a small env helper in `convex/lib/env.ts` to fail fast when a secret is missing.

### 0.3 Add Minimal CI

Create a GitHub Actions workflow that runs `npm run build` and `npm run test` (when tests exist).

---

## Phase 1: Project Setup

### 1.1 Initialize Convex in the Project

```bash
# From project root (Patchwork_MCP/)
npm install convex@latest
npx convex dev
```

This will:
- Create `convex/` folder
- Generate `convex/_generated/` types
- Start the Convex dev server

### 1.2 Install Better Auth

```bash
npm install @convex-dev/better-auth better-auth@1.4.9 --save-exact
```

> **Important**: Pin `better-auth` to `1.4.9` for compatibility

### 1.3 Configure Convex

Create `convex/convex.config.ts`:

```typescript
import { defineApp } from "convex/server";
import { convexAuth } from "@convex-dev/better-auth";

export default defineApp({
  components: {
    auth: convexAuth,
  },
});
```

### 1.4 Project Structure

```
Patchwork_MCP/
├── convex/
│   ├── _generated/          # Auto-generated (don't edit)
│   ├── convex.config.ts     # Convex app config
│   ├── schema.ts            # Database schema
│   ├── auth.ts              # Auth configuration
│   ├── users.ts             # User mutations/queries
│   ├── taskers.ts           # Tasker mutations/queries
│   ├── jobs.ts              # Jobs mutations/queries
│   ├── requests.ts          # Job requests
│   ├── messages.ts          # Messaging
│   ├── proposals.ts         # Proposals
│   ├── reviews.ts           # Reviews
│   ├── subscriptions.ts     # Subscription management
│   ├── categories.ts        # Categories (seed data)
│   └── search.ts            # Search queries
├── src/
│   ├── lib/
│   │   ├── convex.ts        # Convex client setup
│   │   └── auth.ts          # Auth client setup
│   └── ...existing code
└── package.json
```

### 1.5 Environment Variables

Create `.env.local`:

```bash
# Convex
CONVEX_DEPLOYMENT=dev:your-project-name
VITE_CONVEX_URL=http://localhost:3000

# Better Auth
BETTER_AUTH_SECRET=your-random-secret-32-chars-min
BETTER_AUTH_URL=http://localhost:3000
VITE_BETTER_AUTH_URL=http://localhost:3000

# OAuth Providers
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
APPLE_CLIENT_ID=your-apple-client-id
APPLE_CLIENT_SECRET=your-apple-client-secret

# Stripe (Phase 7)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRICE_BASIC=price_...
STRIPE_PRICE_PREMIUM=price_...
```

---

## Phase 2: Authentication

### 2.1 Configure Better Auth

Configure providers and email auth following the Convex + Better Auth guide:

- Use the Better Auth config file recommended by the guide (often `convex/auth.ts` or `convex/auth.config.ts`)
- Use `@auth/core/providers/*` providers (Google, Apple) per Better Auth docs
- Keep sign-in/sign-out strictly client-side (Convex functions run over websockets)

### 2.2 Frontend Auth Client

Create `src/lib/auth.ts`:

```typescript
import { createAuthClient } from "better-auth/react";

export const authClient = createAuthClient({
  baseURL: import.meta.env.VITE_BETTER_AUTH_URL,
});

// Hook for auth state
export function useAuth() {
  return authClient.useSession();
}
```

### 2.3 Wrap App with Providers

Update `src/main.tsx`:

```typescript
import { ConvexProvider, ConvexReactClient } from "convex/react";

const convex = new ConvexReactClient(import.meta.env.VITE_CONVEX_URL);

ReactDOM.createRoot(document.getElementById("root")!).render(
  <ConvexProvider client={convex}>
    <App />
  </ConvexProvider>
);
```

### 2.4 Implement Auth Screens

Update existing auth screens to use Better Auth:

```typescript
// SignIn.tsx
import { authClient } from "../lib/auth";

export function SignIn({ onSignIn, ... }) {
  const handleGoogleSignIn = async () => {
    await authClient.signIn.social({
      provider: "google",
      callbackURL: "/",
    });
  };

  const handleAppleSignIn = async () => {
    await authClient.signIn.social({
      provider: "apple", 
      callbackURL: "/",
    });
  };

  const handleEmailSignIn = async (email: string) => {
    await authClient.signIn.emailOtp({ email });
    // Navigate to verification screen
  };

  // ... rest of component
}
```

---

## Phase 3: Core Data Layer

### 3.1 Define Schema

See `CONVEX_SCHEMA.md` for complete schema. Key tables:

```typescript
// convex/schema.ts
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  users: defineTable({ ... }),
  seekerProfiles: defineTable({ ... }),
  taskerProfiles: defineTable({ ... }),
  taskerCategories: defineTable({ ... }),
  categories: defineTable({ ... }),
  addresses: defineTable({ ... }),
  jobRequests: defineTable({ ... }),
  jobs: defineTable({ ... }),
  conversations: defineTable({ ... }),
  messages: defineTable({ ... }),
  proposals: defineTable({ ... }),
  reviews: defineTable({ ... }),
  subscriptions: defineTable({ ... }),
});
```

### 3.2 Seed Categories

```typescript
// convex/categories.ts
import { mutation, query } from "./_generated/server";

export const seed = mutation({
  handler: async (ctx) => {
    const categories = [
      { name: "Plumbing", slug: "plumbing", icon: "wrench" },
      { name: "Electrical", slug: "electrical", icon: "zap" },
      { name: "Handyman", slug: "handyman", icon: "hammer" },
      { name: "Cleaning", slug: "cleaning", icon: "sparkles" },
      { name: "Moving", slug: "moving", icon: "truck" },
      { name: "Painting", slug: "painting", icon: "paintbrush" },
      { name: "Gardening", slug: "gardening", icon: "flower" },
      { name: "Pest Control", slug: "pest-control", icon: "bug" },
      { name: "Appliance Repair", slug: "appliance-repair", icon: "refrigerator" },
      { name: "HVAC", slug: "hvac", icon: "thermometer" },
      { name: "IT Support", slug: "it-support", icon: "laptop" },
      { name: "Tutoring", slug: "tutoring", icon: "book" },
    ];

    for (const category of categories) {
      await ctx.db.insert("categories", {
        ...category,
        isActive: true,
      });
    }
  },
});
```

### 3.3 User Management

```typescript
// convex/users.ts
import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const createProfile = mutation({
  args: {
    name: v.string(),
    photo: v.optional(v.string()),
    city: v.string(),
    province: v.string(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    const userId = await ctx.db.insert("users", {
      authId: identity.tokenIdentifier,
      email: identity.email!,
      name: args.name,
      photo: args.photo,
      location: {
        city: args.city,
        province: args.province,
      },
      roles: {
        isSeeker: true,
        isTasker: false,
      },
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    // Create seeker profile
    await ctx.db.insert("seekerProfiles", {
      userId,
      jobsPosted: 0,
      completedJobs: 0,
      rating: 0,
      favouriteTaskers: [],
    });

    return userId;
  },
});

export const getCurrentUser = query({
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return null;

    return await ctx.db
      .query("users")
      .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
      .first();
  },
});
```

---

## Phase 4: Real-time Messaging

### 4.1 Conversation Management

```typescript
// convex/messages.ts
import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const startConversation = mutation({
  args: {
    taskerId: v.id("users"),
    jobRequestId: v.optional(v.id("jobRequests")),
    initialMessage: v.string(),
  },
  handler: async (ctx, args) => {
    const user = await getCurrentUser(ctx);
    if (!user) throw new Error("Not authenticated");

    // Check if conversation exists
    const existing = await ctx.db
      .query("conversations")
      .filter((q) =>
        q.and(
          q.eq(q.field("seekerId"), user._id),
          q.eq(q.field("taskerId"), args.taskerId)
        )
      )
      .first();

    if (existing) {
      // Add message to existing conversation
      await ctx.db.insert("messages", {
        conversationId: existing._id,
        senderId: user._id,
        type: "text",
        content: args.initialMessage,
        createdAt: Date.now(),
      });
      return existing._id;
    }

    // Create new conversation
    const conversationId = await ctx.db.insert("conversations", {
      seekerId: user._id,
      taskerId: args.taskerId,
      jobRequestId: args.jobRequestId,
      lastMessageAt: Date.now(),
      createdAt: Date.now(),
    });

    // Add initial message
    await ctx.db.insert("messages", {
      conversationId,
      senderId: user._id,
      type: "text",
      content: args.initialMessage,
      createdAt: Date.now(),
    });

    return conversationId;
  },
});

// Real-time subscription to messages
export const listMessages = query({
  args: { conversationId: v.id("conversations") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("messages")
      .withIndex("by_conversation", (q) => q.eq("conversationId", args.conversationId))
      .order("asc")
      .collect();
  },
});
```

### 4.2 Frontend Integration

```typescript
// Chat.tsx
import { useQuery, useMutation } from "convex/react";
import { api } from "../../convex/_generated/api";

export function Chat({ conversationId }) {
  // Real-time messages subscription
  const messages = useQuery(api.messages.listMessages, { conversationId });
  const sendMessage = useMutation(api.messages.sendMessage);

  const handleSend = async (text: string) => {
    await sendMessage({ conversationId, content: text });
  };

  // messages updates automatically in real-time!
}
```

---

## Phase 5: Proposals & Jobs

### 5.1 Proposal Lifecycle

```typescript
// convex/proposals.ts
export const sendProposal = mutation({
  args: {
    conversationId: v.id("conversations"),
    rate: v.number(), // cents
    rateType: v.union(v.literal("hourly"), v.literal("flat")),
    startDateTime: v.string(),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    // ... create proposal
    // ... send system message to conversation
  },
});

export const acceptProposal = mutation({
  args: { proposalId: v.id("proposals") },
  handler: async (ctx, args) => {
    const proposal = await ctx.db.get(args.proposalId);
    
    // Update proposal status
    await ctx.db.patch(args.proposalId, { status: "accepted" });
    
    // Create job from proposal
    const jobId = await ctx.db.insert("jobs", {
      seekerId: proposal.receiverId,
      taskerId: proposal.senderId,
      proposalId: args.proposalId,
      rate: proposal.rate,
      rateType: proposal.rateType,
      startDate: proposal.startDateTime,
      status: "pending",
      // ...
    });

    return jobId;
  },
});
```

---

## Phase 6: Search & Discovery

### 6.1 Geospatial Search (Recommended)

Prefer the Convex geospatial component (`@get-convex/geospatial`) over manual bounding-box filters. This keeps distance calculations accurate and efficient.

### 6.1 Geospatial Search

Convex supports geospatial queries. For tasker discovery:

```typescript
// convex/search.ts
import { query } from "./_generated/server";
import { v } from "convex/values";

export const searchTaskers = query({
  args: {
    category: v.optional(v.string()),
    lat: v.number(),
    lng: v.number(),
    radiusKm: v.number(),
    limit: v.optional(v.number()),
    cursor: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    // Calculate bounding box from lat/lng and radius
    const { minLat, maxLat, minLng, maxLng } = getBoundingBox(
      args.lat,
      args.lng,
      args.radiusKm
    );

    let query = ctx.db
      .query("taskerProfiles")
      .filter((q) =>
        q.and(
          q.eq(q.field("ghostMode"), false),
          q.gte(q.field("location.lat"), minLat),
          q.lte(q.field("location.lat"), maxLat),
          q.gte(q.field("location.lng"), minLng),
          q.lte(q.field("location.lng"), maxLng)
        )
      );

    if (args.category) {
      // Filter by category
    }

    const results = await query.take(args.limit || 20);

    // Calculate actual distance and sort
    return results
      .map((tasker) => ({
        ...tasker,
        distance: calculateDistance(args.lat, args.lng, tasker.location.lat, tasker.location.lng),
      }))
      .filter((t) => t.distance <= args.radiusKm)
      .sort((a, b) => a.distance - b.distance);
  },
});
```

---

## Phase 7: Payments & Subscriptions

### 7.0 HTTP Routes for Webhooks

Add `convex/http.ts` to register Stripe webhooks and any future HTTP endpoints.

### 7.1 Stripe Integration

```typescript
// convex/subscriptions.ts
import { action, mutation } from "./_generated/server";
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

export const createCheckoutSession = action({
  args: { plan: v.union(v.literal("basic"), v.literal("premium")) },
  handler: async (ctx, args) => {
    const user = await ctx.runQuery(internal.users.getCurrentUser);
    
    const priceId = args.plan === "basic"
      ? process.env.STRIPE_PRICE_BASIC
      : process.env.STRIPE_PRICE_PREMIUM;

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer_email: user.email,
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: `${process.env.APP_URL}/subscription/success`,
      cancel_url: `${process.env.APP_URL}/subscription/cancel`,
      metadata: {
        userId: user._id,
        plan: args.plan,
      },
    });

    return { url: session.url };
  },
});

// Webhook handler for subscription events
export const handleStripeWebhook = httpAction(async (ctx, request) => {
  const signature = request.headers.get("stripe-signature")!;
  const body = await request.text();
  
  const event = stripe.webhooks.constructEvent(
    body,
    signature,
    process.env.STRIPE_WEBHOOK_SECRET!
  );

  switch (event.type) {
    case "checkout.session.completed":
      await ctx.runMutation(internal.subscriptions.activate, {
        userId: event.data.object.metadata.userId,
        plan: event.data.object.metadata.plan,
        stripeSubscriptionId: event.data.object.subscription,
      });
      break;
    case "customer.subscription.deleted":
      await ctx.runMutation(internal.subscriptions.cancel, {
        stripeSubscriptionId: event.data.object.id,
      });
      break;
  }

  return new Response("OK");
});
```

---

## Phase 8: Frontend Integration

### 8.1 Replace Mock Data with Convex Queries

```typescript
// Before (mock data)
const [messages, setMessages] = useState<Message[]>([
  { sender: "them", text: "Hi!", time: "10:30 AM" },
]);

// After (Convex subscription)
const messages = useQuery(api.messages.listMessages, { conversationId });
const sendMessage = useMutation(api.messages.sendMessage);
```

### 8.2 Integration Checklist

| Screen | Replace Mock Data With |
|--------|----------------------|
| SignIn, CreateAccount | Better Auth methods |
| Profile | `api.users.getCurrentUser` |
| HomeSwipe | `api.search.searchTaskers` |
| Messages | `api.messages.listConversations` |
| Chat | `api.messages.listMessages` |
| Jobs | `api.jobs.listJobs` |
| RequestStep1-4 | `api.requests.create` |
| Subscriptions | `api.subscriptions.createCheckoutSession` |

---

## Phase 9: Testing & Observability

### 9.0 Test Framework Setup

Install Vitest and necessary dependencies:

```bash
npm install -D vitest @vitest/coverage-v8 jsdom @testing-library/react @testing-library/jest-dom
```

Add test scripts to `package.json`:

```json
{
  "scripts": {
    "test": "vitest",
    "test:ui": "vitest --ui",
    "test:coverage": "vitest run --coverage"
  }
}
```

Create `vitest.config.ts`:

```typescript
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: './src/test/setup.ts',
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
    },
  },
});
```

### 9.1 Test File Structure

Maintain a clean separation between frontend and backend tests:

```
Patchwork_MCP/
├── convex/
│   └── __tests__/           # Convex function tests
│       ├── users.test.ts
│       └── jobs.test.ts
├── src/
│   ├── test/
│   │   └── setup.ts         # Vitest setup (matchers, etc.)
│   ├── components/
│   │   └── __tests__/       # Component unit tests
│   └── lib/
│       └── __tests__/       # Utility and logic tests
└── ...
```

### 9.2 Convex Testing

Use `convex-test` for end-to-end testing of Convex functions without a real backend:

```bash
npm install -D convex-test
```

Example test in `convex/__tests__/users.test.ts`:

```typescript
import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import { api } from "../_generated/api";
import schema from "../schema";

test("creating a user profile", async () => {
  const t = convexTest(schema);
  
  // Mock authentication
  const authenticated = t.withIdentity({
    tokenIdentifier: "google|123",
    email: "test@example.com",
  });

  const userId = await authenticated.mutation(api.users.createProfile, {
    name: "Test User",
    city: "Toronto",
    province: "ON",
  });

  const user = await authenticated.query(api.users.getCurrentUser);
  expect(user?.name).toBe("Test User");
  expect(user?._id).toBe(userId);
});
```

### 9.3 Coverage Targets

Aim for high confidence in core business logic:

| Component Type | Coverage Target | Focus Areas |
|----------------|-----------------|-------------|
| Convex Mutations | 80% | Validation, Auth, State transitions |
| Convex Queries | 70% | Filtering logic, Privacy/Access control |
| React Components | 60% | Happy paths, Error states, User interaction |
| Utilities/Helpers | 90% | Pure functions, Date/Currency formatting |

### 9.4 Minimum Test Suite
- Unit tests for auth/session flow
- Mutation tests for critical writes (requests, proposals, jobs)
- Query tests for search and messaging

### 9.5 Monitoring
- Error tracking (Sentry or equivalent)
- Structured logging for mutations/actions

---

## Deployment

### Development
```bash
npx convex dev  # Starts Convex dev server
npm run dev     # Starts Vite dev server
```

### Staging (Vercel Preview)
```bash
npx convex deploy --preview  # Deploy to preview
# Vercel auto-deploys on PR
```

### Production
```bash
npx convex deploy  # Deploy to production
# Configure Vercel production deployment
```

### Environment Variables on Vercel
Set all `.env.local` variables in Vercel project settings.

### iOS App (Future)
- Use same Convex backend
- Replace Vite frontend with React Native/Expo
- Use `@convex-dev/better-auth` Expo guide
- No Vercel needed for production iOS

---

## Migration Path

### Step 1: Parallel Development
- Keep mock data working in UI
- Build Convex backend in parallel
- Test each feature in isolation

### Step 2: Feature Flags
```typescript
const USE_CONVEX = import.meta.env.VITE_USE_CONVEX === "true";

// In components
const messages = USE_CONVEX 
  ? useQuery(api.messages.listMessages, { conversationId })
  : mockMessages;
```

### Step 3: Gradual Rollout
1. Auth (Better Auth)
2. User profiles
3. Categories
4. Messages (high impact, validates real-time)
5. Job requests
6. Proposals & Jobs
7. Subscriptions (Stripe)
8. Search & discovery

---

## Testing Checklist

- [ ] Auth: Sign up, sign in, sign out (email + OAuth)
- [ ] Profile: Create, update, view
- [ ] Tasker: Onboarding flow, category management
- [ ] Requests: Create job request (4 steps)
- [ ] Search: Find taskers by location/category
- [ ] Messages: Real-time chat
- [ ] Proposals: Send, counter, accept, decline
- [ ] Jobs: Track in-progress, complete
- [ ] Reviews: Leave review after job
- [ ] Subscriptions: Purchase Basic/Premium, manage
- [ ] Ghost mode: Verify invisible without subscription
