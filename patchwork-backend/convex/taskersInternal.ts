import { internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { getDefaultSubscriptionTermMs } from "../lib/convex/subscriptionState";

const MAX_SCHEDULER_DELAY_MS = 2_147_483_647;
const PATCHWORK_APP_ID = "app6be2ab0fb8";
const PATCHWORK_ANNUAL_PRODUCT_ID = "ltd.ddga.patchwork.tasker.subscription.yearly";
const PATCHWORK_LIFETIME_PRODUCT_ID = "ltd.ddga.patchwork.tasker.lifetime";
const PATCHWORK_LEGACY_WEEKLY_PRODUCT_ID = "ltd.ddga.patchwork.tasker.weekly";

type RevenueCatAccessType = "subscription" | "lifetime";

function mapRevenueCatProduct(productId: string | undefined): RevenueCatAccessType | "legacy_weekly" | null {
  if (!productId) {
    return null;
  }

  if (productId === PATCHWORK_ANNUAL_PRODUCT_ID) {
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

async function loadTaskerProfileForRevenueCatUsers(
  ctx: any,
  candidateIds: string[],
) {
  for (const candidateId of candidateIds) {
    if (!candidateId || candidateId.startsWith("$RCAnonymousID:")) {
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
      subscriptionStatus: "expired",
      ghostMode: true,
      updatedAt: Date.now(),
    });
  },
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
    if (args.appId && args.appId !== PATCHWORK_APP_ID) {
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
      await scheduleTermEndExpiration(ctx, profile._id, endsAt);
      console.info("[RevenueCatWebhook] Scheduled subscription cancellation", {
        profileId: profile._id,
        endsAt,
      });
      return { applied: true, reason: "cancellation_scheduled" };
    }

    if (args.type === "EXPIRATION" || (args.type === "CANCELLATION" && mappedProduct === "lifetime")) {
      updates.subscriptionStatus = "expired";
      updates.subscriptionEndsAt =
        mappedProduct === "subscription" ? expirationAt ?? profile.subscriptionEndsAt : undefined;
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
