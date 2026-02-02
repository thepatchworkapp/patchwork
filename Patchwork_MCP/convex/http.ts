import { httpRouter } from "convex/server";
import { authComponent, createAuth } from "./auth";
import { api } from "./_generated/api";

const http = httpRouter();

authComponent.registerRoutes(http, createAuth, { cors: true });

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

http.route({
  path: "/admin/send-otp",
  method: "OPTIONS",
  handler: async () => {
    return new Response(null, { status: 204, headers: corsHeaders });
  },
});

http.route({
  path: "/admin/send-otp",
  method: "POST",
  handler: async (ctx, request) => {
    const body = await request.json();
    const { email, otp } = body;

    if (!email || !otp) {
      return new Response(JSON.stringify({ error: "Missing email or otp" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    try {
      const result = await ctx.runMutation(api.adminOtp.sendOTP, { email, otp });
      return new Response(JSON.stringify(result), {
        status: 200,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown error";
      return new Response(JSON.stringify({ error: message }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }
  },
});

http.route({
  path: "/admin/verify-otp",
  method: "OPTIONS",
  handler: async () => {
    return new Response(null, { status: 204, headers: corsHeaders });
  },
});

http.route({
  path: "/admin/verify-otp",
  method: "POST",
  handler: async (ctx, request) => {
    const body = await request.json();
    const { email, otp } = body;

    if (!email || !otp) {
      return new Response(JSON.stringify({ error: "Missing email or otp" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    try {
      const result = await ctx.runMutation(api.adminOtp.verifyOTP, { email, otp });
      return new Response(JSON.stringify(result), {
        status: 200,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown error";
      return new Response(JSON.stringify({ error: message }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }
  },
});

export default http;
