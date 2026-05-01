# Plan: Backend DTO Enrichment Helpers

## Objective

Centralize repeated backend DTO enrichment logic for users, taskers, conversations, jobs, and image fields. This should reduce drift between search, favourites, detail, conversations, jobs, and admin surfaces while preserving existing response shapes.

## Current State

Primary files:

- `patchwork-backend/convex/search.ts`
- `patchwork-backend/convex/taskers.ts`
- `patchwork-backend/convex/conversations.ts`
- `patchwork-backend/convex/jobs.ts`
- `patchwork-backend/convex/admin.ts`
- `patchwork-backend/convex/imageAssetHelpers.ts`
- `patchwork-backend/lib/convex/validators.ts`

Repeated logic includes:

- choosing account photo vs tasker custom photo
- resolving legacy `photo` URLs and new image asset DTOs
- building tasker summary cards
- building category/portfolio cover images
- building conversation participant summaries
- building job counterparty summaries
- loading reviewer display data

## Backend Interop Requirements

- Preserve every public endpoint field name and nullability unless the iOS model changes in the same PR.
- Keep helper-only modules outside `convex/` when they do not export Convex functions. Use `patchwork-backend/lib/convex/` to avoid generated API drift.
- Keep legacy URL fields until active clients no longer need them:
  - `avatarUrl`
  - `categoryPhotoUrl`
  - `userPhotoUrl`
  - `counterpartyPhotoUrl`
- Keep image asset DTO fields as the forward-looking contract:
  - `avatarImage`
  - `profileImage`
  - `categoryCoverImage`
  - `portfolioImages`
  - `counterpartyImage`

## Proposed Helper Modules

Add under `patchwork-backend/lib/convex/`:

- `dtoImages.ts`
  - helper wrappers around image asset URL resolution
  - account image vs tasker profile image selection
- `dtoTaskers.ts`
  - tasker summary DTO builder
  - tasker detail category DTO builder
  - price/distance formatting helpers if shared
- `dtoConversations.ts`
  - participant summary enrichment
  - list/detail conversation DTO builders
- `dtoJobs.ts`
  - job counterparty enrichment
  - job summary/detail shared helpers

If the helper count stays small, start with one file such as `lib/convex/dtoHelpers.ts` and split only when it becomes hard to navigate. Do not place helper-only modules under `convex/`, because Convex codegen treats that directory as API surface.

## Implementation Phases

### Phase 1: Lock Current Contracts

- Confirm `returns:` validators for endpoints being touched.
- Add missing focused tests before extracting helper logic.
- Snapshot representative return payloads in tests where shape drift is likely.

Start with endpoints that iOS consumes heavily:

- `search:searchTaskers`
- `taskers:listFavouriteTaskers`
- `taskers:getTaskerById`
- `conversations:listConversations`
- `conversations:getConversation`
- `jobs:listJobs`

### Phase 2: Extract Image Selection Helpers

- Move account-photo and tasker-photo selection logic into helper functions.
- Preserve legacy URL fields and image asset DTO fields.
- Keep `includeUrls` behavior explicit.
- Verify URL resolution is not done when unauthenticated contracts intentionally omit URLs.

### Phase 3: Extract Tasker Summary Builder

- Use one builder for search and favourites.
- Parameters should cover:
  - profile
  - user
  - primary category data
  - category doc
  - distance string
  - includeUrls
- Preserve search-specific distance filtering outside the DTO builder.

### Phase 4: Extract Conversation Participant Builder

- Use one helper for list and detail participant enrichment.
- Preserve tasker custom avatar preference.
- Keep unauthenticated query behavior unchanged.

### Phase 5: Extract Job Counterparty Builder

- Use one helper for `jobs:listJobs` and any job detail counterparty fields that share shape.
- Combine this with the `jobs:listJobs` ordering fix only if the diff stays reviewable. Otherwise, do ordering first.

### Phase 6: Apply To Admin Only After Client Surfaces

- Admin can reuse helpers after production client endpoints are stable.
- Do not let admin-only fields drive public DTO shape.

## Testing Plan

Focused backend tests:

```bash
cd patchwork-backend
npm run test:run -- convex/__tests__/search.test.ts
npm run test:run -- convex/__tests__/taskers.test.ts
npm run test:run -- convex/__tests__/conversations.test.ts
npm run test:run -- convex/__tests__/jobs.test.ts
npm run test:run -- convex/__tests__/messages.test.ts
npm run test:run -- convex/__tests__/imageAssets.test.ts
npm run codegen
```

iOS checks:

- Build scheme `Patchwork`.
- Verify discovery cards still show names, categories, prices, distance, avatars, and cover photos.
- Verify favourites match discovery card shape.
- Verify provider detail still shows avatar, category images, and reviews.
- Verify conversation list/detail avatars.
- Verify job list/detail counterparty avatar/name.

## Acceptance Criteria

- Search and favourite tasker summary construction uses one backend helper path.
- Conversation list and detail participant enrichment use one backend helper path.
- Job counterparty enrichment uses one backend helper path.
- Existing Swift models decode unchanged.
- Legacy URL fields and image asset DTO fields remain available where they existed before.
- Helper modules do not appear as public Convex API modules.
- Backend focused tests and codegen pass.

## Risks And Guards

- Risk: helper extraction changes nullability.
  - Guard: lock validators and tests before extraction.
- Risk: helper modules under `convex/` affect codegen.
  - Guard: place helper-only modules under `lib/convex/`.
- Risk: admin and public client needs diverge.
  - Guard: migrate public client endpoints first; adapt admin afterward.
