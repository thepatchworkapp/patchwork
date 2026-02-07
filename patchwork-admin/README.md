# Patchwork Admin (Astro + React + Kumo)

Deployed to Cloudflare Pages:

- https://admin.ddga.ltd
- https://patchwork-admin-staging.pages.dev

## Local Development

```bash
cd patchwork-admin

PUBLIC_CONVEX_URL="https://<deployment>.convex.cloud" \
  npm run dev
```

## Build

```bash
cd patchwork-admin

PUBLIC_CONVEX_URL="https://<deployment>.convex.cloud" \
  npm run build
```

## Deploy (Direct Upload)

This repo deploys via `wrangler pages deploy` (no Git integration).

```bash
cd patchwork-admin

npx wrangler pages deploy dist \
  --project-name patchwork-admin-staging \
  --branch main
```

## Environment Variables (Build-Time)

Astro only exposes variables prefixed with `PUBLIC_` to browser code:

- `PUBLIC_CONVEX_URL` (required): `https://<deployment>.convex.cloud`
- `PUBLIC_CONVEX_SITE_URL` (optional): `https://<deployment>.convex.site`
  - If omitted, derived from `PUBLIC_CONVEX_URL` by replacing `.convex.cloud` -> `.convex.site`
- Admin authorization is enforced server-side in Convex via `ADMIN_EMAILS` (deployment env var)

More details: `./AGENTS.md`
