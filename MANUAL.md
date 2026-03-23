# Patchwork Manual Actions

This file is the source of truth for human-only actions that cannot be completed reliably from the local repo with the available CLI/MCP access.

Ignore [`Patchwork_MCP/MANUAL_STEPS.md`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_MCP/MANUAL_STEPS.md) for the native iOS release path. That older file reflects legacy web/Stripe setup, not the current App Store + RevenueCat billing path.

## RevenueCat

### 1. Apply Apple server notifications to the recreated RevenueCat app

Status:
- RevenueCat was recreated successfully on March 9, 2026.
- The native iOS client now uses the new RevenueCat public SDK key.
- Both Apple credential slots validate successfully for `ltd.ddga.patchwork`.
- The App Store Server Notification URLs were applied in App Store Connect on March 9, 2026.

What was applied:
- Production Server URL:
  - `https://api.revenuecat.com/v1/incoming-webhooks/apple-server-to-server-notification/XezJPyleQeobqaUGKqOeQBxCNJXDufog`
- Sandbox Server URL:
  - `https://api.revenuecat.com/v1/incoming-webhooks/apple-server-to-server-notification/XezJPyleQeobqaUGKqOeQBxCNJXDufog`

Official docs:
- [RevenueCat Apple Server Notifications](https://www.revenuecat.com/docs/platform-resources/server-notifications/apple-server-notifications)
- [RevenueCat Configuring the SDK](https://www.revenuecat.com/docs/configuring-sdk)

Remaining follow-up:
1. Submit the first app version with the weekly subscription and lifetime IAP attached.
2. After Apple starts sending commerce events, confirm RevenueCat stops showing `No notifications received`.

Values to use:
- RevenueCat project: `projb937e82a`
- RevenueCat app: `app6be2ab0fb8`
- Bundle ID: `ltd.ddga.patchwork`

Notes:
- The client-side public SDK key is now wired in iOS:
  - `appl_KVrqPtiNVMghtWZGRGrnCnBQyfh`
- The App Store Connect API key in RevenueCat is healthy:
  - key id `P97M62VL75`
  - issuer id `d7954ae0-edb8-443d-8d6f-582ce10827cb`
- The App Store In-App Purchase key in RevenueCat is healthy:
  - key id `KHDNVP73MC`
  - local file uploaded from `/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/SubscriptionKey_KHDNVP73MC.p8`

### 2. Verify RevenueCat integrations/webhooks only if backend support is added

Status:
- Not required for the current thin-client iOS billing flow.
- Apple server notifications to RevenueCat are configured in App Store Connect.
- No separate custom forwarding webhook is configured from this session.

Why this is manual:
- The current RevenueCat API key in this session does not have integration read access.
- The backend currently has no dedicated RevenueCat webhook reconciliation endpoint in scope for this iOS-only task.

Official docs:
- [RevenueCat Apple App Store Server Notifications](https://www.revenuecat.com/docs/platform-resources/server-notifications/apple-server-notifications)
- [RevenueCat Platform Server Notifications Overview](https://www.revenuecat.com/docs/platform-resources/server-notifications)

Only do this if backend support is added later:
1. Create the backend webhook endpoint.
2. Add the forwarding webhook in RevenueCat.
3. Verify delivery and reconciliation behavior.

## App Store Connect

### 3. Submit the first weekly subscription and lifetime purchase on the app version

Status:
- Completed from this session:
  - subscription group created
  - subscription group localization created
  - weekly subscription + lifetime purchase created
  - localizations added
  - review screenshots uploaded
  - product images uploaded
  - Canada-only availability set
  - weekly price set to `1.99 CAD`
  - lifetime price set to `79.99 CAD`
  - legacy monthly subscriptions `6760245588` and `6760245570` deleted from ASC
- Remaining blocker:
  - the weekly subscription is now `READY_TO_SUBMIT`
  - the lifetime purchase is `READY_TO_SUBMIT`
  - Apple will not accept either one until they are submitted on the first app version review
  - the app version still has unrelated App Store submission gaps outside commerce setup (build attachment, review contact, screenshots, app metadata, age rating, availability)

Subscriptions:
- Weekly: `6760315381` / `ltd.ddga.patchwork.tasker.weekly`
- Lifetime: `6760315382` / `ltd.ddga.patchwork.tasker.lifetime`

What to do in ASC:
1. Open App Store Connect.
2. Open app `Patchwork: Freelance` (`6759272540`).
3. Open app version `1.0` (`eb759dbb-89a1-41d4-b42a-5864ce14cd44`) in `Prepare for Submission`.
4. Finish the app-version submission requirements that are still missing:
   - attach a valid build
   - fill App Store review contact details
   - fill app description / keywords / support URL
   - upload required app screenshots
   - set app availability
   - complete the age rating declaration
5. Confirm weekly subscription `ltd.ddga.patchwork.tasker.weekly` (`6760315381`) still shows `READY_TO_SUBMIT`.
6. Confirm lifetime purchase `ltd.ddga.patchwork.tasker.lifetime` (`6760315382`) still shows `READY_TO_SUBMIT`.
7. Submit the app version so Apple reviews the first subscription and first IAP with that version.

Reason this is manual:
- The ASC CLI successfully cleared the commerce-specific blockers, but Apple requires the first subscription and first IAP to be attached to an app-version review submission.
- This environment does not currently have the missing App Store metadata assets or an authenticated Apple web session to finish that end-to-end submission flow.

### 4. Confirm the subscriptions are actually in review-ready state

Status:
- Review screenshots and product images were uploaded successfully from this session.
- Weekly is `READY_TO_SUBMIT`.
- Lifetime is `READY_TO_SUBMIT`.
- The obsolete monthly subscriptions were deleted from ASC.

Uploaded assets from this session:
- Review screenshot for Weekly:
  - screenshot id `4fcaaf30-5a36-4d79-9003-b2e887615010`
- Review screenshot for Lifetime:
  - screenshot id `efb340cd-fee2-4fca-8e52-3181b80a7e32`
- Product image for Weekly:
  - image id `e75ec650-78ad-4fdf-a3da-8fd8da4ec4bf`
- Product image for Lifetime:
  - image id `3840c223-1856-46e6-a95a-62d153baa063`

What to do:
1. Re-open weekly subscription `6760315381` in ASC.
2. Confirm all required sections are complete:
   - localization
   - review screenshot
   - subscription image
   - pricing
   - availability
3. Confirm Apple still shows `READY_TO_SUBMIT`.
4. Re-open lifetime purchase `6760315382`.
5. Confirm the lifetime purchase still shows `READY_TO_SUBMIT`.
6. After the app version is submitted, confirm both commerce items move into Apple's expected review state.

## Backend Contract

### 5. Decide whether to accept or fix the expiry reconciliation gap

Status:
- Not fixable from iOS alone under the current public Convex contract.

Current limitation:
- iOS now reconciles:
  - purchase activation -> `taskers:updateSubscriptionPlan`
  - cancellation / no-renew -> `taskers:cancelSubscription`
- iOS cannot truthfully force backend state to `expired` if RevenueCat no longer shows an active entitlement and the backend never previously scheduled term-end expiry.

What to do:
1. Either accept this for the current release, or
2. add a backend-supported reconciliation path for expired subscriptions.

This is tracked in:
- [`PROGRESS.md`](/Users/daldwinc/Documents/nosync/development/patchwork/PROGRESS.md)
- [`Patchwork_iOS/PRODUCTION_RELEASE_CHECKLIST.md`](/Users/daldwinc/Documents/nosync/development/patchwork/Patchwork_iOS/PRODUCTION_RELEASE_CHECKLIST.md)
