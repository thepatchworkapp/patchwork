# Progress

## Current Goal

Ship the native iOS marketplace loop as the production path on `iPhone 17` / latest `iOS 26.x`, using Convex as the source of truth and removing fallback-based UI test behavior instead of preserving it.

## Execution Rules

- Do not add or preserve fallbacks in app code or UI tests.
- If a test currently uses a fallback selector, fallback tab index, coordinate tap, or alternate control path, fix the primary UI/accessibility path and update the test to use that single truthful path.
- Use `xcodebuildmcp` as the default simulator/build/test workflow.
- Treat the web PoC as frozen behavior reference only; do not spend more time on web-only improvements unless they affect product truth.

## Verified Baseline

- Auth, profile creation, location sync, tasker onboarding, RevenueCat-backed subscription catalog loading, restore purchases, Ghost Mode, App Store subscription management routing, seeker discovery, provider detail, conversation start, proposal send, proposal accept, and proposal decline are implemented in the native path.
- Email account creation now uses the same truthful OTP path as sign-in; unsupported Google auth is no longer presented as a live feature in iOS.
- Current discovery/detail files:
  - [`Patchwork_iOS/Patchwork/Features/Home/HomeView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Home/HomeView.swift)
  - [`Patchwork_iOS/Patchwork/Features/Home/ProviderDetailView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Home/ProviderDetailView.swift)
- Active proposal tests in repo:
  - `testTaskerSendsProposal`
  - `testSeekerAcceptsProposalCreatesJob`
  - `testSeekerDeclinesProposalDoesNotCreateJob`

## Remaining Work

### 1. Production billing setup and release readiness

#### Objective

- Replace the current mock/direct subscription mutations with a real App Store + RevenueCat billing path for `ltd.ddga.patchwork`.

#### ASC + RevenueCat Findings

- `asc apps list` confirms the production app exists in App Store Connect as `Patchwork: Freelance` (`6759272540`) with bundle ID `ltd.ddga.patchwork`.
- App Store Connect catalog is now created:
  - subscription group `Tasker Access` (`21966744`)
  - weekly subscription `ltd.ddga.patchwork.tasker.weekly` (`6760315381`)
  - lifetime non-consumable `ltd.ddga.patchwork.tasker.lifetime` (`6760315382`)
  - availability set for `CAN`
  - pricing set to `1.99 CAD` weekly and `79.99 CAD` lifetime
- RevenueCat project `Patchwork` (`projb937e82a`) is now aligned to the production bundle:
  - App Store app `app6be2ab0fb8` is `Patchwork: Freelance`
  - bundle ID is `ltd.ddga.patchwork`
  - production public SDK key is `appl_KVrqPtiNVMghtWZGRGrnCnBQyfh`
  - entitlement `tasker_access` is attached only to `ltd.ddga.patchwork.tasker.weekly` and `ltd.ddga.patchwork.tasker.lifetime`
  - current offering is `tasker_access_paywall` (`ofrng422905835c`) with `$rc_weekly` and `$rc_lifetime`
- Remaining external release-prep gap:
  - RevenueCat App Store Connect API credentials and App Store In-App Purchase key both validate successfully on the recreated app
  - Apple server notification URLs are now configured in App Store Connect for both production and sandbox
  - ASC product images and review screenshots are uploaded for the new weekly and lifetime products
  - the weekly subscription and lifetime purchase are both now `READY_TO_SUBMIT`
  - the obsolete monthly ASC subscriptions were deleted from the subscription group
  - Apple still requires the first subscription and first IAP to be submitted with app version `1.0` (`eb759dbb-89a1-41d4-b42a-5864ce14cd44`)
  - the current manual follow-up is tracked in [`MANUAL.md`](/Users/daldwinc/Documents/nosync/development/patchwork/MANUAL.md)
- Residual backend contract gap:
  - the current public Convex contract still has no truthful client-callable mutation for “store says expired, backend still active”
  - iOS now reconciles `active` and `cancel_at_period_end` truthfully, but exact expiry still requires backend support or prior in-app cancellation sync

#### Execution Tasks

- [x] Create the App Store subscription catalog for `ltd.ddga.patchwork`
  Scope:
  - create a subscription group for tasker access
  - create weekly and lifetime products under the production bundle ID
  - set initial pricing and availability
- [x] Align RevenueCat to the production app identity
  Scope:
  - create or switch to a RevenueCat App Store app using bundle ID `ltd.ddga.patchwork`
  - keep the entitlement key `tasker_access`
  - attach the production weekly/lifetime products to the current offering path
  - avoid carrying legacy bundle ID wiring into the shipping client
- [x] Add iOS RevenueCat scaffolding
  Scope:
  - add the RevenueCat iOS SDK to `Patchwork_iOS`
  - configure RevenueCat with the production public API key
  - use the authenticated user ID as the RevenueCat app user ID
  - fetch offerings/customer info from the real SDK instead of hardcoded buttons
- [x] Replace direct subscription activation with real purchase flow
  Scope:
  - purchasing weekly/lifetime access should start from RevenueCat packages
  - successful purchases should reconcile into the existing Convex tasker subscription state
  - subscription management should route through App Store / RevenueCat management, not fake local toggles
- [x] Review the remaining reconciliation gap
  Scope:
  - verify active, cancelled-at-period-end, and expired states against the current public Convex contract
  - document any residual backend contract gap if expiry cannot be reconciled truthfully from the client alone

#### Acceptance Criteria

- [x] App Store Connect contains the production subscription products for `ltd.ddga.patchwork`.
- [x] RevenueCat is configured for the production bundle ID, not `com.agk.patchwork`.
- [x] The iOS subscription screen purchases real RevenueCat packages.
- [x] The iOS app no longer treats direct Convex plan mutation as the purchase step.
- [x] The remaining cancellation/expiry reconciliation behavior is either implemented truthfully or documented as a blocking contract gap.

### 2. Remove UI test fallbacks and make the primary path explicit

- [x] Replace fallback tab selection in [`Patchwork_iOS/PatchworkUITests/PatchworkUITests.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/PatchworkUITests/PatchworkUITests.swift)
  Scope:
  - remove `tabButton(named:fallbackIndex:)`
  - require stable tab accessibility labels/identifiers for `Seek`, `Jobs`, `Messages`, and `Profile`
  - update tests to fail if the primary tab control is missing
- [x] Remove alternate selector fallbacks in discovery/chat tests
  Scope:
  - stop falling back from `ProviderDetail.startChatButton` to a generic `"Chat"` button
  - stop falling back from identified proposal buttons/banners to generic text labels
  - stop falling back from the primary provider-detail CTA to plain `"View full profile"` text lookups
- [x] Remove coordinate-based taps and ambiguous sheet/control interaction from tests
  Scope:
  - replace coordinate taps used for Ghost Mode and post-onboarding navigation with a real tappable control or accessibility identifier
  - replace `.firstMatch` / index-based confirmation taps where a unique accessibility path should exist
- [x] Remove outdated test-plan language that recommends workaround execution paths
  Scope:
  - keep `xcodebuildmcp` as the default execution path
  - only document direct `xcodebuild` as an exceptional debugging escape hatch if still absolutely required after cleanup

Verification:
- `xcodebuildmcp simulator build` passed for scheme `Patchwork` on `iPhone 17`
- `xcodebuildmcp simulator test` passed for `PatchworkUITests/PatchworkUITests/testAccessibilitySelectorsPresent`
- `xcodebuildmcp simulator test` passed for `PatchworkUITests/PatchworkUITests/testSeekerDiscoveryStartsConversation`
- `xcodebuildmcp simulator test` passed for `PatchworkUITests/PatchworkUITests/testSeekerAcceptsProposalCreatesJob`

### 3. Finish Phase 8: jobs completion and review flow

#### Objective

- Complete the post-acceptance marketplace lifecycle on iOS:
  - accepted job visible in Jobs
  - complete job
  - review eligibility check
  - submit review
  - refresh back into truthful Jobs/Profile state

#### Convex Source Of Truth

- `jobs:listJobs`
- `jobs:getJob`
- `jobs:completeJob`
- `reviews:createReview`
- `reviews:canReview`

#### iOS File Targets

- [ ] [`Patchwork_iOS/Patchwork/Features/Jobs/JobsView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Jobs/JobsView.swift)
- [x] [`Patchwork_iOS/Patchwork/Features/Jobs/JobsView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Jobs/JobsView.swift)
  Focus:
  - active vs completed grouping
  - truthful row summaries
  - no stale duplication across groups
- [x] [`Patchwork_iOS/Patchwork/Features/Jobs/JobDetailView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Jobs/JobDetailView.swift)
  Focus:
  - completion action
  - review gating via `reviews:canReview`
  - correct refresh after completion
- [x] [`Patchwork_iOS/Patchwork/Features/Jobs/LeaveReviewView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Jobs/LeaveReviewView.swift)
  Focus:
  - rating/text validation
  - review submission
  - post-submit navigation and refresh
- [x] [`Patchwork_iOS/Patchwork/Core/AppState.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Core/AppState.swift)
  Focus:
  - job refresh after completion
  - clean refresh after review submission
  - no stale active/completed state

Completed:
- added explicit Jobs status-tab accessibility identifiers for primary-path UI testing
- refreshed `JobDetailView` when returning from child screens so review/completion state does not stay stale after dismiss
- refreshed `LeaveReviewView` submission flow so review creation refreshes app state before dismiss
- removed container-level screen identifiers that were polluting child CTA accessibility
- split Phase 8 simulator coverage into focused completion and review tests that fit the CLI runtime envelope

#### Required Checks

- [x] Accepted jobs appear under `In Progress`.
- [x] Completing a job removes it from `In Progress` and places it under `Completed`.
- [x] No completed job remains duplicated in both lists.
- [x] Only review-eligible completed jobs show the leave-review CTA.
- [x] Submitted reviews persist and affect later refreshed profile/job state.

#### Acceptance Criteria

- [x] A user can complete a job from native job detail.
- [x] A user can submit a review from the eligible completed job.
- [x] Review success returns to the correct screen without stale data.
- [x] The app shows no dead-end CTA or misleading review/completion state.

### 4. Add Phase 8 simulator coverage with no fallbacks

- [x] Replace the removed monolithic completion/review test with focused primary-path coverage
  Scope:
  - `PatchworkUITests.testCompleteJobMovesAcceptedJobToCompleted`
  - `PatchworkUITests.testLeaveReviewOnCompletedJob`
  - both use seeded backend state plus primary accessibility controls only
- [x] Keep assertions tied to the primary UI path plus backend truth
  Scope:
  - use explicit accessibility identifiers for job rows, completion CTA, review CTA, submit button, and success state
  - verify backend outcome through `/test-proxy` where it reduces UI ambiguity
  - do not add alternate selectors to “make the test pass”

Verification:
- `xcodebuildmcp simulator test` passed for `PatchworkUITests/PatchworkUITests/testCompleteJobMovesAcceptedJobToCompleted`
- `xcodebuildmcp simulator test` passed for `PatchworkUITests/PatchworkUITests/testLeaveReviewOnCompletedJob`

### 5. Run the final native smoke suite on the production path

#### Required Coverage

- [x] `testEmailAuthCompletesProfileSetup`
- [x] `testTaskerSubscriptionLifecycle`
- [x] `testSeekerDiscoveryStartsConversation`
- [x] `testTaskerSendsProposal`
- [x] `testSeekerAcceptsProposalCreatesJob`
- [x] `testSeekerDeclinesProposalDoesNotCreateJob`
- [x] `testCompleteJobMovesAcceptedJobToCompleted`
- [x] `testLeaveReviewOnCompletedJob`

#### Execution Standard

- [x] Run on `iPhone 17`
- [x] Run on latest available `iOS 26.x`
- [x] Keep tests independent and self-cleaning through `/test-proxy`
- [x] Prefer backend-verified assertions for marketplace state transitions
- [x] Do not rely on fallback selectors, fallback tabs, coordinate taps, or generic text matches when a primary accessibility path should exist

Verification:
- `xcodebuildmcp simulator test` passed for the required smoke batch on `iPhone 17` / `iOS 26.3.1`:
  - `testEmailAuthCompletesProfileSetup`
  - `testTaskerSubscriptionLifecycle`
  - `testSeekerDiscoveryStartsConversation`
  - `testTaskerSendsProposal`
  - `testSeekerAcceptsProposalCreatesJob`
  - `testSeekerDeclinesProposalDoesNotCreateJob`
  - `testCompleteJobMovesAcceptedJobToCompleted`
  - `testLeaveReviewOnCompletedJob`

### 6. Investigate the non-smoke full UITest target run

- [ ] Re-run the entire `PatchworkUITests` target, including non-smoke utility/parity tests, under `xcodebuildmcp`
  Scope:
  - determine why a full target run behaved differently from the explicit smoke batch
  - confirm whether the remaining issue is isolated to non-product tests such as parity capture helpers
- [ ] Keep the smoke gate separate from non-product coverage
  Scope:
  - do not block the production-path smoke status on screenshot/parity-only tests
  - document any remaining full-target instability with the exact test names involved

## Immediate Next Step

- [ ] Complete the remaining manual billing items in [`MANUAL.md`](/Users/daldwinc/Documents/nosync/development/patchwork/MANUAL.md), then run the production release checklist in [`Patchwork_iOS/PRODUCTION_RELEASE_CHECKLIST.md`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/PRODUCTION_RELEASE_CHECKLIST.md).
