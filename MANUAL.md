# Patchwork Manual Actions

This file is the current source of truth for human-only actions that cannot be completed reliably from the local repo with the available CLI/MCP access.

Ignore older references to weekly pricing, direct client billing mutations, or a thin-client RevenueCat setup. The live billing contract is now:

- RevenueCat offering `tasker_access_paywall`
- RevenueCat entitlement `tasker_access`
- annual product `ltd.ddga.patchwork.tasker.subscription.yearly`
- lifetime product `ltd.ddga.patchwork.tasker.lifetime`
- Convex webhook route `POST /revenuecat/webhook`

## RevenueCat

Status:
- Production app is `app6be2ab0fb8` on bundle `ltd.ddga.patchwork`.
- Public iOS SDK key is `appl_KVrqPtiNVMghtWZGRGrnCnBQyfh`.
- RevenueCat webhook forwarding to Convex is required for billing truth.

Manual checks:
1. Confirm offering `tasker_access_paywall` contains only annual + lifetime packages.
2. Confirm the legacy weekly product is inactive/unsellable.
3. Confirm the Convex webhook integration remains enabled and healthy.
4. After the first real purchase events, confirm RevenueCat is delivering commerce events successfully.

## App Store Connect

Status:
- App: `Patchwork: Freelance` (`6759272540`)
- Bundle ID: `ltd.ddga.patchwork`
- Annual subscription: `6761341338` / `ltd.ddga.patchwork.tasker.subscription.yearly`
- Lifetime non-consumable: `6760315382` / `ltd.ddga.patchwork.tasker.lifetime`

Manual checks:
1. Confirm both products are still Canada-only if that remains the intended storefront scope.
2. Confirm annual pricing remains `47.99 CAD` and lifetime pricing remains `95.99 CAD`.
3. Confirm both products remain review-ready and attached to the intended app version.
4. Complete any App Review-only metadata that cannot be finalized from the CLI.

## Native Commerce Validation

Manual validation to run on TestFlight or sandbox:
1. Purchase annual access and verify backend state becomes `tasker + subscription + active`.
2. Purchase lifetime access and verify backend state becomes `tasker + lifetime + active`.
3. Restore purchases and confirm the authenticated user regains access.
4. Cancel annual renewal in App Store and confirm backend state becomes `cancel_at_period_end`.
5. Re-enable renewal before term end and confirm backend state returns to `active`.
