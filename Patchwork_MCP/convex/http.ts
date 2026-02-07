import { httpRouter } from "convex/server";
import { authComponent, createAuth } from "./auth";
import { api } from "./_generated/api";
import { httpAction } from "./_generated/server";

const http = httpRouter();

authComponent.registerRoutes(http, createAuth, { cors: true });

const adminAppOrigin = process.env.ADMIN_APP_ORIGIN || "http://localhost:5174";

function validateAdminOrigin(request: Request) {
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

export default http;
