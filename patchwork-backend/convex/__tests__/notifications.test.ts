import { Buffer } from "node:buffer";
import { convexTest } from "convex-test";
import { afterEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "../_generated/api";
import schema from "../schema";
import * as authModule from "../auth";
import * as categoriesModule from "../categories";
import * as conversationsModule from "../conversations";
import * as filesModule from "../files";
import * as httpModule from "../http";
import * as jobsModule from "../jobs";
import * as messagesModule from "../messages";
import * as moderationModule from "../moderation";
import * as notificationsModule from "../notifications";
import * as proposalsModule from "../proposals";
import * as taskersModule from "../taskers";
import * as usersModule from "../users";

const modules: Record<string, () => Promise<any>> = {
  "../auth.ts": async () => authModule,
  "../categories.ts": async () => categoriesModule,
  "../conversations.ts": async () => conversationsModule,
  "../files.ts": async () => filesModule,
  "../http.ts": async () => httpModule,
  "../jobs.ts": async () => jobsModule,
  "../messages.ts": async () => messagesModule,
  "../moderation.ts": async () => moderationModule,
  "../notifications.ts": async () => notificationsModule,
  "../proposals.ts": async () => proposalsModule,
  "../taskers.ts": async () => taskersModule,
  "../users.ts": async () => usersModule,
  "../_generated/api.ts": async () => ({ default: api }),
  "../schema.ts": async () => ({ default: schema }),
};

const APNS_ENV_KEYS = [
  "APNS_KEY_ID",
  "APNS_TEAM_ID",
  "APNS_PRIVATE_KEY",
  "APNS_BUNDLE_ID",
] as const;

const originalApnsEnv = Object.fromEntries(
  APNS_ENV_KEYS.map((key) => [key, process.env[key]])
) as Record<(typeof APNS_ENV_KEYS)[number], string | undefined>;

afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllGlobals();
  for (const key of APNS_ENV_KEYS) {
    const originalValue = originalApnsEnv[key];
    if (originalValue === undefined) {
      delete process.env[key];
    } else {
      process.env[key] = originalValue;
    }
  }
});

async function createConversation(t: ReturnType<typeof convexTest>, suffix: string) {
  const asSeeker = t.withIdentity({
    tokenIdentifier: `google|notification-seeker-${suffix}`,
    email: `notification-seeker-${suffix}@example.com`,
  });
  const seekerId = await asSeeker.mutation(api.users.createProfile, {
    name: `Notification Seeker ${suffix}`,
    city: "Toronto",
    province: "ON",
    notificationsEnabled: true,
  });

  const asTasker = t.withIdentity({
    tokenIdentifier: `google|notification-tasker-${suffix}`,
    email: `notification-tasker-${suffix}@example.com`,
  });
  const taskerId = await asTasker.mutation(api.users.createProfile, {
    name: `Notification Tasker ${suffix}`,
    city: "Toronto",
    province: "ON",
    notificationsEnabled: true,
  });

  const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
    taskerId,
  });

  return { asSeeker, asTasker, seekerId, taskerId, conversationId };
}

async function scheduledNotificationJobs(t: ReturnType<typeof convexTest>) {
  return await t.run(async (ctx: any) => {
    const jobs = await ctx.db.system.query("_scheduled_functions").collect();
    return jobs.filter((job: any) => job.name === "notifications:sendChatNotification");
  });
}

async function testApnsPrivateKeyPem() {
  const keyPair = await globalThis.crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"]
  );
  const pkcs8 = await globalThis.crypto.subtle.exportKey("pkcs8", keyPair.privateKey);
  const base64 = Buffer.from(pkcs8)
    .toString("base64")
    .match(/.{1,64}/g)!
    .join("\n");
  return `-----BEGIN PRIVATE KEY-----\n${base64}\n-----END PRIVATE KEY-----`;
}

describe("notifications", () => {
  test("sendMessage schedules a chat notification and increments the recipient badge count", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema, modules);
    const { asSeeker, asTasker, taskerId, seekerId, conversationId } = await createConversation(t, "message");

    await asTasker.mutation(api.users.registerPushToken, {
      token: "tasker-message-token",
      environment: "sandbox",
    });

    const messageId = await asSeeker.mutation(api.messages.sendMessage, {
      conversationId,
      content: "Can you help with a repair?",
    });

    const jobs = await scheduledNotificationJobs(t);
    expect(jobs).toHaveLength(1);
    expect(jobs[0].state.kind).toBe("pending");
    expect(jobs[0].args[0]).toMatchObject({
      recipientId: taskerId,
      senderId: seekerId,
      conversationId,
      messageId,
      title: "Notification Seeker message",
      body: "Can you help with a repair?",
    });
    expect(await asTasker.query(api.users.getUnreadBadgeCount)).toBe(1);
  });

  test("sendProposal schedules a proposal notification and increments the receiver badge count", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema, modules);
    const { asSeeker, asTasker, seekerId, taskerId, conversationId } = await createConversation(t, "proposal");

    await asSeeker.mutation(api.users.registerPushToken, {
      token: "seeker-proposal-token",
      environment: "sandbox",
    });

    await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 12_500,
      rateType: "flat",
      startDateTime: "2026-06-08T13:00:00.000Z",
      notes: "I can handle this next week.",
    });

    const jobs = await scheduledNotificationJobs(t);
    expect(jobs).toHaveLength(1);
    expect(jobs[0].state.kind).toBe("pending");
    expect(jobs[0].args[0]).toMatchObject({
      recipientId: seekerId,
      senderId: taskerId,
      conversationId,
      title: "Notification Tasker proposal",
      body: "New proposal",
    });
    expect(jobs[0].args[0].messageId).toBeDefined();
    expect(await asSeeker.query(api.users.getUnreadBadgeCount)).toBe(1);
  });

  test("sendChatNotification sends APNs alert payload with current unread badge count", async () => {
    const t = convexTest(schema, modules);
    const { asTasker, seekerId, taskerId, conversationId } = await createConversation(t, "apns");

    await asTasker.mutation(api.users.registerPushToken, {
      token: "sandbox-token",
      environment: "sandbox",
    });

    const messageId = await t.run(async (ctx: any) => {
      await ctx.db.patch(conversationId, {
        taskerUnreadCount: 2,
      });
      return await ctx.db.insert("messages", {
        conversationId,
        senderId: seekerId,
        type: "text",
        content: "The details are ready.",
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });
    });

    process.env.APNS_KEY_ID = "KEY123ABC";
    process.env.APNS_TEAM_ID = "TEAM123ABC";
    process.env.APNS_PRIVATE_KEY = await testApnsPrivateKeyPem();
    process.env.APNS_BUNDLE_ID = "ltd.ddga.patchwork.test";
    const fetchMock = vi.fn(async () => new Response(null, { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);

    const result = await t.action(internal.notifications.sendChatNotification, {
      recipientId: taskerId,
      senderId: seekerId,
      conversationId,
      messageId,
      title: "Notification Seeker",
      body: "The details are ready.",
    });

    expect(result).toEqual({ sent: 1, skipped: 0 });
    expect(fetchMock).toHaveBeenCalledTimes(1);

    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toBe("https://api.sandbox.push.apple.com/3/device/sandbox-token");
    expect(init.method).toBe("POST");
    expect(init.headers).toMatchObject({
      "apns-topic": "ltd.ddga.patchwork.test",
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    });
    expect((init.headers as Record<string, string>).authorization).toMatch(/^bearer /);

    const payload = JSON.parse(String(init.body));
    expect(payload).toEqual({
      aps: {
        alert: {
          title: "Notification Seeker",
          body: "The details are ready.",
        },
        badge: 2,
        sound: "default",
        "thread-id": String(conversationId),
      },
      conversationId: String(conversationId),
      senderId: String(seekerId),
      messageId: String(messageId),
    });
  });
});
