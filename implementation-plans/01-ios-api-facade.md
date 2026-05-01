# Plan: Typed iOS API Facade

## Objective

Replace scattered raw Convex calls such as `client.query("users:getCurrentUser", args: [:])` and ad hoc `[String: Any]` dictionaries with a thin typed facade. The goal is to reduce endpoint typo risk, make iOS/backend interop easier to audit, and prepare for later bundled backend reads without moving auth behavior out of `ConvexHTTPClient`.

## Current State

Primary files:

- `Patchwork_iOS/Patchwork/Core/ConvexHTTPClient.swift`
- `Patchwork_iOS/Patchwork/Core/AppState.swift`
- `Patchwork_iOS/Patchwork/Core/Models.swift`
- `Patchwork_iOS/Patchwork/Features/Messages/MessagesView.swift`
- `Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift`
- `Patchwork_iOS/Patchwork/Features/Jobs/JobDetailView.swift`
- `Patchwork_iOS/Patchwork/Core/ImageAssetUploadService.swift`

The low-level client already handles Convex function envelopes, auth headers, token refresh, and retry-after-auth-failure behavior. The problem is the call-site contract surface: endpoint names and argument keys are spread across feature views and state code.

## Non-Goals

- Do not replace `ConvexHTTPClient`.
- Do not change Better Auth cookie/session/origin handling.
- Do not change backend endpoint names in this pass.
- Do not introduce local persistence or a second networking stack.

## Proposed Shape

Add a new facade in `Patchwork_iOS/Patchwork/Core/PatchworkAPI.swift`.

Recommended initial structure:

```swift
struct PatchworkAPI {
    let client: ConvexHTTPClient

    var users: UsersAPI { UsersAPI(client: client) }
    var categories: CategoriesAPI { CategoriesAPI(client: client) }
    var taskers: TaskersAPI { TaskersAPI(client: client) }
    var conversations: ConversationsAPI { ConversationsAPI(client: client) }
    var messages: MessagesAPI { MessagesAPI(client: client) }
    var jobs: JobsAPI { JobsAPI(client: client) }
    var reviews: ReviewsAPI { ReviewsAPI(client: client) }
    var moderation: ModerationAPI { ModerationAPI(client: client) }
    var files: FilesAPI { FilesAPI(client: client) }
}
```

The first version can still build `[String: Any]` internally. The important change is that views and state code no longer know string endpoint names or raw argument keys.

Example target:

```swift
let user = try await api.users.currentUser()
let jobs = try await api.jobs.list(statusGroup: appState.jobsStatusGroup, limit: 50)
let page = try await api.messages.list(conversationId: conversationId, cursor: cursor, limit: 30)
```

## Backend Interop Requirements

- Keep the facade endpoint inventory aligned with the backend functions in `Patchwork_iOS/AGENTS.md`.
- When a backend return validator changes, update the matching facade method return type and Swift model in the same PR.
- When a new backend endpoint is added, land its iOS facade method before direct feature usage.
- Keep RevenueCat reconciliation and auth refresh actions routed through their existing endpoints until a dedicated backend contract replaces them.

## Implementation Phases

### Phase 1: Add The Facade Without Migrating Screens

- Add `PatchworkAPI.swift`.
- Add one nested API struct per domain.
- Keep raw `query`, `mutation`, and `action` available only as the transport API during migration; new feature code should use typed facade methods once the relevant domain exists.
- Implement methods for the endpoints already used by `AppState`:
  - `categories:listCategories`
  - `users:getCurrentUser`
  - `conversations:listConversations`
  - `jobs:listJobs`
  - `taskers:getTaskerProfile`
  - `search:searchTaskers`
  - `taskers:getTaskerById`
  - `conversations:getConversation`
  - `taskers:listFavouriteTaskers`
  - `moderation:listBlockedUsers`
- Add a convenience on `SessionStore` if useful:
  - `var api: PatchworkAPI { PatchworkAPI(client: client) }`

### Phase 2: Migrate Core State

- Move `AppState` query/mutation calls to `PatchworkAPI`.
- Preserve current partial-failure behavior in `refreshAuthedData`.
- Keep image prefetch behavior untouched.
- Compile and verify no endpoint strings remain in `AppState`.

### Phase 3: Migrate High-Risk Feature Flows

Migrate one feature at a time:

- Jobs:
  - `jobs:getJob`
  - `jobs:completeJob`
  - `reviews:canReview`
  - `reviews:createReview`
- Messages:
  - `messages:listMessages`
  - `messages:sendMessage`
  - `proposals:*`
  - `moderation:*`
- Profile/tasker:
  - `taskers:createTaskerProfile`
  - `taskers:updateTaskerProfile`
  - `taskers:addTaskerCategory`
  - `taskers:updateTaskerCategory`
  - `taskers:removeTaskerCategory`
  - `taskers:setTaskerPhoto`
  - `taskers:setGhostMode`
  - `users:updateProfilePhoto`
  - `users:deleteAccount`

### Phase 4: Add Contract Tests

- Add lightweight Swift unit tests for facade argument construction where practical.
- Reuse the existing `TestURLProtocol` testing pattern in `Patchwork_iOS/PatchworkTests` so facade methods can be tested without live Convex calls.
- Add decode tests for DTOs that are most likely to drift:
  - `CurrentUser`
  - `TaskerProfileSelf`
  - `TaskerDetail`
  - `TaskerSummary`
  - `ConversationSummary`
  - `MessagesPage`
  - `JobSummary`
  - `JobDetail`
- Use fixture JSON that mirrors backend `returns:` validators.

## Testing Plan

Backend:

```bash
cd patchwork-backend
npm run codegen
npm run test:run
```

iOS:

- Build the `Patchwork` scheme.
- Run unit tests for facade DTO decoding.
- Smoke these flows after migration:
  - login restore
  - bootstrap
  - tasker create/update
  - chat send
  - block/unblock/report
  - image upload
  - job completion
  - review submission

## Acceptance Criteria

- Feature views and `AppState` do not contain raw Convex endpoint strings after their migration phase.
- `ConvexHTTPClient` remains the only layer that knows how to call `/api/query`, `/api/mutation`, and `/api/action`.
- Auth retry and session invalidation behavior is unchanged.
- All migrated flows compile without changing backend payload fields.
- New backend endpoints have facade methods before direct UI usage.
- Focused iOS tests and full backend tests pass for any migrated contract.

## Risks And Guards

- Risk: facade migration accidentally changes an argument key.
  - Guard: migrate one domain at a time and add fixture/argument tests.
- Risk: facade grows into a second state container.
  - Guard: keep it stateless. It should wrap calls, not own app data.
- Risk: existing direct transport methods remain attractive for new code.
  - Guard: document that new feature code should add a facade method first, then call through that typed method.
- Risk: generated/backend validators and Swift models drift.
  - Guard: add contract fixture tests and update backend validators plus Swift models together.
