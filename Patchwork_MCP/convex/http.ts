import { httpRouter } from "convex/server";
import { authComponent, createAuth } from "./auth";
import { api, internal } from "./_generated/api";
import { httpAction } from "./_generated/server";

const http = httpRouter();

authComponent.registerRoutes(http, createAuth, { cors: true });

const adminAppOrigin = process.env.ADMIN_APP_ORIGIN;

function validateAdminOrigin(request: Request) {
  if (!adminAppOrigin) return false;
  const origin = request.headers.get("origin");
  return origin === adminAppOrigin;
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

const sendOtpHandler = httpAction(async (ctx, request) => {
  if (!validateAdminOrigin(request)) {
    return new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  }

  const body = await request.json();
  const { email } = body;

  if (!email) {
    return new Response(JSON.stringify({ error: "Missing email" }), {
      status: 400,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  }

  try {
    const result = await ctx.runMutation(api.adminOtp.sendOTP, { email });
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  } catch (error) {
    const message = sanitizeErrorMessage(error);
    return new Response(JSON.stringify({ error: message }), {
      status: 400,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  }
});

const verifyOtpHandler = httpAction(async (ctx, request) => {
  if (!validateAdminOrigin(request)) {
    return new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  }

  const body = await request.json();
  const { email, otp } = body;

  if (!email || !otp) {
    return new Response(JSON.stringify({ error: "Missing email or otp" }), {
      status: 400,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  }

  try {
    const result = await ctx.runMutation(api.adminOtp.verifyOTP, { email, otp });
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  } catch (error) {
    const message = sanitizeErrorMessage(error);
    return new Response(JSON.stringify({ error: message }), {
      status: 400,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  }
});

http.route({
  path: "/admin/send-otp",
  method: "POST",
  handler: sendOtpHandler,
});

http.route({
  path: "/admin/verify-otp",
  method: "POST",
  handler: verifyOtpHandler,
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
