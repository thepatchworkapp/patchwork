# Patchwork iOS (SwiftUI)

Native SwiftUI client for the Patchwork PoC, wired to the existing Convex backend.

## What Is Implemented

- Callback-free native navigation with `NavigationStack` + `TabView`.
- Auth flow (email OTP) against Better Auth routes on `VITE_CONVEX_SITE_URL` equivalent.
- Convex Functions API integration over HTTP (`/api/query`, `/api/mutation`).
- Core PoC flows mapped from `Patchwork_MCP/src/App.tsx`:
  - splash/onboarding/sign-in
  - home + browse taskers
  - provider detail
  - request creation
  - conversations + chat
  - jobs list
  - profile + tasker onboarding + subscriptions

## Backend Compatibility

No backend changes required. This app calls existing functions such as:

- `categories:listCategories`
- `search:searchTaskers`
- `taskers:getTaskerById`
- `users:getCurrentUser`
- `conversations:listConversations`
- `messages:listMessages`
- `messages:sendMessage`
- `jobRequests:createJobRequest`
- `taskers:createTaskerProfile`
- `taskers:updateSubscriptionPlan`

## Configure

Set the two constants in `Patchwork/Core/AppConfig.swift`:

- `convexCloudURL` (e.g. `https://aware-meerkat-572.convex.cloud`)
- `convexSiteURL` (e.g. `https://aware-meerkat-572.convex.site`)

## Build

Open `Patchwork_iOS/Patchwork.xcodeproj` in Xcode and run on iPhone simulator.
