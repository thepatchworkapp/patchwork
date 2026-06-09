import { convexTest } from "convex-test";
import { expect, test, describe } from "vitest";
import { api, internal } from "../_generated/api";
import schema from "../schema";
import * as usersModule from "../users";
import * as categoriesModule from "../categories";
import * as filesModule from "../files";
import * as taskersModule from "../taskers";
import * as authModule from "../auth";
import * as httpModule from "../http";
import * as conversationsModule from "../conversations";
import * as messagesModule from "../messages";
import * as notificationsModule from "../notifications";
import * as moderationModule from "../moderation";
import * as proposalsModule from "../proposals";
import * as jobsModule from "../jobs";

const modules: Record<string, () => Promise<any>> = {
  "../users.ts": async () => usersModule,
  "../categories.ts": async () => categoriesModule,
  "../files.ts": async () => filesModule,
  "../taskers.ts": async () => taskersModule,
  "../auth.ts": async () => authModule,
  "../http.ts": async () => httpModule,
  "../conversations.ts": async () => conversationsModule,
  "../messages.ts": async () => messagesModule,
  "../notifications.ts": async () => notificationsModule,
  "../moderation.ts": async () => moderationModule,
  "../proposals.ts": async () => proposalsModule,
  "../jobs.ts": async () => jobsModule,
  "../_generated/api.ts": async () => ({ default: api }),
  "../schema.ts": async () => ({ default: schema }),
};

async function storeImage(t: any) {
  return await t.run(async (ctx: any) => {
    const bytes = new Uint8Array(12_000).fill(1);
    return await ctx.storage.store(new Blob([bytes], { type: "image/jpeg" }));
  });
}

async function createImageAsset(
  t: any,
  asUser: any,
  purpose: "userPhoto" | "taskerPhoto" | "taskerCategoryPortfolio",
) {
  const thumbStorageId = await storeImage(t);
  const displayStorageId = await storeImage(t);

  return await asUser.mutation(api.files.commitImageAsset, {
    purpose,
    sourceContentType: "image/jpeg",
    variants: [
      {
        kind: "thumb",
        storageId: thumbStorageId,
        contentType: "image/jpeg",
        width: 300,
        height: 300,
        byteSize: 12_000,
      },
      {
        kind: "display",
        storageId: displayStorageId,
        contentType: "image/jpeg",
        width: 900,
        height: 900,
        byteSize: 12_000,
      },
    ],
  });
}

function storageIdsForAsset(asset: any) {
  return [
    asset.variants.thumb.storageId,
    asset.variants.display.storageId,
    asset.variants.large?.storageId,
  ].filter(Boolean);
}

describe("users", () => {
  test("registerPushToken upserts the current user's iOS token", async () => {
    const t = convexTest(schema, modules);

    const asUser = t.withIdentity({
      tokenIdentifier: "google|push-token-user",
      email: "push-token@example.com",
    });

    const userId = await asUser.mutation(api.users.createProfile, {
      name: "Push Token User",
      city: "Toronto",
      province: "ON",
      notificationsEnabled: true,
    });

    await asUser.mutation(api.users.registerPushToken, {
      token: "abc123",
      environment: "sandbox",
    });
    await asUser.mutation(api.users.registerPushToken, {
      token: "abc123",
      environment: "production",
    });

    const tokens = await t.run(async (ctx: any) => {
      return await ctx.db
        .query("pushTokens")
        .withIndex("by_user", (q: any) => q.eq("userId", userId))
        .collect();
    });

    expect(tokens).toHaveLength(1);
    expect(tokens[0].token).toBe("abc123");
    expect(tokens[0].platform).toBe("ios");
    expect(tokens[0].environment).toBe("production");
    expect(tokens[0].disabledAt).toBeUndefined();
  });

  test("createProfile defaults notifications off and gates push token registration", async () => {
    const t = convexTest(schema, modules);

    const asUser = t.withIdentity({
      tokenIdentifier: "google|push-token-disabled-user",
      email: "push-token-disabled@example.com",
    });

    const userId = await asUser.mutation(api.users.createProfile, {
      name: "Push Token Disabled User",
      city: "Toronto",
      province: "ON",
    });

    const currentUser = await asUser.query(api.users.getCurrentUser);
    expect(currentUser?.settings?.notificationsEnabled).toBe(false);

    const disabledResult = await asUser.mutation(api.users.registerPushToken, {
      token: "disabled-token",
      environment: "sandbox",
    });
    expect(disabledResult).toEqual({ registered: false });

    await asUser.mutation(api.users.updateNotificationSettings, {
      notificationsEnabled: true,
    });
    const enabledResult = await asUser.mutation(api.users.registerPushToken, {
      token: "enabled-token",
      environment: "sandbox",
    });
    expect(enabledResult).toEqual({ registered: true });

    const tokens = await t.run(async (ctx: any) => {
      return await ctx.db
        .query("pushTokens")
        .withIndex("by_user", (q: any) => q.eq("userId", userId))
        .collect();
    });

    expect(tokens).toHaveLength(1);
    expect(tokens[0].token).toBe("enabled-token");
  });

  test("getUnreadBadgeCount returns the current user's unread conversation total", async () => {
    const t = convexTest(schema, modules);

    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|badge-seeker",
      email: "badge-seeker@example.com",
    });
    const seekerId = await asSeeker.mutation(api.users.createProfile, {
      name: "Badge Seeker",
      city: "Toronto",
      province: "ON",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|badge-tasker",
      email: "badge-tasker@example.com",
    });
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Badge Tasker",
      city: "Toronto",
      province: "ON",
    });

    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
      initialMessage: "Can you help with cleaning?",
    });

    expect(await asTasker.query(api.users.getUnreadBadgeCount)).toBe(1);
    expect(await asSeeker.query(api.users.getUnreadBadgeCount)).toBe(0);

    await asTasker.mutation(api.conversations.markAsRead, { conversationId });
    await asTasker.mutation(api.messages.sendMessage, {
      conversationId,
      content: "Yes, I can help tomorrow.",
    });

    expect(await asTasker.query(api.users.getUnreadBadgeCount)).toBe(0);
    expect(await asSeeker.query(api.users.getUnreadBadgeCount)).toBe(1);

    await asSeeker.mutation(api.conversations.markAsRead, { conversationId });
    expect(await asSeeker.query(api.users.getUnreadBadgeCount)).toBe(0);
    expect(seekerId).toBeDefined();
  });

  test("createProfile creates user and seekerProfile", async () => {
    const t = convexTest(schema, modules);
    
    const asUser = t.withIdentity({
      tokenIdentifier: "google|123",
      email: "test@example.com",
    });

    const userId = await asUser.mutation(api.users.createProfile, {
      name: "Test User",
      city: "Toronto",
      province: "ON",
    });

    expect(userId).toBeDefined();

    const user = await asUser.query(api.users.getCurrentUser);
    expect(user?.name).toBe("Test User");
    expect(user?.email).toBe("test@example.com");
  });

  test("getCurrentUser returns null when unauthenticated", async () => {
    const t = convexTest(schema, modules);
    const user = await t.query(api.users.getCurrentUser);
    expect(user).toBeNull();
  });

  test("getCurrentUser returns user when authenticated", async () => {
    const t = convexTest(schema, modules);
    
    const asUser = t.withIdentity({
      tokenIdentifier: "google|456",
      email: "existing@example.com",
    });

    // First create a profile
    await asUser.mutation(api.users.createProfile, {
      name: "Existing User",
      city: "Vancouver",
      province: "BC",
    });

    // Then verify getCurrentUser returns it
    const user = await asUser.query(api.users.getCurrentUser);
    expect(user).not.toBeNull();
    expect(user?.name).toBe("Existing User");
  });

  test("getClientStateVersion requires a valid app user", async () => {
    const t = convexTest(schema, modules);

    await expect(t.query(api.users.getClientStateVersion, {})).rejects.toThrow("Unauthorized");

    const asMissingAppUser = t.withIdentity({
      tokenIdentifier: "google|missing-client-state-user",
      email: "missing-client-state@example.com",
    });
    await expect(asMissingAppUser.query(api.users.getClientStateVersion, {})).rejects.toThrow("User not found");

    const asUser = t.withIdentity({
      tokenIdentifier: "google|client-state-user",
      email: "client-state@example.com",
    });
    await asUser.mutation(api.users.createProfile, {
      name: "Client State User",
      city: "Toronto",
      province: "ON",
    });

    await expect(asUser.query(api.users.getClientStateVersion, {})).resolves.toEqual({
      version: 0,
      updatedAt: 0,
    });
  });

  test("createProfile throws when unauthenticated", async () => {
    const t = convexTest(schema, modules);
    
    await expect(
      t.mutation(api.users.createProfile, {
        name: "Should Fail",
        city: "Montreal",
        province: "QC",
      })
    ).rejects.toThrow();
  });

  test("createProfile is idempotent - returns existing user ID on duplicate", async () => {
    const t = convexTest(schema, modules);
    
    const asUser = t.withIdentity({
      tokenIdentifier: "google|idempotent789",
      email: "idempotent@example.com",
    });

    const firstUserId = await asUser.mutation(api.users.createProfile, {
      name: "First Call",
      city: "Ottawa",
      province: "ON",
    });

    const secondUserId = await asUser.mutation(api.users.createProfile, {
      name: "Second Call",
      city: "Calgary",
      province: "AB",
    });

    expect(secondUserId).toBe(firstUserId);

    const user = await asUser.query(api.users.getCurrentUser);
    expect(user?.name).toBe("First Call");
    expect(user?.location?.city).toBe("Ottawa");
  });

  test("updateProfile updates basic fields and preserves coordinates and settings", async () => {
    const t = convexTest(schema, modules);

    const asUser = t.withIdentity({
      tokenIdentifier: "google|update_profile",
      email: "update_profile@example.com",
    });

    const userId = await asUser.mutation(api.users.createProfile, {
      name: "Original User",
      city: "Toronto",
      province: "ON",
    });

    await t.run(async (ctx: any) => {
      await ctx.db.patch(userId, {
        location: {
          city: "Toronto",
          province: "ON",
          coordinates: {
            lat: 43.6532,
            lng: -79.3832,
          },
        },
        settings: {
          notificationsEnabled: false,
          locationEnabled: true,
        },
      });
    });

    const updated = await asUser.mutation((api.users as any).updateProfile, {
      name: "Updated User",
      city: "Ottawa",
      province: "ON",
    });

    expect(updated.name).toBe("Updated User");
    expect(updated.location.city).toBe("Ottawa");
    expect(updated.location.province).toBe("ON");
    expect(updated.location.coordinates).toEqual({
      lat: 43.6532,
      lng: -79.3832,
    });
    expect(updated.settings).toEqual({
      notificationsEnabled: false,
      locationEnabled: true,
    });
  });

  test("updateProfile uses createProfile length validation", async () => {
    const t = convexTest(schema, modules);

    const asUser = t.withIdentity({
      tokenIdentifier: "google|update_profile_validation",
      email: "update_profile_validation@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Valid User",
      city: "Toronto",
      province: "ON",
    });

    await expect(
      asUser.mutation((api.users as any).updateProfile, {
        name: "A".repeat(101),
        city: "Toronto",
        province: "ON",
      })
    ).rejects.toThrow("Name must be 100 characters or less");

    await expect(
      asUser.mutation((api.users as any).updateProfile, {
        name: "Valid User",
        city: "A".repeat(101),
        province: "ON",
      })
    ).rejects.toThrow("City must be 100 characters or less");

    await expect(
      asUser.mutation((api.users as any).updateProfile, {
        name: "Valid User",
        city: "Toronto",
        province: "A".repeat(101),
      })
    ).rejects.toThrow("Province must be 100 characters or less");
  });

  test("deleteAccount anonymizes account data, removes uploaded photos, and keeps completed job history", async () => {
    const t = convexTest(schema, modules);

    await t.mutation(internal.categories.seedCategories, {});
    const category = await t.query(api.categories.getCategoryBySlug, { slug: "plumber" });
    expect(category).not.toBeNull();

    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|delete_account_seeker",
      email: "delete_account_seeker@example.com",
    });
    const seekerId = await asSeeker.mutation(api.users.createProfile, {
      name: "Delete Account Seeker",
      city: "Toronto",
      province: "ON",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|delete_account_tasker",
      email: "delete_account_tasker@example.com",
    });
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Delete Account Tasker",
      city: "Toronto",
      province: "ON",
    });

    const userPhoto = await createImageAsset(t, asTasker, "userPhoto");
    const taskerPhoto = await createImageAsset(t, asTasker, "taskerPhoto");
    const portfolioPhoto = await createImageAsset(t, asTasker, "taskerCategoryPortfolio");
    const looseAttachmentStorageId = await storeImage(t);

    await asTasker.mutation(api.users.updateProfilePhoto, { photoAssetId: userPhoto._id });
    await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Tasker To Delete",
      bio: "This profile should be removed.",
      photoSource: "custom",
      photoAssetId: taskerPhoto._id,
      categoryId: category!._id,
      categoryBio: "Portfolio content that should be removed.",
      portfolioAssetIds: [portfolioPhoto._id],
      coverAssetId: portfolioPhoto._id,
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 25,
    });

    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
      initialMessage: "I need help with plumbing.",
    });
    const messageId = await asTasker.mutation(api.messages.sendMessage, {
      conversationId,
      content: "I can help. Here is a photo.",
      attachments: [looseAttachmentStorageId],
    });
    const proposalId = await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 5000,
      rateType: "hourly",
      startDateTime: "2026-03-15T10:00:00Z",
      notes: "Historical proposal should remain.",
    });
    const { jobId } = await asSeeker.mutation(api.proposals.acceptProposal, { proposalId });
    await asSeeker.mutation(api.jobs.completeJob, { jobId });

    const result = await asTasker.mutation((api.users as any).deleteAccount, {});
    expect(result.deleted).toBe(true);
    expect(result.imageAssetsDeleted).toBe(3);

    await expect(asTasker.query(api.users.getCurrentUser)).resolves.toBeNull();

    const persisted = await t.run(async (ctx: any) => {
      const [
        user,
        taskerProfile,
        taskerCategories,
        seekerProfile,
        conversation,
        message,
        proposal,
        job,
      ] = await Promise.all([
        ctx.db.get(taskerId),
        ctx.db
          .query("taskerProfiles")
          .withIndex("by_userId", (q: any) => q.eq("userId", taskerId))
          .unique(),
        ctx.db
          .query("taskerCategories")
          .withIndex("by_userId", (q: any) => q.eq("userId", taskerId))
          .collect(),
        ctx.db
          .query("seekerProfiles")
          .withIndex("by_userId", (q: any) => q.eq("userId", taskerId))
          .unique(),
        ctx.db.get(conversationId),
        ctx.db.get(messageId),
        ctx.db.get(proposalId),
        ctx.db.get(jobId),
      ]);

      const imageAssets = await Promise.all([
        ctx.db.get(userPhoto._id),
        ctx.db.get(taskerPhoto._id),
        ctx.db.get(portfolioPhoto._id),
      ]);

      return {
        user,
        taskerProfile,
        taskerCategories,
        seekerProfile,
        conversation,
        message,
        proposal,
        job,
        imageAssets,
      };
    });

    expect(persisted.user?.authId).toMatch(/^deleted:/);
    expect(persisted.user?.email).toMatch(/^deleted\+/);
    expect(persisted.user?.name).toBe("Deleted User");
    expect(persisted.user?.photo).toBeUndefined();
    expect(persisted.user?.photoAssetId).toBeUndefined();
    expect(persisted.user?.roles).toEqual({ isSeeker: false, isTasker: false });
    expect(persisted.user?.location).toEqual({ city: "", province: "" });
    expect(persisted.taskerProfile).toBeNull();
    expect(persisted.taskerCategories).toEqual([]);
    expect(persisted.seekerProfile).toBeNull();
    expect(persisted.conversation?._id).toBe(conversationId);
    expect(persisted.message?._id).toBe(messageId);
    expect(persisted.message?.content).toBe("I can help. Here is a photo.");
    expect(persisted.message?.attachments).toBeUndefined();
    expect(persisted.proposal?._id).toBe(proposalId);
    expect(persisted.job?._id).toBe(jobId);
    expect(persisted.job?.status).toBe("completed");
    expect(persisted.job?.seekerId).toBe(seekerId);
    expect(persisted.job?.taskerId).toBe(taskerId);
    expect(persisted.imageAssets.map((asset: any) => asset?.status)).toEqual([
      "deleted",
      "deleted",
      "deleted",
    ]);

    const deletedStorageIds = [
      ...storageIdsForAsset(userPhoto),
      ...storageIdsForAsset(taskerPhoto),
      ...storageIdsForAsset(portfolioPhoto),
      looseAttachmentStorageId,
    ];
    for (const storageId of deletedStorageIds) {
      const url = await t.run(async (ctx: any) => await ctx.storage.getUrl(storageId));
      expect(url).toBeNull();
    }
  });
});
