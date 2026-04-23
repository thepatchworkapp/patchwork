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

  test("deleteAccount anonymizes account data, removes uploaded photos, and keeps completed job history", async () => {
    const t = convexTest(schema, modules);

    await t.mutation(internal.categories.seedCategories, {});
    const category = await t.query(api.categories.getCategoryBySlug, { slug: "plumbing" });
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
