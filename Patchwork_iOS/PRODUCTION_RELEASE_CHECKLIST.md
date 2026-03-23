# Patchwork iOS Production Release Checklist

## Billing Catalog

- [ ] Confirm ASC app `6759272540` still maps to bundle ID `ltd.ddga.patchwork`.
- [ ] Confirm subscription group `Tasker Access` (`21966744`) exists in ASC.
- [ ] Confirm the current tasker catalog exists and is sale-ready in ASC:
  - weekly subscription `ltd.ddga.patchwork.tasker.weekly` (`6760315381`)
  - lifetime non-consumable `ltd.ddga.patchwork.tasker.lifetime` (`6760315382`)
- [ ] Confirm Canada-only availability remains correct for both products.
- [ ] Confirm weekly pricing remains `1.99 CAD` and lifetime pricing remains `79.99 CAD`.
- [x] Upload product images in ASC.
- [x] Upload App Store review screenshots for both products.
- [x] Clear the weekly subscription `MISSING_METADATA` state in ASC.
- [ ] Submit the weekly subscription and lifetime purchase with app version `1.0` once the version-level submission requirements are complete.

## RevenueCat

- [ ] Confirm RevenueCat project `projb937e82a` still has App Store app `app6be2ab0fb8` on bundle ID `ltd.ddga.patchwork`.
- [ ] Confirm the production public SDK key in iOS matches RevenueCat key `appl_KVrqPtiNVMghtWZGRGrnCnBQyfh`.
- [ ] Confirm entitlement `tasker_access` is attached only to:
  - `ltd.ddga.patchwork.tasker.weekly`
  - `ltd.ddga.patchwork.tasker.lifetime`
- [ ] Confirm current offering is `tasker_access_paywall` (`ofrng422905835c`) with packages `$rc_weekly` and `$rc_lifetime`.
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
- [ ] Build `Patchwork` for simulator and device with `xcodebuildmcp`.
- [ ] Archive and export a release build before submission.

## Automated Verification

- [ ] Run `PatchworkTests`.
- [ ] Run the native marketplace smoke suite on `iPhone 17` / latest iOS simulator.
- [ ] Run `testTaskerSubscriptionLifecycle` to confirm tasker onboarding still reaches the RevenueCat-backed subscription screen.

## Manual Commerce Validation

- [ ] On a sandbox or TestFlight build, purchase weekly access and verify Convex tasker state becomes `tasker` + `weekly` + `active`.
- [ ] On a sandbox or TestFlight build, purchase lifetime access and verify Convex tasker state becomes `tasker` + `lifetime` + `active`.
- [ ] Verify `Restore purchases` correctly restores entitlements onto the authenticated user.
- [ ] Verify App Store subscription management opens from the native subscription screen for weekly access.
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

## Known Blocker

- [ ] Resolve or explicitly accept the backend contract gap for exact expiry reconciliation.
  Current limitation:
  - iOS can truthfully sync `active` and `cancel_at_period_end` using RevenueCat + the existing public Convex mutations.
  - iOS cannot truthfully force backend state to `expired` when RevenueCat no longer shows an active entitlement and Convex never previously scheduled the term-end expiration.
  - Shipping without a backend reconciliation endpoint means expiry can remain stale until backend support exists or cancellation was synced before the term ended.
