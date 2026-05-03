import { internalAction, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { getDefaultSubscriptionTermMs } from "../lib/convex/subscriptionState";
import {
  dedupeRevenueCatAppUserIds,
  isRevenueCatAnonymousAppUserId,
  mapRevenueCatProduct,
  PATCHWORK_REVENUECAT_APP_ID,
  REVENUECAT_SUBSCRIBER_API_BASE_URL,
  resolveRevenueCatCustomerState,
  type RevenueCatResolvedCustomerState,
} from "../lib/convex/revenueCat";

const MAX_SCHEDULER_DELAY_MS = 2_147_483_647;

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

async function syncTaskerGeoFromOwningUser(ctx: any, profile: any) {
  const user = await ctx.db.get(profile.userId);
  const coordinates = user?.location?.coordinates;
  if (!user || !coordinates) {
    return;
  }

  await ctx.runMutation(internal.location.syncTaskerGeo, {
    userId: user._id,
    lat: coordinates.lat,
    lng: coordinates.lng,
  });
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
      effectiveStatus: resolvedCustomer.resolved.effectiveStatus,
      subscriptionEndsAt: resolvedCustomer.resolved.subscriptionEndsAt ?? null,
      lastKnownAccessType: resolvedCustomer.resolved.lastKnownAccessType,
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
    effectiveStatus: revenueCatSubscriptionStatusValidator(),
    subscriptionEndsAt: v.optional(v.union(v.number(), v.null())),
    lastKnownAccessType: v.optional(revenueCatAccessTypeValidator()),
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
      await ctx.db.patch(profile._id, updates);
      await syncTaskerGeoFromOwningUser(ctx, profile);

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
      updates.subscriptionStatus = "expired";
      updates.subscriptionEndsAt =
        args.lastKnownAccessType === "subscription" ? args.subscriptionEndsAt ?? profile.subscriptionEndsAt : undefined;
      updates.ghostMode = true;
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
      updates.subscriptionStatus = "inactive";
      updates.subscriptionEndsAt = undefined;
      updates.ghostMode = true;
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
    if (mappedProduct === "legacy_weekly") {
      console.info("[RevenueCatWebhook] Ignoring legacy weekly product", { productId: args.productId });
      return { applied: false, reason: "legacy_weekly_ignored" };
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
      await ctx.db.patch(profile._id, updates);
      await syncTaskerGeoFromOwningUser(ctx, profile);
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
      await ctx.db.patch(profile._id, updates);
      await syncTaskerGeoFromOwningUser(ctx, profile);
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
