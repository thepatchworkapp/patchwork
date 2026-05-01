# Plan: Photo Flow Consolidation

## Objective

Consolidate repeated camera, gallery, crop, upload, and cleanup orchestration across profile setup, account profile, tasker avatar, and portfolio flows. The goal is to reduce duplicated state machines while preserving each flow's current behavior.

## Current State

Primary files:

- `Patchwork_iOS/Patchwork/Features/Photos/PatchworkPhotoFlow.swift`
- `Patchwork_iOS/Patchwork/Core/ImageAssetUploadService.swift`
- `Patchwork_iOS/Patchwork/App/RootView.swift`
- `Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift`
- `patchwork-backend/convex/files.ts`
- `patchwork-backend/convex/imageAssetHelpers.ts`

Repeated patterns exist for:

- camera availability checks
- gallery picker presentation
- crop editor presentation
- single-image avatar upload
- multi-image portfolio crop queue
- uploaded asset cleanup after failed commit
- remote asset vs local draft handling

## Backend Interop Requirements

- Keep these backend endpoints stable:
  - `files:generateImageAssetUploadUrls`
  - `files:commitImageAsset`
  - `files:deleteImageAsset`
  - `users:updateProfilePhoto`
  - `taskers:setTaskerPhoto`
  - tasker category mutations that accept portfolio asset IDs
- Preserve the backend image asset model as the storage source of truth.
- Do not remove legacy raw storage ID fields until a separate migration proves all active data and clients are image-asset based.
- Keep iOS variant generation aligned with backend constraints. If dimensions or size limits change, document the backend and iOS change in the same PR.

## Proposed Shape

Add a shared photo coordinator under:

- `Patchwork_iOS/Patchwork/Features/Photos/PhotoFlowCoordinator.swift`

The coordinator should own reusable state and actions, not product-specific mutation commits.

Candidate responsibilities:

- expose presentation state for camera/gallery/crop
- convert camera/gallery `UIImage` output into `PhotoCropInput`
- manage single-image crop confirmation
- manage optional multi-image crop queue
- expose selected `PhotoDraft` values
- support cancellation without leaking UI state
- enforce per-flow max counts, including the portfolio 10-photo maximum

Keep product-specific commit logic in the owning feature:

- profile setup decides when to call `users:updateProfilePhoto`
- profile account decides when to call `users:updateProfilePhoto`
- tasker profile decides when to call `taskers:setTaskerPhoto`
- tasker category flows decide when to commit portfolio asset IDs to tasker category mutations

## Implementation Phases

### Phase 1: Document Current Behavior With Tests Or Manual Scripts

Before refactoring, record current expected behavior:

- profile setup camera uses full-screen presentation and presents crop only after camera dismissal
- gallery can select one image for avatars
- portfolio gallery can select up to remaining slots
- portfolio crop queue advances one image at a time
- cancelling portfolio crop clears the remaining queue
- failed tasker profile/category mutation deletes newly uploaded portfolio assets

### Phase 2: Extract Single-Image Photo Flow

- Create a coordinator for one-image camera/gallery/crop.
- Migrate account profile photo first because it is narrower than onboarding.
- Keep `ImageAssetUploadService` unchanged.
- Verify upload and remove behavior.

### Phase 3: Migrate Tasker Avatar Flows

- Use the coordinator for tasker onboarding avatar.
- Use the coordinator for tasker profile management avatar.
- Keep "Use Account Photo" behavior outside the coordinator.
- Preserve uploaded custom asset state until the backend mutation succeeds.

### Phase 4: Add Multi-Image Portfolio Queue Support

- Extend the coordinator or add a separate `PortfolioPhotoFlowCoordinator`.
- Migrate onboarding portfolio selection.
- Migrate add/edit category portfolio selection.
- Preserve cover-photo replacement behavior when the current cover is removed.

### Phase 5: Consider Backend Constraint Discovery

If useful after consolidation, add a backend read endpoint that exposes image upload constraints:

- allowed content types
- max upload bytes
- variant names
- recommended dimensions

This should be additive. The existing client-side constants should stay until the new endpoint is consumed and tested.

## Testing Plan

iOS focused checks:

- profile setup avatar:
  - camera
  - gallery
  - crop
  - remove selected photo
  - foreground/background restore while draft is selected
- account profile avatar:
  - upload
  - replace
  - remove
- tasker avatar:
  - upload custom
  - replace custom
  - switch to account photo
- portfolio:
  - select multiple images
  - crop queue advances
  - queue order is preserved
  - cancel midway
  - cover photo persists
  - removing cover chooses a valid replacement
  - failed category mutation cleans uploaded assets

iOS unit coverage:

- coordinator opens the correct sheet for camera and gallery actions
- coordinator respects max counts
- coordinator clears crop queue on cancel
- coordinator does not upload or delete assets by itself

Backend focused checks:

```bash
cd patchwork-backend
npm run test:run -- convex/__tests__/imageAssets.test.ts
npm run test:run -- convex/__tests__/taskers.test.ts
npm run test:run -- convex/__tests__/users.test.ts
```

Full checks after broad migration:

```bash
cd patchwork-backend
npm run codegen
npm run test:run
```

Build the iOS app after each migration phase.

## Acceptance Criteria

- Shared photo-flow code is used by account avatar, tasker avatar, and portfolio flows.
- Product-specific backend commit decisions remain in the owning feature.
- Existing image upload endpoints and Swift DTOs remain compatible.
- Multi-photo portfolio selection still respects the 10-photo limit.
- Uploaded assets created during a failed portfolio commit are deleted.
- Profile setup still preserves selected photo draft state across background/foreground.
- All focused image/tasker/user backend tests pass when backend-adjacent behavior is touched.

## Risks And Guards

- Risk: over-generalizing the coordinator makes the flow harder to reason about.
  - Guard: keep backend mutations out of the coordinator.
- Risk: profile setup camera presentation regresses.
  - Guard: migrate it after simpler avatar flows and keep full-screen camera behavior explicit.
- Risk: uploaded-but-uncommitted assets leak.
  - Guard: keep uploaded asset IDs tracked until a backend mutation succeeds.
