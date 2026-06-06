# Patchwork Convex Backend

This directory contains Patchwork's Convex backend: schema, queries, mutations,
internal actions, HTTP routes, Better Auth integration, geospatial discovery,
notifications, admin maintenance functions, and backend tests.

## Key Files

| File | Purpose |
| --- | --- |
| `schema.ts` | Data model, table validators, and indexes |
| `auth.ts` / `http.ts` | Better Auth setup and HTTP routes |
| `users.ts` | User profiles, push tokens, and account maintenance |
| `taskers.ts` / `taskersInternal.ts` | Tasker profiles, subscriptions, and category state |
| `search.ts` / `geospatial.ts` | Discover/search queries and geospatial indexing |
| `messages.ts` / `conversations.ts` | Chat, unread counts, and message pagination |
| `proposals.ts` / `jobs.ts` / `reviews.ts` | Job lifecycle and review flows |
| `admin.ts` | Admin dashboard queries, reset, and maintenance operations |
| `testing.ts` | Internal test helpers only |
| `_generated/` | Convex-generated types; do not edit by hand |

## Operating Rules

- Read `AGENTS.md` before editing backend functions. It is the source of truth
  for Patchwork-specific Convex patterns.
- Check auth in every non-public query or mutation. Look up app users by
  `identity.tokenIdentifier` through the `users.by_authId` index.
- Keep queries bounded. Use `.take(n)` with clamped limits for fixed lists and
  `.paginate()` for infinite-scroll flows such as chat history.
- Do not use `.collect()` in production paths. The only normal exception is
  bounded test or maintenance code where the caller explicitly chunks the work.
- Filter server-side with schema indexes. Add composite indexes when a feature
  needs to filter by more than one field.
- Store Convex storage IDs in documents, not generated URLs. Resolve URLs at
  read time only when the caller needs them.
- Run `npm run codegen` after schema or function signature changes that affect
  generated API/types.

## Common Commands

Run these from `patchwork-backend`:

```bash
npm run codegen
npm run test:run
npm run deploy -- --dry-run -y
```

For focused backend verification, prefer targeted Vitest files first:

```bash
npm run test:run -- convex/__tests__/search.test.ts
npm run test:run -- convex/__tests__/messages.test.ts
```

## Deployment Notes

Use `convex deploy --dry-run -y` before production deploys to catch schema and
function-contract problems. Production admin dashboard builds should point at
the production Convex deployment URLs, not a local or preview deployment.

Backend changes that touch schema, validators, or public function signatures
usually require regenerating types and checking dependent clients.
