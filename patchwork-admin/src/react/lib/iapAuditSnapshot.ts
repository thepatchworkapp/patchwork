export type Tone = "healthy" | "warning" | "risk" | "info";

export type SnapshotItem = {
  label: string;
  value: string;
  tone?: Tone;
  note?: string;
};

export type CatalogAuditRow = {
  id: "subscription" | "lifetime";
  title: string;
  subtitle: string;
  nativePriceNote: string;
  productId: string;
  revenueCatProductId: string;
  revenueCatState: string;
  revenueCatType: string;
  revenueCatPackage: string;
  revenueCatOffering: string;
  entitlement: string;
  appStoreConnectId: string;
  appStoreState: string;
  appStoreAvailability: string;
  appStorePricing: string;
  appStoreLocalization: string;
  backendShape: string;
  backendBehavior: string;
  statusTone: Tone;
  statusLabel: string;
};

export const iapAuditSnapshot = {
  capturedAt: "March 30, 2026",
  meta: {
    appName: "Patchwork: Freelance",
    bundleId: "ltd.ddga.patchwork",
    convexDeployment: "vibrant-caribou-150",
    revenueCatProjectId: "projb937e82a",
    revenueCatAppId: "app6be2ab0fb8",
    appStoreConnectAppId: "6759272540",
  },
  summaryTiles: [
    {
      label: "Payment Modes",
      value: "2",
      tone: "healthy" as Tone,
      note: "Subscribe plus Founders Club in the native iOS billing sheet.",
    },
    {
      label: "ASC Catalog",
      value: "normalized",
      tone: "healthy" as Tone,
      note: "Canada pricing is correct, both items are READY_TO_SUBMIT, and the store-facing names now match the app.",
    },
    {
      label: "RevenueCat Drift",
      value: "0 active",
      tone: "healthy" as Tone,
      note: "Patchwork owns the current offering and the package/product labels now match Subscribe and Founders Club.",
    },
    {
      label: "Backend Rollout",
      value: "live",
      tone: "healthy" as Tone,
      note: "Convex is deployed with the `subscription | lifetime` contract, the webhook route, and the RevenueCat auth header on both deployments.",
    },
  ],
  executiveSummary: [
    "The native billing UI is a custom SwiftUI sheet titled `Start tasking!`, with a hero image, stacked `Subscribe` and `Founders Club` options, and Founders Club preselected as the best-value path.",
    "RevenueCat now attaches annual plus lifetime to entitlement `tasker_access`, `tasker_access_paywall` is the current project-level offering, and both package/product labels now match the app copy.",
    "App Store Connect is commercially correct in Canada: annual is `47.99 CAD`, lifetime is `95.99 CAD`, both products are `READY_TO_SUBMIT`, and the deleted weekly SKU is gone. The storefront names now also match `Subscribe` and `Founders Club`.",
    "Convex is deployed with `plan = tasker` plus `accessType = subscription | lifetime`, and the webhook-backed backend is the production truth path for purchase, restore, renewal, cancellation, and expiration events.",
  ],
  paywall: {
    title: "Native custom iOS billing sheet",
    source:
      "Patchwork_iOS/Patchwork/Features/Profile/Subscriptions/TaskerBillingSheet.swift + TaskerPaywallOptionCard.swift + RevenueCatManager.swift",
    headline: "Start tasking!",
    body:
      "Go live with your Tasker profile and get discovered.",
    packages: [
      {
        title: "Subscribe",
        subtitle: "$47.99/year (`$3.99/mo.`)",
        priceNote:
          "The custom card copy is app-authored. Store billing logic still maps to the annual SKU `ltd.ddga.patchwork.tasker.subscription.yearly`.",
        buttonLabel: "Subscription.subscriptionButton",
      },
      {
        title: "Founders Club",
        subtitle: "$95.99 one-time",
        priceNote:
          "This card is highlighted as `Best Value` and maps to the lifetime SKU `ltd.ddga.patchwork.tasker.lifetime`.",
        buttonLabel: "Subscription.lifetimeButton",
      },
    ],
    behavior: [
      "This is still a custom SwiftUI sheet, not a RevenueCatUI-hosted paywall.",
      "The unpaid state shows the hero art plus stacked plan cards, while the active state still collapses into App Store management and restore actions.",
      "Founders Club is preselected and visibly tagged as `Best Value` in the current native design.",
      "The app requires offering `tasker_access_paywall`, and RevenueCat now also marks that same offering as current/default.",
    ],
  },
  catalogRows: [
    {
      id: "subscription",
      title: "Subscribe",
      subtitle: "Auto-renewable annual tasker access",
      nativePriceNote:
        "The iOS paywall renders this as `Subscribe` with app-side copy `$47.99/year` and `($3.99/mo.)`, backed by the annual RevenueCat product.",
      productId: "ltd.ddga.patchwork.tasker.subscription.yearly",
      revenueCatProductId: "prodde8cbc7a05",
      revenueCatState: "active",
      revenueCatType: "subscription / annual",
      revenueCatPackage: "$rc_annual",
      revenueCatOffering: "tasker_access_paywall",
      entitlement: "tasker_access",
      appStoreConnectId: "6761341338",
      appStoreState: "READY_TO_SUBMIT",
      appStoreAvailability: "Canada only (`CAN`), `availableInNewTerritories = false`.",
      appStorePricing: "Base Canada price set to `47.99 CAD`.",
      appStoreLocalization:
        "en-CA localization now uses display name `Subscribe`. The longer ASC description still uses the earlier annual billing sentence.",
      backendShape:
        "`plan = tasker`, `accessType = subscription`, `status = active|cancel_at_period_end|expired`",
      backendBehavior:
        "Cancellation is supported. Renewable access keeps `subscriptionEndsAt` and is now maintained by the deployed RevenueCat webhook route.",
      statusTone: "healthy" as Tone,
      statusLabel: "aligned",
    },
    {
      id: "lifetime",
      title: "Founders Club",
      subtitle: "One-time unlock for permanent tasker access",
      nativePriceNote:
        "The iOS paywall renders this as `Founders Club` with app-side copy `$95.99 one-time` and highlights it as the current best-value option.",
      productId: "ltd.ddga.patchwork.tasker.lifetime",
      revenueCatProductId: "prod27133e6ef1",
      revenueCatState: "active",
      revenueCatType: "non_consumable",
      revenueCatPackage: "$rc_lifetime",
      revenueCatOffering: "tasker_access_paywall",
      entitlement: "tasker_access",
      appStoreConnectId: "6760315382",
      appStoreState: "READY_TO_SUBMIT",
      appStoreAvailability:
        "Canada only (`CAN`), `availableInNewTerritories = false`.",
      appStorePricing: "Current price is `95.99 CAD`.",
      appStoreLocalization:
        "en-CA localization now uses display name `Founders Club`. The longer ASC description still uses the earlier lifetime sentence.",
      backendShape: "`plan = tasker`, `accessType = lifetime`, `status = active|expired`",
      backendBehavior:
        "Cancellation is rejected because lifetime access does not renew.",
      statusTone: "healthy" as Tone,
      statusLabel: "aligned",
    },
  ] satisfies CatalogAuditRow[],
  revenueCat: {
    facts: [
      {
        label: "Project",
        value: "Patchwork (`projb937e82a`)",
        tone: "healthy" as Tone,
      },
      {
        label: "App",
        value: "Patchwork: Freelance (`app6be2ab0fb8`)",
        tone: "healthy" as Tone,
      },
      {
        label: "Offering",
        value: "`tasker_access_paywall` with `$rc_annual` and `$rc_lifetime`",
        tone: "healthy" as Tone,
      },
      {
        label: "Entitlement",
        value: "`tasker_access` attached to annual plus lifetime",
        tone: "healthy" as Tone,
      },
      {
        label: "Webhook integration",
        value: "`Patchwork Convex Webhook` -> `https://vibrant-caribou-150.convex.site/revenuecat/webhook`",
        tone: "healthy" as Tone,
      },
      {
        label: "Current offering",
        value: "`tasker_access_paywall` is now the project-level current/default offering",
        tone: "healthy" as Tone,
        note: "The old `default` offering is still present, but it is no longer current.",
      },
    ] satisfies SnapshotItem[],
    products: [
      "Active and referenced: `ltd.ddga.patchwork.tasker.subscription.yearly` (`prodde8cbc7a05`) plus `ltd.ddga.patchwork.tasker.lifetime` (`prod27133e6ef1`).",
      "The package and product display names now match the native paywall: `Subscribe` and `Founders Club`.",
      "Inactive legacy RC products are still present: `com.patchwork.tasker.basic.monthly`, `com.patchwork.tasker.premium.monthly`.",
      "Legacy weekly product `ltd.ddga.patchwork.tasker.weekly` (`prodbf228458a7`) is now inactive and removed from the offering and entitlement.",
    ],
    drifts: [
      {
        title: "RevenueCat offering ownership is now correct",
        tone: "healthy" as Tone,
        body:
          "Patchwork now owns the current offering, and the annual/lifetime package names no longer drift from the app-facing billing copy.",
      },
      {
        title: "Legacy monthly RC products remain inactive",
        tone: "info" as Tone,
        body:
          "The old `basic` and `premium` monthly products are still retained in RevenueCat as inactive history. They are no longer referenced by Patchwork entitlements or offerings.",
      },
    ],
  },
  appStoreConnect: {
    facts: [
      {
        label: "App",
        value: "Patchwork: Freelance (`6759272540`)",
        tone: "healthy" as Tone,
      },
      {
        label: "Subscription group",
        value: "Tasker Access (`21966744`)",
        tone: "healthy" as Tone,
      },
      {
        label: "Annual subscription",
        value: "`6761341338` / `ltd.ddga.patchwork.tasker.subscription.yearly`",
        tone: "healthy" as Tone,
      },
      {
        label: "Lifetime IAP",
        value: "`6760315382` / `ltd.ddga.patchwork.tasker.lifetime`",
        tone: "healthy" as Tone,
      },
      {
        label: "Weekly subscription",
        value: "deleted (`6760315381`)",
        tone: "healthy" as Tone,
      },
    ] satisfies SnapshotItem[],
    assets: [
      "Annual subscription is `READY_TO_SUBMIT` with `47.99 CAD` pricing in Canada.",
      "Lifetime IAP is `READY_TO_SUBMIT` with `95.99 CAD` pricing in Canada.",
      "Annual localization now uses `Subscribe` and the lifetime localization now uses `Founders Club`.",
      "The deleted weekly subscription no longer exists in the ASC catalog.",
    ],
    drifts: [
      {
        title: "ASC product names now match the app",
        tone: "healthy" as Tone,
        body:
          "The annual subscription and lifetime IAP now use `Subscribe` and `Founders Club`, so the store catalog no longer disagrees with the native billing sheet on product naming.",
      },
      {
        title: "Commerce items still need submission",
        tone: "warning" as Tone,
        body:
          "The annual subscription and updated lifetime IAP still need to move through the version-level review flow after metadata is complete.",
      },
    ],
  },
  backend: {
    facts: [
      {
        label: "Deployment",
        value: "Convex `vibrant-caribou-150`",
        tone: "healthy" as Tone,
      },
      {
        label: "Contract",
        value: "`tasker` plan with `subscription | lifetime` access types",
        tone: "healthy" as Tone,
      },
      {
        label: "Webhook path",
        value: "`POST /revenuecat/webhook`",
        tone: "healthy" as Tone,
        note: "The live route expects `REVENUECAT_WEBHOOK_AUTHORIZATION` and maps annual/lifetime events into tasker profile state.",
      },
      {
        label: "Legacy tiering",
        value: "`basic` / `premium` removed from the local validators, schema, and web UI assumptions",
        tone: "healthy" as Tone,
      },
    ] satisfies SnapshotItem[],
    realities: [
      "The local code now treats renewable access as `subscription`, not `weekly`.",
      "The current client-facing naming is `Subscribe` and `Founders Club`; the old basic, premium, and weekly labels are gone from the app/backend contract.",
      "The iOS client still performs direct reconciliation after purchase and restore, but the backend now also has a server path for RevenueCat events.",
      "The RevenueCat webhook route is live on both Convex deployments and rejects unauthorized requests before applying events.",
    ],
    drifts: [
      {
        title: "Historical tasker records required one migration pass",
        tone: "info" as Tone,
        body:
          "Deploying the strict schema surfaced legacy `basic` records on the dev deployment, so the rollout included a one-off normalization mutation before the final schema push.",
      },
    ],
  },
  nextSteps: [
    {
      title: "Validate build 26 in TestFlight",
      owner: "iOS",
      priority: "P0",
      detail:
        "Run real-device purchase and restore validation against the uploaded TestFlight build so the live billing surface is checked outside the simulator.",
    },
    {
      title: "Run annual and lifetime purchase smoke tests",
      owner: "iOS + Backend",
      priority: "P1",
      detail:
        "Verify annual purchase, restore, cancel-at-period-end, renewal, and lifetime purchase flows against the webhook-backed backend on a real TestFlight build.",
    },
    {
      title: "Optionally tighten ASC marketing descriptions",
      owner: "ASC",
      priority: "P1",
      detail:
        "The product names are aligned, but the longer ASC localization descriptions still use the earlier marketing sentences. Update them if you want the App Store metadata to mirror the native paywall copy exactly.",
    },
    {
      title: "Optionally prune inactive monthly legacy RC products",
      owner: "RevenueCat",
      priority: "P2",
      detail:
        "The old basic and premium monthly SKUs are already inactive and unreferenced. They can be left as history or archived later if you want a cleaner RC catalog.",
    },
  ],
  sourceNotes: [
    "Local code snapshot: `Patchwork_iOS/Patchwork/Core/AppConfig.swift`, `RevenueCatManager.swift`, `TaskerBillingSheet.swift`, `ProfileView.swift`, `patchwork-backend/convex/taskers.ts`, `patchwork-backend/convex/taskersInternal.ts`, `patchwork-backend/convex/http.ts`, `patchwork-backend/convex/feedback.ts`.",
    "Live RevenueCat snapshot: `tasker_access_paywall` is now the current offering, annual+lifetime remain attached, webhook integration is live, weekly is inactive, and only inactive monthly legacy SKUs remain as of March 30, 2026.",
    "Live App Store Connect snapshot: Canada pricing confirms `47.99 CAD` annual and `95.99 CAD` lifetime, both products are `READY_TO_SUBMIT`, weekly is deleted, and the remaining drift is store-side product naming as of March 30, 2026.",
  ],
} as const;
