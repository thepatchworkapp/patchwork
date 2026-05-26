import { v } from "convex/values";
import { internalAction, internalMutation, internalQuery } from "./_generated/server";
import { internal } from "./_generated/api";
import { Id } from "./_generated/dataModel";

const MAX_PUSH_TOKENS = 20;
const DEFAULT_APNS_TOPIC = "ltd.ddga.patchwork";

type PushTokenSnapshot = {
  tokenId: Id<"pushTokens">;
  token: string;
  environment: "sandbox" | "production";
};

type ApnsConfig = {
  keyId: string;
  teamId: string;
  topic: string;
  privateKey: string;
};

export const getPushSnapshot = internalQuery({
  args: {
    recipientId: v.id("users"),
  },
  returns: v.object({
    enabled: v.boolean(),
    badgeCount: v.number(),
    tokens: v.array(v.object({
      tokenId: v.id("pushTokens"),
      token: v.string(),
      environment: v.union(v.literal("sandbox"), v.literal("production")),
    })),
  }),
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.recipientId);
    if (!user || user.settings?.notificationsEnabled === false) {
      return { enabled: false, badgeCount: 0, tokens: [] };
    }

    const [seekerConversations, taskerConversations, pushTokens] = await Promise.all([
      ctx.db
        .query("conversations")
        .withIndex("by_seeker_lastMessage", (q) => q.eq("seekerId", args.recipientId))
        .take(200),
      ctx.db
        .query("conversations")
        .withIndex("by_tasker_lastMessage", (q) => q.eq("taskerId", args.recipientId))
        .take(200),
      ctx.db
        .query("pushTokens")
        .withIndex("by_user", (q) => q.eq("userId", args.recipientId))
        .take(MAX_PUSH_TOKENS),
    ]);

    const badgeCount = [...seekerConversations, ...taskerConversations].reduce((total, conversation) => {
      if (conversation.seekerId === args.recipientId) {
        return total + (conversation.seekerUnreadCount ?? 0);
      }
      return total + (conversation.taskerUnreadCount ?? 0);
    }, 0);

    const tokens: PushTokenSnapshot[] = pushTokens
      .filter((token) => !token.disabledAt)
      .map((token) => ({
        tokenId: token._id,
        token: token.token,
        environment: token.environment,
      }));

    return {
      enabled: true,
      badgeCount,
      tokens,
    };
  },
});

export const disablePushToken = internalMutation({
  args: {
    tokenId: v.id("pushTokens"),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    await ctx.db.patch(args.tokenId, {
      disabledAt: Date.now(),
      updatedAt: Date.now(),
    });
    return null;
  },
});

export const sendChatNotification = internalAction({
  args: {
    recipientId: v.id("users"),
    senderId: v.id("users"),
    conversationId: v.id("conversations"),
    messageId: v.optional(v.id("messages")),
    title: v.string(),
    body: v.string(),
  },
  returns: v.object({
    sent: v.number(),
    skipped: v.number(),
  }),
  handler: async (ctx, args) => {
    const snapshot = await ctx.runQuery(internal.notifications.getPushSnapshot, {
      recipientId: args.recipientId,
    });
    if (!snapshot.enabled || snapshot.tokens.length === 0) {
      return { sent: 0, skipped: snapshot.tokens.length };
    }

    const config = getApnsConfig();
    if (!config) {
      return { sent: 0, skipped: snapshot.tokens.length };
    }

    const jwt = await createApnsJwt(config);
    const payload = {
      aps: {
        alert: {
          title: sanitizeAlertText(args.title, "Patchwork"),
          body: sanitizeAlertText(args.body, "New message"),
        },
        badge: snapshot.badgeCount,
        sound: "default",
        "thread-id": String(args.conversationId),
      },
      conversationId: String(args.conversationId),
      senderId: String(args.senderId),
      messageId: args.messageId ? String(args.messageId) : undefined,
    };

    let sent = 0;
    let skipped = 0;

    await Promise.all(snapshot.tokens.map(async (token) => {
      const result = await sendApnsNotification(token, config, jwt, payload);
      if (result.sent) {
        sent += 1;
        return;
      }

      skipped += 1;
      if (result.disableToken) {
        await ctx.runMutation(internal.notifications.disablePushToken, {
          tokenId: token.tokenId,
        });
      }
    }));

    return { sent, skipped };
  },
});

async function sendApnsNotification(
  token: PushTokenSnapshot,
  config: ApnsConfig,
  jwt: string,
  payload: unknown,
): Promise<{ sent: boolean; disableToken: boolean }> {
  const host = token.environment === "production"
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";
  const response = await fetch(`${host}/3/device/${token.token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": config.topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (response.ok) {
    return { sent: true, disableToken: false };
  }

  let reason = "";
  try {
    reason = String((await response.json() as { reason?: string }).reason ?? "");
  } catch {
    reason = "";
  }

  const disableToken =
    response.status === 410
    || reason === "BadDeviceToken"
    || reason === "Unregistered"
    || reason === "DeviceTokenNotForTopic";

  return { sent: false, disableToken };
}

function getApnsConfig(): ApnsConfig | null {
  const keyId = process.env.APNS_KEY_ID?.trim();
  const teamId = process.env.APNS_TEAM_ID?.trim();
  const privateKey = process.env.APNS_PRIVATE_KEY?.replace(/\\n/g, "\n").trim();
  const topic = process.env.APNS_BUNDLE_ID?.trim() || DEFAULT_APNS_TOPIC;

  if (!keyId || !teamId || !privateKey) {
    return null;
  }

  return {
    keyId,
    teamId,
    topic,
    privateKey,
  };
}

async function createApnsJwt(config: ApnsConfig): Promise<string> {
  const header = {
    alg: "ES256",
    kid: config.keyId,
  };
  const claims = {
    iss: config.teamId,
    iat: Math.floor(Date.now() / 1000),
  };
  const signingInput = `${base64UrlJson(header)}.${base64UrlJson(claims)}`;
  const key = await importPrivateKey(config.privateKey);
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );

  return `${signingInput}.${base64UrlBytes(normalizeEcdsaSignature(new Uint8Array(signature)))}`;
}

async function importPrivateKey(privateKey: string): Promise<CryptoKey> {
  const body = privateKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binary = atob(body);
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));

  return await crypto.subtle.importKey(
    "pkcs8",
    bytes.buffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
}

function normalizeEcdsaSignature(signature: Uint8Array): Uint8Array {
  if (signature.length === 64) {
    return signature;
  }

  if (signature[0] !== 0x30) {
    return signature;
  }

  let offset = signature[1] > 0x80 ? 2 + (signature[1] & 0x7f) : 2;
  if (signature[offset] !== 0x02) {
    return signature;
  }
  const rLength = signature[offset + 1];
  const r = signature.slice(offset + 2, offset + 2 + rLength);
  offset += 2 + rLength;
  if (signature[offset] !== 0x02) {
    return signature;
  }
  const sLength = signature[offset + 1];
  const s = signature.slice(offset + 2, offset + 2 + sLength);

  const normalized = new Uint8Array(64);
  normalized.set(trimAndPadInteger(r), 0);
  normalized.set(trimAndPadInteger(s), 32);
  return normalized;
}

function trimAndPadInteger(value: Uint8Array): Uint8Array {
  const trimmed = value[0] === 0 ? value.slice(1) : value;
  const padded = new Uint8Array(32);
  padded.set(trimmed.slice(-32), Math.max(0, 32 - trimmed.length));
  return padded;
}

function base64UrlJson(value: unknown): string {
  return base64UrlBytes(new TextEncoder().encode(JSON.stringify(value)));
}

function base64UrlBytes(bytes: Uint8Array): string {
  let binary = "";
  for (let index = 0; index < bytes.length; index += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(index, index + 0x8000));
  }
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function sanitizeAlertText(value: string, fallback: string): string {
  const trimmed = value.trim();
  if (!trimmed) {
    return fallback;
  }
  if (trimmed.length <= 178) {
    return trimmed;
  }
  return `${trimmed.slice(0, 175)}...`;
}
