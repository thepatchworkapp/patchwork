import { httpRouter } from "convex/server";
import { authComponent, createAuth } from "./auth";
import { api } from "./_generated/api";
import { httpAction } from "./_generated/server";

const http = httpRouter();

authComponent.registerRoutes(http, createAuth, { cors: true });

const sendOtpHandler = httpAction(async (ctx, request) => {
  const body = await request.json();
  const { email, otp } = body;

  if (!email || !otp) {
    return new Response(JSON.stringify({ error: "Missing email or otp" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const result = await ctx.runMutation(api.adminOtp.sendOTP, { email, otp });
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return new Response(JSON.stringify({ error: message }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
});

const verifyOtpHandler = httpAction(async (ctx, request) => {
  const body = await request.json();
  const { email, otp } = body;

  if (!email || !otp) {
    return new Response(JSON.stringify({ error: "Missing email or otp" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const result = await ctx.runMutation(api.adminOtp.verifyOTP, { email, otp });
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return new Response(JSON.stringify({ error: message }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
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
