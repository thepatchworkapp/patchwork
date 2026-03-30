# patchwork-backend Guidelines

> Convex backend for the Patchwork iOS app and the `patchwork-admin` web app.

## Scope

- This folder is the Convex project root.
- The old React/Vite PoC frontend has been removed.
- Keep this folder backend-only: `convex/`, `lib/`, backend tests, and backend docs.

## Quick Reference

| Aspect | Value |
|--------|-------|
| Stack | Convex 1.31 + Better Auth |
| Auth | Google OAuth + Email OTP via `@convex-dev/better-auth` |
| Billing | RevenueCat webhook-driven |
| Tests | Vitest + convex-test |
| Convex | `https://<deployment>.convex.cloud` (queries) / `https://<deployment>.convex.site` (HTTP actions) |

## Project Structure

```text
patchwork-backend/
├── convex/           # Backend functions, schema, HTTP actions
│   └── __tests__/    # Backend tests with convex-test
├── lib/              # Shared backend helpers and validators
└── .sisyphus/        # Work plans and tracking
```

## Commands

```bash
cd patchwork-backend
npm install
npm run dev
npm run codegen
npm run test:run
```

Use `npm run dev` to run `convex dev`. Use `npm run deploy` for production deploys when explicitly requested.

## Core Conventions

### Auth and user lookup

```ts
const identity = await ctx.auth.getUserIdentity();
if (!identity) throw new ConvexError("Unauthorized");

const user = await ctx.db
  .query("users")
  .withIndex("by_authId", (q) => q.eq("authId", identity.tokenIdentifier))
  .unique();
```

- Mutations must auth-check first.
- Look up app users by `identity.tokenIdentifier`, not email.
- Prefer shared helpers like `requireAppUser` and `getAppUserOrNull` when available.

### Return contracts

- Public queries should return `null` or empty collections for missing data where the client expects that behavior.
- Add `returns:` validators on public functions when touching contracts.
- Do not hand-edit `convex/_generated/*`.

### Query discipline

- Prefer `.unique()` when the invariant is one row.
- Avoid `.collect()` in production handlers when `.take()` or pagination will do.
- Resolve client-derived fields on the server when possible.

## Billing Rules

- The only tasker access types are `subscription` and `lifetime`.
- RevenueCat webhooks are the purchase-state source of truth.
- Do not add new client-driven billing mutations.
- Ghost Mode requires active paid tasker access.

## Testing Rules

- Backend tests live in `convex/__tests__/`.
- Use `convex-test` module maps for backend suites.
- Testing helpers live in `convex/testing.ts`, `convex/testingPhotos.ts`, and `convex/testingTasker.ts`.
- Keep tests backend-focused; do not recreate browser UI coverage in this folder.

## Environment Notes

Important environment variables:

- `CONVEX_DEPLOYMENT`
- `SITE_URL`
- `TRUSTED_ORIGINS`
- `ADMIN_APP_ORIGIN`
- `BETTER_AUTH_SECRET`
- `BETTER_AUTH_URL`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `RESEND_API_KEY`
- `OTP_FROM_EMAIL`
- `REVENUECAT_WEBHOOK_AUTHORIZATION`

## Avoid

- Reintroducing frontend build tooling into this folder
- Preserving stale `basic`, `premium`, weekly, Stripe, or Vercel assumptions
- Editing generated Convex files manually
