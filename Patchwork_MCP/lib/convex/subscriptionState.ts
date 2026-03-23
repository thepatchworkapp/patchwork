export type TaskerSubscriptionPlan = "none" | "tasker" | "basic" | "premium";
export type TaskerSubscriptionAccessType = "weekly" | "lifetime";
export type TaskerSubscriptionStatus =
  | "inactive"
  | "active"
  | "cancel_at_period_end"
  | "expired";

type TaskerSubscriptionFields = {
  subscriptionPlan: TaskerSubscriptionPlan;
  subscriptionAccessType?: TaskerSubscriptionAccessType;
  subscriptionStatus?: TaskerSubscriptionStatus;
  subscriptionEndsAt?: number;
  ghostMode: boolean;
};

export const DEFAULT_SUBSCRIPTION_TERM_MS = 7 * 24 * 60 * 60 * 1000;
export const LEGACY_MONTHLY_SUBSCRIPTION_TERM_MS = 30 * 24 * 60 * 60 * 1000;

export function getDefaultSubscriptionTermMs(
  profile: Pick<TaskerSubscriptionFields, "subscriptionPlan" | "subscriptionAccessType">,
): number {
  if (profile.subscriptionAccessType === "weekly" || profile.subscriptionPlan === "tasker") {
    return DEFAULT_SUBSCRIPTION_TERM_MS;
  }

  return LEGACY_MONTHLY_SUBSCRIPTION_TERM_MS;
}

export function getEffectiveSubscriptionStatus(
  profile: TaskerSubscriptionFields,
  now = Date.now(),
): TaskerSubscriptionStatus {
  if (profile.subscriptionPlan === "none") {
    return "inactive";
  }

  if (profile.subscriptionEndsAt !== undefined && profile.subscriptionEndsAt <= now) {
    return "expired";
  }

  return profile.subscriptionStatus ?? "active";
}

export function hasActiveSubscription(
  profile: TaskerSubscriptionFields,
  now = Date.now(),
): boolean {
  const status = getEffectiveSubscriptionStatus(profile, now);
  return status === "active" || status === "cancel_at_period_end";
}

export function getEffectiveSubscriptionPlan(
  profile: TaskerSubscriptionFields,
  now = Date.now(),
): TaskerSubscriptionPlan {
  return hasActiveSubscription(profile, now) ? profile.subscriptionPlan : "none";
}

export function getEffectiveGhostMode(
  profile: TaskerSubscriptionFields,
  now = Date.now(),
): boolean {
  if (!hasActiveSubscription(profile, now)) {
    return true;
  }

  return profile.ghostMode;
}
