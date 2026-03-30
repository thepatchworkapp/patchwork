# patchwork-backend

Convex backend for Patchwork. The old React/Vite PoC client has been removed; the live clients are the native iOS app and the separate admin app in `patchwork-admin/`.

## Scope

- Backend functions: `convex/`
- Shared backend helpers and validators: `lib/`
- Backend tests: `convex/__tests__/`

This folder is still the Convex project root, even though the client web UI is gone.

## Running Locally

Install dependencies:

```bash
cd patchwork-backend
npm i
```

Run Convex dev:

```bash
cd patchwork-backend
npm run dev
```

Regenerate bindings:

```bash
cd patchwork-backend
npm run codegen
```

## Environment Variables

Copy `patchwork-backend/.env.example` to `patchwork-backend/.env.local` and fill the required values.

Important variables:

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

## Billing Contract

Tasker billing is normalized to RevenueCat plus App Store Connect. Convex is updated by RevenueCat webhook events, not by client-side purchase mutations.

Current behavior:

- The only paid tasker access types are `subscription` and `lifetime`
- RevenueCat webhooks activate, renew, restore, cancel-at-period-end, and expire tasker access
- Ghost Mode requires active paid tasker access

## Tests

Backend/unit tests:

```bash
cd patchwork-backend
npm run test:run
```

Focused test helpers live in Convex under `testing.ts`, `testingPhotos.ts`, and `testingTasker.ts`.

## References

- `patchwork-backend/AGENTS.md`
- `patchwork-backend/convex/AGENTS.md`
