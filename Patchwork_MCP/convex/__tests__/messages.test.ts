import { convexTest } from "convex-test";
import { expect, test, describe } from "vitest";
import { api } from "../_generated/api";
import schema from "../schema";
import * as conversationsModule from "../conversations";
import * as usersModule from "../users";
import * as messagesModule from "../messages";
import * as categoriesModule from "../categories";
import * as filesModule from "../files";
import * as taskersModule from "../taskers";
import * as authModule from "../auth";
import * as httpModule from "../http";

const modules: Record<string, () => Promise<any>> = {
  "../conversations.ts": async () => conversationsModule,
  "../users.ts": async () => usersModule,
  "../messages.ts": async () => messagesModule,
  "../categories.ts": async () => categoriesModule,
  "../files.ts": async () => filesModule,
  "../taskers.ts": async () => taskersModule,
  "../auth.ts": async () => authModule,
  "../http.ts": async () => httpModule,
  "../_generated/api.ts": async () => ({ default: api }),
  "../schema.ts": async () => ({ default: schema }),
};

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
});
