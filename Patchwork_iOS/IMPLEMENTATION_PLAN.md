# Patchwork iOS Implementation Plan

## Goal

Rebuild the former Patchwork web PoC as a native SwiftUI iPhone app while keeping it aligned with the live webhook-driven Convex billing backend.

## Architecture

1. **Client layer**
   - `ConvexHTTPClient` for Convex Functions API calls (`/api/query`, `/api/mutation`).
   - Better Auth email OTP calls via Convex site URL.
2. **State layer**
   - `SessionStore` for auth state and token.
   - `AppState` for app data and flow state.
3. **UI layer**
   - `NavigationStack` + `TabView`.
   - Feature groups: Auth, Home/Browse, Messages/Chat, Jobs, Profile.

## PoC Flow Mapping

- `Splash/Onboarding/SignIn/EmailEntry/EmailVerify` -> `AuthFlowView`
- `HomeSwipe + Browse + ProviderDetail` -> `HomeView`, `BrowseView`, `ProviderDetailView`
- `Messages + Chat` -> `MessagesView`, `ChatView`
- `Jobs` -> `JobsView`
- `Profile + TaskerOnboarding + Subscriptions` -> `ProfileView`, `TaskerOnboardingView`, `TaskerBillingSheet`

## Convex Functions Used

- `categories:listCategories`
- `search:searchTaskers`
- `taskers:getTaskerById`
- `users:getCurrentUser`
- `conversations:listConversations`
- `conversations:startConversation`
- `messages:listMessages`
- `messages:sendMessage`
- `jobs:listJobs`
- `taskers:createTaskerProfile`
- `taskers:setGhostMode`

## Billing Contract

- RevenueCat offering: `tasker_access_paywall`
- RevenueCat entitlement: `tasker_access`
- Product IDs:
  - `ltd.ddga.patchwork.tasker.subscription.yearly`
  - `ltd.ddga.patchwork.tasker.lifetime`
- Backend access types:
  - `subscription`
  - `lifetime`
- Backend status values:
  - `inactive`
  - `active`
  - `cancel_at_period_end`
  - `expired`

RevenueCat/App Store events update tasker billing through the Convex webhook route. Direct client billing mutations are no longer part of the production contract.

## Verification

- Build target: `Patchwork_iOS/Patchwork.xcodeproj` scheme `Patchwork` on iOS Simulator.
- Verify against the active Convex deployment configured in `Patchwork/Core/AppConfig.swift`.
