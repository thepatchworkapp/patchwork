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
| **Convex** | https://aware-meerkat-572.convex.site |

## Project Structure

```
Patchwork_MCP/
├── convex/           # Backend (mutations, queries, schema)
│   └── __tests__/    # Backend tests with convex-test
├── src/
│   ├── screens/      # 38 screen components (non-router navigation)
│   ├── components/
│   │   ├── ui/       # shadcn/ui components (48 files)
│   │   └── patchwork/ # Custom app components (10 files)
│   └── styles/       # Tailwind + global CSS
├── tests/ui/         # Browser-based UI tests
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

## Build & Test Commands

```bash
npm run dev        # Start Vite dev server
npm run build      # Build to build/ directory
npm run test       # Run Vitest in watch mode
npm run test:run   # Run tests once
npx convex dev     # Start Convex backend
```

## Environment Variables

Required in `.env.local`:
```
CONVEX_DEPLOYMENT=aware-meerkat-572
VITE_CONVEX_URL=https://aware-meerkat-572.convex.site
BETTER_AUTH_SECRET=<32+ chars>
GOOGLE_CLIENT_ID=<oauth>
GOOGLE_CLIENT_SECRET=<oauth>
```

## See Also

- `convex/AGENTS.md` - Backend-specific patterns
- `src/screens/AGENTS.md` - Screen component patterns
- `src/components/patchwork/AGENTS.md` - Custom component patterns
