# Patchwork_MCP

Mobile-first service marketplace (TaskRabbit-like) built with React + Vite + Convex + Better Auth.

Design source: https://www.figma.com/design/4sgVZ8eMkA18LI4cYaqQSl/Patchwork_MCP

## Stack

- Frontend: React 18, Vite
- Backend: Convex
- Auth: Better Auth (Google OAuth + Email OTP)
- Styling: Tailwind CSS, Radix UI (shadcn/ui) + custom `src/components/patchwork/`

## Project Layout

This repo is a monorepo-ish layout:

- `Patchwork_MCP/` is the app (Vite, Convex functions, backend tests)
- Repo root has Playwright configuration and E2E tests under `tests/ui/`

## Running Locally

Install deps:

```bash
cd Patchwork_MCP
npm i
```

Run the frontend:

```bash
cd Patchwork_MCP
npm run dev
```

Run Convex:

```bash
cd Patchwork_MCP
npx convex dev
```

Local dev URL: `http://localhost:5173`

## Environment Variables

Copy and fill `Patchwork_MCP/.env.example` -> `Patchwork_MCP/.env.local`.

Important:

- `VITE_CONVEX_URL` should be the Convex deployment URL ending in `.convex.cloud`.
- `VITE_CONVEX_SITE_URL` ends in `.convex.site` (used for HTTP Actions).
- `VITE_SITE_URL` should be `http://localhost:5173` for OAuth callbacks.

## Navigation (No React Router)

This app does NOT use React Router. Navigation is callback-based via the state machine in `Patchwork_MCP/src/App.tsx`.

## Data Sources (Mock vs Real)

Wired to real Convex data (smoke-test targets):

- Auth + profile creation
- Profile screen
- Categories
- Messages + Chat (real-time)
- Proposals + job creation on accept
- Jobs list
- Tasker onboarding
- Home swipe cards
- Browse provider list and provider detail
- Request flow steps (job requests)

Still mock / placeholder data:

- Map view in Browse (list view is real)
- Stripe/RevenueCat payment processing (subscriptions use mock bypass - always succeed)

## Subscription System (Mock Payment Bypass)

Subscriptions are wired to real Convex data but bypass actual payment processing. This is intentional - real payments will use RevenueCat when the mobile app goes to production.

**Current behavior:**
- User selects Basic ($7/mo) or Premium ($15/mo) plan
- Clicks "Subscribe" → mutation immediately succeeds (no payment)
- Subscription persists to database
- Ghost mode toggle requires active subscription
- Premium subscribers get a unique 6-digit PIN

**Mutations:**
- `updateSubscriptionPlan({ plan: "basic" | "premium" })` - Subscribe to a plan
- `setGhostMode({ ghostMode: boolean })` - Toggle visibility (requires subscription)

## Tests

Backend/unit tests (Vitest + convex-test):

```bash
cd Patchwork_MCP
npm run test:run
```

E2E UI tests (Playwright) live at repo root `tests/ui/`:

```bash
cd ..
# Ensure VITE_CONVEX_URL is set (use the value from Patchwork_MCP/.env.local)
VITE_CONVEX_URL=https://<deployment>.convex.cloud \
VITE_CONVEX_SITE_URL=https://<deployment>.convex.site \
  npx playwright test tests/ui/smoke.test.ts
```

Notes:

- Email OTP E2E uses the `/test-proxy` HTTP endpoint to invoke internal testing functions. Testing functions (`testing.ts`, `testingPhotos.ts`, `testingTasker.ts`) are `internalMutation`/`internalQuery` and cannot be called directly from clients. OTPs are stored hashed.
- E2E test isolation/cleanup is implemented as internal functions in `Patchwork_MCP/convex/testing.ts`, accessed via `/test-proxy`:
  - `deleteTestUser`, `deleteByEmailPrefix`, `ensureCategoryExists`, `cleanupConversations`
- Vitest is scoped to `convex/__tests__/**` and excludes `tests/ui/**` (Playwright)

## Conventions

- Backend mutations must: auth check first, lookup user by `identity.tokenIdentifier` (NOT email), include timestamps.
- Queries should return `null` when data is missing.
- Avoid `as any`, `@ts-ignore`, `@ts-expect-error`.
- Auth redirects should gate on Convex auth readiness (`useConvexAuth`) before using `getCurrentUser`.

See:

- `Patchwork_MCP/AGENTS.md`
- `Patchwork_MCP/convex/AGENTS.md`
- `Patchwork_MCP/src/screens/AGENTS.md`

## Staging (Cloudflare)

For staging deployment and security settings, see `doc/staging-cloudflare.md`.
