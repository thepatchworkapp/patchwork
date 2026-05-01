# Plan: Backend Jobs List Ordering

## Objective

Fix `jobs:listJobs` so unfiltered and grouped job lists return the newest jobs by `updatedAt` without missing rows because of the current index and limit order. This is a correctness fix with performance benefits.

## Current State

Primary files:

- `patchwork-backend/convex/jobs.ts`
- `patchwork-backend/convex/schema.ts`
- `patchwork-backend/convex/__tests__/jobs.test.ts`
- `Patchwork_iOS/Patchwork/Core/AppState.swift`
- `Patchwork_iOS/Patchwork/Features/Jobs/JobsView.swift`

Current behavior:

- `listJobs` uses `by_seeker_status` and `by_tasker_status`.
- When no specific status or status group is supplied, the query constrains only `seekerId` or `taskerId` and takes `limit` rows before sorting by `updatedAt`.
- Because the compound index starts with `status`, a limited read can exclude newer jobs from another status before the in-memory sort runs.
- Status-group reads can return more than the requested limit after merging seeker and tasker rows.

## Backend Interop Requirements

- Keep the public function name `jobs:listJobs`.
- Preserve existing arguments:
  - `status`
  - `statusGroup`
  - `role`
  - `limit`
- Preserve the `JobSummary` fields expected by iOS.
- iOS should not need a code change for the initial fix unless the return contract is intentionally tightened.
- If the returned count is corrected to respect `limit` after dedupe, confirm the UI does not rely on over-limit payloads.

## Proposed Backend Changes

### Schema

Add indexes for unfiltered recency reads:

```ts
.index("by_seeker_updatedAt", ["seekerId", "updatedAt"])
.index("by_tasker_updatedAt", ["taskerId", "updatedAt"])
```

Add status-specific recency indexes:

```ts
.index("by_seeker_status_updatedAt", ["seekerId", "status", "updatedAt"])
.index("by_tasker_status_updatedAt", ["taskerId", "status", "updatedAt"])
```

Keep the existing `by_seeker_status` and `by_tasker_status` indexes unless a later index audit proves they are unused after this migration.

### Query Strategy

For each role:

- If `status` is provided, query the matching `*_status_updatedAt` index.
- If `statusGroup` maps to a finite status list, query each status with the `*_status_updatedAt` index, merge, sort by `updatedAt`, dedupe, and slice to `limit`.
- If no status filter exists, query the new `*_updatedAt` indexes in descending order.

After combining seeker and tasker rows:

- Dedupe by job ID.
- Sort once by `updatedAt` descending.
- Slice to the requested `limit`.
- Enrich only the final page, not every pre-slice candidate.

## Implementation Phases

### Phase 1: Add Failing Tests

Add tests that fail under the current implementation:

- User has more than `limit` jobs across mixed statuses.
- Newest jobs are in statuses that are not first in the current compound-index ordering.
- `statusGroup: "active"` returns only `pending` and `in_progress`, sorted by `updatedAt`.
- `statusGroup: "completed"` returns completed jobs only.
- User appears as both seeker and tasker and duplicate safety still holds.
- Returned array length is at most `limit`.

### Phase 2: Add Indexes And Query Helpers

- Add schema indexes.
- Create small local helpers in `jobs.ts`:
  - `normalizeLimit`
  - `statusesForArgs`
  - `listJobsForRole`
  - `dedupeSortAndLimitJobs`
- Apply a deterministic tie-breaker after `updatedAt`, such as `_creationTime` or stringified `_id`, so equal timestamps have stable ordering.
- Keep helpers local unless another module needs them.

### Phase 3: Enrich Final Results Only

- Move counterparty and image enrichment after dedupe/sort/slice.
- Preserve existing preference for tasker profile image when the counterparty is the tasker.
- Preserve `counterpartyPhotoUrl` for current iOS compatibility until legacy storage fields are retired.

### Phase 4: Verify iOS Behavior

- Confirm `AppState.refreshJobs` and `JobsView` need no API change.
- Verify active/completed tab switching still returns expected rows.

## Testing Plan

Focused backend tests:

```bash
cd patchwork-backend
npm run test:run -- convex/__tests__/jobs.test.ts
```

Full backend check:

```bash
cd patchwork-backend
npm run codegen
npm run test:run
```

iOS checks:

- Build scheme `Patchwork`.
- Smoke active and completed Jobs tabs.
- If UI tests are updated, run the focused jobs completion/review tests serially.

## Acceptance Criteria

- `jobs:listJobs` returns the newest jobs by `updatedAt` for unfiltered lists.
- `statusGroup: "active"` includes only pending and in-progress jobs.
- `statusGroup: "completed"` includes only completed jobs.
- Results are deduped when the current user can match multiple roles.
- Returned result count never exceeds the requested `limit`.
- Existing iOS `JobSummary` decoding does not change.
- Backend codegen and focused jobs tests pass.

## Risks And Guards

- Risk: new indexes require a Convex deploy before production traffic benefits.
  - Guard: keep old status indexes and avoid removing indexes in the same patch.
- Risk: slicing after dedupe changes over-limit results.
  - Guard: treat `limit` as the public contract and verify iOS displays the same or fewer correctly ordered rows.
- Risk: enrichment cost remains high.
  - Guard: enrich only final results after limiting.
