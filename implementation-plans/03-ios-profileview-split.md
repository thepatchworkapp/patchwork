# Plan: Split ProfileView By Flow Ownership

## Objective

Reduce `ProfileView.swift` size and risk by moving self-contained flows into dedicated files without changing runtime behavior. This is a structural refactor only.

## Current State

Primary file:

- `Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift`

The file currently owns:

- account/profile display and photo editing
- profile sidebar menu
- favourites panel
- blocked users panel
- support, delete account, help, legal, and feedback screens
- tasker onboarding
- tasker create flow
- tasker profile management
- add/edit category sheets
- portfolio photo editor and thumbnails

## Backend Interop Requirements

- No backend endpoint changes in this refactor.
- Existing Convex function calls must remain identical until the typed API facade is available.
- Preserve these cross-layer contracts:
  - `taskers:createTaskerProfile`
  - `taskers:updateTaskerProfile`
  - `taskers:addTaskerCategory`
  - `taskers:updateTaskerCategory`
  - `taskers:removeTaskerCategory`
  - `taskers:setTaskerPhoto`
  - `taskers:setGhostMode`
  - `users:updateProfilePhoto`
  - `moderation:listBlockedUsers`
  - `moderation:unblockUser`
  - `users:deleteAccount`

## Proposed File Split

Keep:

- `Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift`
  - top-level `ProfileView`
  - account summary
  - sidebar presentation wiring
  - high-level navigation/sheet routing

Add:

- `Patchwork_iOS/Patchwork/Features/Profile/ProfileAccountSection.swift`
- `Patchwork_iOS/Patchwork/Features/Profile/ProfilePanels.swift`
  - favourites panel
  - blocked users panel
  - support section
  - help/legal/feedback screens, or split further if needed
- `Patchwork_iOS/Patchwork/Features/Profile/TaskerOnboardingView.swift`
- `Patchwork_iOS/Patchwork/Features/Profile/TaskerCreateFlowView.swift`
- `Patchwork_iOS/Patchwork/Features/Profile/TaskerProfileManageView.swift`
- `Patchwork_iOS/Patchwork/Features/Profile/TaskerCategoryEditor.swift`
  - add category sheet
  - editable category sheet
  - category service details section
- `Patchwork_iOS/Patchwork/Features/Profile/TaskerPortfolioEditor.swift`
  - portfolio photo image
  - portfolio editor
  - portfolio thumbnail
- Optional if the file is still too broad after extraction:
  - `TaskerWorkspaceSection.swift`
  - `ProfileSupportSection.swift`
  - `TaskerCategoryEditorViews.swift`

Because `project.yml` includes the `Patchwork` source directory, adding files under this tree should not require project.yml edits.

## Implementation Phases

### Phase 1: Extract Passive Views

Move low-risk view-only structs first:

- link row style/label
- support/help/legal/feedback views
- favourites and blocked panels if they carry minimal dependencies
- tasker portfolio thumbnail/image primitives

Preserve accessibility identifiers exactly.

### Phase 2: Extract Category Editor Views

Move:

- `AddCategorySheet`
- `EditableTaskerCategorySheet`
- `CategoryServiceDetailsSection`
- supporting draft/field types if currently local

If a `private` type is needed across files, change it to internal only where required. Do not widen visibility more than necessary.

### Phase 3: Extract Tasker Create And Manage Flows

Move:

- `TaskerCreateFlowView`
- `TaskerProfileManageView`
- tasker onboarding support views

Preserve local `@State` ownership. Do not lift state to `AppState` just to make extraction easier.

### Phase 4: Extract TaskerOnboardingView

Move `TaskerOnboardingView` after its child views have landed. Keep the existing sheet and billing presentation behavior.

### Phase 5: Cleanup Imports And Access Control

- Add `SwiftUI` imports where needed.
- Add `PhotosUI` or UIKit imports only to files that require them.
- Keep `private` where the type is file-local.
- Avoid new shared catch-all files.

## Testing Plan

iOS build:

- Build scheme `Patchwork`.

Focused manual or UI coverage:

- open Profile tab
- update account display/photo
- open favourites panel
- open blocked users panel
- unblock a user
- open support/help/legal/feedback
- submit feedback
- run tasker onboarding
- add category
- edit category
- remove category
- set portfolio cover image
- upload tasker photo
- switch tasker photo back to account photo
- open billing sheet from tasker onboarding

Backend:

- No backend tests are required for a pure file split.
- If any endpoint call changes during extraction, run the affected backend test suite too.

## Acceptance Criteria

- `ProfileView.swift` is reduced to top-level profile orchestration rather than all profile-related flows.
- No user-visible copy, accessibility identifier, route, or sheet presentation changes unintentionally.
- Tasker onboarding drafts, portfolio selections, cover photo choice, and photo source survive navigation as before.
- Favourites and blocked panels still refresh through existing `AppState` methods.
- Delete account remains under the existing support/sign-out area with typed confirmation behavior intact.
- Build passes.

## Risks And Guards

- Risk: moving local types changes visibility and accidentally exposes implementation details.
  - Guard: prefer one file per flow and keep helpers `private` inside that file.
- Risk: `@State` lifetime changes if wrappers are inserted incorrectly.
  - Guard: extract existing views without adding owner containers or moving state to shared objects.
- Risk: sheet routing changes.
  - Guard: keep existing sheet bindings and enum cases with the moved view whenever possible.
- Risk: direct Convex calls become harder to find after the split.
  - Guard: after extraction, migrate profile-owned files through the typed API facade in a separate reviewable patch.
