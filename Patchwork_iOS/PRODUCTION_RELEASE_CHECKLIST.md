# Patchwork iOS Production Release Checklist

## Billing Catalog

- [ ] Confirm ASC app `6759272540` still maps to bundle ID `ltd.ddga.patchwork`.
- [ ] Confirm subscription group `Tasker Access` (`21966744`) exists in ASC.
- [ ] Confirm the current tasker catalog exists and is sale-ready in ASC:
  - annual subscription `ltd.ddga.patchwork.tasker.subscription.yearly` (`6761341338`)
  - lifetime non-consumable `ltd.ddga.patchwork.tasker.lifetime` (`6760315382`)
- [ ] Confirm Canada-only availability remains correct for both products.
- [ ] Confirm annual pricing remains `47.99 CAD` and lifetime pricing remains `95.99 CAD`.
- [x] Upload product images in ASC.
- [ ] Upload App Store review screenshots for both products.
- [ ] Confirm the annual subscription remains out of `MISSING_METADATA` and is still review-ready in ASC.
- [ ] Submit the annual subscription and lifetime purchase with app version `3.2` once the version-level submission requirements are complete.

## RevenueCat

- [ ] Confirm RevenueCat project `projb937e82a` still has App Store app `app6be2ab0fb8` on bundle ID `ltd.ddga.patchwork`.
- [ ] Confirm the production public SDK key in iOS matches RevenueCat key `appl_KVrqPtiNVMghtWZGRGrnCnBQyfh`.
- [ ] Confirm entitlement `tasker_access` is attached only to:
  - `ltd.ddga.patchwork.tasker.subscription.yearly`
  - `ltd.ddga.patchwork.tasker.lifetime`
- [ ] Confirm current sellable offering is `tasker_access_paywall` (`ofrng422905835c`) with packages `$rc_annual` and `$rc_lifetime`.
- [ ] Confirm the weekly product `ltd.ddga.patchwork.tasker.weekly` is archived or otherwise unsellable.
- [ ] Confirm the deleted legacy monthly offering does not reappear in RevenueCat.
- [ ] Confirm legacy monthly RevenueCat products remain inactive.
- [ ] Confirm no release path in the iOS client references legacy bundle ID `com.agk.patchwork`.
- [ ] Confirm the App Store Connect API key remains valid in RevenueCat.
- [ ] Confirm the App Store In-App Purchase key remains valid in RevenueCat.
- [x] Apply the Apple server notification URLs from RevenueCat to App Store Connect for the recreated app.
- [ ] Confirm Apple commerce events start arriving in RevenueCat after the first real store events.

## Native Client

- [ ] Run `xcodegen generate` after any project setting or package change.
- [ ] Confirm `Patchwork/Core/AppConfig.swift` still points at the production Convex URLs and RevenueCat key.
- [ ] Confirm `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml` match release intent.
- [ ] Confirm the next uploaded TestFlight build number is higher than the latest ASC build.
- [ ] Build `Patchwork` for simulator and device with `xcodebuildmcp`.
- [ ] Archive and export a release build before submission.

## Automated Verification

- [ ] Run `PatchworkTests`.
- [ ] Run the native marketplace smoke suite on `iPhone 17` / latest iOS simulator.
- [ ] Run `testTaskerSubscriptionLifecycle` to confirm tasker onboarding still reaches the RevenueCat-backed subscription screen.

## Manual Commerce Validation

- [ ] On a sandbox or TestFlight build, purchase annual access and verify Convex tasker state becomes `tasker` + `subscription` + `active`.
- [ ] On a sandbox or TestFlight build, purchase lifetime access and verify Convex tasker state becomes `tasker` + `lifetime` + `active`.
- [ ] Verify `Restore purchases` correctly restores entitlements onto the authenticated user.
- [ ] Verify App Store subscription management opens from the native subscription screen for annual access.
- [ ] Verify lifetime access does not show a cancellation path in the native client.
- [ ] Cancel auto-renew in App Store while entitlement is still active, reopen the app, and verify Convex moves to `cancel_at_period_end`.
- [ ] Re-enable auto-renew before term end, reopen the app, and verify Convex returns to `active`.
- [ ] Verify Ghost Mode remains editable only while the backend still reports an active subscription.

## Release Submission

- [ ] Confirm `ITSAppUsesNonExemptEncryption = NO` remains correct for the submitted binary.
- [ ] Confirm build processing completes in ASC.
- [ ] Confirm export compliance is accepted.
- [ ] Assign the build to the intended TestFlight testers/groups.
- [ ] Validate release metadata, screenshots, and subscription messaging before App Review submission.

## Backend Rollout

- [ ] Deploy the local Convex changes that add `POST /revenuecat/webhook` and the `subscription | lifetime` contract.
- [ ] Set `REVENUECAT_WEBHOOK_AUTHORIZATION` in production Convex.
- [ ] Set `REVENUECAT_SECRET_API_KEY` in production Convex for server-side subscriber reconciliation and admin reset cleanup.
- [ ] Create the RevenueCat webhook integration against the live Convex site URL.
