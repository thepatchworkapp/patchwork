import { internalAction, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { getDefaultSubscriptionTermMs } from "../lib/convex/subscriptionState";
import {
  dedupeRevenueCatAppUserIds,
  isRevenueCatAnonymousAppUserId,
  mapRevenueCatProduct,
  mapRevenueCatProductTier,
  PATCHWORK_REVENUECAT_APP_ID,
  REVENUECAT_SUBSCRIBER_API_BASE_URL,
  resolveRevenueCatCustomerState,
  type RevenueCatResolvedCustomerState,
  type RevenueCatSubscriptionTier,
} from "../lib/convex/revenueCat";

const MAX_SCHEDULER_DELAY_MS = 2_147_483_647;
const PREMIUM_PIN_ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const PREMIUM_PIN_LENGTH = 8;

type RevenueCatWebhookFallbackArgs = {
  type: string;
  appId?: string;
  productId?: string;
  appUserId?: string;
  originalAppUserId?: string;
  aliases?: string[];
  expirationAtMs?: number | null;
};

function revenueCatAccessTypeValidator() {
  return v.union(v.literal("subscription"), v.literal("lifetime"));
}

function revenueCatSubscriptionStatusValidator() {
  return v.union(
    v.literal("inactive"),
    v.literal("active"),
    v.literal("cancel_at_period_end"),
    v.literal("expired"),
  );
}

function revenueCatSubscriptionTierValidator() {
  return v.union(v.literal("basic"), v.literal("premium"), v.literal("founders"));
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  return value as Record<string, unknown>;
}

async function loadTaskerProfileForRevenueCatUsers(
  ctx: any,
  candidateIds: string[],
) {
  for (const candidateId of dedupeRevenueCatAppUserIds(candidateIds)) {
    if (isRevenueCatAnonymousAppUserId(candidateId)) {
      continue;
    }

    try {
      const user = await ctx.db.get(candidateId as Id<"users">);
      if (!user) {
        continue;
      }

      const profile = await ctx.db
        .query("taskerProfiles")
        .withIndex("by_userId", (q: any) => q.eq("userId", user._id))
        .unique();

      if (profile) {
        return profile;
      }
    } catch {
      continue;
    }
  }

  return null;
}

async function scheduleTermEndExpiration(ctx: any, taskerProfileId: Id<"taskerProfiles">, endsAt: number) {
  await ctx.scheduler.runAfter(
    Math.min(Math.max(endsAt - Date.now(), 0), MAX_SCHEDULER_DELAY_MS),
    internal.taskersInternal.expireSubscriptionAtTermEnd,
    {
      taskerProfileId,
      expectedEndsAt: endsAt,
    },
  );
}

async function syncTaskerGeoFromLastGpsCheckIn(ctx: any, profile: any) {
  const currentProfile = await ctx.db.get(profile._id);
  if (currentProfile?.location && currentProfile.locationCheckedInAt) {
    await ctx.runMutation(internal.location.syncTaskerGeo, {
      userId: currentProfile.userId,
      lat: currentProfile.location.lat,
      lng: currentProfile.location.lng,
      checkedInAt: currentProfile.locationCheckedInAt,
    });
    return;
  }

  const user = await ctx.db.get(profile.userId);
  const coordinates = user?.location?.gpsCoordinates;
  if (!user || !coordinates) {
    return;
  }

  await ctx.runMutation(internal.location.syncTaskerGeo, {
    userId: user._id,
    lat: coordinates.lat,
    lng: coordinates.lng,
    checkedInAt: coordinates.checkedInAt,
  });
}

function shouldHaveActivePremiumPin(tier?: RevenueCatSubscriptionTier, status?: string) {
  return status === "active" && (tier === "premium" || tier === "founders");
}

function generatePremiumPinCandidate() {
  let pin = "";
  for (let index = 0; index < PREMIUM_PIN_LENGTH; index += 1) {
    pin += PREMIUM_PIN_ALPHABET[Math.floor(Math.random() * PREMIUM_PIN_ALPHABET.length)];
  }
  return pin;
}

async function getUniquePremiumPin(ctx: any, profile: any) {
  if (
    typeof profile.premiumPin === "string" &&
    /^[0-9A-Z]{8}$/.test(profile.premiumPin)
  ) {
    return profile.premiumPin;
  }

  for (let attempt = 0; attempt < 20; attempt += 1) {
    const candidate = generatePremiumPinCandidate();
    const existing = await ctx.db
      .query("taskerProfiles")
      .withIndex("by_premiumPin", (q: any) => q.eq("premiumPin", candidate))
      .first();

    if (!existing || existing._id === profile._id) {
      return candidate;
    }
  }

  throw new Error("Unable to generate unique premium pin");
}

async function applyPremiumPinLifecycle(
  ctx: any,
  profile: any,
  updates: Record<string, unknown>,
  tier?: RevenueCatSubscriptionTier,
  status?: string,
) {
  if (shouldHaveActivePremiumPin(tier, status)) {
    updates.premiumPin = await getUniquePremiumPin(ctx, profile);
    return;
  }

  updates.premiumPin = undefined;
}

async function fetchRevenueCatSubscriber(
  appUserId: string,
  secretApiKey: string,
  sandboxOnly = false,
): Promise<Record<string, unknown> | null> {
  const response = await fetch(
    `${REVENUECAT_SUBSCRIBER_API_BASE_URL}/${encodeURIComponent(appUserId)}`,
    {
      method: "GET",
      headers: {
        Authorization: `Bearer ${secretApiKey}`,
        Accept: "application/json",
        ...(sandboxOnly ? { "X-Is-Sandbox": "true" } : {}),
      },
    },
  );

  if (response.status === 404) {
    return null;
  }

  if (!response.ok) {
    const responseText = await response.text();
    throw new Error(
      `RevenueCat lookup failed for ${appUserId} (${response.status}): ${responseText || "No response body"}`
    );
  }

  const payload = await response.json().catch(() => null);
  const subscriber = asRecord(payload?.subscriber);
  return subscriber;
}

async function fetchResolvedRevenueCatCustomerState(
  appUserId: string,
  secretApiKey: string,
): Promise<RevenueCatResolvedCustomerState | null> {
  const defaultSubscriber = await fetchRevenueCatSubscriber(appUserId, secretApiKey, false);
  if (defaultSubscriber) {
    const resolvedDefault = resolveRevenueCatCustomerState(defaultSubscriber);
    if (resolvedDefault.effectiveStatus !== "inactive" || resolvedDefault.hasTrackedPurchase) {
      return resolvedDefault;
    }
  }

  const sandboxSubscriber = await fetchRevenueCatSubscriber(appUserId, secretApiKey, true);
  if (!sandboxSubscriber) {
    return defaultSubscriber ? resolveRevenueCatCustomerState(defaultSubscriber) : null;
  }

  const resolvedSandbox = resolveRevenueCatCustomerState(sandboxSubscriber);
  if (resolvedSandbox.effectiveStatus !== "inactive" || resolvedSandbox.hasTrackedPurchase) {
    return resolvedSandbox;
  }

  return defaultSubscriber ? resolveRevenueCatCustomerState(defaultSubscriber) : resolvedSandbox;
}

async function findResolvedRevenueCatCustomerState(
  candidateAppUserIds: string[],
  secretApiKey: string,
): Promise<{ sourceAppUserId: string; resolved: RevenueCatResolvedCustomerState } | null> {
  for (const candidateAppUserId of dedupeRevenueCatAppUserIds(candidateAppUserIds)) {
    const resolved = await fetchResolvedRevenueCatCustomerState(candidateAppUserId, secretApiKey);
    if (!resolved) {
      continue;
    }

    if (resolved.effectiveStatus !== "inactive" || resolved.hasTrackedPurchase) {
      return {
        sourceAppUserId: candidateAppUserId,
        resolved,
      };
    }
  }

  return null;
}

async function reconcileRevenueCatCustomerState(
  ctx: any,
  args: {
    appId?: string;
    candidateAppUserIds: string[];
    source: string;
    fallbackEvent?: RevenueCatWebhookFallbackArgs;
  },
) {
  if (args.appId && args.appId !== PATCHWORK_REVENUECAT_APP_ID) {
    console.info("[RevenueCatWebhook] Ignoring event for different app", { appId: args.appId });
    return { applied: false, reason: "wrong_app" };
  }

  const candidateAppUserIds = dedupeRevenueCatAppUserIds(args.candidateAppUserIds);
  if (!candidateAppUserIds.length) {
    console.warn("[RevenueCatWebhook] No candidate app user IDs were provided", { source: args.source });
    if (args.fallbackEvent) {
      return await ctx.runMutation(internal.taskersInternal.applyRevenueCatWebhookEvent, args.fallbackEvent);
    }
    return { applied: false, reason: "candidate_user_ids_missing" };
  }

  const secretApiKey = process.env.REVENUECAT_SECRET_API_KEY;
  if (!secretApiKey) {
    console.warn("[RevenueCatWebhook] Missing REVENUECAT_SECRET_API_KEY; falling back to event payload", {
      source: args.source,
      candidateAppUserIds,
    });
    if (args.fallbackEvent) {
      return await ctx.runMutation(internal.taskersInternal.applyRevenueCatWebhookEvent, args.fallbackEvent);
    }
    return { applied: false, reason: "secret_api_key_missing" };
  }

  try {
    const resolvedCustomer = await findResolvedRevenueCatCustomerState(candidateAppUserIds, secretApiKey);
    if (!resolvedCustomer) {
      console.warn("[RevenueCatWebhook] No canonical RevenueCat customer state found", {
        source: args.source,
        candidateAppUserIds,
      });
      if (args.fallbackEvent) {
        return await ctx.runMutation(internal.taskersInternal.applyRevenueCatWebhookEvent, args.fallbackEvent);
      }
      return { applied: false, reason: "subscriber_not_found" };
    }

    return await ctx.runMutation(internal.taskersInternal.applyResolvedRevenueCatCustomerState, {
      candidateAppUserIds,
      sourceAppUserId: resolvedCustomer.sourceAppUserId,
      activeAccessTypes: resolvedCustomer.resolved.activeAccessTypes,
      effectiveAccessType: resolvedCustomer.resolved.effectiveAccessType,
      effectiveTier: resolvedCustomer.resolved.effectiveTier,
      effectiveStatus: resolvedCustomer.resolved.effectiveStatus,
      subscriptionEndsAt: resolvedCustomer.resolved.subscriptionEndsAt ?? null,
      lastKnownAccessType: resolvedCustomer.resolved.lastKnownAccessType,
      lastKnownTier: resolvedCustomer.resolved.lastKnownTier,
      hasTrackedPurchase: resolvedCustomer.resolved.hasTrackedPurchase,
    });
  } catch (error) {
    console.error("[RevenueCatWebhook] Canonical reconciliation failed", {
      source: args.source,
      candidateAppUserIds,
      error: error instanceof Error ? error.message : String(error),
    });
    if (args.fallbackEvent) {
      return await ctx.runMutation(internal.taskersInternal.applyRevenueCatWebhookEvent, args.fallbackEvent);
    }
    throw error;
  }
}

export const expireSubscriptionAtTermEnd = internalMutation({
  args: {
    taskerProfileId: v.id("taskerProfiles"),
    expectedEndsAt: v.number(),
  },
  handler: async (ctx, args) => {
    const profile = await ctx.db.get(args.taskerProfileId);
    if (!profile) {
      return;
    }

    if (
      profile.subscriptionStatus !== "cancel_at_period_end" ||
      profile.subscriptionEndsAt !== args.expectedEndsAt ||
      profile.subscriptionEndsAt > Date.now()
    ) {
      return;
    }

    const remainingMs = profile.subscriptionEndsAt - Date.now();
    if (remainingMs > 0) {
      await ctx.scheduler.runAfter(
        Math.min(remainingMs, MAX_SCHEDULER_DELAY_MS),
        internal.taskersInternal.expireSubscriptionAtTermEnd,
        args,
      );
      return;
    }

    await ctx.db.patch(profile._id, {
      subscriptionPlan: "tasker",
      subscriptionStatus: "expired",
      subscriptionActiveAccessTypes: [],
      ghostMode: true,
      premiumPin: undefined,
      updatedAt: Date.now(),
    });
  },
});

export const applyResolvedRevenueCatCustomerState = internalMutation({
  args: {
    candidateAppUserIds: v.array(v.string()),
    sourceAppUserId: v.optional(v.string()),
    activeAccessTypes: v.array(revenueCatAccessTypeValidator()),
    effectiveAccessType: v.optional(revenueCatAccessTypeValidator()),
    effectiveTier: v.optional(revenueCatSubscriptionTierValidator()),
    effectiveStatus: revenueCatSubscriptionStatusValidator(),
    subscriptionEndsAt: v.optional(v.union(v.number(), v.null())),
    lastKnownAccessType: v.optional(revenueCatAccessTypeValidator()),
    lastKnownTier: v.optional(revenueCatSubscriptionTierValidator()),
    hasTrackedPurchase: v.boolean(),
  },
  handler: async (ctx, args) => {
    const profile = await loadTaskerProfileForRevenueCatUsers(ctx, args.candidateAppUserIds);

    if (!profile) {
      console.warn("[RevenueCatWebhook] No tasker profile found for canonical RevenueCat state", {
        candidateAppUserIds: args.candidateAppUserIds,
        sourceAppUserId: args.sourceAppUserId,
      });
      return { applied: false, reason: "tasker_profile_not_found" };
    }

    const updates: Record<string, unknown> = {
      updatedAt: Date.now(),
      subscriptionActiveAccessTypes: args.activeAccessTypes,
    };

    if (args.effectiveStatus === "active" || args.effectiveStatus === "cancel_at_period_end") {
      updates.subscriptionPlan = "tasker";
      updates.subscriptionAccessType = args.effectiveAccessType;
      updates.subscriptionTier = args.effectiveTier;
      updates.subscriptionStatus = args.effectiveStatus;
      updates.subscriptionEndsAt =
        args.effectiveAccessType === "subscription"
          ? args.subscriptionEndsAt ??
            profile.subscriptionEndsAt ??
            Date.now() +
              getDefaultSubscriptionTermMs({
                subscriptionPlan: "tasker",
                subscriptionAccessType: "subscription",
              })
          : undefined;
      updates.ghostMode = false;
      await applyPremiumPinLifecycle(ctx, profile, updates, args.effectiveTier, args.effectiveStatus);
      await ctx.db.patch(profile._id, updates);
      await syncTaskerGeoFromLastGpsCheckIn(ctx, profile);

      if (args.effectiveStatus === "cancel_at_period_end" && typeof updates.subscriptionEndsAt === "number") {
        await scheduleTermEndExpiration(ctx, profile._id, updates.subscriptionEndsAt);
      }

      console.info("[RevenueCatWebhook] Applied canonical active tasker access", {
        profileId: profile._id,
        sourceAppUserId: args.sourceAppUserId,
        effectiveAccessType: args.effectiveAccessType,
        activeAccessTypes: args.activeAccessTypes,
        effectiveStatus: args.effectiveStatus,
      });
      return { applied: true, reason: "canonical_state_applied" };
    }

    if (args.effectiveStatus === "expired") {
      updates.subscriptionPlan = "tasker";
      updates.subscriptionAccessType = args.lastKnownAccessType;
      updates.subscriptionTier = args.lastKnownTier;
      updates.subscriptionStatus = "expired";
      updates.subscriptionEndsAt =
        args.lastKnownAccessType === "subscription" ? args.subscriptionEndsAt ?? profile.subscriptionEndsAt : undefined;
      updates.ghostMode = true;
      await applyPremiumPinLifecycle(ctx, profile, updates, args.lastKnownTier, "expired");
      await ctx.db.patch(profile._id, updates);
      console.info("[RevenueCatWebhook] Applied canonical expired tasker access", {
        profileId: profile._id,
        sourceAppUserId: args.sourceAppUserId,
        lastKnownAccessType: args.lastKnownAccessType,
      });
      return { applied: true, reason: "canonical_state_applied" };
    }

    if (!args.hasTrackedPurchase) {
      updates.subscriptionPlan = "none";
      updates.subscriptionAccessType = undefined;
      updates.subscriptionTier = undefined;
      updates.subscriptionStatus = "inactive";
      updates.subscriptionEndsAt = undefined;
      updates.ghostMode = true;
      updates.premiumPin = undefined;
      await ctx.db.patch(profile._id, updates);
      console.info("[RevenueCatWebhook] Applied canonical inactive tasker access", {
        profileId: profile._id,
        sourceAppUserId: args.sourceAppUserId,
      });
      return { applied: true, reason: "canonical_state_applied" };
    }

    return { applied: false, reason: "canonical_state_no_change" };
  },
});

export const reconcileRevenueCatCustomer = internalAction({
  args: {
    candidateAppUserIds: v.array(v.string()),
    source: v.string(),
  },
  handler: async (ctx, args) =>
    await reconcileRevenueCatCustomerState(ctx, {
      candidateAppUserIds: args.candidateAppUserIds,
      source: args.source,
    }),
});

export const reconcileRevenueCatWebhookEvent = internalAction({
  args: {
    type: v.string(),
    appId: v.optional(v.string()),
    productId: v.optional(v.string()),
    appUserId: v.optional(v.string()),
    originalAppUserId: v.optional(v.string()),
    aliases: v.optional(v.array(v.string())),
    transferredFrom: v.optional(v.array(v.string())),
    transferredTo: v.optional(v.array(v.string())),
    expirationAtMs: v.optional(v.union(v.number(), v.null())),
  },
  handler: async (ctx, args) =>
    await reconcileRevenueCatCustomerState(ctx, {
      appId: args.appId,
      candidateAppUserIds: [
        args.appUserId ?? "",
        args.originalAppUserId ?? "",
        ...(args.transferredTo ?? []),
        ...(args.aliases ?? []),
        ...(args.transferredFrom ?? []),
      ],
      source: `webhook:${args.type}`,
      fallbackEvent: {
        type: args.type,
        appId: args.appId,
        productId: args.productId,
        appUserId: args.appUserId,
        originalAppUserId: args.originalAppUserId,
        aliases: args.aliases,
        expirationAtMs: args.expirationAtMs,
      },
    }),
});

export const applyRevenueCatWebhookEvent = internalMutation({
  args: {
    type: v.string(),
    appId: v.optional(v.string()),
    productId: v.optional(v.string()),
    appUserId: v.optional(v.string()),
    originalAppUserId: v.optional(v.string()),
    aliases: v.optional(v.array(v.string())),
    expirationAtMs: v.optional(v.union(v.number(), v.null())),
  },
  handler: async (ctx, args) => {
    if (args.appId && args.appId !== PATCHWORK_REVENUECAT_APP_ID) {
      console.info("[RevenueCatWebhook] Ignoring event for different app", { appId: args.appId });
      return { applied: false, reason: "wrong_app" };
    }

    const mappedProduct = mapRevenueCatProduct(args.productId);
    const mappedTier = mapRevenueCatProductTier(args.productId);
    if (mappedProduct === "legacy_weekly") {
      console.info("[RevenueCatWebhook] Ignoring legacy weekly product", { productId: args.productId });
      return { applied: false, reason: "legacy_weekly_ignored" };
    }
    if (mappedTier === "legacy_weekly" || !mappedTier) {
      console.info("[RevenueCatWebhook] Ignoring untracked tier product", { productId: args.productId });
      return { applied: false, reason: "untracked_product" };
    }
    if (!mappedProduct) {
      console.info("[RevenueCatWebhook] Ignoring untracked product", { productId: args.productId });
      return { applied: false, reason: "untracked_product" };
    }

    const profile = await loadTaskerProfileForRevenueCatUsers(ctx, [
      args.appUserId ?? "",
      args.originalAppUserId ?? "",
      ...(args.aliases ?? []),
    ]);

    if (!profile) {
      console.warn("[RevenueCatWebhook] No tasker profile found for purchase", {
        appUserId: args.appUserId,
        originalAppUserId: args.originalAppUserId,
        aliases: args.aliases ?? [],
      });
      return { applied: false, reason: "tasker_profile_not_found" };
    }

    const expirationAt =
      typeof args.expirationAtMs === "number"
        ? args.expirationAtMs
        : undefined;

    const activeTypes = new Set([
      "INITIAL_PURCHASE",
      "RENEWAL",
      "NON_RENEWING_PURCHASE",
      "PRODUCT_CHANGE",
      "UNCANCELLATION",
      "SUBSCRIPTION_EXTENDED",
    ]);

    const updates: Record<string, unknown> = {
      subscriptionPlan: "tasker",
      subscriptionAccessType: mappedProduct,
      subscriptionTier: mappedTier,
      subscriptionActiveAccessTypes: [mappedProduct],
      updatedAt: Date.now(),
    };

    if (activeTypes.has(args.type)) {
      updates.subscriptionStatus = "active";
      updates.subscriptionEndsAt =
        mappedProduct === "subscription"
          ? expirationAt ??
            profile.subscriptionEndsAt ??
            Date.now() +
              getDefaultSubscriptionTermMs({
                subscriptionPlan: "tasker",
                subscriptionAccessType: "subscription",
              })
          : undefined;
      updates.ghostMode = false;
      await applyPremiumPinLifecycle(ctx, profile, updates, mappedTier, "active");
      await ctx.db.patch(profile._id, updates);
      await syncTaskerGeoFromLastGpsCheckIn(ctx, profile);
      console.info("[RevenueCatWebhook] Activated tasker access", {
        profileId: profile._id,
        accessType: mappedProduct,
        eventType: args.type,
      });
      return { applied: true, reason: "activated" };
    }

    if (args.type === "CANCELLATION" && mappedProduct === "subscription") {
      const endsAt =
        expirationAt ??
        profile.subscriptionEndsAt ??
        Date.now() +
          getDefaultSubscriptionTermMs({
            subscriptionPlan: "tasker",
            subscriptionAccessType: "subscription",
          });

      updates.subscriptionStatus = "cancel_at_period_end";
      updates.subscriptionEndsAt = endsAt;
      updates.ghostMode = false;
      await applyPremiumPinLifecycle(ctx, profile, updates, mappedTier, "cancel_at_period_end");
      await ctx.db.patch(profile._id, updates);
      await syncTaskerGeoFromLastGpsCheckIn(ctx, profile);
      await scheduleTermEndExpiration(ctx, profile._id, endsAt);
      console.info("[RevenueCatWebhook] Scheduled subscription cancellation", {
        profileId: profile._id,
        endsAt,
      });
      return { applied: true, reason: "cancellation_scheduled" };
    }

    if (args.type === "EXPIRATION" || (args.type === "CANCELLATION" && mappedProduct === "lifetime")) {
      updates.subscriptionPlan = "tasker";
      updates.subscriptionStatus = "expired";
      updates.subscriptionEndsAt =
        mappedProduct === "subscription" ? expirationAt ?? profile.subscriptionEndsAt : undefined;
      updates.subscriptionActiveAccessTypes = [];
      updates.ghostMode = true;
      await applyPremiumPinLifecycle(ctx, profile, updates, mappedTier, "expired");
      await ctx.db.patch(profile._id, updates);
      console.info("[RevenueCatWebhook] Expired tasker access", {
        profileId: profile._id,
        accessType: mappedProduct,
        eventType: args.type,
      });
      return { applied: true, reason: "expired" };
    }

    console.info("[RevenueCatWebhook] Ignored event type", {
      profileId: profile._id,
      eventType: args.type,
      accessType: mappedProduct,
    });
    return { applied: false, reason: "ignored_event_type" };
  },
});
