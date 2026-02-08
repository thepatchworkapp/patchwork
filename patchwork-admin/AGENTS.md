# Patchwork Admin (Astro + React + Kumo)

This folder contains the **Patchwork admin** frontend deployed to Cloudflare Pages at:

- `https://admin.ddga.ltd` (custom domain)
- `https://patchwork-admin-staging.pages.dev` (Pages default domain)

## Stack

- Astro (static output) + React islands
- Kumo UI (`@cloudflare/kumo`) + Tailwind v4
- Convex backend (Better Auth + Convex React client)

## High-Level Auth

Admin authentication uses **Better Auth email OTP** hosted by Convex:

- Browser app origin: `https://admin.ddga.ltd`
- Better Auth base URL: `https://<deployment>.convex.site` (HTTP actions)
- Convex queries/mutations: `https://<deployment>.convex.cloud` (websocket)

We use:

- `@convex-dev/better-auth` (server-side in Convex)
- `@convex-dev/better-auth/react` (client-side provider)
- `crossDomainClient()` plugin to persist session across domains using `Better-Auth-Cookie` in localStorage

### Admin Allowlist

Admin authorization is enforced **server-side** in Convex via `ADMIN_EMAILS` (comma-separated), used by:

- `Patchwork_MCP/convex/admin.ts` (admin queries)
- `Patchwork_MCP/convex/adminOtp.ts` (legacy admin OTP routes)

The admin UI intentionally does **not** reveal allowlist status on the login screen (to avoid email enumeration).

**Important**: `ADMIN_APP_ORIGIN` must be explicitly set as a Convex environment variable. There is no localhost fallback -- if unset, all admin HTTP requests are rejected (fail-closed).

## Required Environment Variables (Build-Time)

Astro only exposes **client-safe** env vars to browser code when prefixed with `PUBLIC_`.

Set at build time:

- `PUBLIC_CONVEX_URL`
  - Example: `https://<deployment>.convex.cloud`
  - Used for `ConvexReactClient`
- `PUBLIC_CONVEX_SITE_URL` (optional)
  - Example: `https://<deployment>.convex.site`
  - If omitted, derived from `PUBLIC_CONVEX_URL` by replacing `.convex.cloud` -> `.convex.site`

Notes:

- `VITE_*` vars are **not** reliably exposed in Astro client bundles. Prefer `PUBLIC_*`.
- Keep `.convex.cloud` and `.convex.site` pointing at the **same** Convex deployment name.

## Local Development

```bash
cd patchwork-admin

PUBLIC_CONVEX_URL="https://<deployment>.convex.cloud" \
  npm run dev
```

## Deploy (Cloudflare Pages)

This repo deploys via **direct upload** (no Git integration). Env vars are baked at build time.

```bash
cd patchwork-admin

PUBLIC_CONVEX_URL="https://<deployment>.convex.cloud" \
  npm run build

npx wrangler pages deploy dist \
  --project-name patchwork-admin-staging \
  --branch main
```

## Key Files

- UI entry: `/Users/daldwinc/Documents/nosync/development/patchwork/patchwork-admin/src/pages/index.astro`
- React app: `/Users/daldwinc/Documents/nosync/development/patchwork/patchwork-admin/src/react/AdminApp.tsx`
- Env helpers: `/Users/daldwinc/Documents/nosync/development/patchwork/patchwork-admin/src/react/lib/env.ts`
- Convex URL helpers: `/Users/daldwinc/Documents/nosync/development/patchwork/patchwork-admin/src/react/lib/convexUrls.ts`
- Security headers: `/Users/daldwinc/Documents/nosync/development/patchwork/patchwork-admin/public/_headers`

## Design System Notes (Kumo)

- Use Kumo components directly (e.g. `@cloudflare/kumo/components/button`).
- The published Kumo CLI is currently unreliable for installing blocks in a non-interactive workflow.
- Styling lives in:
  - `/Users/daldwinc/Documents/nosync/development/patchwork/patchwork-admin/src/styles/global.css`
