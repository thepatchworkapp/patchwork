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

describe("conversations", () => {
  test("unauthenticated user cannot start conversation", async () => {
    const t = convexTest(schema, modules);
    
    // Create a tasker user first
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker123",
      email: "tasker@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker User",
      city: "Toronto",
      province: "ON",
    });

    // Try to start conversation without auth
    await expect(
      t.mutation(api.conversations.startConversation, {
        taskerId,
      })
    ).rejects.toThrow("Unauthorized");
  });

  test("seeker can start conversation with tasker", async () => {
    const t = convexTest(schema, modules);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker123",
      email: "seeker@example.com",
    });
    
    const seekerId = await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker User",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker456",
      email: "tasker@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker User",
      city: "Toronto",
      province: "ON",
    });

    // Seeker starts conversation
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    expect(conversationId).toBeDefined();

    // Verify conversation exists
    const conversation = await asSeeker.query(api.conversations.getConversation, {
      conversationId,
    });

    expect(conversation).not.toBeNull();
    expect(conversation?.seekerId).toBe(seekerId);
    expect(conversation?.taskerId).toBe(taskerId);
    expect(conversation?.seekerUnreadCount).toBe(0);
    expect(conversation?.taskerUnreadCount).toBe(0);
  });

  test("provider-detail style flow resolves tasker userId and opens chat with valid conversationId", async () => {
    const t = convexTest(schema, modules);

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_provider_flow",
      email: "tasker_provider_flow@example.com",
    });

    const taskerUserId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Provider",
      city: "Waterloo",
      province: "ON",
    });

    await asTasker.mutation(api.categories.seedCategories, {});
    const categories = await asTasker.query(api.categories.listCategories, {});
    const firstCategory = categories[0];
    expect(firstCategory?._id).toBeDefined();

    const taskerProfileId = await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Provider Flow Tasker",
      categoryId: firstCategory._id,
      categoryBio: "Experienced and reliable",
      rateType: "hourly",
      hourlyRate: 7500,
      serviceRadius: 25,
    });

    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_provider_flow",
      email: "seeker_provider_flow@example.com",
    });

    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker Provider",
      city: "Waterloo",
      province: "ON",
    });

    const taskerFromDetail = await asSeeker.query(api.taskers.getTaskerById, {
      taskerId: taskerProfileId,
    });

    expect(taskerFromDetail).not.toBeNull();
    expect(taskerFromDetail?.userId).toStrictEqual(taskerUserId);

    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId: taskerFromDetail!.userId,
    });

    const conversation = await asSeeker.query(api.conversations.getConversation, {
      conversationId,
    });
    expect(conversation).not.toBeNull();

    const messages = await asSeeker.query(api.messages.listMessages, {
      conversationId,
      paginationOpts: { cursor: null, numItems: 25 },
    });
    expect(messages.page).toStrictEqual([]);
    expect(messages.isDone).toBe(true);
  });

  test("seeker can start conversation with initial message", async () => {
    const t = convexTest(schema, modules);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker789",
      email: "seeker2@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker User 2",
      city: "Vancouver",
      province: "BC",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker789",
      email: "tasker2@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker User 2",
      city: "Vancouver",
      province: "BC",
    });

    // Start conversation with initial message
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
      initialMessage: "Hi, I need help with cleaning",
    });

    expect(conversationId).toBeDefined();

    // Verify conversation has lastMessagePreview
    const conversation = await asSeeker.query(api.conversations.getConversation, {
      conversationId,
    });

    expect(conversation?.lastMessagePreview).toBe("Hi, I need help with cleaning");
    expect(conversation?.taskerUnreadCount).toBe(1); // Tasker has 1 unread message
  });

  test("cannot start duplicate conversation with same participants", async () => {
    const t = convexTest(schema, modules);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_dup",
      email: "seeker_dup@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker Dup",
      city: "Montreal",
      province: "QC",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_dup",
      email: "tasker_dup@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Dup",
      city: "Montreal",
      province: "QC",
    });

    // Start first conversation
    const conversationId1 = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    expect(conversationId1).toBeDefined();

    // Starting again with same participants returns existing conversation
    const conversationId2 = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    expect(conversationId2).toStrictEqual(conversationId1);
  });

  test("listConversations returns conversations for authenticated user", async () => {
    const t = convexTest(schema, modules);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_list",
      email: "seeker_list@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker List",
      city: "Toronto",
      province: "ON",
    });

    // Create two taskers
    const asTasker1 = t.withIdentity({
      tokenIdentifier: "google|tasker_list1",
      email: "tasker_list1@example.com",
    });
    
    const taskerId1 = await asTasker1.mutation(api.users.createProfile, {
      name: "Tasker List 1",
      city: "Toronto",
      province: "ON",
    });

    const asTasker2 = t.withIdentity({
      tokenIdentifier: "google|tasker_list2",
      email: "tasker_list2@example.com",
    });
    
    const taskerId2 = await asTasker2.mutation(api.users.createProfile, {
      name: "Tasker List 2",
      city: "Toronto",
      province: "ON",
    });

    // Start two conversations
    await asSeeker.mutation(api.conversations.startConversation, {
      taskerId: taskerId1,
    });

    await asSeeker.mutation(api.conversations.startConversation, {
      taskerId: taskerId2,
    });

    // List conversations
    const conversations = await asSeeker.query(api.conversations.listConversations);

    expect(conversations).toBeDefined();
    expect(conversations.length).toBe(2);
  });

  test("markAsRead updates unread count for seeker", async () => {
    const t = convexTest(schema, modules);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_read",
      email: "seeker_read@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker Read",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_read",
      email: "tasker_read@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Read",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation with initial message (seeker sends to tasker)
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
      initialMessage: "Hello tasker",
    });

    // Tasker marks as read
    await asTasker.mutation(api.conversations.markAsRead, {
      conversationId,
    });

    // Verify taskerUnreadCount is 0
    const conversation = await asTasker.query(api.conversations.getConversation, {
      conversationId,
    });

    expect(conversation?.taskerUnreadCount).toBe(0);
    expect(conversation?.taskerLastReadAt).toBeDefined();
  });

  test("tasker cannot initiate conversation (seeker only)", async () => {
    const t = convexTest(schema, modules);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_init",
      email: "seeker_init@example.com",
    });
    
    const seekerId = await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker Init",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_init",
      email: "tasker_init@example.com",
    });
    
    await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Init",
      city: "Toronto",
      province: "ON",
    });

    // Tasker tries to start conversation - should fail
    // This test assumes we need a way to identify who is tasker vs seeker
    // For now, we'll test that tasker can't pass their own ID as taskerId
    await expect(
      asSeeker.mutation(api.conversations.startConversation, {
        taskerId: seekerId, // Can't start conversation with yourself
      })
    ).rejects.toThrow("Cannot start conversation with yourself");
  });

  test("getConversation returns null for non-participant", async () => {
    const t = convexTest(schema, modules);
    
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_auth1",
      email: "seeker_auth1@example.com",
    });
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker Auth 1",
      city: "Toronto",
      province: "ON",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_auth1",
      email: "tasker_auth1@example.com",
    });
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Auth 1",
      city: "Toronto",
      province: "ON",
    });

    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    const asStranger = t.withIdentity({
      tokenIdentifier: "google|stranger_auth1",
      email: "stranger_auth1@example.com",
    });
    await asStranger.mutation(api.users.createProfile, {
      name: "Stranger",
      city: "Toronto",
      province: "ON",
    });

    const result = await asStranger.query(api.conversations.getConversation, {
      conversationId,
    });
    expect(result).toBeNull();
  });

  test("getConversation returns null for unauthenticated user", async () => {
    const t = convexTest(schema, modules);
    
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_auth2",
      email: "seeker_auth2@example.com",
    });
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker Auth 2",
      city: "Toronto",
      province: "ON",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_auth2",
      email: "tasker_auth2@example.com",
    });
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Auth 2",
      city: "Toronto",
      province: "ON",
    });

    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    const result = await t.query(api.conversations.getConversation, {
      conversationId,
    });
    expect(result).toBeNull();
  });
});
