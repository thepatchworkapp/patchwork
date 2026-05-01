# Plan: AppState Refresh Narrowing And Bundled Reads

## Objective

Reduce over-refreshing in iOS and add backend bundled reads where a screen currently needs several independent calls to render one coherent state. This should improve performance and reduce race-prone client choreography without hiding backend contracts.

## Current State

Primary files:

- `Patchwork_iOS/Patchwork/Core/AppState.swift`
- `Patchwork_iOS/Patchwork/App/RootView.swift`
- `Patchwork_iOS/Patchwork/Features/Messages/MessagesView.swift`
- `Patchwork_iOS/Patchwork/Features/Jobs/JobDetailView.swift`
- `patchwork-backend/convex/conversations.ts`
- `patchwork-backend/convex/messages.ts`
- `patchwork-backend/convex/jobs.ts`
- `patchwork-backend/convex/moderation.ts`
- `patchwork-backend/convex/taskers.ts`
- `patchwork-backend/convex/users.ts`

`AppState.refreshAuthedData` currently fetches current user, conversations, jobs, and tasker profile together. It is used from root restore, profile, tasker onboarding, chat bootstrap, billing, reviews, and related flows. This makes unrelated screens refresh unrelated data.

Chat also loads conversation detail, safety status, messages, and job/review state through separate calls.

## Backend Interop Requirements

- Preserve existing narrow endpoints as stable public contracts and for isolated refreshes.
- Add bundled endpoints as new read APIs, not replacements.
- Keep auth and moderation semantics identical between bundled and existing narrow endpoints.
- Add `returns:` validators for bundled endpoints before iOS consumes them.
- Update Swift models and typed facade methods in the same PR as any new bundled endpoint.

## Proposed Backend Endpoints

### `app:getBootstrap`

Purpose: return data needed for initial signed-in app bootstrap.

Candidate response:

```ts
{
  currentUser: CurrentUser | null,
  categories: Category[],
  conversations: ConversationSummary[],
  jobs: JobSummary[],
  taskerProfile: TaskerProfileSelf | null,
}
```

Arguments:

- `conversationRole`
- `jobsStatusGroup`
- `limit`
- optional search/location inputs only if the home screen needs them immediately

### `messages:getThreadState`

Purpose: return all state needed to open a chat thread.

Candidate response:

```ts
{
  conversation: ConversationDetail | null,
  messages: MessagesPage,
  safetyStatus: ConversationSafetyStatus,
  job: JobDetail | null,
  canReview: boolean,
  reviewPolicy: { currentTimeMs: number, reviewWindowDays: number }
}
```

Arguments:

- `conversationId`
- `messageCursor`
- `messageLimit`

Review eligibility should use server time in the bundled endpoint. Keep the existing `reviews:canReview` contract available until the server-time review contract is implemented and iOS is migrated in the same release slice.

## Implementation Phases

### Phase 1: Make iOS Refresh Intent Explicit

Before backend bundled reads:

- Split `refreshAuthedData` into smaller public methods if needed:
  - `refreshCurrentUser`
  - `refreshTaskerProfile`
  - `refreshInboxSummary`
  - `refreshJobsSummary`
  - `refreshDashboardLists`
  - keep existing `refreshAuthedData` as an orchestration method
- Preserve partial-failure behavior:
  - do not clear existing conversations, jobs, or profile on transient subquery failure
  - only surface errors where the previous UI was empty or the user explicitly triggered refresh
- Replace broad calls where a narrow method already exists.
- Add AppState tests that prove targeted refreshes do not fetch unrelated categories, conversations, jobs, or tasker profile data.

### Phase 2: Add Typed API Facade Methods

Use the API facade plan first or in parallel:

- `api.app.bootstrap(...)`
- `api.messages.threadState(...)`
- wrappers for existing narrow refresh methods

### Phase 3: Add Backend `app:getBootstrap`

- Implement with the same helper functions and validators used by existing endpoints.
- Reuse existing enrichment behavior.
- Keep response field names stable and explicit.
- Add tests for unauthenticated and authenticated cases.

### Phase 4: Migrate Root Bootstrap

- Use `app:getBootstrap` in `loadBootstrapData`.
- Keep category-only retry behavior for unauthenticated users.
- Preserve foreground route preservation in `RootView`.
- Confirm background/foreground refresh does not unmount active onboarding/profile flows.
- Do not add a client fallback branch for a broken bundle endpoint; if bundle adoption fails, fix the backend contract or keep the primary narrow orchestration until the bundle is ready.

### Phase 5: Add Backend `messages:getThreadState`

- Implement after chat-specific behavior is well understood.
- Reuse message pagination and safety status code.
- Return a first page of messages plus cursor metadata.
- Preserve block/unblock/report behavior and composer-disabled semantics.

### Phase 6: Migrate Chat Bootstrap

- Replace initial chat load choreography with `messages:getThreadState`.
- Keep `messages:listMessages` for load-older pagination.
- Refresh only the changed pieces after sending messages, proposals, reviews, or moderation actions.

## Testing Plan

Backend:

```bash
cd patchwork-backend
npm run test:run -- convex/__tests__/users.test.ts
npm run test:run -- convex/__tests__/conversations.test.ts
npm run test:run -- convex/__tests__/messages.test.ts
npm run test:run -- convex/__tests__/jobs.test.ts
npm run test:run -- convex/__tests__/reviews.test.ts
npm run test:run -- convex/__tests__/security.test.ts
npm run codegen
```

iOS:

- Build scheme `Patchwork`.
- Verify foreground/background restore.
- Verify profile tab refresh.
- Verify billing sheet reconciliation refresh.
- Verify chat open from conversation list.
- Verify chat open from provider detail.
- Verify send message, load older messages, block, unblock, report.
- Verify complete job and submit review from chat and Jobs.

Regression tests to add or preserve:

- one failed bundled subread does not blank previously visible state unless the top-level auth state is invalid
- unauthenticated bootstrap returns categories plus null authed data if that is the chosen contract
- blocked conversation returns safety status that disables composer

## Acceptance Criteria

- Existing narrow backend endpoints remain available.
- `refreshAuthedData` no longer serves as the default answer for every screen-level refresh.
- Root bootstrap can render with one backend read for signed-in core data.
- Chat initial load can render from one thread-state read plus existing message pagination.
- Partial-failure behavior is preserved or explicitly documented where a bundled endpoint is all-or-nothing.
- iOS and backend DTO validators/models land together.
- Backend tests and focused iOS flows pass.

## Risks And Guards

- Risk: bundled endpoints become oversized.
  - Guard: bundle per screen, not per entire app. Keep pagination for messages and large lists.
- Risk: bundled reads hide failed subqueries.
  - Guard: decide per endpoint whether failures should fail the whole read or preserve previous client state.
- Risk: older TestFlight builds still use narrow endpoints.
  - Guard: retire existing endpoints only through an explicit release decision, not as part of the first bundled-read migration.
