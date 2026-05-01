# Simplification And Optimization Plan Overview

## Purpose

This folder turns the backend and iOS review findings into implementation plans. Each plan is written to preserve existing Patchwork behavior while reducing duplication, hidden contract drift, or avoidable backend/client choreography.

## Plans

1. [`01-ios-api-facade.md`](01-ios-api-facade.md) - add a typed iOS API facade over raw Convex endpoint strings.
2. [`02-backend-jobs-list-ordering.md`](02-backend-jobs-list-ordering.md) - fix `jobs:listJobs` ordering and limit semantics.
3. [`03-ios-profileview-split.md`](03-ios-profileview-split.md) - split `ProfileView.swift` by owned flow.
4. [`04-photo-flow-consolidation.md`](04-photo-flow-consolidation.md) - consolidate repeated camera, gallery, crop, and upload orchestration.
5. [`05-appstate-refresh-and-bundled-reads.md`](05-appstate-refresh-and-bundled-reads.md) - narrow iOS refreshes and add backend bundled reads where useful.
6. [`06-backend-dto-enrichment.md`](06-backend-dto-enrichment.md) - centralize backend DTO enrichment for users, taskers, conversations, and image fields.

## Recommended Order

1. Fix `jobs:listJobs` first because it is a correctness issue, not just cleanup.
2. Add the typed iOS API facade before broad iOS refactors so later migrations have a safer contract surface.
3. Split `ProfileView.swift` without changing behavior. This creates clean file ownership for later work.
4. Consolidate photo orchestration after the split, when repeated flows are isolated.
5. Narrow `AppState.refreshAuthedData`, then add backend bundled reads only where the screen contract is clear.
6. Extract backend DTO enrichment helpers after the typed API and bundled-read shape are known, so helpers match the final contract.

## Cross-Layer Rules

- Backend response shape changes and Swift model changes must land together.
- Add or update backend `returns:` validators before relying on a new iOS decode contract.
- Prefer additive backend endpoints for bundled reads. Keep existing narrow endpoints as public contracts until they are deliberately retired; do not add alternate iOS code paths that hide a broken primary implementation.
- Keep `ConvexHTTPClient` responsible for auth token refresh, Better Auth cookie/session handling, and retry behavior.
- Do not weaken existing account deletion, moderation, report-length, billing, image cleanup, or foreground route-preservation behavior.
- Do not hand-edit `patchwork-backend/convex/_generated/*`.
- If `Patchwork_iOS/project.yml` changes, regenerate the Xcode project with `xcodegen generate`.

## Shared Verification Baseline

Backend checks:

```bash
cd patchwork-backend
npm run codegen
npm run test:run
```

iOS checks:

- Build scheme `Patchwork` with the Build iOS Apps tooling or the project-aware Xcode workflow.
- Run focused unit/UI coverage for the touched flows.
- Run UI tests serially when UI-test coverage is required.

## Release Safety

These plans do not call for immediate TestFlight or production deploys. If implementation changes app behavior, release work should separately verify the current App Store Connect app target, build number, valid processing state, and TestFlight tester assignment before claiming the release is complete.
