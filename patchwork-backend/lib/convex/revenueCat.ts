export const PATCHWORK_REVENUECAT_APP_ID = "app6be2ab0fb8";
export const PATCHWORK_REVENUECAT_ENTITLEMENT_ID = "tasker_access";
export const PATCHWORK_BASIC_MONTHLY_PRODUCT_ID = "ltd.ddga.patchwork.tasker.subscription.basic.monthly";
export const PATCHWORK_ANNUAL_PRODUCT_ID = "ltd.ddga.patchwork.tasker.subscription.yearly";
export const PATCHWORK_LIFETIME_PRODUCT_ID = "ltd.ddga.patchwork.tasker.lifetime";
export const PATCHWORK_LEGACY_WEEKLY_PRODUCT_ID = "ltd.ddga.patchwork.tasker.weekly";
export const REVENUECAT_SUBSCRIBER_API_BASE_URL = "https://api.revenuecat.com/v1/subscribers";

export type RevenueCatAccessType = "subscription" | "lifetime";
export type RevenueCatSubscriptionTier = "basic" | "premium" | "founders";
export type RevenueCatSubscriptionStatus =
  | "inactive"
  | "active"
  | "cancel_at_period_end"
  | "expired";

export type RevenueCatResolvedCustomerState = {
  activeAccessTypes: RevenueCatAccessType[];
  effectiveAccessType?: RevenueCatAccessType;
  effectiveTier?: RevenueCatSubscriptionTier;
  effectiveStatus: RevenueCatSubscriptionStatus;
  subscriptionEndsAt?: number;
  lastKnownAccessType?: RevenueCatAccessType;
  lastKnownTier?: RevenueCatSubscriptionTier;
  hasTrackedPurchase: boolean;
};

type RevenueCatSubscriberRecord = Record<string, unknown>;

function asRecord(value: unknown): RevenueCatSubscriberRecord | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  return value as RevenueCatSubscriberRecord;
}

function asRecordArray(value: unknown): RevenueCatSubscriberRecord[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((entry) => asRecord(entry))
    .filter((entry): entry is RevenueCatSubscriberRecord => entry !== null);
}

function asString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim().length > 0 ? value : undefined;
}

export function parseRevenueCatDateMs(value: unknown): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value > 1_000_000_000_000 ? Math.round(value) : Math.round(value * 1000);
  }

  const stringValue = asString(value);
  if (!stringValue) {
    return undefined;
  }

  const numericValue = Number(stringValue);
  if (Number.isFinite(numericValue)) {
    return numericValue > 1_000_000_000_000 ? Math.round(numericValue) : Math.round(numericValue * 1000);
  }

  const parsed = Date.parse(stringValue);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function latestDefined(values: Array<number | undefined>): number | undefined {
  return values.reduce<number | undefined>((latest, value) => {
    if (value === undefined) {
      return latest;
    }
    if (latest === undefined) {
      return value;
    }
    return value > latest ? value : latest;
  }, undefined);
}

function getSubscriptionRecord(
  subscriber: RevenueCatSubscriberRecord,
  productId: string,
): RevenueCatSubscriberRecord | null {
  const subscriptions = asRecord(subscriber.subscriptions);
  return subscriptions ? asRecord(subscriptions[productId]) : null;
}

function getSubscriptionActivity(
  subscriber: RevenueCatSubscriberRecord,
  productId: string,
) {
  const record = getSubscriptionRecord(subscriber, productId);
  const expiresAt =
    parseRevenueCatDateMs(record?.expires_date_ms)
    ?? parseRevenueCatDateMs(record?.expiration_at_ms)
    ?? parseRevenueCatDateMs(record?.expires_date)
    ?? parseRevenueCatDateMs(record?.expiration_at);
  const purchaseAt =
    parseRevenueCatDateMs(record?.purchase_date_ms)
    ?? parseRevenueCatDateMs(record?.purchase_date)
    ?? parseRevenueCatDateMs(record?.original_purchase_date_ms)
    ?? parseRevenueCatDateMs(record?.original_purchase_date);
  const cancellationDetectedAt =
    parseRevenueCatDateMs(record?.unsubscribe_detected_at_ms)
    ?? parseRevenueCatDateMs(record?.unsubscribe_detected_at);

  return {
    record,
    expiresAt,
    purchaseAt,
    cancellationDetectedAt,
    isActive: expiresAt !== undefined && expiresAt > Date.now(),
  };
}

function getNonSubscriptionRecords(
  subscriber: RevenueCatSubscriberRecord,
  productId: string,
): RevenueCatSubscriberRecord[] {
  const nonSubscriptions = asRecord(subscriber.non_subscriptions) ?? asRecord(subscriber.other_purchases);
  if (!nonSubscriptions) {
    return [];
  }

  const records = nonSubscriptions[productId];
  const asArray = asRecordArray(records);
  if (asArray.length > 0) {
    return asArray;
  }

  const singletonRecord = asRecord(records);
  return singletonRecord ? [singletonRecord] : [];
}

function getEntitlementRecord(subscriber: RevenueCatSubscriberRecord): RevenueCatSubscriberRecord | null {
  const entitlements = asRecord(subscriber.entitlements);
  return entitlements ? asRecord(entitlements[PATCHWORK_REVENUECAT_ENTITLEMENT_ID]) : null;
}

function sortActiveAccessTypes(accessTypes: Iterable<RevenueCatAccessType>): RevenueCatAccessType[] {
  const ordered = ["subscription", "lifetime"] as const;
  const values = new Set(accessTypes);
  return ordered.filter((value): value is RevenueCatAccessType => values.has(value));
}

export function mapRevenueCatProduct(
  productId: string | undefined,
): RevenueCatAccessType | "legacy_weekly" | null {
  if (!productId) {
    return null;
  }

  if (productId === PATCHWORK_BASIC_MONTHLY_PRODUCT_ID || productId === PATCHWORK_ANNUAL_PRODUCT_ID) {
    return "subscription";
  }

  if (productId === PATCHWORK_LIFETIME_PRODUCT_ID) {
    return "lifetime";
  }

  if (productId === PATCHWORK_LEGACY_WEEKLY_PRODUCT_ID) {
    return "legacy_weekly";
  }

  return null;
}

export function mapRevenueCatProductTier(
  productId: string | undefined,
): RevenueCatSubscriptionTier | "legacy_weekly" | null {
  if (!productId) {
    return null;
  }

  if (productId === PATCHWORK_BASIC_MONTHLY_PRODUCT_ID) {
    return "basic";
  }

  if (productId === PATCHWORK_ANNUAL_PRODUCT_ID) {
    return "premium";
  }

  if (productId === PATCHWORK_LIFETIME_PRODUCT_ID) {
    return "founders";
  }

  if (productId === PATCHWORK_LEGACY_WEEKLY_PRODUCT_ID) {
    return "legacy_weekly";
  }

  return null;
}

export function isRevenueCatAnonymousAppUserId(appUserId: string): boolean {
  return appUserId.startsWith("$RCAnonymousID:");
}

export function dedupeRevenueCatAppUserIds(candidateIds: Array<string | undefined>): string[] {
  const uniqueIds: string[] = [];

  for (const candidateId of candidateIds) {
    const trimmed = candidateId?.trim();
    if (!trimmed || uniqueIds.includes(trimmed)) {
      continue;
    }
    uniqueIds.push(trimmed);
  }

  return uniqueIds;
}

export function resolveRevenueCatCustomerState(
  subscriberLike: unknown,
  now = Date.now(),
): RevenueCatResolvedCustomerState {
  const subscriber = asRecord(subscriberLike) ?? {};
  const entitlement = getEntitlementRecord(subscriber);
  const entitlementProductId = asString(entitlement?.product_identifier) ?? asString(entitlement?.product_id);
  const mappedEntitlementProduct = mapRevenueCatProduct(entitlementProductId);
  const mappedEntitlementTier = mapRevenueCatProductTier(entitlementProductId);
  const entitlementExpiresAt =
    parseRevenueCatDateMs(entitlement?.expires_date_ms)
    ?? parseRevenueCatDateMs(entitlement?.expiration_at_ms)
    ?? parseRevenueCatDateMs(entitlement?.expires_date)
    ?? parseRevenueCatDateMs(entitlement?.expiration_at);
  const entitlementCancellationDetectedAt =
    parseRevenueCatDateMs(entitlement?.unsubscribe_detected_at_ms)
    ?? parseRevenueCatDateMs(entitlement?.unsubscribe_detected_at);
  const entitlementPurchaseAt =
    parseRevenueCatDateMs(entitlement?.purchase_date_ms)
    ?? parseRevenueCatDateMs(entitlement?.purchase_date)
    ?? parseRevenueCatDateMs(entitlement?.latest_purchase_date_ms)
    ?? parseRevenueCatDateMs(entitlement?.latest_purchase_date);
  const entitlementIsActive = Boolean(entitlement)
    && (entitlementExpiresAt === undefined || entitlementExpiresAt > now);

  const annualSubscription = getSubscriptionActivity(subscriber, PATCHWORK_ANNUAL_PRODUCT_ID);
  const basicMonthlySubscription = getSubscriptionActivity(subscriber, PATCHWORK_BASIC_MONTHLY_PRODUCT_ID);
  const annualSubscriptionExpiresAt = annualSubscription.expiresAt;
  const annualSubscriptionPurchaseAt = annualSubscription.purchaseAt;
  const annualCancellationDetectedAt = annualSubscription.cancellationDetectedAt;
  const basicMonthlySubscriptionExpiresAt = basicMonthlySubscription.expiresAt;
  const basicMonthlySubscriptionPurchaseAt = basicMonthlySubscription.purchaseAt;
  const basicMonthlyCancellationDetectedAt = basicMonthlySubscription.cancellationDetectedAt;
  const annualSubscriptionIsActive =
    annualSubscriptionExpiresAt !== undefined && annualSubscriptionExpiresAt > now;
  const basicMonthlySubscriptionIsActive =
    basicMonthlySubscriptionExpiresAt !== undefined && basicMonthlySubscriptionExpiresAt > now;

  const lifetimePurchaseRecords = getNonSubscriptionRecords(subscriber, PATCHWORK_LIFETIME_PRODUCT_ID);
  const latestLifetimePurchaseAt = latestDefined([
    ...lifetimePurchaseRecords.map(
      (record) =>
        parseRevenueCatDateMs(record.purchase_date_ms)
        ?? parseRevenueCatDateMs(record.purchase_date)
        ?? parseRevenueCatDateMs(record.original_purchase_date_ms)
        ?? parseRevenueCatDateMs(record.original_purchase_date),
    ),
    mappedEntitlementProduct === "lifetime" ? entitlementPurchaseAt : undefined,
  ]);

  const latestSubscriptionActivityAt = latestDefined([
    annualSubscriptionPurchaseAt,
    annualSubscriptionExpiresAt,
    basicMonthlySubscriptionPurchaseAt,
    basicMonthlySubscriptionExpiresAt,
    mappedEntitlementProduct === "subscription" ? entitlementPurchaseAt : undefined,
    mappedEntitlementProduct === "subscription" ? entitlementExpiresAt : undefined,
  ]);

  const activeAccessTypes = new Set<RevenueCatAccessType>();
  if (entitlementIsActive && mappedEntitlementProduct && mappedEntitlementProduct !== "legacy_weekly") {
    activeAccessTypes.add(mappedEntitlementProduct);
  }
  if (annualSubscriptionIsActive) {
    activeAccessTypes.add("subscription");
  }
  if (basicMonthlySubscriptionIsActive) {
    activeAccessTypes.add("subscription");
  }

  const orderedActiveAccessTypes = sortActiveAccessTypes(activeAccessTypes);
  const effectiveAccessType = orderedActiveAccessTypes.includes("lifetime")
    ? "lifetime"
    : orderedActiveAccessTypes.includes("subscription")
      ? "subscription"
      : undefined;

  const lastKnownAccessType = latestLifetimePurchaseAt !== undefined || latestSubscriptionActivityAt !== undefined
    ? latestLifetimePurchaseAt !== undefined
        && (latestSubscriptionActivityAt === undefined || latestLifetimePurchaseAt >= latestSubscriptionActivityAt)
      ? "lifetime"
      : "subscription"
    : mappedEntitlementProduct && mappedEntitlementProduct !== "legacy_weekly"
      ? mappedEntitlementProduct
      : undefined;

  const activeTiers = new Set<RevenueCatSubscriptionTier>();
  if (entitlementIsActive && mappedEntitlementTier && mappedEntitlementTier !== "legacy_weekly") {
    activeTiers.add(mappedEntitlementTier);
  }
  if (annualSubscriptionIsActive) {
    activeTiers.add("premium");
  }
  if (basicMonthlySubscriptionIsActive) {
    activeTiers.add("basic");
  }
  if (latestLifetimePurchaseAt !== undefined) {
    activeTiers.add("founders");
  }

  const effectiveTier: RevenueCatSubscriptionTier | undefined = activeTiers.has("founders")
    ? "founders"
    : activeTiers.has("premium")
      ? "premium"
      : activeTiers.has("basic")
        ? "basic"
        : undefined;

  const lastKnownTier = latestLifetimePurchaseAt !== undefined || latestSubscriptionActivityAt !== undefined
    ? latestLifetimePurchaseAt !== undefined
        && (latestSubscriptionActivityAt === undefined || latestLifetimePurchaseAt >= latestSubscriptionActivityAt)
      ? "founders"
      : annualSubscriptionPurchaseAt !== undefined
          && (
            basicMonthlySubscriptionPurchaseAt === undefined
            || annualSubscriptionPurchaseAt >= basicMonthlySubscriptionPurchaseAt
          )
        ? "premium"
        : "basic"
    : mappedEntitlementTier && mappedEntitlementTier !== "legacy_weekly"
      ? mappedEntitlementTier
      : undefined;

  let effectiveStatus: RevenueCatSubscriptionStatus = "inactive";
  let subscriptionEndsAt: number | undefined;

  if (effectiveAccessType === "lifetime") {
    effectiveStatus = "active";
  } else if (effectiveAccessType === "subscription") {
    subscriptionEndsAt = effectiveTier === "basic"
      ? basicMonthlySubscriptionExpiresAt ?? entitlementExpiresAt
      : annualSubscriptionExpiresAt ?? entitlementExpiresAt ?? basicMonthlySubscriptionExpiresAt;
    effectiveStatus =
      annualCancellationDetectedAt !== undefined
        || basicMonthlyCancellationDetectedAt !== undefined
        || entitlementCancellationDetectedAt !== undefined
        ? "cancel_at_period_end"
        : "active";
  } else if (lastKnownAccessType) {
    effectiveStatus = "expired";
    if (lastKnownAccessType === "subscription") {
      subscriptionEndsAt = annualSubscriptionExpiresAt ?? entitlementExpiresAt;
    }
  }

  return {
    activeAccessTypes: orderedActiveAccessTypes,
    effectiveAccessType,
    effectiveTier,
    effectiveStatus,
    subscriptionEndsAt,
    lastKnownAccessType,
    lastKnownTier,
    hasTrackedPurchase: lastKnownAccessType !== undefined,
  };
}
