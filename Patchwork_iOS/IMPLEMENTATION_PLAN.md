# Patchwork iOS Implementation Plan

## Goal

Rebuild the Patchwork_MCP PoC frontend as a native SwiftUI iPhone app while keeping the Convex backend unchanged.

## Architecture

1. **Client layer**
   - `ConvexHTTPClient` for Convex Functions API calls (`/api/query`, `/api/mutation`).
   - Better Auth email OTP calls via Convex site URL.
2. **State layer**
   - `SessionStore` for auth state and token.
   - `AppState` for app data and flow state.
3. **UI layer**
   - `NavigationStack` + `TabView`.
   - Feature groups: Auth, Home/Browse, Messages/Chat, Jobs, Profile, Request wizard.

## PoC Flow Mapping

- `Splash/Onboarding/SignIn/EmailEntry/EmailVerify` -> `AuthFlowView`
- `HomeSwipe + Browse + ProviderDetail` -> `HomeView`, `BrowseView`, `ProviderDetailView`
- `RequestStep1-4` -> `RequestWizardView`
- `Messages + Chat` -> `MessagesView`, `ChatView`
- `Jobs` -> `JobsView`
- `Profile + TaskerOnboarding + Subscriptions` -> `ProfileView`, `TaskerOnboardingView`, `SubscriptionsView`

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
- `jobRequests:createJobRequest`
- `taskers:createTaskerProfile`
- `taskers:updateSubscriptionPlan`

## Verification

- Build target: `Patchwork_iOS/Patchwork.xcodeproj` scheme `Patchwork` on iOS Simulator.
- No backend code modifications.
