# Patchwork iOS UI Overhaul

This file is the source of truth for the native iOS visual redesign.

Goal:
- bring every primary screen up to the quality bar of the splash/title experience
- make the app feel modern, premium, clean, and consistent
- replace ad hoc styling with a real shared design system

Non-goals:
- do not change working product behavior unless a UI change requires small supporting refactors
- do not add fallback UI paths to make styling easier
- do not preserve ugly or inconsistent legacy styling just because it already exists

## Visual Direction

Target feel:
- premium but bright, not dark and moody by default
- confident, crisp, local-service marketplace
- clean hierarchy, strong typography, restrained but intentional color
- fewer generic white rectangles, more shaped sections with clear emphasis

Visual reference:
- [`Patchwork_iOS/Patchwork/Features/Auth/AuthFlowView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Auth/AuthFlowView.swift)
  The splash/title screen is the current quality bar.

## Current Assessment

Observed issues in the current app:
- visual tokens are duplicated across files instead of centralized
- top bars, cards, pills, buttons, and form fields are inconsistent by feature
- several screens are structurally correct but visually default-looking
- post-auth flows do not feel like the same product as the splash screen
- empty, loading, and success states are mostly functional rather than polished

Resolved code smell:
- per-screen palette wrappers have been removed from the supported iOS surfaces, and shared tokens now live in `Patchwork_iOS/Patchwork/Core/UITheme.swift`

## Execution Rules

- Build the shared design system before restyling individual screens.
- Preserve the existing app flows and accessibility identifiers.
- Every redesigned screen must still pass the primary-path smoke tests.
- Prefer reusable primitives over screen-specific one-off styling.
- Keep the app coherent: one product, not separate feature teams with different visual languages.
- Do not adopt Liquid Glass blindly. Use modern SwiftUI styling intentionally and only where it improves the product.

## Phase Plan

### Phase 1. Shared Theme Layer

Objective:
- create a real shared visual system for the app

Tasks:
- [x] Add centralized color tokens
- [x] Add centralized typography tokens
- [x] Add spacing, radius, border, and shadow tokens
- [x] Add reusable surface styles for cards, sections, and form groups
- [x] Add reusable CTA styles for primary, secondary, destructive, and subtle actions
- [x] Add reusable top-bar and segmented-tab components
- [x] Add reusable empty/loading/error state components

Deliverables:
- [x] Shared theme file(s) exist under `Patchwork_iOS/Patchwork`
- [x] Shared SwiftUI primitives are split into focused files instead of one catch-all component file
- [x] Existing per-screen palette enums are no longer the source of truth

### Phase 2. Auth And First-Run Flow

Objective:
- make the first impression cohesive from splash through profile setup

Screens:
- [x] [`Patchwork_iOS/Patchwork/Features/Auth/AuthFlowView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Auth/AuthFlowView.swift)
  Scope:
  - keep splash quality high
  - upgrade onboarding, sign-in, email, verify to match splash tone
- [x] [`Patchwork_iOS/Patchwork/App/RootView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/App/RootView.swift)
  Scope:
  - profile setup
  - location permission gate
  - notifications gate
  - loading state

Acceptance:
- [x] The full auth-to-app entry flow feels like one premium sequence
- [x] Forms and CTAs look intentional, not default

### Phase 3. Home Discovery Flow

Objective:
- make discovery the strongest post-auth surface in the app

Screens:
- [x] [`Patchwork_iOS/Patchwork/Features/Home/HomeView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Home/HomeView.swift)
  Scope:
  - header
  - category/radius controls
  - spotlight mode
  - list mode
  - empty state
  - radius sheet
- [x] [`Patchwork_iOS/Patchwork/Features/Home/ProviderDetailView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Home/ProviderDetailView.swift)
  Scope:
  - hero/header
  - social proof
  - service cards
  - pricing/details
  - primary CTA section
- [x] [`Patchwork_iOS/Patchwork/Features/Home/CategoriesView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Home/CategoriesView.swift)

Acceptance:
- [x] Discovery looks screenshot-worthy
- [x] Provider detail feels premium enough to justify conversion

### Phase 4. Profile And Subscription Flow

Objective:
- make profile and billing feel trustworthy, polished, and premium

Screens:
- [x] [`Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift)
  Scope:
  - account summary
  - tasker status summary
  - support area
  - version/footer treatment
- [x] `TaskerOnboardingView` in [`Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift)
- [x] `TaskerCreateFlowView` in [`Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift)
- [x] `TaskerProfileManageView` in [`Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift)
- [x] `SubscriptionsView` in [`Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift)
- [x] `PremiumUpgradeView` in [`Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift)
- [x] `HelpView` in [`Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift)
- [x] Add/edit category sheets in [`Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Profile/ProfileView.swift)

Acceptance:
- [x] The subscription screen looks worthy of asking for money
- [x] Tasker onboarding feels aspirational, not administrative

### Phase 5. Messages And Chat Flow

Objective:
- make conversation flows feel focused, calm, and high-trust

Screens:
- [x] [`Patchwork_iOS/Patchwork/Features/Messages/MessagesView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Messages/MessagesView.swift)
  Scope:
  - inbox
  - role tabs
  - locked tasker state
  - search
- [x] `ChatView` in [`Patchwork_iOS/Patchwork/Features/Messages/MessagesView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Messages/MessagesView.swift)
  Scope:
  - header
  - message rows
  - proposal cards
  - action banners
  - composer
- [x] Proposal, review, and completion sheets in [`Patchwork_iOS/Patchwork/Features/Messages/MessagesView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Messages/MessagesView.swift)

Acceptance:
- [x] Chat feels premium and native, not like a utility panel
- [x] Important actions are clear without becoming visually noisy

### Phase 6. Jobs And Reviews

Objective:
- make jobs feel like a polished operations surface, not a placeholder list

Screens:
- [x] [`Patchwork_iOS/Patchwork/Features/Jobs/JobsView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Jobs/JobsView.swift)
- [x] [`Patchwork_iOS/Patchwork/Features/Jobs/JobDetailView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Jobs/JobDetailView.swift)
- [x] [`Patchwork_iOS/Patchwork/Features/Jobs/LeaveReviewView.swift`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Features/Jobs/LeaveReviewView.swift)

Acceptance:
- [x] Jobs has clear hierarchy and premium card treatment
- [x] Review flow feels lightweight and high-trust

### Phase 7. Final Polish Pass

Objective:
- eliminate rough edges after the major redesigns land

Tasks:
- [x] Standardize empty states across all tabs
- [x] Standardize loading states and spinners on supported primary flows
- [x] Standardize alerts, inline errors, and success messages
- [x] Standardize sheet and modal presentation styling
- [x] Validate small-screen build viability on `iPhone 16e`
- [ ] Validate large Dynamic Type behavior on primary screens
- [ ] Validate the app visually in real end-to-end flows

## Implementation Notes

- `swiftui-pro` cleanup is part of the shared-layer work:
  - Dynamic Type-friendly theme fonts
  - split shared components into focused files
  - no `Text + Text` concatenation in auth flow
  - no inline manual email `Binding(get:set:)` in auth flow
  - text-backed labels for icon-only controls

## Screen Checklist

Use this checklist before marking any screen complete:
- [ ] Clear first-glance hierarchy
- [ ] One obvious focal area or hero element
- [ ] Consistent spacing and corner radius
- [ ] Typography feels deliberate, not default
- [ ] Primary CTA is visually obvious
- [ ] Empty/loading/error states look intentional
- [ ] Accessibility identifiers preserved
- [ ] No product regressions in the primary path

## Progress Log

### 2026-03-08

Completed:
- [x] Audit current screen inventory and route map
- [x] Identify duplicated palette/theme problem
- [x] Create `UI.md` as the UI overhaul tracker
- [x] Add shared theme tokens and reusable UI primitives in `Patchwork_iOS/Patchwork/Core`
- [x] Apply `swiftui-pro` cleanup to the shared layer and auth/discovery surfaces
- [x] Restyle auth flow and first-run setup surfaces onto the shared theme
- [x] Verify auth entry and profile setup primary-path UI tests after the redesign
- [x] Restyle `HomeView` onto the shared theme and verify discovery-to-chat primary path
- [x] Restyle `ProviderDetailView` with themed hero/info cards and re-verify discovery-to-chat primary path
- [x] Restyle `MessagesView` and `ChatView` with premium inbox/chat surfaces and verify proposal/review paths
- [x] Restyle `CategoriesView` to match the discovery visual system and verify onboarding category selection
- [x] Restyle the main profile tab shell and subscriptions surface with stronger hierarchy and border treatment
- [x] Restyle tasker onboarding and tasker profile management while preserving the subscription lifecycle path
- [x] Restyle profile support, premium upsell, and category management sheets with consistent bordered surfaces
- [x] Re-verify the tasker subscription lifecycle after the profile redesign
- [x] Restyle jobs, job detail, and leave-review surfaces with the shared bordered visual system
- [x] Re-verify completion and review UI paths after the Jobs redesign
- [x] Remove the unsupported seeker request flow so the native client matches the actual tasker-discovery product
- [x] Remove leftover local palette wrappers and move star/empty/loading/error styling into the shared theme layer
- [x] Standardize empty/loading states on Home, Messages, Jobs, Job Detail, and boot loading with shared state components
- [x] Standardize inline error/success treatment on auth and subscription flows with shared status banners
- [x] Standardize sheet chrome across Home, Messages, and Profile modal presentations
- [x] Re-verify supported auth, discovery, tasker onboarding, and proposal flows after removing the unsupported request feature

In progress:
- [ ] Phase 7. Final Polish Pass
  Remaining work is manual QA-style validation: large Dynamic Type and visual end-to-end review.
  Targeted `xcodebuildmcp simulator test` reruns for the final polish pass stalled before `xctest` launch on `iPhone 16e`, so verification is currently build-backed plus previously passing smoke coverage rather than a fresh post-polish UI rerun.

## Verification Standard

After each major phase:
- [ ] Build with `xcodebuildmcp`
- [ ] Run affected focused tests
- [ ] Re-run the primary smoke path before closing the phase
- [ ] Capture before/after screenshots for visual comparison

Most recent verification:
- `xcodegen generate`
- `xcodebuildmcp simulator build` for `Patchwork` on `iPhone 16e`
- Previously passing focused smoke tests before the final polish pass:
  - `xcodebuildmcp simulator test --extra-args=-only-testing:PatchworkUITests/PatchworkUITests/testEmailAuthCompletesProfileSetup`
  - `xcodebuildmcp simulator test --extra-args=-only-testing:PatchworkUITests/PatchworkUITests/testSeekerDiscoveryStartsConversation`
  - `xcodebuildmcp simulator test --extra-args=-only-testing:PatchworkUITests/PatchworkUITests/testTaskerSendsProposal`
  - `xcodebuildmcp simulator test --extra-args=-only-testing:PatchworkUITests/PatchworkUITests/testTaskerSubscriptionLifecycle`
- Post-polish targeted UI rerun attempt stalled in `xcodebuildmcp` before `xctest` launch and was stopped rather than counted as a pass
