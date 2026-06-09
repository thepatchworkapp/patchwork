import { useEffect, useMemo, useState } from "react";
import { ConvexReactClient, useAction, useMutation, useQuery } from "convex/react";
import { anyApi } from "convex/server";
import { ConvexBetterAuthProvider } from "@convex-dev/better-auth/react";

import { authClient, signOut, useSession } from "./lib/auth";
import { getConvexCloudUrl, getConvexSiteUrl } from "./lib/convexUrls";

import { Badge } from "@cloudflare/kumo/components/badge";
import { Banner } from "@cloudflare/kumo/components/banner";
import { Button } from "@cloudflare/kumo/components/button";
import { ClipboardText } from "@cloudflare/kumo/components/clipboard-text";
import { Collapsible } from "@cloudflare/kumo/components/collapsible";
import { Input } from "@cloudflare/kumo/components/input";
import { Surface } from "@cloudflare/kumo/components/surface";
import { Table } from "@cloudflare/kumo/components/table";
import { Tabs } from "@cloudflare/kumo/components/tabs";
import { CodeBlock } from "@cloudflare/kumo/components/code";

import { AlertTriangle, ArrowRight, BarChart3, Briefcase, Globe, LogOut, MapPin, MessageSquare, Search, ShieldAlert, Star, User } from "lucide-react";

const api = anyApi as any;

function safeEnvValueForUI(value: string | undefined): string {
  // Don't leak backend URLs in deployed builds; keep full detail only in local dev.
  if (import.meta.env.DEV) return value || "(missing)";
  return value ? "configured" : "(missing)";
}

function redactBackendUrls(text: string): string {
  return text.replace(/https?:\/\/[a-z0-9-]+\.convex\.(cloud|site)\b/gi, "<backend-url>");
}

function isProbablyEmail(value: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function EnvMisconfigured({ message }: { message: string }) {
  const cloud = getConvexCloudUrl();
  const site = getConvexSiteUrl();

  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-[1100px] flex-col px-4 py-10">
      <Surface className="pw-card pw-fade-up relative overflow-hidden rounded-[var(--pw-radius)] border border-kumo-fill bg-kumo-base p-6 shadow-[var(--pw-shadow)]">
        <div className="mb-3 flex items-center gap-2">
          <ShieldAlert className="size-5 text-kumo-danger" />
          <h1 className="pw-display text-lg tracking-tight">Patchwork Admin</h1>
          <Badge variant="destructive">misconfigured</Badge>
        </div>
        <p className="text-sm text-kumo-muted">{message}</p>

        <div className="mt-5 grid gap-3 md:grid-cols-2">
          <div className="pw-subcard">
            <div className="pw-mono mb-1 text-xs text-kumo-muted">VITE_CONVEX_URL / PUBLIC_CONVEX_URL</div>
            <div className="pw-mono text-sm break-all text-kumo-strong">{safeEnvValueForUI(cloud)}</div>
          </div>
          <div className="pw-subcard">
            <div className="pw-mono mb-1 text-xs text-kumo-muted">VITE_CONVEX_SITE_URL / PUBLIC_CONVEX_SITE_URL</div>
            <div className="pw-mono text-sm break-all text-kumo-strong">{safeEnvValueForUI(site)}</div>
          </div>
        </div>
      </Surface>
    </div>
  );
}

function LoginCard() {
  const [email, setEmail] = useState("");
  const [stage, setStage] = useState<"email" | "otp">("email");
  const [otp, setOtp] = useState("");
  const [otpRequestedAt, setOtpRequestedAt] = useState<number | null>(null);
  const [status, setStatus] = useState<
    | { kind: "idle" }
    | { kind: "sending" }
    | { kind: "verifying" }
    | { kind: "error"; message: string }
    | { kind: "sent" }
  >({ kind: "idle" });

  // If the user comes back much later, don't strand them on an old OTP screen.
  useEffect(() => {
    if (stage !== "otp" || otpRequestedAt === null) return;
    const ageMs = Date.now() - otpRequestedAt;
    if (ageMs > 15 * 60 * 1000) {
      setStage("email");
      setOtp("");
      setStatus({ kind: "idle" });
      setOtpRequestedAt(null);
    }
  }, [stage, otpRequestedAt]);

  const onSend = async () => {
    const normalized = email.trim().toLowerCase();
    if (!normalized) {
      setStatus({ kind: "error", message: "Enter an email address." });
      return;
    }
    if (!isProbablyEmail(normalized)) {
      setStatus({ kind: "error", message: "Enter a valid email address." });
      return;
    }

    setStatus({ kind: "sending" });
    try {
      await authClient.emailOtp.sendVerificationOtp({
        email: normalized,
        type: "sign-in",
      });
      setStatus({ kind: "sent" });
      setEmail(normalized);
      setStage("otp");
      setOtp("");
      const ts = Date.now();
      setOtpRequestedAt(ts);
    } catch (err) {
      const message = err instanceof Error ? err.message : "Failed to send code.";
      setStatus({ kind: "error", message: redactBackendUrls(message) });
    }
  };

  const onVerify = async () => {
    const normalized = email.trim().toLowerCase();
    const code = otp.trim();
    if (!code) {
      setStatus({ kind: "error", message: "Enter the 6-digit code." });
      return;
    }
    setStatus({ kind: "verifying" });
    try {
      await authClient.signIn.emailOtp({ email: normalized, otp: code });
      setStatus({ kind: "idle" });
    } catch (err) {
      const message = err instanceof Error ? err.message : "Invalid code.";
      setStatus({ kind: "error", message: redactBackendUrls(message) });
    }
  };

  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-[640px] flex-col items-center justify-center px-4 py-10">
      <div className="mb-6 text-center">
        <div className="pw-display text-2xl tracking-tight">Patchwork</div>
      </div>

      <Surface className="pw-card pw-fade-up w-full rounded-[var(--pw-radius)] border border-kumo-fill bg-kumo-base p-6 shadow-[var(--pw-shadow)]">
        <div className="grid gap-3">
          <Input
            label="Admin email"
            placeholder="you@domain.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="email"
            spellCheck={false}
          />

          {stage === "otp" && (
            <Input
              label="Verification code"
              placeholder="6 digits"
              value={otp}
              onChange={(e) => setOtp(e.target.value)}
              inputMode="numeric"
              autoComplete="one-time-code"
              spellCheck={false}
            />
          )}

          {status.kind === "error" && (
            <div className="rounded-xl border border-kumo-danger/30 bg-kumo-danger/5 p-3 text-sm text-kumo-strong">
              {status.message}
            </div>
          )}

          <div className="flex flex-wrap items-center gap-2">
            {stage === "email" ? (
              <Button
                variant="primary"
                onClick={onSend}
                loading={status.kind === "sending"}
                icon={<ArrowRight className="size-4" />}
              >
                Send code
              </Button>
            ) : (
              <>
                <Button
                  variant="primary"
                  onClick={onVerify}
                  loading={status.kind === "verifying"}
                  icon={<ArrowRight className="size-4" />}
                >
                  Verify
                </Button>
                <Button
                  variant="secondary"
                  onClick={() => {
                    setStage("email");
                    setOtp("");
                    setOtpRequestedAt(null);
                    setStatus({ kind: "idle" });
                  }}
                >
                  Back
                </Button>
                <Button variant="ghost" onClick={onSend} loading={status.kind === "sending"}>
                  Resend
                </Button>
              </>
            )}
          </div>
        </div>
      </Surface>
    </div>
  );
}

type ResetDatabaseResult = {
  resetAt: number;
  deletedMessages: number;
  deletedReviews: number;
  deletedJobs: number;
  deletedProposals: number;
  deletedConversations: number;
  deletedJobRequests: number;
  deletedTaskerCategories: number;
  deletedTaskerProfiles: number;
  deletedSeekerProfiles: number;
  deletedFavouriteTaskers?: number;
  deletedReviewAccess: number;
  deletedOtps: number;
  deletedAdminOtps: number;
  deletedUsers: number;
  deletedImageAssets: number;
  deletedFeedbackSubmissions?: number;
  deletedDiscoverCategoryDailyViews?: number;
  deletedDiscoverCategoryUserDailyViews?: number;
  deletedDiscoverCategorySearchDailyTerms?: number;
  deletedUserBlocks: number;
  deletedUserReports: number;
  deletedPushTokens: number;
  deletedTaskerGeoPoints?: number;
  resendEmailCleanupPasses?: number;
  deletedStorageFiles: number;
  missingStorageFiles?: number;
  failedStorageFiles?: number;
  clientStateVersion?: number;
  preservedAdminEmails: string[];
  revenueCatCleanup?: {
    status: "completed" | "partial" | "skipped";
    attemptedCustomers: number;
    deletedCustomers: number;
    missingCustomers: number;
    failedCustomers: number;
    message: string;
  };
  adminUser?: AdminUserReseedStatus;
  reviewAccess?: ReviewAccessStatus;
};

type AdminUserReseedStatus = {
  email?: string;
  appUserId?: string;
  created?: boolean;
  updatedAt?: number;
};

const RESET_CONFIRM_TEXT = "RESET PATCHWORK";

function ResetCountTile({ label, value }: { label: string; value: number | undefined }) {
  return (
    <div className="pw-microcard">
      <div className="pw-mono text-lg text-kumo-strong">{(value ?? 0).toLocaleString()}</div>
      <div className="mt-1 text-xs text-kumo-muted">{label}</div>
    </div>
  );
}

function ResetResultSummary({ result }: { result: ResetDatabaseResult }) {
  const countTiles = [
    ["Users", result.deletedUsers],
    ["Jobs", result.deletedJobs],
    ["Messages", result.deletedMessages],
    ["Proposals", result.deletedProposals],
    ["Conversations", result.deletedConversations],
    ["Job requests", result.deletedJobRequests],
    ["Tasker profiles", result.deletedTaskerProfiles],
    ["Seeker profiles", result.deletedSeekerProfiles],
    ["Favourite taskers", result.deletedFavouriteTaskers],
    ["Reviews", result.deletedReviews],
    ["Review access", result.deletedReviewAccess],
    ["Tasker categories", result.deletedTaskerCategories],
    ["Feedback", result.deletedFeedbackSubmissions],
    ["Category analytics", result.deletedDiscoverCategoryDailyViews],
    ["Category analytics dedupe", result.deletedDiscoverCategoryUserDailyViews],
    ["Search analytics", result.deletedDiscoverCategorySearchDailyTerms],
    ["User blocks", result.deletedUserBlocks],
    ["User reports", result.deletedUserReports],
    ["Push tokens", result.deletedPushTokens],
    ["Tasker geo points", result.deletedTaskerGeoPoints],
    ["Image assets", result.deletedImageAssets],
    ["Storage files", result.deletedStorageFiles],
    ["Missing storage files", result.missingStorageFiles],
    ["Failed storage files", result.failedStorageFiles],
    ["Client state version", result.clientStateVersion],
    ["User OTPs", result.deletedOtps],
    ["Admin OTPs", result.deletedAdminOtps],
    ["Resend cleanup passes", result.resendEmailCleanupPasses],
  ] as const;

  return (
    <div className="mt-4 grid gap-4">
      <div className="pw-subcard">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <div className="text-sm font-semibold text-kumo-strong">Reset result</div>
            <div className="text-xs text-kumo-muted">{formatDate(result.resetAt)}</div>
          </div>
          <Badge variant="outline">production backend</Badge>
        </div>

        <div className="mt-3 grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
          {countTiles.map(([label, value]) => (
            <ResetCountTile key={label} label={label} value={value} />
          ))}
        </div>
      </div>

      <div className="grid gap-3 lg:grid-cols-3">
        <div className="pw-subcard">
          <div className="text-xs font-semibold uppercase tracking-wide text-kumo-muted">Preserved</div>
          <div className="mt-2 text-sm text-kumo-strong">Admin auth records and configured admin emails.</div>
          <div className="mt-2 flex flex-wrap gap-1">
            {result.preservedAdminEmails.length ? (
              result.preservedAdminEmails.map((email) => (
                <Badge key={email} variant="outline">
                  {email}
                </Badge>
              ))
            ) : (
              <span className="text-xs text-kumo-muted">No preserved admin emails reported.</span>
            )}
          </div>
        </div>

        <div className="pw-subcard">
          <div className="text-xs font-semibold uppercase tracking-wide text-kumo-muted">Deleted</div>
          <div className="mt-2 text-sm text-kumo-strong">
            Non-admin users, marketplace records, conversations, reports, OTPs, image assets, and storage files.
            Discover analytics buckets, tasker geo index entries, and Resend OTP email history are reset with application data.
          </div>
          <div className="mt-2 text-xs text-kumo-muted">
            Component cleanup: {(result.deletedTaskerGeoPoints ?? 0).toLocaleString()} tasker geo point(s) removed;{" "}
            {(result.resendEmailCleanupPasses ?? 0).toLocaleString()} Resend cleanup pass(es) ran.
          </div>
          {result.revenueCatCleanup && (
            <div className="mt-2 text-xs text-kumo-muted">
              RevenueCat: {result.revenueCatCleanup.deletedCustomers.toLocaleString()} deleted,{" "}
              {result.revenueCatCleanup.missingCustomers.toLocaleString()} missing,{" "}
              {result.revenueCatCleanup.failedCustomers.toLocaleString()} failed.
            </div>
          )}
        </div>

        <div className="pw-subcard">
          <div className="text-xs font-semibold uppercase tracking-wide text-kumo-muted">Reseeded</div>
          <div className="mt-2 grid gap-2 text-sm text-kumo-strong">
            <div>
              Admin user {result.adminUser ? `${result.adminUser.created ? "created" : "updated"}.` : "was not reported by the reset action."}
            </div>
            <div>
              Apple reviewer access {result.reviewAccess ? "was reseeded by the reset action." : "was not reported by the reset action."}
            </div>
          </div>
          <div className="mt-2 grid gap-1 text-xs text-kumo-muted">
            {result.adminUser && (
              <div>
                {result.adminUser.email ?? "Admin"} - {formatDate(result.adminUser.updatedAt)}
              </div>
            )}
            {result.reviewAccess && (
              <div>
                {result.reviewAccess.email} - {result.reviewAccess.enabled ? "enabled" : "disabled"} -{" "}
                {formatDate(result.reviewAccess.updatedAt)}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function AdminMaintenanceCard() {
  const resetDatabase = useAction(api.admin.resetDatabaseAndRevenueCat);
  const reseedReviewerAccounts = useMutation(api.admin.reseedReviewerAccounts);
  const reseedAdminUser = useMutation(api.admin.reseedAdminUser);
  const [isResetting, setIsResetting] = useState(false);
  const [isReseeding, setIsReseeding] = useState(false);
  const [isReseedingAdmin, setIsReseedingAdmin] = useState(false);
  const [showResetConfirm, setShowResetConfirm] = useState(false);
  const [resetConfirmText, setResetConfirmText] = useState("");
  const [resetResult, setResetResult] = useState<ResetDatabaseResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const onReset = async () => {
    if (resetConfirmText.trim() !== RESET_CONFIRM_TEXT) {
      setError(`Type ${RESET_CONFIRM_TEXT} to confirm the production reset.`);
      return;
    }

    setIsResetting(true);
    setError(null);
    setNotice(null);
    setResetResult(null);
    try {
      const result = (await resetDatabase({})) as ResetDatabaseResult;
      setResetResult(result);
      setShowResetConfirm(false);
      setResetConfirmText("");
      let nextNotice = `Reset completed at ${formatDate(result.resetAt)}. Deleted ${result.deletedUsers} users, ${result.deletedJobs} jobs, ${result.deletedMessages} messages, ${result.deletedPushTokens} push tokens, ${result.deletedImageAssets} image assets, and ${result.deletedStorageFiles} storage files. Cleaned ${(result.deletedTaskerGeoPoints ?? 0).toLocaleString()} tasker geo point(s), ran ${(result.resendEmailCleanupPasses ?? 0).toLocaleString()} Resend cleanup pass(es), and bumped client state to ${(result.clientStateVersion ?? 0).toLocaleString()}.`;
      if (result.failedStorageFiles && result.failedStorageFiles > 0) {
        nextNotice += ` ${result.failedStorageFiles} storage file(s) could not be deleted; check backend logs.`;
      }
      if (result.missingStorageFiles && result.missingStorageFiles > 0) {
        nextNotice += ` ${result.missingStorageFiles} stale storage reference(s) were already gone.`;
      }

      if (result.revenueCatCleanup) {
        nextNotice += ` ${result.revenueCatCleanup.message}`;

        if (result.revenueCatCleanup.status !== "completed") {
          setError(
            result.revenueCatCleanup.status === "skipped"
              ? result.revenueCatCleanup.message
              : `Database reset succeeded, but RevenueCat cleanup was incomplete. ${result.revenueCatCleanup.message}`
          );
        }
      }

      if (result.reviewAccess) {
        nextNotice += ` Apple reviewer accounts were reseeded at ${formatDate(result.reviewAccess.updatedAt)} and review access is ${result.reviewAccess.enabled ? "enabled" : "disabled"}.`;
      } else {
        setIsReseeding(true);
        try {
          const reviewResult = (await reseedReviewerAccounts({})) as ReviewAccessStatus;
          nextNotice += ` Apple reviewer accounts were reseeded at ${formatDate(reviewResult.updatedAt)} and review access is ${reviewResult.enabled ? "enabled" : "disabled"}.`;
        } catch (reseedError) {
          nextNotice += " Reviewer accounts were not reseeded automatically.";
          setError(
            reseedError instanceof Error
              ? `Database reset succeeded, but reseeding Apple reviewer accounts failed: ${redactBackendUrls(reseedError.message)}`
              : "Database reset succeeded, but reseeding Apple reviewer accounts failed."
          );
        } finally {
          setIsReseeding(false);
        }
      }

      setNotice(nextNotice);
    } catch (err) {
      setError(err instanceof Error ? redactBackendUrls(err.message) : "Failed to reset database.");
    } finally {
      setIsResetting(false);
    }
  };

  const onReseed = async () => {
    setIsReseeding(true);
    setError(null);
    setNotice(null);
    try {
      const result = (await reseedReviewerAccounts({})) as ReviewAccessStatus;
      setNotice(
        `Reviewer accounts reseeded at ${formatDate(result.updatedAt)} and review access is ${result.enabled ? "enabled" : "disabled"}.`
      );
    } catch (err) {
      setError(err instanceof Error ? redactBackendUrls(err.message) : "Failed to reseed reviewer accounts.");
    } finally {
      setIsReseeding(false);
    }
  };

  const onReseedAdmin = async () => {
    setIsReseedingAdmin(true);
    setError(null);
    setNotice(null);
    try {
      const result = (await reseedAdminUser({})) as AdminUserReseedStatus;
      const email = result.email ? ` for ${result.email}` : "";
      const mode = result.created ? "created" : "updated";
      const when = result.updatedAt ? ` at ${formatDate(result.updatedAt)}` : "";
      setNotice(`Admin user ${mode}${email}${when}.`);
    } catch (err) {
      setError(
        err instanceof Error
          ? `Admin user reseed endpoint api.admin.reseedAdminUser is not available or failed: ${redactBackendUrls(err.message)}`
          : "Admin user reseed endpoint api.admin.reseedAdminUser is not available or failed."
      );
    } finally {
      setIsReseedingAdmin(false);
    }
  };

  return (
    <Surface className="pw-card pw-fade-up rounded-[var(--pw-radius)] border border-kumo-danger/25 bg-kumo-base p-5 shadow-[var(--pw-shadow)]">
      <div className="flex flex-wrap items-start gap-3">
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <div className="pw-display text-base tracking-tight">Admin Tools</div>
            <Badge variant="outline">production</Badge>
          </div>
          <div className="mt-1 text-sm text-kumo-muted">
            Database reset is destructive and targets the production backend. Admin auth records are preserved, application data is deleted, RevenueCat customers are cleaned up when required, and Apple reviewer access is reseeded by the reset action.
          </div>
        </div>
      </div>

      <div className="mt-4 flex flex-wrap gap-2">
        <Button
          variant="destructive"
          onClick={() => {
            setShowResetConfirm(true);
            setError(null);
          }}
          disabled={isResetting || isReseeding || isReseedingAdmin}
        >
          {isResetting ? "Resetting..." : "Reset database"}
        </Button>
        <Button variant="secondary" onClick={onReseed} disabled={isResetting || isReseeding || isReseedingAdmin}>
          {isReseeding ? "Reseeding..." : "Reseed Apple reviewer accounts"}
        </Button>
        <Button variant="secondary" onClick={onReseedAdmin} disabled={isResetting || isReseeding || isReseedingAdmin}>
          {isReseedingAdmin ? "Reseeding admin..." : "Reseed admin user"}
        </Button>
      </div>

      {showResetConfirm && (
        <div className="mt-4 rounded-2xl border border-kumo-danger/35 bg-kumo-danger/5 p-4">
          <div className="flex items-start gap-3">
            <AlertTriangle className="mt-0.5 size-5 shrink-0 text-kumo-danger" />
            <div className="min-w-0 flex-1">
              <div className="text-sm font-semibold text-kumo-strong">Confirm production reset</div>
              <div className="mt-1 text-sm text-kumo-muted">
                This preserves configured admin auth records and deletes/reseeds production data: users, jobs, messages,
                favourites, reports, uploads, storage files, RevenueCat customers, OTPs, and Apple reviewer access.
              </div>
              <div className="mt-3 grid gap-2 sm:grid-cols-[1fr_auto_auto]">
                <Input
                  label={`Type ${RESET_CONFIRM_TEXT}`}
                  value={resetConfirmText}
                  onChange={(event) => setResetConfirmText(event.target.value)}
                  spellCheck={false}
                  autoComplete="off"
                />
                <div className="flex items-end">
                  <Button
                    variant="destructive"
                    onClick={onReset}
                    disabled={isResetting || resetConfirmText.trim() !== RESET_CONFIRM_TEXT}
                  >
                    {isResetting ? "Resetting..." : "Confirm reset"}
                  </Button>
                </div>
                <div className="flex items-end">
                  <Button
                    variant="ghost"
                    onClick={() => {
                      setShowResetConfirm(false);
                      setResetConfirmText("");
                    }}
                    disabled={isResetting}
                  >
                    Cancel
                  </Button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {notice && (
        <div className="mt-4">
          <Banner text={notice} />
        </div>
      )}

      {error && (
        <div className="mt-4">
          <Banner variant="error" icon={<ShieldAlert className="size-4" />} text={error} />
        </div>
      )}

      {resetResult && <ResetResultSummary result={resetResult} />}
    </Surface>
  );
}

type UserRow = {
  _id: string;
  email?: string | null;
  name?: string | null;
  photo?: string | null;
  photoAssetId?: string | null;
  photoImage?: any;
  photoUrl?: string | null;
  location?: any;
  roles?: any;
  createdAt?: number | string | null;
  updatedAt?: number | string | null;
};

function formatDate(value: unknown): string {
  if (typeof value === "number") return new Date(value).toLocaleString();
  if (typeof value === "string") {
    const n = Number(value);
    if (!Number.isNaN(n)) return new Date(n).toLocaleString();
    return value;
  }
  return "—";
}

function formatConfiguredLocation(location: {
  city?: string | null;
  province?: string | null;
}): string {
  const city = typeof location.city === "string" ? location.city.trim() : "";
  const province = typeof location.province === "string" ? location.province.trim() : "";
  const parts = [city, province].filter(Boolean);
  return parts.length > 0 ? parts.join(", ") : "—";
}

function formatCoordinates(coordinates: unknown): string {
  if (!coordinates || typeof coordinates !== "object") return "—";
  const { lat, lng } = coordinates as { lat?: unknown; lng?: unknown };
  if (typeof lat !== "number" || typeof lng !== "number") return "—";
  return `${lat.toFixed(6)}, ${lng.toFixed(6)}`;
}

function formatCheckedInCoordinates(coordinates: unknown, checkedInAt: unknown): string {
  const formattedCoordinates = formatCoordinates(coordinates);
  if (formattedCoordinates === "—") return "—";
  const formattedDate = formatDate(checkedInAt);
  return formattedDate === "—" ? formattedCoordinates : `${formattedCoordinates} - ${formattedDate}`;
}

function formatTaskerDiscoverability(taskerProfile: any | null): string {
  if (!taskerProfile) return "—";
  if (!taskerProfile.location || typeof taskerProfile.locationCheckedInAt !== "number") {
    return "Not geographically discoverable";
  }
  return formatCheckedInCoordinates(taskerProfile.location, taskerProfile.locationCheckedInAt);
}

type TaskerSubscriptionAdmin = {
  subscriptionPlan?: string | null;
  effectiveSubscriptionPlan?: string | null;
  subscriptionAccessType?: string | null;
  subscriptionTier?: string | null;
  effectiveSubscriptionTier?: string | null;
  subscriptionActiveAccessTypes?: string[];
  subscriptionStatus?: string | null;
  storedSubscriptionStatus?: string | null;
  subscriptionEndsAt?: number | null;
  hasActiveSubscription?: boolean;
  premiumPin?: {
    code?: string | null;
    searchStatus?: "active" | "inactive" | string;
    inactiveReason?: string | null;
  } | null;
};

function formatSubscriptionValue(value: unknown): string {
  if (typeof value !== "string" || value.trim().length === 0) return "—";
  return value.replaceAll("_", " ");
}

function formatSubscriptionDate(value: unknown): string {
  return value === null || value === undefined ? "—" : formatDate(value);
}

function formatActiveAccessTypes(value: unknown): string {
  if (!Array.isArray(value) || value.length === 0) return "—";
  return value
    .filter((item): item is string => typeof item === "string" && item.trim().length > 0)
    .map(formatSubscriptionValue)
    .join(", ") || "—";
}

function getTaskerSubscriptionAdmin(taskerProfile: any | null): TaskerSubscriptionAdmin | null {
  if (!taskerProfile) return null;
  const summary = taskerProfile.subscriptionAdmin as TaskerSubscriptionAdmin | undefined;
  if (summary) return summary;

  const storedPin = typeof taskerProfile.premiumPin === "string" ? taskerProfile.premiumPin : null;
  return {
    subscriptionPlan: taskerProfile.subscriptionPlan ?? null,
    effectiveSubscriptionPlan: taskerProfile.subscriptionPlan ?? null,
    subscriptionAccessType: taskerProfile.subscriptionAccessType ?? null,
    subscriptionTier: taskerProfile.subscriptionTier ?? null,
    effectiveSubscriptionTier: taskerProfile.subscriptionTier ?? null,
    subscriptionActiveAccessTypes: Array.isArray(taskerProfile.subscriptionActiveAccessTypes)
      ? taskerProfile.subscriptionActiveAccessTypes
      : [],
    subscriptionStatus: taskerProfile.subscriptionStatus ?? null,
    storedSubscriptionStatus: taskerProfile.subscriptionStatus ?? null,
    subscriptionEndsAt: taskerProfile.subscriptionEndsAt ?? null,
    hasActiveSubscription: taskerProfile.subscriptionPlan === "tasker",
    premiumPin: storedPin
      ? {
          code: storedPin,
          searchStatus: "inactive",
          inactiveReason: "unknown",
        }
      : null,
  };
}

function formatPremiumPinSearchStatus(summary: TaskerSubscriptionAdmin | null): string {
  const pin = summary?.premiumPin;
  if (!pin?.code) return "No stored pin";
  if (pin.searchStatus === "active") return "Search active";
  return `Search inactive${pin.inactiveReason ? `: ${formatSubscriptionValue(pin.inactiveReason)}` : ""}`;
}

type AdminUserDetail = {
  user: any;
  userPhotoUrl?: string | null;
  userPhotoImage?: any | null;
  seekerProfile: any | null;
  taskerProfile: any | null;
  jobsAsSeeker: any[];
  jobsAsTasker: any[];
  reviewsGiven: any[];
  reviewsReceived: any[];
  feedbackSubmissions: FeedbackSubmissionRow[];
  blocksCreated: ModerationBlockRow[];
  blocksReceived: ModerationBlockRow[];
  reportsSubmitted: ModerationReportRow[];
  reportsReceived: ModerationReportRow[];
};

type FeedbackSubmissionRow = {
  _id: string;
  userId: string;
  message: string;
  createdAt?: number | null;
  updatedAt?: number | null;
  userName?: string | null;
  userEmail?: string | null;
};

type ModerationBlockRow = {
  _id: string;
  blockerId: string;
  blockerName?: string | null;
  blockerEmail?: string | null;
  blockedId: string;
  blockedUserName?: string | null;
  blockedUserEmail?: string | null;
  conversationId?: string | null;
  createdAt?: number | null;
  updatedAt?: number | null;
};

type ModerationReportRow = {
  _id: string;
  reporterId: string;
  reporterName?: string | null;
  reporterEmail?: string | null;
  reportedUserId: string;
  reportedUserName?: string | null;
  reportedUserEmail?: string | null;
  conversationId?: string | null;
  reason: string;
  action: "report" | "block_and_report";
  status: "open" | "reviewing" | "resolved" | "dismissed";
  createdAt?: number | null;
  updatedAt?: number | null;
};

type DiscoverAnalytics = {
  generatedAt: number;
  categories: DiscoverCategoryAnalyticsRow[];
  searchTerms: DiscoverCategorySearchAnalyticsRow[];
};

type DiscoverCategoryAnalyticsRow = {
  categoryId: string;
  categoryName: string;
  categorySlug: string;
  oneDayCount: number;
  sevenDayCount: number;
  sevenDayAverage: number;
  thirtyDayCount: number;
  thirtyDayAverage: number;
  oneDayUniqueUsers: number;
  sevenDayUniqueUsers: number;
  thirtyDayUniqueUsers: number;
};

type DiscoverCategorySearchAnalyticsRow = {
  displayTerm: string;
  normalizedTerm: string;
  oneDayCount: number;
  sevenDayCount: number;
  thirtyDayCount: number;
  lastSeenDayKey: string;
};

type ReviewAccessStatus = {
  allowedEmails?: string[];
  email: string;
  enabled: boolean;
  betterAuthUserId?: string | null;
  appUserId?: string | null;
  lastEnabledAt?: number | null;
  lastDisabledAt?: number | null;
  updatedAt?: number | null;
};

function shortId(id: string, start = 10, end = 6): string {
  if (!id) return "—";
  if (id.length <= start + end + 3) return id;
  return `${id.slice(0, start)}…${id.slice(-end)}`;
}

function formatMoneyCents(cents: unknown): string {
  if (typeof cents !== "number" || !Number.isFinite(cents)) return "—";
  return (cents / 100).toLocaleString(undefined, { style: "currency", currency: "USD" });
}

function formatCount(value: unknown): string {
  return typeof value === "number" && Number.isFinite(value) ? value.toLocaleString() : "—";
}

function formatAverage(value: unknown): string {
  return typeof value === "number" && Number.isFinite(value)
    ? value.toLocaleString(undefined, { maximumFractionDigits: 1 })
    : "—";
}

function formatIsoDate(value: unknown): string {
  if (typeof value !== "string") return "—";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleString();
}

function statusBadge(status: unknown): { label: string; variant: "primary" | "secondary" | "outline" | "destructive" } {
  const s = typeof status === "string" ? status : "unknown";
  switch (s) {
    case "completed":
      return { label: "completed", variant: "secondary" };
    case "cancelled":
      return { label: "cancelled", variant: "destructive" };
    case "disputed":
      return { label: "disputed", variant: "destructive" };
    case "in_progress":
      return { label: "in progress", variant: "primary" };
    case "pending":
      return { label: "pending", variant: "outline" };
    default:
      return { label: s, variant: "outline" };
  }
}

function EmptyHint({ title, body }: { title: string; body: string }) {
  return (
    <div className="pw-subcard">
      <div className="pw-display text-sm tracking-tight text-kumo-strong">{title}</div>
      <div className="mt-1 text-sm leading-relaxed text-kumo-muted">{body}</div>
    </div>
  );
}

function DiscoverAnalyticsCard({ analytics }: { analytics: DiscoverAnalytics | undefined }) {
  const categoryCount = analytics?.categories.length ?? 0;
  const searchTermCount = analytics?.searchTerms.length ?? 0;

  return (
    <Surface className="pw-card pw-fade-up mb-6 rounded-[var(--pw-radius)] border border-kumo-fill bg-kumo-base p-5 shadow-[var(--pw-shadow)]">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <BarChart3 className="size-4 text-kumo-muted" />
          <div className="pw-display text-base tracking-tight">Discover analytics</div>
          <Badge variant="outline" className="pw-badge-tight">
            {categoryCount.toLocaleString()} categories
          </Badge>
        </div>
        {analytics && (
          <div className="pw-mono text-xs text-kumo-muted">
            Updated {formatDate(analytics.generatedAt)}
          </div>
        )}
      </div>

      {!analytics ? (
        <EmptyHint title="Loading Discover analytics…" body="Fetching category selections and submitted category searches from Convex." />
      ) : categoryCount === 0 && searchTermCount === 0 ? (
        <EmptyHint title="No Discover analytics yet" body="Category selections and submitted searches will appear here once seekers use Discover." />
      ) : (
        <div className="grid gap-5 xl:grid-cols-[1.15fr_0.85fr]">
          <div>
            <div className="mb-2 flex items-center gap-2">
              <div className="text-sm font-semibold text-kumo-strong">Category selections</div>
              <Badge variant="outline" className="pw-badge-tight">
                1 / 7 / 30 days
              </Badge>
            </div>
            {categoryCount === 0 ? (
              <EmptyHint title="No category selections" body="No category has been selected in the current reporting window." />
            ) : (
              <div className="pw-inset">
                <div className="max-h-[36dvh] overflow-auto">
                  <Table layout="fixed" className="w-full text-[13px]">
                    <Table.Header className="pw-inset-header">
                      <Table.Row>
                        <Table.Head className="pw-th w-[30%]">Category</Table.Head>
                        <Table.Head className="pw-th w-[10%] text-right">1d</Table.Head>
                        <Table.Head className="pw-th w-[12%] text-right">7d</Table.Head>
                        <Table.Head className="pw-th w-[13%] text-right">7d/day</Table.Head>
                        <Table.Head className="pw-th w-[12%] text-right">30d</Table.Head>
                        <Table.Head className="pw-th w-[13%] text-right">30d/day</Table.Head>
                        <Table.Head className="pw-th w-[10%] text-right">Users</Table.Head>
                      </Table.Row>
                    </Table.Header>
                    <Table.Body className="divide-y divide-kumo-fill/80">
                      {analytics.categories.map((row) => (
                        <Table.Row key={row.categoryId}>
                          <Table.Cell className="pw-td">
                            <div className="truncate text-sm font-semibold text-kumo-strong">{row.categoryName}</div>
                            <div className="pw-mono truncate text-[11px] text-kumo-muted">{row.categorySlug}</div>
                          </Table.Cell>
                          <Table.Cell className="pw-td text-right">{formatCount(row.oneDayCount)}</Table.Cell>
                          <Table.Cell className="pw-td text-right">{formatCount(row.sevenDayCount)}</Table.Cell>
                          <Table.Cell className="pw-td text-right">{formatAverage(row.sevenDayAverage)}</Table.Cell>
                          <Table.Cell className="pw-td text-right">{formatCount(row.thirtyDayCount)}</Table.Cell>
                          <Table.Cell className="pw-td text-right">{formatAverage(row.thirtyDayAverage)}</Table.Cell>
                          <Table.Cell className="pw-td text-right">{formatCount(row.thirtyDayUniqueUsers)}</Table.Cell>
                        </Table.Row>
                      ))}
                    </Table.Body>
                  </Table>
                </div>
              </div>
            )}
          </div>

          <div>
            <div className="mb-2 flex items-center gap-2">
              <Search className="size-3.5 text-kumo-muted" />
              <div className="text-sm font-semibold text-kumo-strong">Submitted searches</div>
            </div>
            {searchTermCount === 0 ? (
              <EmptyHint title="No submitted searches" body="Explicit category search submissions will appear here." />
            ) : (
              <div className="pw-inset">
                <div className="max-h-[36dvh] overflow-auto">
                  <Table layout="fixed" className="w-full text-[13px]">
                    <Table.Header className="pw-inset-header">
                      <Table.Row>
                        <Table.Head className="pw-th w-[42%]">Term</Table.Head>
                        <Table.Head className="pw-th w-[12%] text-right">1d</Table.Head>
                        <Table.Head className="pw-th w-[12%] text-right">7d</Table.Head>
                        <Table.Head className="pw-th w-[12%] text-right">30d</Table.Head>
                        <Table.Head className="pw-th w-[22%]">Last seen</Table.Head>
                      </Table.Row>
                    </Table.Header>
                    <Table.Body className="divide-y divide-kumo-fill/80">
                      {analytics.searchTerms.map((row) => (
                        <Table.Row key={row.normalizedTerm}>
                          <Table.Cell className="pw-td">
                            <div className="truncate text-sm font-semibold text-kumo-strong">{row.displayTerm}</div>
                            <div className="pw-mono truncate text-[11px] text-kumo-muted">{row.normalizedTerm}</div>
                          </Table.Cell>
                          <Table.Cell className="pw-td text-right">{formatCount(row.oneDayCount)}</Table.Cell>
                          <Table.Cell className="pw-td text-right">{formatCount(row.sevenDayCount)}</Table.Cell>
                          <Table.Cell className="pw-td text-right">{formatCount(row.thirtyDayCount)}</Table.Cell>
                          <Table.Cell className="pw-td">
                            <span className="pw-mono text-[11px] text-kumo-muted">{row.lastSeenDayKey}</span>
                          </Table.Cell>
                        </Table.Row>
                      ))}
                    </Table.Body>
                  </Table>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </Surface>
  );
}

function TaskerLinksAdminCard({ title, links }: { title: string; links?: string[] | null }) {
  const normalizedLinks = (Array.isArray(links) ? links : []).filter((link) => typeof link === "string" && link.trim());

  return (
    <div className="pw-microcard">
      <div className="mb-2 flex items-center gap-2">
        <Globe className="size-3.5 text-kumo-muted" />
        <div className="pw-mono text-xs text-kumo-muted">{title}</div>
      </div>
      {normalizedLinks.length > 0 ? (
        <div className="space-y-1">
          {normalizedLinks.map((link, index) => {
            const href = externalLinkHref(link);
            return href ? (
              <a
                key={`${title}-${index}-${link}`}
                href={href}
                target="_blank"
                rel="noreferrer"
                className="block truncate text-sm text-kumo-strong underline decoration-kumo-muted/50 underline-offset-2"
              >
                {link}
              </a>
            ) : (
              <div key={`${title}-${index}-${link}`} className="truncate text-sm text-kumo-strong">
                {link}
              </div>
            );
          })}
        </div>
      ) : (
        <div className="text-sm text-kumo-muted">—</div>
      )}
    </div>
  );
}

function externalLinkHref(value: string): string | null {
  const trimmed = value.trim();
  if (!/^https?:\/\//i.test(trimmed)) return null;
  try {
    return new URL(trimmed).toString();
  } catch {
    return null;
  }
}

function avatarInitials(name?: string | null, email?: string | null): string {
  const raw = (name || "").trim() || (email || "").trim();
  if (!raw) return "";
  const parts = raw.split(/[\s@._-]+/g).filter(Boolean);
  const letters = parts
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase())
    .join("");
  return letters || raw.slice(0, 2).toUpperCase();
}

function getPrimaryImageUrl(image: any): string | null {
  const displayUrl = image?.variants?.display?.url;
  if (typeof displayUrl === "string" && displayUrl) return displayUrl;

  const thumbUrl = image?.variants?.thumb?.url;
  if (typeof thumbUrl === "string" && thumbUrl) return thumbUrl;

  const largeUrl = image?.variants?.large?.url;
  if (typeof largeUrl === "string" && largeUrl) return largeUrl;

  return null;
}

function dedupeUrls(urls: Array<string | null | undefined>): string[] {
  const seen = new Set<string>();
  const deduped: string[] = [];

  for (const url of urls) {
    if (typeof url !== "string" || !url || seen.has(url)) continue;
    seen.add(url);
    deduped.push(url);
  }

  return deduped;
}

function getUserRowPhotoUrl(user: UserRow): string | null {
  if (typeof user.photoUrl === "string" && user.photoUrl) return user.photoUrl;
  return getPrimaryImageUrl(user.photoImage);
}

function getUserDetailPhotoUrl(detail: AdminUserDetail): string | null {
  if (typeof detail.userPhotoUrl === "string" && detail.userPhotoUrl) return detail.userPhotoUrl;
  return getPrimaryImageUrl(detail.userPhotoImage);
}

function getCategoryPhotoUrls(category: any): string[] {
  const legacyUrls = Array.isArray(category?.photoUrls)
    ? category.photoUrls.filter((url: unknown): url is string => typeof url === "string" && !!url)
    : [];
  const portfolioUrls = Array.isArray(category?.portfolioImages)
    ? category.portfolioImages
      .map((image: any) => getPrimaryImageUrl(image))
      .filter((url: string | null): url is string => !!url)
    : [];
  return dedupeUrls([...legacyUrls, ...portfolioUrls]);
}

function UserAvatar({
  url,
  name,
  email,
  sizeClassName,
  className,
}: {
  url?: string | null;
  name?: string | null;
  email?: string | null;
  sizeClassName: string;
  className?: string;
}) {
  const [failed, setFailed] = useState(false);
  const initials = avatarInitials(name, email);
  const showImage = !!url && !failed;

  return (
    <div
      className={
        "grid shrink-0 place-items-center overflow-hidden rounded-2xl border border-kumo-fill bg-kumo-base " +
        sizeClassName +
        (className ? " " + className : "")
      }
    >
      {showImage ? (
        <img
          src={url!}
          alt={name ? `${name} avatar` : "User avatar"}
          className="h-full w-full object-cover"
          loading="lazy"
          decoding="async"
          onError={() => setFailed(true)}
        />
      ) : initials ? (
        <div className="pw-display text-xs tracking-tight text-kumo-muted">{initials}</div>
      ) : (
        <User className="size-4 text-kumo-muted" />
      )}
    </div>
  );
}

function AppReviewAccessCard({ status }: { status: ReviewAccessStatus | null | undefined }) {
  const setReviewAccess = useMutation(api.admin.setReviewAccess);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const enabled = !!status?.enabled;
  const allowedEmails = status?.allowedEmails?.length
    ? status.allowedEmails
    : ["review@apple.com", "seeker@apple.com"];

  const onToggle = async () => {
    setIsSaving(true);
    setError(null);
    try {
      await setReviewAccess({ enabled: !enabled });
    } catch (err) {
      setError(err instanceof Error ? redactBackendUrls(err.message) : "Failed to update app review access.");
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <Surface className="pw-card pw-fade-up rounded-[var(--pw-radius)] border border-kumo-fill bg-kumo-base p-5 shadow-[var(--pw-shadow)]">
      <div className="flex flex-wrap items-start gap-3">
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <div className="pw-display text-base tracking-tight">App Review Access</div>
            <Badge variant={enabled ? "secondary" : "outline"} className="pw-badge-tight">
              {enabled ? "enabled" : "disabled"}
            </Badge>
          </div>
          <div className="mt-1 text-sm text-kumo-muted">Reviewer emails</div>
          <div className="mt-2 flex flex-wrap gap-2">
            {allowedEmails.map((email) => (
              <span
                key={email}
                className="pw-mono inline-flex items-center rounded-full border border-kumo-fill bg-kumo-tint px-2.5 py-1 text-xs text-kumo-strong"
              >
                {email}
              </span>
            ))}
          </div>
        </div>

        <Button variant={enabled ? "secondary" : "primary"} onClick={onToggle} disabled={isSaving || status === undefined}>
          {isSaving ? "Saving..." : enabled ? "Disable" : "Enable"}
        </Button>
      </div>

      <div className="mt-4 grid gap-3 md:grid-cols-3">
        <div className="pw-microcard">
          <div className="pw-mono text-xs text-kumo-muted">Last enabled</div>
          <div className="text-sm text-kumo-strong">{formatDate(status?.lastEnabledAt)}</div>
        </div>
        <div className="pw-microcard">
          <div className="pw-mono text-xs text-kumo-muted">Last disabled</div>
          <div className="text-sm text-kumo-strong">{formatDate(status?.lastDisabledAt)}</div>
        </div>
        <div className="pw-microcard">
          <div className="pw-mono text-xs text-kumo-muted">Updated</div>
          <div className="text-sm text-kumo-strong">{formatDate(status?.updatedAt)}</div>
        </div>
      </div>

      <div className="mt-4 grid gap-3 md:grid-cols-2">
        <div>
          <div className="pw-mono mb-1 text-xs text-kumo-muted">Auth user</div>
          <ClipboardText size="sm" text={status?.betterAuthUserId || "Not provisioned"} />
        </div>
        <div>
          <div className="pw-mono mb-1 text-xs text-kumo-muted">App user</div>
          <ClipboardText size="sm" text={status?.appUserId || "Not provisioned"} />
        </div>
      </div>

      {error && (
        <div className="mt-4">
          <Banner variant="error" icon={<ShieldAlert className="size-4" />} text={error} />
        </div>
      )}
    </Surface>
  );
}

function DashboardShell({ email }: { email: string }) {
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [limit, setLimit] = useState(80);
  const reviewAccess = useQuery(api.admin.getReviewAccess, {}) as ReviewAccessStatus | null | undefined;
  const recentFeedback = useQuery(api.admin.listRecentFeedback, { limit: 12 }) as
    | FeedbackSubmissionRow[]
    | undefined;
  const recentReports = useQuery(api.admin.listRecentReports, { limit: 12 }) as
    | ModerationReportRow[]
    | undefined;
  const discoverAnalytics = useQuery(api.admin.getDiscoverAnalytics, { limit: 50 }) as
    | DiscoverAnalytics
    | undefined;

  const data = useQuery(api.admin.listAllUsers, { limit }) as
    | { users: UserRow[]; cursor: string | null }
    | undefined;

  const users = data?.users ?? [];
  const filtered = users.filter((u) => {
    const q = search.trim().toLowerCase();
    if (!q) return true;
    return (
      (u.email || "").toLowerCase().includes(q) ||
      (u.name || "").toLowerCase().includes(q) ||
      (u._id || "").toLowerCase().includes(q)
    );
  });

  const selected = useQuery(
    api.admin.getUserDetail,
    selectedUserId ? { userId: selectedUserId } : "skip"
  ) as AdminUserDetail | null | undefined;

  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-[1440px] flex-col px-4 py-8 md:px-8 md:py-10">
      <Surface className="pw-card pw-fade-up mb-6 flex flex-wrap items-center gap-3 rounded-[var(--pw-radius)] border border-kumo-fill bg-kumo-base/70 p-5 shadow-[var(--pw-shadow)] backdrop-blur">
        <div className="min-w-0">
          <div className="pw-display text-xl tracking-tight">Patchwork Admin</div>
          <div className="mt-0.5 text-sm text-kumo-muted">
            Signed in as <span className="pw-mono text-kumo-strong">{email}</span>
          </div>
        </div>

        <div className="ml-auto flex items-center gap-2">
          <Button
            variant="secondary"
            icon={<LogOut className="size-4" />}
            onClick={() => signOut()}
          >
            Sign out
          </Button>
        </div>
      </Surface>

      <div className="mb-6">
        <AppReviewAccessCard status={reviewAccess} />
      </div>

      <div className="mb-6">
        <AdminMaintenanceCard />
      </div>

      <DiscoverAnalyticsCard analytics={discoverAnalytics} />

      <Surface className="pw-card pw-fade-up mb-6 rounded-[var(--pw-radius)] border border-kumo-fill bg-kumo-base p-5 shadow-[var(--pw-shadow)]">
        <div className="mb-3 flex items-center gap-2">
          <MessageSquare className="size-4 text-kumo-muted" />
          <div className="pw-display text-base tracking-tight">Recent feedback</div>
          <Badge variant="outline" className="pw-badge-tight">
            {recentFeedback?.length ?? 0}
          </Badge>
        </div>

        {!recentFeedback ? (
          <EmptyHint title="Loading feedback…" body="Fetching the latest user feedback from Convex." />
        ) : recentFeedback.length === 0 ? (
          <EmptyHint title="No feedback yet" body="Feedback submissions will appear here once users send them from the app." />
        ) : (
          <div className="grid gap-3 md:grid-cols-2">
            {recentFeedback.map((item) => (
              <button
                key={item._id}
                type="button"
                className="pw-subcard text-left transition hover:bg-kumo-tint"
                onClick={() => setSelectedUserId(item.userId)}
              >
                <div className="flex items-start gap-3">
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <div className="text-sm font-semibold text-kumo-strong">
                        {item.userName || item.userEmail || shortId(item.userId)}
                      </div>
                      <div className="pw-mono text-[11px] text-kumo-muted">{formatDate(item.createdAt)}</div>
                    </div>
                    {item.userEmail && (
                      <div className="mt-1 text-xs text-kumo-muted">{item.userEmail}</div>
                    )}
                    <div className="mt-2 line-clamp-3 text-sm leading-relaxed text-kumo-default whitespace-pre-wrap">
                      {item.message}
                    </div>
                  </div>
                </div>
              </button>
            ))}
          </div>
        )}
      </Surface>

      <Surface className="pw-card pw-fade-up mb-6 rounded-[var(--pw-radius)] border border-kumo-fill bg-kumo-base p-5 shadow-[var(--pw-shadow)]">
        <div className="mb-3 flex items-center gap-2">
          <ShieldAlert className="size-4 text-kumo-muted" />
          <div className="pw-display text-base tracking-tight">Recent reports</div>
          <Badge variant="outline" className="pw-badge-tight">
            {recentReports?.length ?? 0}
          </Badge>
        </div>

        {!recentReports ? (
          <EmptyHint title="Loading reports…" body="Fetching the latest user reports from Convex." />
        ) : recentReports.length === 0 ? (
          <EmptyHint title="No reports yet" body="User reports will appear here once submitted from chat." />
        ) : (
          <div className="grid gap-3 md:grid-cols-2">
            {recentReports.map((item) => (
              <button
                key={item._id}
                type="button"
                className="pw-subcard text-left transition hover:bg-kumo-tint"
                onClick={() => setSelectedUserId(item.reportedUserId)}
              >
                <div className="flex flex-wrap items-center gap-2">
                  <Badge variant={item.status === "open" ? "destructive" : "outline"} className="pw-badge-tight">
                    {item.status}
                  </Badge>
                  <Badge variant="outline" className="pw-badge-tight">
                    {item.action === "block_and_report" ? "block & report" : "report"}
                  </Badge>
                  <div className="pw-mono text-[11px] text-kumo-muted">{formatDate(item.createdAt)}</div>
                </div>
                <div className="mt-2 text-sm font-semibold text-kumo-strong">
                  {item.reporterName || item.reporterEmail || shortId(item.reporterId)} -&gt;{" "}
                  {item.reportedUserName || item.reportedUserEmail || shortId(item.reportedUserId)}
                </div>
                <div className="mt-2 line-clamp-3 text-sm leading-relaxed text-kumo-default whitespace-pre-wrap">
                  {item.reason}
                </div>
              </button>
            ))}
          </div>
        )}
      </Surface>

      <div className="grid gap-5 lg:grid-cols-[1.1fr_0.9fr]">
        <Surface className="pw-card pw-fade-up rounded-[var(--pw-radius)] border border-kumo-fill bg-kumo-base p-5 shadow-[var(--pw-shadow)]">
          <div className="mb-4 flex flex-wrap items-end gap-3">
            <div className="flex items-center gap-2">
              <div className="pw-display text-base tracking-tight">Users</div>
              <Badge variant="outline" className="pw-badge-tight">
                {filtered.length} loaded
              </Badge>
            </div>
          </div>

          <div className="mb-4 pw-subcard p-4">
            <div className="grid gap-3 sm:grid-cols-[1fr_auto] sm:items-end">
              <div className="grid gap-1">
                <div className="pw-mono text-xs text-kumo-muted">Search</div>
                <Input
                  placeholder="Name, email, or id"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  aria-label="Search users"
                  size="sm"
                  className="w-full sm:min-w-[240px]"
                />
              </div>
              <div className="grid gap-1">
                <div className="pw-mono text-xs text-kumo-muted">Limit</div>
                <Input
                  placeholder="80"
                  value={String(limit)}
                  onChange={(e) => {
                    const n = Number(e.target.value);
                    if (!Number.isFinite(n)) return;
                    setLimit(Math.max(1, Math.min(500, Math.floor(n))));
                  }}
                  inputMode="numeric"
                  aria-label="User limit"
                  size="sm"
                  className="w-full sm:w-[120px]"
                />
              </div>
            </div>
          </div>

          <div className="pw-inset">
            <div className="max-h-[68dvh] overflow-auto">
              <Table layout="fixed" className="w-full text-[13px]">
                <Table.Header className="pw-inset-header">
                  <Table.Row>
                    <Table.Head className="pw-th w-[38%]">User</Table.Head>
                    <Table.Head className="pw-th w-[34%]">Email</Table.Head>
                    <Table.Head className="pw-th w-[14%]">Roles</Table.Head>
                    <Table.Head className="pw-th w-[14%]">Created</Table.Head>
                  </Table.Row>
                </Table.Header>
                <Table.Body className="divide-y divide-kumo-fill/80">
                  {filtered.map((u) => {
                    const selectedRow = u._id === selectedUserId;
                    return (
                      <Table.Row
                        key={u._id}
                        variant={selectedRow ? "selected" : "default"}
                        className={
                          "group cursor-pointer transition-colors " +
                          (selectedRow ? "" : "hover:bg-kumo-tint")
                        }
                        onClick={() => setSelectedUserId(u._id)}
                      >
                        <Table.Cell className="pw-td">
                          <div className="flex items-center gap-3">
                            <UserAvatar
                              url={getUserRowPhotoUrl(u)}
                              name={u.name}
                              email={u.email}
                              sizeClassName="size-8"
                              className={selectedRow ? "ring-2 ring-kumo-brand/20" : "shadow-sm shadow-black/5"}
                            />
                            <div className="min-w-0">
                              <div className="truncate text-sm font-semibold text-kumo-strong">
                                {u.name || "—"}
                              </div>
                              <div className="pw-mono truncate text-[11px] text-kumo-muted">
                                {shortId(u._id)}
                              </div>
                            </div>
                          </div>
                        </Table.Cell>
                        <Table.Cell className="pw-td">
                          <div className="truncate text-sm text-kumo-default">
                            {u.email || "—"}
                          </div>
                        </Table.Cell>
                        <Table.Cell className="pw-td">
                          <div className="flex flex-wrap gap-1">
                            {u.roles?.isSeeker && (
                              <Badge variant="secondary" className="pw-badge-tight">
                                seeker
                              </Badge>
                            )}
                            {u.roles?.isTasker && (
                              <Badge variant="outline" className="pw-badge-tight">
                                tasker
                              </Badge>
                            )}
                            {!u.roles?.isSeeker && !u.roles?.isTasker && (
                              <Badge variant="outline" className="pw-badge-tight">
                                unknown
                              </Badge>
                            )}
                          </div>
                        </Table.Cell>
                        <Table.Cell className="pw-td">
                          <div className="text-[11px] text-kumo-muted">{formatDate(u.createdAt)}</div>
                        </Table.Cell>
                      </Table.Row>
                    );
                  })}
                </Table.Body>
              </Table>
            </div>
          </div>
        </Surface>

        <Surface className="pw-card pw-fade-up rounded-[var(--pw-radius)] border border-kumo-fill bg-kumo-base p-5 shadow-[var(--pw-shadow)]">
          <div className="mb-3 flex items-center justify-between">
            <div className="pw-display text-base tracking-tight">Case file</div>
            {selectedUserId ? (
              <Button variant="ghost" onClick={() => setSelectedUserId(null)}>
                Clear
              </Button>
            ) : (
              <Badge variant="secondary">select</Badge>
            )}
          </div>

          {!selectedUserId ? (
            <EmptyHint
              title="Pick a user"
              body="Select a row on the left to inspect the user’s profiles, jobs, and reviews."
            />
          ) : selected === undefined ? (
            <EmptyHint title="Loading…" body="Fetching the latest snapshot from Convex." />
          ) : selected === null ? (
            <Banner variant="error" icon={<ShieldAlert className="size-4" />} text="Not authorized (or user not found)." />
          ) : (
            <UserDetailView detail={selected} fallbackUserId={selectedUserId} />
          )}
        </Surface>
      </div>
    </div>
  );
}

function UserDetailView({
  detail,
  fallbackUserId,
}: {
  detail: AdminUserDetail;
  fallbackUserId: string;
}) {
  const user = detail.user ?? {};
  const userId = (user._id as string | undefined) ?? fallbackUserId;
  const userPhotoUrl = getUserDetailPhotoUrl(detail);

  const roles = (user.roles ?? {}) as { isSeeker?: boolean; isTasker?: boolean };
  const location = (user.location ?? {}) as {
    city?: string | null;
    province?: string | null;
    coordinates?: unknown;
    gpsCoordinates?: unknown;
  };
  const settings = (user.settings ?? {}) as { notificationsEnabled?: boolean; locationEnabled?: boolean };

  type PhotoLightboxItem = { url: string; label: string; meta?: string };

  const [tab, setTab] = useState<"overview" | "seeker" | "tasker" | "jobs" | "reviews" | "moderation" | "feedback" | "photos" | "raw">("overview");
  const [rawOpen, setRawOpen] = useState(false);
  const [lightbox, setLightbox] = useState<PhotoLightboxItem | null>(null);

  const taskerCategories = Array.isArray((detail.taskerProfile as any)?.categories)
    ? (((detail.taskerProfile as any).categories ?? []) as any[])
    : [];
  const taskerSubscriptionAdmin = getTaskerSubscriptionAdmin(detail.taskerProfile);

  const taskerCategoryCount = taskerCategories.length;
  const taskerPhotoCount = taskerCategories.reduce((acc, c) => {
    return acc + getCategoryPhotoUrls(c).length;
  }, 0);

  const totalPhotoCount = (userPhotoUrl ? 1 : 0) + taskerPhotoCount;
  const taskerCategoriesWithPhotos = taskerCategories.filter(
    (c) => getCategoryPhotoUrls(c).length > 0
  );
  const feedbackSubmissions = Array.isArray(detail.feedbackSubmissions) ? detail.feedbackSubmissions : [];
  const blocksCreated = Array.isArray(detail.blocksCreated) ? detail.blocksCreated : [];
  const blocksReceived = Array.isArray(detail.blocksReceived) ? detail.blocksReceived : [];
  const reportsSubmitted = Array.isArray(detail.reportsSubmitted) ? detail.reportsSubmitted : [];
  const reportsReceived = Array.isArray(detail.reportsReceived) ? detail.reportsReceived : [];

  useEffect(() => {
    setTab("overview");
    setRawOpen(false);
    setLightbox(null);
  }, [userId]);

  const tabs = [
    { value: "overview", label: "Overview" },
    { value: "seeker", label: "Seeker" },
    { value: "tasker", label: `Tasker (${taskerCategoryCount})` },
    { value: "jobs", label: `Jobs (${(detail.jobsAsSeeker?.length ?? 0) + (detail.jobsAsTasker?.length ?? 0)})` },
    { value: "reviews", label: `Reviews (${(detail.reviewsReceived?.length ?? 0) + (detail.reviewsGiven?.length ?? 0)})` },
    { value: "moderation", label: `Safety (${blocksCreated.length + blocksReceived.length + reportsSubmitted.length + reportsReceived.length})` },
    { value: "feedback", label: `Feedback (${feedbackSubmissions.length})` },
    { value: "photos", label: `Photos (${totalPhotoCount})` },
    { value: "raw", label: "Raw" },
  ] as const;

  const name = (user.name as string | undefined) || "Unnamed user";
  const email = (user.email as string | undefined) || "—";
  const emailVerified = !!user.emailVerified;

  const createdAt = user.createdAt;
  const updatedAt = user.updatedAt;

  useEffect(() => {
    if (!lightbox) return;
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") setLightbox(null);
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [lightbox]);

  const formatRate = (rate: unknown, rateType: unknown) => {
    const money = formatMoneyCents(rate);
    if (money === "—") return "—";
    if (rateType === "hourly") return `${money}/hr`;
    if (rateType === "flat") return `${money} flat`;
    return money;
  };

  const renderJobsTable = (jobs: any[], emptyTitle: string) => {
    if (!jobs || jobs.length === 0) {
      return <EmptyHint title={emptyTitle} body="No jobs found for this role." />;
    }

    return (
      <div className="pw-inset">
        <div className="max-h-[36dvh] overflow-auto">
          <Table layout="fixed" className="w-full text-[13px]">
            <Table.Header className="pw-inset-header">
              <Table.Row>
                <Table.Head className="pw-th w-[18%]">Status</Table.Head>
                <Table.Head className="pw-th w-[36%]">Job</Table.Head>
                <Table.Head className="pw-th w-[18%]">Rate</Table.Head>
                <Table.Head className="pw-th w-[14%]">Start</Table.Head>
                <Table.Head className="pw-th w-[14%]">Created</Table.Head>
              </Table.Row>
            </Table.Header>
            <Table.Body className="divide-y divide-kumo-fill/80">
              {jobs.map((j, idx) => {
                const sb = statusBadge(j?.status);
                return (
                  <Table.Row key={String(j?._id ?? `${j?.createdAt ?? "job"}-${idx}`)}>
                    <Table.Cell className="pw-td">
                      <Badge variant={sb.variant} className="pw-badge-tight">{sb.label}</Badge>
                    </Table.Cell>
                    <Table.Cell className="pw-td">
                      <div className="text-sm text-kumo-strong">{j?.categoryName ?? "—"}</div>
                      <div className="pw-mono text-xs text-kumo-muted">{shortId(String(j?._id ?? ""))}</div>
                    </Table.Cell>
                    <Table.Cell className="pw-td">
                      <div className="text-sm text-kumo-default">
                      {formatRate(j?.rate, j?.rateType)}
                      </div>
                    </Table.Cell>
                    <Table.Cell className="pw-td">
                      <div className="text-xs text-kumo-muted">
                      {formatIsoDate(j?.startDate)}
                      </div>
                    </Table.Cell>
                    <Table.Cell className="pw-td">
                      <div className="text-xs text-kumo-muted">
                      {formatDate(j?.createdAt)}
                      </div>
                    </Table.Cell>
                  </Table.Row>
                );
              })}
            </Table.Body>
          </Table>
        </div>
      </div>
    );
  };

  const renderReviews = (reviews: any[], kind: "received" | "given") => {
    if (!reviews || reviews.length === 0) {
      return (
        <EmptyHint
          title={kind === "received" ? "No reviews received" : "No reviews given"}
          body="Nothing to show yet."
        />
      );
    }

    return (
      <div className="grid gap-4">
        {reviews.map((r, idx) => {
          const counterpart =
            kind === "received"
              ? (r?.reviewerName as string | undefined) ?? shortId(String(r?.reviewerId ?? ""))
              : (r?.revieweeName as string | undefined) ?? shortId(String(r?.revieweeId ?? ""));

          const rating = typeof r?.rating === "number" ? r.rating : null;
          return (
            <div
              key={String(r?._id ?? `${r?.createdAt ?? "review"}-${idx}`)}
              className="pw-subcard p-5"
            >
              <div className="flex flex-wrap items-center gap-2">
                <Badge variant="outline">
                  <span className="inline-flex items-center gap-1">
                    <Star className="size-3" /> {rating ?? "—"}
                  </span>
                </Badge>
                <div className="text-sm text-kumo-strong">
                  {kind === "received" ? "From" : "To"} {counterpart}
                </div>
                <div className="ml-auto pw-mono text-xs text-kumo-muted">{formatDate(r?.createdAt)}</div>
              </div>
              <div className="mt-2 text-sm text-kumo-default whitespace-pre-wrap">{r?.text ?? "—"}</div>
              {r?.jobId && (
                <div className="mt-3">
                  <div className="pw-mono mb-1 text-xs text-kumo-muted">Job ID</div>
                  <ClipboardText size="sm" text={String(r.jobId)} />
                </div>
              )}
            </div>
          );
        })}
      </div>
    );
  };

  const renderFeedback = (items: FeedbackSubmissionRow[]) => {
    if (!items.length) {
      return <EmptyHint title="No feedback submitted" body="This user has not sent any in-app feedback yet." />;
    }

    return (
      <div className="grid gap-4">
        {items.map((item) => (
          <div key={item._id} className="pw-subcard p-5">
            <div className="flex flex-wrap items-center gap-2">
              <Badge variant="outline">feedback</Badge>
              <div className="pw-mono text-xs text-kumo-muted">{formatDate(item.createdAt)}</div>
            </div>
            <div className="mt-3 text-sm leading-relaxed text-kumo-default whitespace-pre-wrap">
              {item.message}
            </div>
          </div>
        ))}
      </div>
    );
  };

  const renderReports = (items: ModerationReportRow[], emptyTitle: string) => {
    if (!items.length) {
      return <EmptyHint title={emptyTitle} body="No user reports found for this side of the case." />;
    }

    return (
      <div className="grid gap-4">
        {items.map((item) => (
          <div key={item._id} className="pw-subcard p-5">
            <div className="flex flex-wrap items-center gap-2">
              <Badge variant={item.status === "open" ? "destructive" : "outline"} className="pw-badge-tight">
                {item.status}
              </Badge>
              <Badge variant="outline" className="pw-badge-tight">
                {item.action === "block_and_report" ? "block & report" : "report"}
              </Badge>
              <div className="pw-mono text-xs text-kumo-muted">{formatDate(item.createdAt)}</div>
            </div>

            <div className="mt-3 grid gap-3 md:grid-cols-2">
              <div>
                <div className="pw-mono mb-1 text-xs text-kumo-muted">Reporter</div>
                <div className="text-sm text-kumo-strong">
                  {item.reporterName || item.reporterEmail || shortId(item.reporterId)}
                </div>
              </div>
              <div>
                <div className="pw-mono mb-1 text-xs text-kumo-muted">Reported user</div>
                <div className="text-sm text-kumo-strong">
                  {item.reportedUserName || item.reportedUserEmail || shortId(item.reportedUserId)}
                </div>
              </div>
            </div>

            <div className="mt-3 text-sm leading-relaxed text-kumo-default whitespace-pre-wrap">
              {item.reason}
            </div>

            {item.conversationId && (
              <div className="mt-3">
                <div className="pw-mono mb-1 text-xs text-kumo-muted">Conversation ID</div>
                <ClipboardText size="sm" text={item.conversationId} />
              </div>
            )}
          </div>
        ))}
      </div>
    );
  };

  const renderBlocks = (items: ModerationBlockRow[], emptyTitle: string) => {
    if (!items.length) {
      return <EmptyHint title={emptyTitle} body="No block records found for this side of the case." />;
    }

    return (
      <div className="pw-inset">
        <div className="max-h-[32dvh] overflow-auto">
          <Table layout="fixed" className="w-full text-[13px]">
            <Table.Header className="pw-inset-header">
              <Table.Row>
                <Table.Head className="pw-th w-[28%]">Blocker</Table.Head>
                <Table.Head className="pw-th w-[28%]">Blocked</Table.Head>
                <Table.Head className="pw-th w-[24%]">Conversation</Table.Head>
                <Table.Head className="pw-th w-[20%]">Created</Table.Head>
              </Table.Row>
            </Table.Header>
            <Table.Body className="divide-y divide-kumo-fill/80">
              {items.map((item) => (
                <Table.Row key={item._id}>
                  <Table.Cell className="pw-td">
                    <div className="text-sm text-kumo-strong">
                      {item.blockerName || item.blockerEmail || shortId(item.blockerId)}
                    </div>
                    <div className="pw-mono text-xs text-kumo-muted">{shortId(item.blockerId)}</div>
                  </Table.Cell>
                  <Table.Cell className="pw-td">
                    <div className="text-sm text-kumo-strong">
                      {item.blockedUserName || item.blockedUserEmail || shortId(item.blockedId)}
                    </div>
                    <div className="pw-mono text-xs text-kumo-muted">{shortId(item.blockedId)}</div>
                  </Table.Cell>
                  <Table.Cell className="pw-td">
                    <div className="pw-mono text-xs text-kumo-muted">
                      {item.conversationId ? shortId(item.conversationId) : "—"}
                    </div>
                  </Table.Cell>
                  <Table.Cell className="pw-td">
                    <div className="text-xs text-kumo-muted">{formatDate(item.createdAt)}</div>
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table.Body>
          </Table>
        </div>
      </div>
    );
  };

  return (
    <div className="grid gap-4">
      <div className="pw-subcard">
        <div className="flex flex-wrap items-start gap-4">
          {userPhotoUrl ? (
            <button
              type="button"
              className="mt-0.5 rounded-2xl outline-none transition focus-visible:ring-2 focus-visible:ring-kumo-brand/30"
              onClick={() => setLightbox({ url: userPhotoUrl, label: "Avatar" })}
            >
              <UserAvatar
                url={userPhotoUrl}
                name={name}
                email={email === "—" ? null : email}
                sizeClassName="size-12"
                className="shadow-sm shadow-black/10"
              />
            </button>
          ) : (
            <div className="mt-0.5">
              <UserAvatar
                url={null}
                name={name}
                email={email === "—" ? null : email}
                sizeClassName="size-12"
              />
            </div>
          )}

          <div className="min-w-0 flex-1">
            <div className="pw-display text-base tracking-tight text-kumo-strong">{name}</div>
            <div className="mt-1 flex flex-wrap items-center gap-2">
              {emailVerified ? (
                <Badge variant="secondary">email verified</Badge>
              ) : (
                <Badge variant="outline">email unverified</Badge>
              )}
              {roles.isSeeker && <Badge variant="secondary">seeker</Badge>}
              {roles.isTasker && <Badge variant="outline">tasker</Badge>}
            </div>

            <div className="mt-4 grid gap-3 md:grid-cols-2">
              <div>
                <div className="pw-mono mb-1 text-xs text-kumo-muted">Email</div>
                <ClipboardText size="sm" text={email} />
              </div>
              <div>
                <div className="pw-mono mb-1 text-xs text-kumo-muted">User ID</div>
                <ClipboardText size="sm" text={userId} />
              </div>
            </div>
          </div>

          <div className="grid w-full gap-2 md:w-[260px]">
            <div className="pw-microcard">
              <div className="pw-mono text-xs text-kumo-muted">Created</div>
              <div className="text-sm text-kumo-strong">{formatDate(createdAt)}</div>
            </div>
            <div className="pw-microcard">
              <div className="pw-mono text-xs text-kumo-muted">Updated</div>
              <div className="text-sm text-kumo-strong">{formatDate(updatedAt)}</div>
            </div>
          </div>
        </div>
      </div>

      <div className="pw-subcard p-2">
        <Tabs
          variant="segmented"
          tabs={tabs as any}
          value={tab}
          onValueChange={(v) => setTab(v as any)}
          className="w-full"
          listClassName="w-full overflow-x-auto"
          activateOnFocus
        />
      </div>

      {tab === "overview" && (
        <div className="grid gap-4 md:grid-cols-2">
          <div className="pw-subcard">
            <div className="mb-2 flex items-center gap-2">
              <MapPin className="size-4 text-kumo-muted" />
              <div className="pw-display text-sm tracking-tight">Location</div>
            </div>
            <div className="grid gap-2 text-sm">
              <div className="pw-microcard">
                <div className="pw-mono text-xs text-kumo-muted">Home base</div>
                <div className="text-sm text-kumo-strong">{formatConfiguredLocation(location)}</div>
              </div>
              <div className="pw-microcard">
                <div className="pw-mono text-xs text-kumo-muted">Profile/manual coordinates</div>
                <div className="pw-mono text-sm text-kumo-strong">{formatCoordinates(location.coordinates)}</div>
              </div>
              <div className="pw-microcard">
                <div className="pw-mono text-xs text-kumo-muted">Last GPS check-in</div>
                <div className="pw-mono text-sm text-kumo-strong">
                  {formatCheckedInCoordinates(location.gpsCoordinates, (location.gpsCoordinates as any)?.checkedInAt)}
                </div>
              </div>
              <div className="pw-microcard">
                <div className="pw-mono text-xs text-kumo-muted">Tasker discoverability</div>
                <div className="pw-mono text-sm text-kumo-strong">
                  {formatTaskerDiscoverability(detail.taskerProfile)}
                </div>
              </div>
            </div>
          </div>

          <div className="pw-subcard">
            <div className="mb-2 flex items-center gap-2">
              <Briefcase className="size-4 text-kumo-muted" />
              <div className="pw-display text-sm tracking-tight">Activity</div>
            </div>
            <div className="grid grid-cols-2 gap-2 text-sm">
              <div className="pw-microcard">
                <div className="pw-mono text-xs text-kumo-muted">Jobs (seeker)</div>
                <div className="text-sm font-semibold text-kumo-strong">{detail.jobsAsSeeker?.length ?? 0}</div>
              </div>
              <div className="pw-microcard">
                <div className="pw-mono text-xs text-kumo-muted">Jobs (tasker)</div>
                <div className="text-sm font-semibold text-kumo-strong">{detail.jobsAsTasker?.length ?? 0}</div>
              </div>
              <div className="pw-microcard">
                <div className="pw-mono text-xs text-kumo-muted">Reviews received</div>
                <div className="text-sm font-semibold text-kumo-strong">{detail.reviewsReceived?.length ?? 0}</div>
              </div>
              <div className="pw-microcard">
                <div className="pw-mono text-xs text-kumo-muted">Reviews given</div>
                <div className="text-sm font-semibold text-kumo-strong">{detail.reviewsGiven?.length ?? 0}</div>
              </div>
            </div>
          </div>

          <div className="pw-subcard md:col-span-2">
            <div className="mb-2 flex items-center gap-2">
              <User className="size-4 text-kumo-muted" />
              <div className="pw-display text-sm tracking-tight">Settings</div>
            </div>
            <div className="flex flex-wrap gap-2">
              <Badge variant={settings.notificationsEnabled ? "secondary" : "outline"}>
                notifications {settings.notificationsEnabled ? "on" : "off"}
              </Badge>
              <Badge variant={settings.locationEnabled ? "secondary" : "outline"}>
                location {settings.locationEnabled ? "on" : "off"}
              </Badge>
            </div>
          </div>
        </div>
      )}

      {tab === "seeker" && (
        detail.seekerProfile ? (
          <div className="grid gap-4 md:grid-cols-2">
            <div className="pw-subcard">
              <div className="mb-2 flex items-center gap-2">
                <Briefcase className="size-4 text-kumo-muted" />
                <div className="pw-display text-sm tracking-tight">Seeker stats</div>
              </div>
              <div className="grid grid-cols-2 gap-2 text-sm">
                <div className="pw-microcard">
                  <div className="pw-mono text-xs text-kumo-muted">Jobs posted</div>
                  <div className="text-sm font-semibold text-kumo-strong">{detail.seekerProfile.jobsPosted ?? "—"}</div>
                </div>
                <div className="pw-microcard">
                  <div className="pw-mono text-xs text-kumo-muted">Completed</div>
                  <div className="text-sm font-semibold text-kumo-strong">{detail.seekerProfile.completedJobs ?? "—"}</div>
                </div>
                <div className="pw-microcard">
                  <div className="pw-mono text-xs text-kumo-muted">Rating</div>
                  <div className="text-sm font-semibold text-kumo-strong">
                    <span className="inline-flex items-center gap-1">
                      <Star className="size-3 text-kumo-muted" />
                      {detail.seekerProfile.rating ?? "—"}
                    </span>
                  </div>
                </div>
                <div className="pw-microcard">
                  <div className="pw-mono text-xs text-kumo-muted">Count</div>
                  <div className="text-sm font-semibold text-kumo-strong">{detail.seekerProfile.ratingCount ?? "—"}</div>
                </div>
              </div>
            </div>

            <div className="pw-subcard">
              <div className="mb-2 flex items-center gap-2">
                <User className="size-4 text-kumo-muted" />
                <div className="pw-display text-sm tracking-tight">Favorites</div>
              </div>
              <div className="text-sm text-kumo-default">
                Favorite taskers:{" "}
                <span className="pw-mono text-kumo-strong">
                  {(detail.seekerProfile.favouriteTaskers?.length ?? 0).toString()}
                </span>
              </div>
              <div className="mt-3 text-xs text-kumo-muted">
                Last updated: <span className="pw-mono">{formatDate(detail.seekerProfile.updatedAt)}</span>
              </div>
            </div>
          </div>
        ) : (
          <EmptyHint title="No seeker profile" body="This user does not have a seeker profile record." />
        )
      )}

      {tab === "tasker" && (
        detail.taskerProfile ? (
          <div className="grid gap-4">
            <div className="pw-subcard">
              <div className="mb-2 flex items-center gap-2">
                <Briefcase className="size-4 text-kumo-muted" />
                <div className="pw-display text-sm tracking-tight">Tasker profile</div>
              </div>
              <div className="grid gap-2 md:grid-cols-2">
                <div className="pw-microcard">
                  <div className="pw-mono text-xs text-kumo-muted">Display name</div>
                  <div className="text-sm text-kumo-strong">{detail.taskerProfile.displayName ?? "—"}</div>
                </div>
                <div className="pw-microcard">
                  <div className="pw-mono text-xs text-kumo-muted">Verified</div>
                  <div className="text-sm text-kumo-strong">{detail.taskerProfile.verified ? "yes" : "no"}</div>
                </div>
                <div className="pw-microcard">
                  <div className="pw-mono text-xs text-kumo-muted">Rating</div>
                  <div className="text-sm font-semibold text-kumo-strong">
                    <span className="inline-flex items-center gap-1">
                      <Star className="size-3 text-kumo-muted" />
                      {detail.taskerProfile.rating ?? "—"}
                    </span>
                  </div>
                </div>
                <div className="pw-microcard">
                  <div className="pw-mono text-xs text-kumo-muted">Completed</div>
                  <div className="text-sm font-semibold text-kumo-strong">{detail.taskerProfile.completedJobs ?? "—"}</div>
                </div>
              </div>

              <div className="mt-3 flex flex-wrap gap-2">
                <Badge variant={taskerSubscriptionAdmin?.hasActiveSubscription ? "secondary" : "outline"}>
                  access {taskerSubscriptionAdmin?.hasActiveSubscription ? "active" : "inactive"}
                </Badge>
                <Badge variant="outline">
                  tier: {formatSubscriptionValue(taskerSubscriptionAdmin?.effectiveSubscriptionTier ?? taskerSubscriptionAdmin?.subscriptionTier)}
                </Badge>
                <Badge variant="outline">
                  status: {formatSubscriptionValue(taskerSubscriptionAdmin?.subscriptionStatus)}
                </Badge>
                <Badge variant={detail.taskerProfile.ghostMode ? "destructive" : "secondary"}>
                  ghost mode {detail.taskerProfile.ghostMode ? "on" : "off"}
                </Badge>
                <Badge variant={taskerSubscriptionAdmin?.premiumPin?.searchStatus === "active" ? "secondary" : "outline"}>
                  {formatPremiumPinSearchStatus(taskerSubscriptionAdmin)}
                </Badge>
              </div>

              <div className="mt-4 grid gap-2 md:grid-cols-4">
                <div className="pw-microcard">
                  <div className="pw-mono text-xs text-kumo-muted">Plan</div>
                  <div className="text-sm text-kumo-strong">
                    {formatSubscriptionValue(taskerSubscriptionAdmin?.effectiveSubscriptionPlan ?? taskerSubscriptionAdmin?.subscriptionPlan)}
                  </div>
                  <div className="mt-1 text-xs text-kumo-muted">
                    stored {formatSubscriptionValue(taskerSubscriptionAdmin?.subscriptionPlan)}
                  </div>
                </div>
                <div className="pw-microcard">
                  <div className="pw-mono text-xs text-kumo-muted">Tier</div>
                  <div className="text-sm text-kumo-strong">
                    {formatSubscriptionValue(taskerSubscriptionAdmin?.effectiveSubscriptionTier ?? taskerSubscriptionAdmin?.subscriptionTier)}
                  </div>
                  <div className="mt-1 text-xs text-kumo-muted">
                    stored {formatSubscriptionValue(taskerSubscriptionAdmin?.subscriptionTier)}
                  </div>
                </div>
                <div className="pw-microcard">
                  <div className="pw-mono text-xs text-kumo-muted">Access type</div>
                  <div className="text-sm text-kumo-strong">
                    {formatSubscriptionValue(taskerSubscriptionAdmin?.subscriptionAccessType)}
                  </div>
                  <div className="mt-1 text-xs text-kumo-muted">
                    active {formatActiveAccessTypes(taskerSubscriptionAdmin?.subscriptionActiveAccessTypes)}
                  </div>
                </div>
                <div className="pw-microcard">
                  <div className="pw-mono text-xs text-kumo-muted">Term end</div>
                  <div className="text-sm text-kumo-strong">
                    {formatSubscriptionDate(taskerSubscriptionAdmin?.subscriptionEndsAt)}
                  </div>
                  <div className="mt-1 text-xs text-kumo-muted">
                    stored status {formatSubscriptionValue(taskerSubscriptionAdmin?.storedSubscriptionStatus)}
                  </div>
                </div>
              </div>

              <div className="mt-3 rounded-[var(--pw-radius-sm)] border border-kumo-fill bg-kumo-subtle p-3">
                <div className="pw-mono text-xs text-kumo-muted">Premium pin</div>
                <div className="mt-1 flex flex-wrap items-center gap-2">
                  <span className="pw-mono text-sm font-semibold text-kumo-strong">
                    {taskerSubscriptionAdmin?.premiumPin?.code ?? "—"}
                  </span>
                  <Badge variant={taskerSubscriptionAdmin?.premiumPin?.searchStatus === "active" ? "secondary" : "outline"}>
                    {formatPremiumPinSearchStatus(taskerSubscriptionAdmin)}
                  </Badge>
                </div>
              </div>

              <div className="mt-4 grid gap-3 md:grid-cols-2">
                <TaskerLinksAdminCard title="Websites" links={detail.taskerProfile.websiteLinks} />
                <TaskerLinksAdminCard title="Social" links={detail.taskerProfile.socialLinks} />
              </div>
            </div>

            {Array.isArray(detail.taskerProfile.categories) && detail.taskerProfile.categories.length > 0 ? (
              <div className="pw-subcard">
                <div className="mb-3 flex items-center justify-between">
                  <div className="pw-display text-sm tracking-tight">Categories</div>
                  <Badge variant="outline">{detail.taskerProfile.categories.length}</Badge>
                </div>
                <div className="pw-inset">
                  <div className="max-h-[32dvh] overflow-auto">
                    <Table layout="fixed" className="w-full text-[13px]">
                      <Table.Header className="pw-inset-header">
                        <Table.Row>
                          <Table.Head className="pw-th w-[46%]">Category</Table.Head>
                          <Table.Head className="pw-th w-[22%]">Rate</Table.Head>
                          <Table.Head className="pw-th w-[16%]">Radius</Table.Head>
                          <Table.Head className="pw-th w-[16%]">Completed</Table.Head>
                        </Table.Row>
                      </Table.Header>
                      <Table.Body className="divide-y divide-kumo-fill/80">
                        {detail.taskerProfile.categories.map((c: any, idx: number) => {
                          const photoUrls = getCategoryPhotoUrls(c);
                          const preview = photoUrls.slice(0, 4);
                          const extra = Math.max(0, photoUrls.length - preview.length);

                          return (
                            <Table.Row key={String(c?._id ?? `${c?.categorySlug ?? "cat"}-${idx}`)}>
                              <Table.Cell className="pw-td">
                                <div className="text-sm font-semibold text-kumo-strong">{c?.categoryName ?? "—"}</div>
                                <div className="pw-mono mt-0.5 text-xs text-kumo-muted">{c?.categorySlug ?? "—"}</div>

                                {preview.length > 0 && (
                                  <div className="mt-2 flex flex-wrap gap-1.5">
                                    {preview.map((url: string, photoIdx: number) => (
                                      <button
                                        key={`${url}-${photoIdx}`}
                                        type="button"
                                        className="group relative block size-9 overflow-hidden rounded-lg border border-kumo-fill bg-kumo-tint shadow-sm shadow-black/5 outline-none transition focus-visible:ring-2 focus-visible:ring-kumo-brand/30"
                                        onClick={() =>
                                          setLightbox({
                                            url,
                                            label: c?.categoryName ? `${c.categoryName} photo` : "Tasker photo",
                                            meta: c?.categorySlug ?? undefined,
                                          })
                                        }
                                      >
                                        <img
                                          src={url}
                                          alt={c?.categoryName ? `${c.categoryName} photo` : "Tasker photo"}
                                          className="h-full w-full object-cover transition-transform duration-200 group-hover:scale-[1.04]"
                                          loading="lazy"
                                          decoding="async"
                                        />
                                      </button>
                                    ))}

                                    {extra > 0 && (
                                      <button
                                        type="button"
                                        className="pw-mono grid size-9 place-items-center rounded-lg border border-kumo-fill bg-kumo-base text-[11px] text-kumo-muted shadow-sm shadow-black/5 hover:bg-kumo-tint"
                                        onClick={() => setTab("photos")}
                                      >
                                        +{extra}
                                      </button>
                                    )}
                                  </div>
                                )}
                              </Table.Cell>
                              <Table.Cell className="pw-td">
                                <div className="text-sm text-kumo-default">
                                  {c?.rateType === "hourly"
                                    ? `${formatMoneyCents(c?.hourlyRate)}/hr`
                                    : c?.rateType === "fixed"
                                      ? `${formatMoneyCents(c?.fixedRate)} flat`
                                      : "—"}
                                </div>
                              </Table.Cell>
                              <Table.Cell className="pw-td">
                                <div className="text-sm text-kumo-default">{c?.serviceRadius ?? "—"} km</div>
                              </Table.Cell>
                              <Table.Cell className="pw-td">
                                <div className="text-sm text-kumo-default">{c?.completedJobs ?? "—"}</div>
                              </Table.Cell>
                            </Table.Row>
                          );
                        })}
                      </Table.Body>
                    </Table>
                  </div>
                </div>
              </div>
            ) : (
              <div className="pw-subcard">
                <div className="mb-3 flex items-center justify-between">
                  <div className="pw-display text-sm tracking-tight">Categories</div>
                  <Badge variant="outline">0</Badge>
                </div>
                <div className="text-sm leading-relaxed text-kumo-muted">
                  No category records yet. When a tasker has multiple categories and photos, they appear here as rows with thumbnail previews.
                </div>

                <div className="mt-4 pw-inset p-4">
                  <div className="grid gap-4">
                    {Array.from({ length: 2 }).map((_, idx) => (
                      <div key={idx} className="flex items-start justify-between gap-4">
                        <div className="min-w-0">
                          <div className="skeleton h-4 w-44 rounded bg-kumo-fill/40" />
                          <div className="mt-2 skeleton h-3 w-28 rounded bg-kumo-fill/35" />
                          <div className="mt-3 flex flex-wrap gap-1.5">
                            {Array.from({ length: 4 }).map((__, jdx) => (
                              <div key={jdx} className="skeleton size-9 rounded-lg bg-kumo-fill/30" />
                            ))}
                            <div className="skeleton size-9 rounded-lg bg-kumo-fill/25" />
                          </div>
                        </div>

                        <div className="grid gap-2 pt-0.5">
                          <div className="skeleton h-4 w-20 rounded bg-kumo-fill/35" />
                          <div className="skeleton h-4 w-14 rounded bg-kumo-fill/30" />
                          <div className="skeleton h-4 w-16 rounded bg-kumo-fill/30" />
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            )}
          </div>
        ) : (
          <EmptyHint title="No tasker profile" body="This user does not have a tasker profile record." />
        )
      )}

      {tab === "jobs" && (
        <div className="grid gap-4">
          <div>
            <div className="mb-2 flex items-center gap-2">
              <Briefcase className="size-4 text-kumo-muted" />
              <div className="pw-display text-sm tracking-tight">Jobs as seeker</div>
              <Badge variant="outline">{detail.jobsAsSeeker?.length ?? 0}</Badge>
            </div>
            {renderJobsTable(detail.jobsAsSeeker ?? [], "No seeker jobs")}
          </div>

          <div>
            <div className="mb-2 flex items-center gap-2">
              <Briefcase className="size-4 text-kumo-muted" />
              <div className="pw-display text-sm tracking-tight">Jobs as tasker</div>
              <Badge variant="outline">{detail.jobsAsTasker?.length ?? 0}</Badge>
            </div>
            {renderJobsTable(detail.jobsAsTasker ?? [], "No tasker jobs")}
          </div>
        </div>
      )}

      {tab === "reviews" && (
        <div className="grid gap-4">
          <div>
            <div className="mb-2 flex items-center gap-2">
              <Star className="size-4 text-kumo-muted" />
              <div className="pw-display text-sm tracking-tight">Received</div>
              <Badge variant="outline">{detail.reviewsReceived?.length ?? 0}</Badge>
            </div>
            {renderReviews(detail.reviewsReceived ?? [], "received")}
          </div>

          <div>
            <div className="mb-2 flex items-center gap-2">
              <Star className="size-4 text-kumo-muted" />
              <div className="pw-display text-sm tracking-tight">Given</div>
              <Badge variant="outline">{detail.reviewsGiven?.length ?? 0}</Badge>
            </div>
            {renderReviews(detail.reviewsGiven ?? [], "given")}
          </div>
        </div>
      )}

      {tab === "moderation" && (
        <div className="grid gap-4">
          <div>
            <div className="mb-2 flex items-center gap-2">
              <ShieldAlert className="size-4 text-kumo-muted" />
              <div className="pw-display text-sm tracking-tight">Reports received</div>
              <Badge variant="outline">{reportsReceived.length}</Badge>
            </div>
            {renderReports(reportsReceived, "No reports received")}
          </div>

          <div>
            <div className="mb-2 flex items-center gap-2">
              <ShieldAlert className="size-4 text-kumo-muted" />
              <div className="pw-display text-sm tracking-tight">Reports submitted</div>
              <Badge variant="outline">{reportsSubmitted.length}</Badge>
            </div>
            {renderReports(reportsSubmitted, "No reports submitted")}
          </div>

          <div>
            <div className="mb-2 flex items-center gap-2">
              <User className="size-4 text-kumo-muted" />
              <div className="pw-display text-sm tracking-tight">Users blocked by this user</div>
              <Badge variant="outline">{blocksCreated.length}</Badge>
            </div>
            {renderBlocks(blocksCreated, "No blocks created")}
          </div>

          <div>
            <div className="mb-2 flex items-center gap-2">
              <User className="size-4 text-kumo-muted" />
              <div className="pw-display text-sm tracking-tight">Users blocking this user</div>
              <Badge variant="outline">{blocksReceived.length}</Badge>
            </div>
            {renderBlocks(blocksReceived, "No incoming blocks")}
          </div>
        </div>
      )}

      {tab === "feedback" && (
        <div>
          <div className="mb-2 flex items-center gap-2">
            <MessageSquare className="size-4 text-kumo-muted" />
            <div className="pw-display text-sm tracking-tight">Feedback</div>
            <Badge variant="outline">{feedbackSubmissions.length}</Badge>
          </div>
          {renderFeedback(feedbackSubmissions)}
        </div>
      )}

      {tab === "raw" && (
        <div className="pw-subcard p-5">
          <Collapsible.Root open={rawOpen} onOpenChange={setRawOpen}>
            <Collapsible.DefaultTrigger>Response JSON</Collapsible.DefaultTrigger>
            <Collapsible.DefaultPanel>
              <CodeBlock lang="jsonc" code={JSON.stringify(detail, null, 2)} />
            </Collapsible.DefaultPanel>
          </Collapsible.Root>
        </div>
      )}

      {tab === "photos" && (
        <div className="grid gap-4">
          <div className="pw-subcard">
            <div className="pw-display text-sm tracking-tight text-kumo-strong">User photos</div>
            <div className="mt-1 text-sm leading-relaxed text-kumo-muted">
              Profile photo plus any tasker category photos. Click to preview.
            </div>
          </div>

          <div className="grid gap-4">
            {userPhotoUrl ? (
              <div className="pw-subcard">
                <div className="mb-3 flex items-center justify-between gap-3">
                  <div className="pw-display text-sm tracking-tight">Avatar</div>
                  <Badge variant="outline" className="pw-badge-tight">1</Badge>
                </div>
                <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4">
                  <button
                    type="button"
                    className="group relative overflow-hidden rounded-xl border border-kumo-fill bg-kumo-tint shadow-sm shadow-black/5 outline-none transition focus-visible:ring-2 focus-visible:ring-kumo-brand/30"
                    onClick={() => setLightbox({ url: userPhotoUrl, label: "Avatar" })}
                  >
                    <img
                      src={userPhotoUrl}
                      alt={`${name} avatar`}
                      className="aspect-square w-full object-cover transition-transform duration-200 group-hover:scale-[1.03]"
                      loading="lazy"
                      decoding="async"
                    />
                  </button>
                </div>
              </div>
            ) : (
              <EmptyHint title="No profile photo" body="This user does not have a profile photo set." />
            )}

            {taskerCategoriesWithPhotos.length > 0 ? (
              <div className="grid gap-4">
                {taskerCategoriesWithPhotos.map((c: any, idx: number) => (
                  <div key={String(c?._id ?? `${c?.categorySlug ?? "cat"}-${idx}`)} className="pw-subcard">
                    <div className="mb-3 flex items-start justify-between gap-3">
                      <div className="min-w-0">
                        <div className="pw-display truncate text-sm tracking-tight text-kumo-strong">
                          {c?.categoryName ?? "Category photos"}
                        </div>
                        <div className="pw-mono mt-1 truncate text-xs text-kumo-muted">
                          {c?.categorySlug ?? "—"}
                        </div>
                      </div>
                      <Badge variant="outline" className="pw-badge-tight">
                        {getCategoryPhotoUrls(c).length.toString()}
                      </Badge>
                    </div>

                    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4">
                      {getCategoryPhotoUrls(c).map((url: string, photoIdx: number) => (
                        <button
                          key={`${url}-${photoIdx}`}
                          type="button"
                          className="group relative overflow-hidden rounded-xl border border-kumo-fill bg-kumo-tint shadow-sm shadow-black/5 outline-none transition focus-visible:ring-2 focus-visible:ring-kumo-brand/30"
                          onClick={() =>
                            setLightbox({
                              url,
                              label: c?.categoryName ? `${c.categoryName} photo` : "Tasker photo",
                              meta: c?.categorySlug ?? undefined,
                            })
                          }
                        >
                          <img
                            src={url}
                            alt={c?.categoryName ? `${c.categoryName} photo` : "Tasker photo"}
                            className="aspect-square w-full object-cover transition-transform duration-200 group-hover:scale-[1.03]"
                            loading="lazy"
                            decoding="async"
                          />
                        </button>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="pw-subcard">
                <div className="mb-3 flex items-center justify-between gap-3">
                  <div className="pw-display text-sm tracking-tight">Category photos</div>
                  <Badge variant="outline" className="pw-badge-tight">0</Badge>
                </div>
                <div className="text-sm leading-relaxed text-kumo-muted">
                  No category photos found. When present, photos are grouped into one card per category (with a grid of images).
                </div>

                <div className="mt-4 grid gap-4">
                  <div className="pw-inset p-4">
                    <div className="mb-3 flex items-start justify-between gap-3">
                      <div className="min-w-0">
                        <div className="skeleton h-4 w-48 rounded bg-kumo-fill/40" />
                        <div className="mt-2 skeleton h-3 w-28 rounded bg-kumo-fill/35" />
                      </div>
                      <div className="skeleton h-6 w-10 rounded-full bg-kumo-fill/30" />
                    </div>
                    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4">
                      {Array.from({ length: 8 }).map((_, idx) => (
                        <div key={idx} className="skeleton aspect-square w-full rounded-xl bg-kumo-fill/30" />
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {lightbox && (
        <div
          role="dialog"
          aria-modal="true"
          className="fixed inset-0 z-50 grid place-items-center bg-black/50 p-4 backdrop-blur-sm"
          onMouseDown={(e) => {
            if (e.target === e.currentTarget) setLightbox(null);
          }}
        >
          <div className="w-full max-w-[900px] overflow-hidden rounded-[22px] border border-white/10 bg-black/40 shadow-2xl">
            <div className="flex items-start gap-3 border-b border-white/10 px-4 py-3">
              <div className="min-w-0 flex-1">
                <div className="pw-display truncate text-sm tracking-tight text-white">{lightbox.label}</div>
                {lightbox.meta && <div className="pw-mono mt-0.5 truncate text-xs text-white/70">{lightbox.meta}</div>}
              </div>
              <div className="flex items-center gap-2">
                <a
                  href={lightbox.url}
                  target="_blank"
                  rel="noreferrer"
                  className="rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-xs font-semibold text-white/90 hover:bg-white/10"
                >
                  Open
                </a>
                <button
                  type="button"
                  className="rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-xs font-semibold text-white/90 hover:bg-white/10"
                  onClick={() => setLightbox(null)}
                >
                  Close
                </button>
              </div>
            </div>
            <div className="bg-black/40 p-3">
              <img
                src={lightbox.url}
                alt={lightbox.label}
                className="max-h-[70dvh] w-full rounded-xl object-contain"
                loading="lazy"
                decoding="async"
              />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default function AdminApp() {
  const convexUrl = getConvexCloudUrl();
  const convexSiteUrl = getConvexSiteUrl();

  if (!convexUrl) {
    return <EnvMisconfigured message="Missing Convex cloud URL. Set PUBLIC_CONVEX_URL (preferred for Astro) or VITE_CONVEX_URL." />;
  }
  if (!convexSiteUrl) {
    return <EnvMisconfigured message="Missing Convex site URL. Set PUBLIC_CONVEX_SITE_URL or VITE_CONVEX_SITE_URL (or set the cloud URL so we can derive it)." />;
  }

  const convex = useMemo(
    () =>
      new ConvexReactClient(convexUrl, {
        expectAuth: true,
      }),
    [convexUrl]
  );

  return (
    <ConvexBetterAuthProvider client={convex} authClient={authClient}>
      <AdminAppInner />
    </ConvexBetterAuthProvider>
  );
}

function AdminAppInner() {
  const session = useSession();
  const userEmail = session.data?.user?.email || null;
  const adminAccess = useQuery(api.admin.isAdmin, userEmail ? {} : "skip") as boolean | undefined;

  if (session.isPending) {
    return (
      <div className="mx-auto flex min-h-dvh w-full max-w-[1100px] items-center px-4 py-10">
        <Surface className="pw-card w-full rounded-[var(--pw-radius)] border border-kumo-fill bg-kumo-base p-6 shadow-[var(--pw-shadow)]">
          <div className="pw-display text-base tracking-tight">Loading session…</div>
          <div className="mt-2 text-sm text-kumo-muted">
            Waiting for Better Auth to resolve.
          </div>
        </Surface>
      </div>
    );
  }

  if (!session.data?.user || !userEmail) {
    return <LoginCard />;
  }

  if (adminAccess === undefined) {
    return (
      <div className="mx-auto flex min-h-dvh w-full max-w-[1100px] items-center px-4 py-10">
        <Surface className="pw-card w-full rounded-[var(--pw-radius)] border border-kumo-fill bg-kumo-base p-6 shadow-[var(--pw-shadow)]">
          <div className="pw-display text-base tracking-tight">Checking access…</div>
          <div className="mt-2 text-sm text-kumo-muted">Verifying admin privileges.</div>
        </Surface>
      </div>
    );
  }

  if (!adminAccess) {
    return (
      <div className="mx-auto flex min-h-dvh w-full max-w-[1100px] flex-col px-4 py-10">
        <div className="mb-8 flex items-center justify-between">
          <div className="pw-fade-up">
            <div className="pw-display text-xl tracking-tight">Patchwork Admin</div>
            <div className="text-sm text-kumo-muted">
              Signed in as <span className="pw-mono text-kumo-strong">{userEmail}</span>
            </div>
          </div>
          <Button variant="secondary" icon={<LogOut className="size-4" />} onClick={() => signOut()}>
            Sign out
          </Button>
        </div>

        <Surface className="pw-card pw-fade-up relative overflow-hidden rounded-[var(--pw-radius)] border border-kumo-danger/30 bg-kumo-danger/5 p-6 shadow-[var(--pw-shadow)]">
          <div className="mb-2 flex items-center gap-2">
            <ShieldAlert className="size-5 text-kumo-danger" />
            <div className="pw-display text-base tracking-tight text-kumo-strong">Access denied</div>
          </div>
          <p className="text-sm text-kumo-muted">
            This account is signed in, but it does not have admin privileges.
          </p>
        </Surface>
      </div>
    );
  }

  return <DashboardShell email={userEmail} />;
}
