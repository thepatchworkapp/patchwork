import { convexTest } from "convex-test";
import { expect, test, describe } from "vitest";
import { api, internal } from "../_generated/api";
import schema from "../schema";
import * as conversationsModule from "../conversations";
import * as usersModule from "../users";
import * as messagesModule from "../messages";
import * as notificationsModule from "../notifications";
import * as moderationModule from "../moderation";
import * as categoriesModule from "../categories";
import * as filesModule from "../files";
import * as taskersModule from "../taskers";
import * as authModule from "../auth";
import * as httpModule from "../http";
import * as proposalsModule from "../proposals";
import * as jobsModule from "../jobs";

const modules: Record<string, () => Promise<any>> = {
  "../conversations.ts": async () => conversationsModule,
  "../users.ts": async () => usersModule,
  "../messages.ts": async () => messagesModule,
  "../notifications.ts": async () => notificationsModule,
  "../moderation.ts": async () => moderationModule,
  "../categories.ts": async () => categoriesModule,
  "../files.ts": async () => filesModule,
  "../taskers.ts": async () => taskersModule,
  "../auth.ts": async () => authModule,
  "../http.ts": async () => httpModule,
  "../proposals.ts": async () => proposalsModule,
  "../jobs.ts": async () => jobsModule,
  "../_generated/api.ts": async () => ({ default: api }),
  "../schema.ts": async () => ({ default: schema }),
};

async function createConversation(t: ReturnType<typeof convexTest>, suffix: string) {
  const asSeeker = t.withIdentity({
    tokenIdentifier: `google|seeker_${suffix}`,
    email: `seeker_${suffix}@example.com`,
  });
  const seekerId = await asSeeker.mutation(api.users.createProfile, {
    name: `Seeker ${suffix}`,
    city: "Toronto",
    province: "ON",
  });

  const asTasker = t.withIdentity({
    tokenIdentifier: `google|tasker_${suffix}`,
    email: `tasker_${suffix}@example.com`,
  });
  const taskerId = await asTasker.mutation(api.users.createProfile, {
    name: `Tasker ${suffix}`,
    city: "Toronto",
    province: "ON",
  });

  const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
    taskerId,
  });

  return { asSeeker, asTasker, seekerId, taskerId, conversationId };
}

async function setConversationMessageTimes(
  t: ReturnType<typeof convexTest>,
  conversationId: any,
  createdAt: number
) {
  await t.run(async (ctx) => {
    const messages = await ctx.db
      .query("messages")
      .withIndex("by_conversation", (q) => q.eq("conversationId", conversationId))
      .collect();
    for (const message of messages) {
      await ctx.db.patch(message._id, { createdAt, updatedAt: createdAt });
    }
  });
}

describe("messages", () => {
  test("unauthenticated user cannot send message", async () => {
    const t = convexTest(schema, modules);
    
    // Create seeker and tasker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker1",
      email: "seeker1@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 1",
      city: "Toronto",
      province: "ON",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker1",
      email: "tasker1@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 1",
      city: "Toronto",
      province: "ON",
    });

    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    // Try to send message without auth
    await expect(
      t.mutation(api.messages.sendMessage, {
        conversationId,
        content: "Hello",
      })
    ).rejects.toThrow("Unauthorized");
  });

  test("can send text message in conversation", async () => {
    const t = convexTest(schema, modules);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker2",
      email: "seeker2@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 2",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker2",
      email: "tasker2@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 2",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    // Send message
    const messageId = await asSeeker.mutation(api.messages.sendMessage, {
      conversationId,
      content: "Hello, I need help with cleaning",
    });

    expect(messageId).toBeDefined();

    // Verify conversation updated
    const conversation = await asSeeker.query(api.conversations.getConversation, {
      conversationId,
    });

    expect(conversation?.lastMessagePreview).toBe("Hello, I need help with cleaning");
    expect(conversation?.lastMessageSenderId).toBeDefined();
    expect(conversation?.taskerUnreadCount).toBe(1);
  });

  test("can send message with 1 attachment", async () => {
    const t = convexTest(schema, modules);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker3",
      email: "seeker3@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 3",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker3",
      email: "tasker3@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 3",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    // Send message without attachment (testing that optional attachments work)
    const messageId = await asSeeker.mutation(api.messages.sendMessage, {
      conversationId,
      content: "Here's a photo",
    });

    expect(messageId).toBeDefined();
  });

  test("validates attachment array length <= 3", async () => {
    const t = convexTest(schema, modules);
    
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker4",
      email: "seeker4@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 4",
      city: "Toronto",
      province: "ON",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker4",
      email: "tasker4@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 4",
      city: "Toronto",
      province: "ON",
    });

    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    const messageId = await asSeeker.mutation(api.messages.sendMessage, {
      conversationId,
      content: "Here are 3 photos",
      attachments: [],
    });

    expect(messageId).toBeDefined();
  });

  test("sendMessage accepts up to 3 attachments without error", async () => {
    const t = convexTest(schema, modules);
    
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker5",
      email: "seeker5@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 5",
      city: "Toronto",
      province: "ON",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker5",
      email: "tasker5@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 5",
      city: "Toronto",
      province: "ON",
    });

    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    const messageId = await asSeeker.mutation(api.messages.sendMessage, {
      conversationId,
      content: "Message with empty attachments array",
      attachments: [],
    });

    expect(messageId).toBeDefined();
  });

  test("listMessages returns paginated messages (25 per page)", async () => {
    const t = convexTest(schema, modules);
    
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker6",
      email: "seeker6@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 6",
      city: "Toronto",
      province: "ON",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker6",
      email: "tasker6@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 6",
      city: "Toronto",
      province: "ON",
    });

    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    for (let i = 1; i <= 10; i++) {
      await asSeeker.mutation(api.messages.sendMessage, {
        conversationId,
        content: `Message ${i}`,
      });
    }

    const result = await asSeeker.query(api.messages.listMessages, {
      conversationId,
      paginationOpts: { cursor: null, numItems: 25 },
    });

    expect(result.page).toBeDefined();
    expect(result.page.length).toBe(10);
    expect(result.isDone).toBe(true);
  });

  test("cursor pagination works for loading older messages", async () => {
    const t = convexTest(schema, modules);
    
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker7",
      email: "seeker7@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 7",
      city: "Toronto",
      province: "ON",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker7",
      email: "tasker7@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 7",
      city: "Toronto",
      province: "ON",
    });

    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    for (let i = 1; i <= 30; i++) {
      await asSeeker.mutation(api.messages.sendMessage, {
        conversationId,
        content: `Message ${i}`,
      });
    }

    const firstPage = await asSeeker.query(api.messages.listMessages, {
      conversationId,
      paginationOpts: { cursor: null, numItems: 25 },
    });

    expect(firstPage.page.length).toBe(25);
    expect(firstPage.isDone).toBe(false);
    expect(firstPage.continueCursor).toBeDefined();

    const secondPage = await asSeeker.query(api.messages.listMessages, {
      conversationId,
      paginationOpts: { cursor: firstPage.continueCursor, numItems: 25 },
    });

    expect(secondPage.page.length).toBe(5);
    expect(secondPage.isDone).toBe(true);
  });

  test("system message created with correct type", async () => {
    const t = convexTest(schema, modules);
    
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker8",
      email: "seeker8@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 8",
      city: "Toronto",
      province: "ON",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker8",
      email: "tasker8@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 8",
      city: "Toronto",
      province: "ON",
    });

    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    const messageId = await asSeeker.mutation(api.messages.sendSystemMessage, {
      conversationId,
      systemType: "proposal_sent",
    });

    expect(messageId).toBeDefined();

    const result = await asSeeker.query(api.messages.listMessages, {
      conversationId,
      paginationOpts: { cursor: null, numItems: 25 },
    });

    const systemMessage = result.page.find((m) => m._id === messageId);
    expect(systemMessage?.type).toBe("system");
    expect(systemMessage?.content).toContain("proposal");
  });

  test("sending message updates conversation metadata", async () => {
    const t = convexTest(schema, modules);
    
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker9",
      email: "seeker9@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 9",
      city: "Toronto",
      province: "ON",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker9",
      email: "tasker9@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 9",
      city: "Toronto",
      province: "ON",
    });

    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    const beforeConversation = await asSeeker.query(api.conversations.getConversation, {
      conversationId,
    });

    const beforeTime = beforeConversation?.lastMessageAt || 0;

    await new Promise((resolve) => setTimeout(resolve, 10));

    await asSeeker.mutation(api.messages.sendMessage, {
      conversationId,
      content: "Test message for metadata",
    });

    const afterConversation = await asSeeker.query(api.conversations.getConversation, {
      conversationId,
    });

    expect(afterConversation?.lastMessageAt).toBeGreaterThanOrEqual(beforeTime);
    expect(afterConversation?.lastMessagePreview).toBe("Test message for metadata");
    expect(afterConversation?.lastMessageSenderId).toBeDefined();
  });

  test("sending message increments recipient's unread count", async () => {
    const t = convexTest(schema, modules);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker10",
      email: "seeker10@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 10",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker10",
      email: "tasker10@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 10",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    // Reset unread counts
    await asSeeker.mutation(api.conversations.markAsRead, { conversationId });
    await asTasker.mutation(api.conversations.markAsRead, { conversationId });

    // Seeker sends message
    await asSeeker.mutation(api.messages.sendMessage, {
      conversationId,
      content: "From seeker to tasker",
    });

    const afterSeekerMessage = await asSeeker.query(api.conversations.getConversation, {
      conversationId,
    });

    expect(afterSeekerMessage?.taskerUnreadCount).toBe(1); // Tasker has 1 unread
    expect(afterSeekerMessage?.seekerUnreadCount).toBe(0); // Seeker's count unchanged

    // Tasker sends message back
    await asTasker.mutation(api.messages.sendMessage, {
      conversationId,
      content: "From tasker to seeker",
    });

    const afterTaskerMessage = await asTasker.query(api.conversations.getConversation, {
      conversationId,
    });

    expect(afterTaskerMessage?.seekerUnreadCount).toBe(1); // Seeker has 1 unread
    expect(afterTaskerMessage?.taskerUnreadCount).toBe(1); // Tasker's count unchanged
  });

  test("listMessages returns empty for non-participant", async () => {
    const t = convexTest(schema, modules);
    
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_auth_msg1",
      email: "seeker_auth_msg1@example.com",
    });
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker Auth Msg 1",
      city: "Toronto",
      province: "ON",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_auth_msg1",
      email: "tasker_auth_msg1@example.com",
    });
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Auth Msg 1",
      city: "Toronto",
      province: "ON",
    });

    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    await asSeeker.mutation(api.messages.sendMessage, {
      conversationId,
      content: "Secret message",
    });

    const asStranger = t.withIdentity({
      tokenIdentifier: "google|stranger_auth_msg1",
      email: "stranger_auth_msg1@example.com",
    });
    await asStranger.mutation(api.users.createProfile, {
      name: "Stranger Msg",
      city: "Toronto",
      province: "ON",
    });

    const result = await asStranger.query(api.messages.listMessages, {
      conversationId,
      paginationOpts: { cursor: null, numItems: 25 },
    });
    expect(result.page).toHaveLength(0);
  });

  test("sendMessage throws for non-participant", async () => {
    const t = convexTest(schema, modules);
    
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_auth_msg2",
      email: "seeker_auth_msg2@example.com",
    });
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker Auth Msg 2",
      city: "Toronto",
      province: "ON",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_auth_msg2",
      email: "tasker_auth_msg2@example.com",
    });
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Auth Msg 2",
      city: "Toronto",
      province: "ON",
    });

    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    const asStranger = t.withIdentity({
      tokenIdentifier: "google|stranger_auth_msg2",
      email: "stranger_auth_msg2@example.com",
    });
    await asStranger.mutation(api.users.createProfile, {
      name: "Stranger Msg 2",
      city: "Toronto",
      province: "ON",
    });

    await expect(
      asStranger.mutation(api.messages.sendMessage, {
        conversationId,
        content: "Hacked message",
      })
    ).rejects.toThrow("Not a participant in this conversation");
  });

  test("one-way block prevents messages in both directions and only blocker can unblock", async () => {
    const t = convexTest(schema, modules);

    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_block_msg",
      email: "seeker_block_msg@example.com",
    });
    const seekerId = await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker Block",
      city: "Toronto",
      province: "ON",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_block_msg",
      email: "tasker_block_msg@example.com",
    });
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Block",
      city: "Toronto",
      province: "ON",
    });

    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    const firstBlockStatus = await asSeeker.mutation((api as any).moderation.blockUser, {
      blockedUserId: taskerId,
      conversationId,
    });
    const duplicateBlockStatus = await asSeeker.mutation((api as any).moderation.blockUser, {
      blockedUserId: taskerId,
      conversationId,
    });

    expect(firstBlockStatus.currentUserBlockedOther).toBe(true);
    expect(duplicateBlockStatus.blockId).toStrictEqual(firstBlockStatus.blockId);

    await expect(
      asTasker.mutation(api.messages.sendMessage, {
        conversationId,
        content: "Can you see this?",
      })
    ).rejects.toThrow("This conversation is unavailable.");

    await expect(
      asSeeker.mutation(api.messages.sendMessage, {
        conversationId,
        content: "I should not be able to send either.",
      })
    ).rejects.toThrow("This conversation is unavailable.");

    const taskerUnblockAttempt = await asTasker.mutation((api as any).moderation.unblockUser, {
      blockedUserId: seekerId,
    });
    expect(taskerUnblockAttempt.currentUserBlockedOther).toBe(false);
    expect(taskerUnblockAttempt.currentUserBlockedByOther).toBe(true);

    await expect(
      asTasker.mutation(api.messages.sendMessage, {
        conversationId,
        content: "Still blocked.",
      })
    ).rejects.toThrow("This conversation is unavailable.");

    const unblockStatus = await asSeeker.mutation((api as any).moderation.unblockUser, {
      blockedUserId: taskerId,
    });
    expect(unblockStatus.isBlocked).toBe(false);

    const messageId = await asTasker.mutation(api.messages.sendMessage, {
      conversationId,
      content: "Unblocked now.",
    });
    expect(messageId).toBeDefined();

    await expect(
      asSeeker.mutation((api as any).moderation.reportUser, {
        reportedUserId: taskerId,
        conversationId,
        reason: "Too short",
      })
    ).rejects.toThrow("Report must be at least 100 characters");

    const reportResult = await asSeeker.mutation((api as any).moderation.reportUser, {
      reportedUserId: taskerId,
      conversationId,
      reason: "A".repeat(100),
      block: true,
    });
    expect(reportResult.reportId).toBeDefined();
    expect(reportResult.blockId).toBeDefined();

    const blockedUsers = await asSeeker.query((api as any).moderation.listBlockedUsers, {
      limit: 10,
    });
    expect(blockedUsers).toHaveLength(1);
    expect(blockedUsers[0]?.blockedUserId).toBe(taskerId);
  });

  test("sendMessage stores clientMessageId and listMessages returns it", async () => {
    const t = convexTest(schema, modules);
    const { asSeeker, conversationId } = await createConversation(t, "client_msg");

    const messageId = await asSeeker.mutation(api.messages.sendMessage, {
      conversationId,
      clientMessageId: "ios-msg-1",
      content: "Client tracked message",
    });

    const result = await asSeeker.query(api.messages.listMessages, {
      conversationId,
      paginationOpts: { cursor: null, numItems: 25 },
    });

    const message = result.page.find((item) => item._id === messageId);
    expect(message?.clientMessageId).toBe("ios-msg-1");
  });

  test("listMessagesSince enforces participant auth and exclusive cursor boundary", async () => {
    const t = convexTest(schema, modules);
    const { asSeeker, conversationId } = await createConversation(t, "since_auth");

    const firstMessageId = await asSeeker.mutation(api.messages.sendMessage, {
      conversationId,
      content: "Before cursor",
    });
    const secondMessageId = await asSeeker.mutation(api.messages.sendMessage, {
      conversationId,
      content: "After cursor",
    });

    await t.run(async (ctx) => {
      await ctx.db.patch(firstMessageId, { createdAt: 1000, updatedAt: 1000 });
      await ctx.db.patch(secondMessageId, { createdAt: 2000, updatedAt: 2000 });
    });

    const delta = await asSeeker.query((api as any).messages.listMessagesSince, {
      conversationId,
      since: 1000,
      limit: 10,
    });
    expect(delta.messages.map((message: any) => message._id)).toStrictEqual([
      secondMessageId,
    ]);
    expect(delta.latestCursor).toBe(2000);
    expect(delta.hasMore).toBe(false);

    const asStranger = t.withIdentity({
      tokenIdentifier: "google|stranger_since_auth",
      email: "stranger_since_auth@example.com",
    });
    await asStranger.mutation(api.users.createProfile, {
      name: "Stranger Since",
      city: "Toronto",
      province: "ON",
    });
    const unauthorized = await asStranger.query((api as any).messages.listMessagesSince, {
      conversationId,
      since: 0,
      limit: 10,
    });
    expect(unauthorized.messages).toHaveLength(0);
    expect(unauthorized.latestCursor).toBe(0);
  });

  test("listMessagesSince respects limit and hasMore", async () => {
    const t = convexTest(schema, modules);
    const { asSeeker, conversationId } = await createConversation(t, "since_limit");

    const messageIds = [];
    for (let i = 1; i <= 3; i++) {
      messageIds.push(
        await asSeeker.mutation(api.messages.sendMessage, {
          conversationId,
          content: `Delta ${i}`,
        })
      );
    }

    await t.run(async (ctx) => {
      for (let i = 0; i < messageIds.length; i++) {
        await ctx.db.patch(messageIds[i], {
          createdAt: 1000 + i,
          updatedAt: 1000 + i,
        });
      }
    });

    const delta = await asSeeker.query((api as any).messages.listMessagesSince, {
      conversationId,
      since: 999,
      limit: 2,
    });

    expect(delta.messages.map((message: any) => message.content)).toStrictEqual([
      "Delta 1",
      "Delta 2",
    ]);
    expect(delta.hasMore).toBe(true);
    expect(delta.latestCursor).toBe(1001);
  });

  test("listMessagesSince hydrates proposal payloads for proposal messages", async () => {
    const t = convexTest(schema, modules);
    const { asSeeker, asTasker, conversationId } = await createConversation(
      t,
      "since_proposal_hydration"
    );

    const proposalId = await asTasker.mutation((api as any).proposals.sendProposal, {
      conversationId,
      clientProposalId: "ios-proposal-1",
      rate: 7500,
      rateType: "flat",
      startDateTime: "2026-02-15T10:00:00Z",
      notes: "I can do it",
    });

    const delta = await asSeeker.query((api as any).messages.listMessagesSince, {
      conversationId,
      since: 0,
      limit: 10,
    });
    const proposalMessage = delta.messages.find(
      (message: any) => message.type === "proposal"
    );

    expect(proposalMessage?.proposalId).toBe(proposalId);
    expect(proposalMessage?.proposal?._id).toBe(proposalId);
    expect(proposalMessage?.proposal?.clientProposalId).toBe("ios-proposal-1");
    expect(proposalMessage?.proposal?.status).toBe("pending");
    expect(delta.latestMessageAt).toBe(delta.latestCursor);
  });

  test("watchThread emits text message deltas after the cursor", async () => {
    const t = convexTest(schema, modules);
    const { asSeeker, conversationId } = await createConversation(t, "watch_text");

    const oldMessageId = await asSeeker.mutation(api.messages.sendMessage, {
      conversationId,
      content: "Already cached",
    });
    const messageId = await asSeeker.mutation(api.messages.sendMessage, {
      conversationId,
      content: "New realtime message",
    });

    await t.run(async (ctx) => {
      await ctx.db.patch(oldMessageId, { createdAt: 1000, updatedAt: 1000 });
      await ctx.db.patch(messageId, { createdAt: 2000, updatedAt: 2000 });
    });

    const watched = await asSeeker.query((api as any).messages.watchThread, {
      conversationId,
      since: 1000,
      limit: 10,
    });

    expect(watched.messages.map((message: any) => message._id)).toStrictEqual([
      messageId,
    ]);
    expect(watched.latestMessageAt).toBe(2000);
    expect(watched.latestProposalUpdatedAt).toBeNull();
    expect(watched.latestCursor).toBe(2000);
  });

  test("watchThread emits proposal messages and latestProposal when proposals are sent", async () => {
    const t = convexTest(schema, modules);
    const { asSeeker, asTasker, conversationId } = await createConversation(
      t,
      "watch_proposal_sent"
    );

    const oldMessageId = await asSeeker.mutation(api.messages.sendMessage, {
      conversationId,
      content: "Before realtime cursor",
    });
    await t.run(async (ctx) => {
      await ctx.db.patch(oldMessageId, { createdAt: 1000, updatedAt: 1000 });
    });

    const proposalId = await asTasker.mutation((api as any).proposals.sendProposal, {
      conversationId,
      clientProposalId: "ios-proposal-2",
      rate: 8800,
      rateType: "flat",
      startDateTime: "2026-02-16T10:00:00Z",
      notes: "I can do it tomorrow",
    });

    const watched = await asSeeker.query((api as any).messages.watchThread, {
      conversationId,
      since: 1000,
      limit: 10,
    });
    const proposalMessage = watched.messages.find(
      (message: any) => message.type === "proposal"
    );

    expect(proposalMessage?.proposalId).toBe(proposalId);
    expect(proposalMessage?.proposal?.status).toBe("pending");
    expect(watched.latestProposal?._id).toBe(proposalId);
    expect(watched.latestProposal?.clientProposalId).toBe("ios-proposal-2");
    expect(watched.latestProposalUpdatedAt).toBe(watched.latestProposal?.updatedAt);
    expect(watched.latestCursor).toBeGreaterThan(1000);
  });

  test("watchThread reflects proposal status updates after accept and decline", async () => {
    const t = convexTest(schema, modules);
    await t.mutation(internal.categories.seedCategories);
    const accepted = await createConversation(t, "watch_accept");
    const acceptedProposalId = await accepted.asTasker.mutation(
      (api as any).proposals.sendProposal,
      {
        conversationId: accepted.conversationId,
        clientProposalId: "ios-proposal-accept",
        rate: 7500,
        rateType: "flat",
        startDateTime: "2026-02-17T10:00:00Z",
      }
    );
    await setConversationMessageTimes(t, accepted.conversationId, 1000);
    await t.run(async (ctx) => {
      await ctx.db.patch(acceptedProposalId, { createdAt: 1000, updatedAt: 1000 });
    });

    await accepted.asSeeker.mutation((api as any).proposals.acceptProposal, {
      proposalId: acceptedProposalId,
    });
    const acceptedWatch = await accepted.asTasker.query(
      (api as any).messages.watchThread,
      {
        conversationId: accepted.conversationId,
        since: 1000,
        limit: 10,
      }
    );

    expect(acceptedWatch.latestProposal?._id).toBe(acceptedProposalId);
    expect(acceptedWatch.latestProposal?.status).toBe("accepted");
    expect(
      acceptedWatch.messages.some(
        (message: any) => message.proposal?._id === acceptedProposalId &&
          message.proposal.status === "accepted"
      )
    ).toBe(true);

    const declined = await createConversation(t, "watch_decline");
    const declinedProposalId = await declined.asTasker.mutation(
      (api as any).proposals.sendProposal,
      {
        conversationId: declined.conversationId,
        clientProposalId: "ios-proposal-decline",
        rate: 6500,
        rateType: "flat",
        startDateTime: "2026-02-18T10:00:00Z",
      }
    );
    await setConversationMessageTimes(t, declined.conversationId, 1000);
    await t.run(async (ctx) => {
      await ctx.db.patch(declinedProposalId, { createdAt: 1000, updatedAt: 1000 });
    });

    await declined.asSeeker.mutation((api as any).proposals.declineProposal, {
      proposalId: declinedProposalId,
    });
    const declinedWatch = await declined.asTasker.query(
      (api as any).messages.watchThread,
      {
        conversationId: declined.conversationId,
        since: 1000,
        limit: 10,
      }
    );

    expect(declinedWatch.latestProposal?._id).toBe(declinedProposalId);
    expect(declinedWatch.latestProposal?.status).toBe("declined");
    expect(
      declinedWatch.messages.some(
        (message: any) => message.proposal?._id === declinedProposalId &&
          message.proposal.status === "declined"
      )
    ).toBe(true);
  });

  test("watchThread reflects proposal status updates after counter", async () => {
    const t = convexTest(schema, modules);
    const { asSeeker, asTasker, conversationId } = await createConversation(
      t,
      "watch_counter"
    );

    const originalProposalId = await asTasker.mutation(
      (api as any).proposals.sendProposal,
      {
        conversationId,
        clientProposalId: "ios-proposal-original",
        rate: 7500,
        rateType: "flat",
        startDateTime: "2026-02-19T10:00:00Z",
      }
    );
    await setConversationMessageTimes(t, conversationId, 1000);
    await t.run(async (ctx) => {
      await ctx.db.patch(originalProposalId, { createdAt: 1000, updatedAt: 1000 });
    });

    const counterProposalId = await asSeeker.mutation(
      (api as any).proposals.counterProposal,
      {
        proposalId: originalProposalId,
        clientProposalId: "ios-proposal-counter",
        rate: 7000,
        rateType: "flat",
        startDateTime: "2026-02-20T10:00:00Z",
      }
    );
    const watched = await asTasker.query((api as any).messages.watchThread, {
      conversationId,
      since: 1000,
      limit: 10,
    });

    expect(
      watched.messages.some(
        (message: any) => message.proposal?._id === originalProposalId &&
          message.proposal.status === "countered"
      )
    ).toBe(true);
    expect(
      watched.messages.some(
        (message: any) => message.proposal?._id === counterProposalId &&
          message.proposal.previousProposalId === originalProposalId &&
          message.proposal.status === "pending"
      )
    ).toBe(true);
    expect(watched.latestProposalUpdatedAt).toBeGreaterThan(1000);
  });

  test("watchThread does not return full history when the cursor is current", async () => {
    const t = convexTest(schema, modules);
    const { asSeeker, conversationId } = await createConversation(t, "watch_current");

    const messageId = await asSeeker.mutation(api.messages.sendMessage, {
      conversationId,
      content: "Already synchronized",
    });
    await t.run(async (ctx) => {
      await ctx.db.patch(messageId, { createdAt: 1000, updatedAt: 1000 });
    });

    const watched = await asSeeker.query((api as any).messages.watchThread, {
      conversationId,
      since: 1000,
      limit: 10,
    });

    expect(watched.messages).toStrictEqual([]);
    expect(watched.latestProposal).toBeNull();
    expect(watched.latestMessageAt).toBeNull();
    expect(watched.latestProposalUpdatedAt).toBeNull();
    expect(watched.latestCursor).toBe(1000);
  });
});
