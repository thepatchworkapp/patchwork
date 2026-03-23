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
- `taskers:createTaskerProfile`
- `taskers:updateSubscriptionPlan`

## Configure

Set the two constants in `Patchwork/Core/AppConfig.swift`:

- `convexCloudURL` (e.g. `https://aware-meerkat-572.convex.cloud`)
- `convexSiteURL` (e.g. `https://aware-meerkat-572.convex.site`)

## Build

Open `Patchwork_iOS/Patchwork.xcodeproj` in Xcode and run on iPhone simulator.

## App Review Test Accounts

The iOS app has two Apple-review bypass accounts:

- `review@apple.com`: seeded reviewer account with seeker + tasker profiles.
- `seeker@apple.com`: OTP bypass only, no app profile; first sign-in lands in profile setup.

Enable or disable them with the admin "App Review Access" control after deploying the admin/frontend changes that expose it.

If you need to toggle them from the CLI instead, run the Convex helper against the same deployment configured in [Patchwork/Core/AppConfig.swift](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/Patchwork/Core/AppConfig.swift):

These examples use `--push`, so they also publish the current local Convex functions to that deployment.

```bash
cd /Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_MCP

# enable both review accounts
npx convex run reviewAccess:bootstrap '{"enabled":true}' --deployment-name vibrant-caribou-150 --push

# disable both review accounts
npx convex run reviewAccess:bootstrap '{"enabled":false}' --deployment-name vibrant-caribou-150 --push

# enable or disable a single review email
npx convex run reviewAccess:bootstrap '{"enabled":true,"email":"review@apple.com"}' --deployment-name vibrant-caribou-150 --push
npx convex run reviewAccess:bootstrap '{"enabled":false,"email":"seeker@apple.com"}' --deployment-name vibrant-caribou-150 --push
```
