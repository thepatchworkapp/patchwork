import { httpRouter } from "convex/server";
import { authComponent, createAuth } from "./auth";
import { internal } from "./_generated/api";
import { httpAction } from "./_generated/server";
import { createReviewSession } from "./reviewAccess";

const http = httpRouter();

authComponent.registerRoutes(http, createAuth, { cors: true });

const adminAppOrigin = process.env.ADMIN_APP_ORIGIN;
const revenueCatWebhookAuthorization = process.env.REVENUECAT_WEBHOOK_AUTHORIZATION;

function validateAdminOrigin(request: Request) {
  if (!adminAppOrigin) return false;
  const origin = request.headers.get("origin");
  return origin === adminAppOrigin;
}

function validateRevenueCatAuthorization(request: Request) {
  if (!revenueCatWebhookAuthorization) {
    return false;
  }

  return request.headers.get("authorization") === revenueCatWebhookAuthorization;
}

function sanitizeErrorMessage(error: unknown): string {
  const raw = error instanceof Error ? error.message : "Unknown error";
  const firstLine = raw.split("\n")[0] ?? "Unknown error";
  const cleaned = firstLine
    .replace(/^Uncaught Error:\s*/, "")
    .replace(/^Error:\s*/, "")
    .trim();
  return cleaned || "Unknown error";
}

function jsonHeaders(extra: Record<string, string> = {}) {
  return {
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
    ...extra,
  };
}

function adminCorsHeaders() {
  if (!adminAppOrigin) {
    return jsonHeaders();
  }

  return jsonHeaders({
    "Access-Control-Allow-Origin": adminAppOrigin,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    Vary: "Origin",
  });
}

function reviewCorsHeaders() {
  return jsonHeaders({
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Accept",
    Vary: "Origin",
  });
}

function jsonResponse(body: unknown, status: number, headers: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...jsonHeaders(),
      ...headers,
    },
  });
}

const sendOtpHandler = httpAction(async (ctx, request) => {
  if (!validateAdminOrigin(request)) {
    return jsonResponse({ error: "Forbidden" }, 403, adminCorsHeaders());
  }

  const body = await request.json();
  const { email } = body;

  if (!email) {
    return jsonResponse({ error: "Missing email" }, 400, adminCorsHeaders());
  }

  try {
    const result = await ctx.runMutation(internal.adminOtp.sendOTP, { email });
    return jsonResponse(result, 200, adminCorsHeaders());
  } catch (error) {
    const message = sanitizeErrorMessage(error);
    return jsonResponse({ error: message }, 400, adminCorsHeaders());
  }
});

const verifyOtpHandler = httpAction(async (ctx, request) => {
  if (!validateAdminOrigin(request)) {
    return jsonResponse({ error: "Forbidden" }, 403, adminCorsHeaders());
  }

  const body = await request.json();
  const { email, otp } = body;

  if (!email || !otp) {
    return jsonResponse({ error: "Missing email or otp" }, 400, adminCorsHeaders());
  }

  try {
    const result = await ctx.runMutation(internal.adminOtp.verifyOTP, { email, otp });
    return jsonResponse(result, 200, adminCorsHeaders());
  } catch (error) {
    const message = sanitizeErrorMessage(error);
    return jsonResponse({ error: message }, 400, adminCorsHeaders());
  }
});

const adminOptionsHandler = httpAction(async (_ctx, request) => {
  if (!validateAdminOrigin(request)) {
    return jsonResponse({ error: "Forbidden" }, 403, adminCorsHeaders());
  }

  return new Response(null, {
    status: 204,
    headers: adminCorsHeaders(),
  });
});

http.route({
  path: "/admin/send-otp",
  method: "POST",
  handler: sendOtpHandler,
});

http.route({
  path: "/admin/send-otp",
  method: "OPTIONS",
  handler: adminOptionsHandler,
});

http.route({
  path: "/admin/verify-otp",
  method: "POST",
  handler: verifyOtpHandler,
});

http.route({
  path: "/admin/verify-otp",
  method: "OPTIONS",
  handler: adminOptionsHandler,
});

const reviewSignInHandler = httpAction(async (ctx, request) => {
  const body = await request.json().catch(() => ({}));
  const email = typeof body?.email === "string" ? body.email : "";

  try {
    const result = await createReviewSession(ctx, email);
    return jsonResponse(result, 200, reviewCorsHeaders());
  } catch (error) {
    const message = sanitizeErrorMessage(error);
    const status = message === "Unknown review account" ? 403 : message === "App review access is disabled" ? 403 : 400;
    return jsonResponse({ error: message }, status, reviewCorsHeaders());
  }
});

const reviewSignInOptionsHandler = httpAction(async () => {
  return new Response(null, {
    status: 204,
    headers: reviewCorsHeaders(),
  });
});

http.route({
  path: "/review/sign-in",
  method: "POST",
  handler: reviewSignInHandler,
});

http.route({
  path: "/review/sign-in",
  method: "OPTIONS",
  handler: reviewSignInOptionsHandler,
});

const revenueCatWebhookHandler = httpAction(async (ctx, request) => {
  if (!revenueCatWebhookAuthorization) {
    console.error("[RevenueCatWebhook] Missing REVENUECAT_WEBHOOK_AUTHORIZATION");
    return jsonResponse({ error: "RevenueCat webhook authorization is not configured" }, 500);
  }

  if (!validateRevenueCatAuthorization(request)) {
    console.warn("[RevenueCatWebhook] Authorization rejected");
    return jsonResponse({ error: "Forbidden" }, 403);
  }

  const body = await request.json().catch(() => null);
  const event = body?.event;

  if (!event || typeof event.type !== "string") {
    console.warn("[RevenueCatWebhook] Missing event payload");
    return jsonResponse({ error: "Missing RevenueCat event payload" }, 400);
  }

  const result = await ctx.runAction(internal.taskersInternal.reconcileRevenueCatWebhookEvent, {
    type: event.type,
    appId: typeof event.app_id === "string" ? event.app_id : undefined,
    productId: typeof event.product_id === "string" ? event.product_id : undefined,
    appUserId: typeof event.app_user_id === "string" ? event.app_user_id : undefined,
    originalAppUserId:
      typeof event.original_app_user_id === "string" ? event.original_app_user_id : undefined,
    aliases: Array.isArray(event.aliases)
      ? event.aliases.filter((value: unknown): value is string => typeof value === "string")
      : undefined,
    transferredFrom: Array.isArray(event.transferred_from)
      ? event.transferred_from.filter((value: unknown): value is string => typeof value === "string")
      : undefined,
    transferredTo: Array.isArray(event.transferred_to)
      ? event.transferred_to.filter((value: unknown): value is string => typeof value === "string")
      : undefined,
    expirationAtMs:
      typeof event.expiration_at_ms === "number" ? event.expiration_at_ms : null,
  });

  console.info("[RevenueCatWebhook] Processed event", {
    type: event.type,
    productId: typeof event.product_id === "string" ? event.product_id : null,
    appUserId: typeof event.app_user_id === "string" ? event.app_user_id : null,
    result,
  });

  return jsonResponse({ ok: true, result }, 200);
});

http.route({
  path: "/revenuecat/webhook",
  method: "POST",
  handler: revenueCatWebhookHandler,
});

// ── Test helper proxy (gated by ENABLE_TESTING_HELPERS) ──────────────────
const enableTestingHelpers = process.env.ENABLE_TESTING_HELPERS === "true";

const testProxyHandler = httpAction(async (ctx, request) => {
  if (!enableTestingHelpers) {
    return new Response(JSON.stringify({ error: "Testing helpers are disabled" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  const body = await request.json();
  const { action, args } = body;

  try {
    let result: unknown;
    switch (action) {
      case "getOtp":
        result = await ctx.runQuery(internal.testing.getOtp, args);
        break;
      case "seedOtp":
        result = await ctx.runMutation(internal.testing.seedOtp, args);
        break;
      case "getUserId":
        result = await ctx.runQuery(internal.testing.getUserId, args);
        break;
      case "getTaskerProfileByEmail":
        result = await ctx.runQuery(internal.testing.getTaskerProfileByEmail, args);
        break;
      case "getConversationByEmails":
        result = await ctx.runQuery(internal.testing.getConversationByEmails, args);
        break;
      case "getLatestProposalByEmails":
        result = await ctx.runQuery(internal.testing.getLatestProposalByEmails, args);
        break;
      case "getJobById":
        result = await ctx.runQuery(internal.testing.getJobById, args);
        break;
      case "getReviewByJobAndReviewer":
        result = await ctx.runQuery(internal.testing.getReviewByJobAndReviewer, args);
        break;
      case "forceCreateConversation":
        result = await ctx.runMutation(internal.testing.forceCreateConversation, args);
        break;
      case "forceMakeTasker":
        result = await ctx.runMutation(internal.testing.forceMakeTasker, args);
        break;
      case "deleteTestUser":
        result = await ctx.runMutation(internal.testing.deleteTestUser, args);
        break;
      case "deleteByEmailPrefix":
        result = await ctx.runMutation(internal.testing.deleteByEmailPrefix, args);
        break;
      case "ensureCategoryExists":
        result = await ctx.runMutation(internal.testing.ensureCategoryExists, args);
        break;
      case "cleanupConversations":
        result = await ctx.runMutation(internal.testing.cleanupConversations, args);
        break;
      case "setTaskerLocationByEmail":
        result = await ctx.runMutation(internal.testing.setTaskerLocationByEmail, args);
        break;
      case "ensureDiscoverableTasker":
        result = await ctx.runMutation(internal.testing.ensureDiscoverableTasker, args);
        break;
      case "ensurePendingProposalBetweenEmails":
        result = await ctx.runMutation(internal.testing.ensurePendingProposalBetweenEmails, args);
        break;
      case "ensureAcceptedJobBetweenEmails":
        result = await ctx.runMutation(internal.testing.ensureAcceptedJobBetweenEmails, args);
        break;
      case "ensureCompletedJobBetweenEmails":
        result = await ctx.runMutation(internal.testing.ensureCompletedJobBetweenEmails, args);
        break;
      case "ensureConversationBetweenEmails":
        result = await ctx.runMutation(internal.testing.ensureConversationBetweenEmails, args);
        break;
      case "expireTaskerSubscription":
        result = await ctx.runMutation(internal.testing.expireTaskerSubscription, args);
        break;
      default:
        return new Response(JSON.stringify({ error: `Unknown action: ${action}` }), {
          status: 400,
          headers: { "Content-Type": "application/json" },
        });
    }
    return new Response(JSON.stringify({ result }), {
      status: 200,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  } catch (error) {
    const message = sanitizeErrorMessage(error);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }
});

const testProxyOptions = httpAction(async () => {
  return new Response(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
});

http.route({
  path: "/test-proxy",
  method: "POST",
  handler: testProxyHandler,
});

http.route({
  path: "/test-proxy",
  method: "OPTIONS",
  handler: testProxyOptions,
});

export default http;
