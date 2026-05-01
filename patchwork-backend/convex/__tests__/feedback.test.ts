import { convexTest } from "convex-test";
import { describe, expect, test, vi } from "vitest";
import { api } from "../_generated/api";
import schema from "../schema";

async function feedbackModules() {
  const feedbackModule = await import("../feedback");
  const moderationModule = await import("../moderation");
  const usersModule = await import("../users");
  const authModule = await import("../auth");

  return {
    "../feedback.ts": async () => feedbackModule,
    "../moderation.ts": async () => moderationModule,
    "../users.ts": async () => usersModule,
    "../auth.ts": async () => authModule,
    "../_generated/api.ts": async () => ({ default: api }),
    "../schema.ts": async () => ({ default: schema }),
  };
}

async function adminFeedbackModules() {
  vi.resetModules();
  const reviewAccessStatus = () => ({
    email: "review@apple.com",
    allowedEmails: ["review@apple.com", "seeker@apple.com"],
    enabled: true,
    betterAuthUserId: null,
    appUserId: null,
    lastEnabledAt: Date.now(),
    lastDisabledAt: null,
    updatedAt: Date.now(),
  });
  vi.doMock("../auth", () => ({
    authComponent: {
      adapter: () =>
        async () => ({
          findOne: async ({ where }: { where?: Array<{ value?: string }> }) => {
            const email = where?.[0]?.value;
            if (email === "admin@example.com") {
              return { id: "admin-auth-user-id" };
            }
            return null;
          },
          deleteMany: async () => undefined,
        }),
    },
  }));
  vi.doMock("../reviewAccess", () => ({
    APP_REVIEW_EMAIL: "review@apple.com",
    APP_REVIEW_SEEKER_EMAIL: "seeker@apple.com",
    getReviewAccessStatus: vi.fn(async () => reviewAccessStatus()),
    setReviewAccessEnabled: vi.fn(async () => reviewAccessStatus()),
  }));
  vi.doMock("../geospatial", () => ({
    taskerGeo: {
      remove: vi.fn(async () => undefined),
    },
  }));
  const baseModules = await feedbackModules();
  const adminModule = await import("../admin");

  return {
    ...baseModules,
    "../admin.ts": async () => adminModule,
  };
}

describe("feedback", () => {
  test("submit stores authenticated feedback with timestamp and user", async () => {
    const t = convexTest(schema, await feedbackModules());

    const asUser = t.withIdentity({
      tokenIdentifier: "google|feedback1",
      email: "feedback@example.com",
    });

    const userId = await asUser.mutation(api.users.createProfile, {
      name: "Feedback User",
      city: "Toronto",
      province: "ON",
    });

    const feedbackId = await asUser.mutation(api.feedback.submit, {
      message: "The new layout is much easier to use.",
    });

    expect(feedbackId).toBeDefined();

    const stored = await t.run(async (ctx) => ctx.db.get(feedbackId));
    expect(stored).not.toBeNull();
    expect(stored?.userId).toBe(userId);
    expect(stored?.message).toBe("The new layout is much easier to use.");
    expect(typeof stored?.createdAt).toBe("number");
    expect(typeof stored?.updatedAt).toBe("number");
  });

  test("submit rejects anonymous feedback", async () => {
    const t = convexTest(schema, await feedbackModules());

    await expect(
      t.mutation(api.feedback.submit, {
        message: "Anonymous feedback should not work.",
      })
    ).rejects.toThrow("Unauthorized");
  });

  test("admin queries expose recent feedback and per-user feedback", async () => {
    const previousAdminEmails = process.env.ADMIN_EMAILS;
    process.env.ADMIN_EMAILS = "admin@example.com";

    try {
      const t = convexTest(schema, await adminFeedbackModules());

      const asAdmin = t.withIdentity({
        tokenIdentifier: "google|feedback-admin",
        email: "admin@example.com",
      });
      const asUser = t.withIdentity({
        tokenIdentifier: "google|feedback-user",
        email: "feedback-detail@example.com",
      });
      const asReportedUser = t.withIdentity({
        tokenIdentifier: "google|feedback-reported-user",
        email: "reported-detail@example.com",
      });

      const userId = await asUser.mutation(api.users.createProfile, {
        name: "Feedback Detail User",
        city: "Toronto",
        province: "ON",
      });
      const reportedUserId = await asReportedUser.mutation(api.users.createProfile, {
        name: "Reported Detail User",
        city: "Toronto",
        province: "ON",
      });

      await asUser.mutation(api.feedback.submit, {
        message: "The feedback form should not error after sending.",
      });
      const blockStatus = await asUser.mutation((api as any).moderation.blockUser, {
        blockedUserId: reportedUserId,
      });
      expect(blockStatus.currentUserBlockedOther).toBe(true);
      await asUser.mutation((api as any).moderation.reportUser, {
        reportedUserId,
        reason: "A".repeat(100),
        block: true,
      });

      const recentFeedback = await asAdmin.query((api as any).admin.listRecentFeedback, {
        limit: 10,
      });

      expect(recentFeedback).toHaveLength(1);
      expect(recentFeedback[0]?.userId).toBe(userId);
      expect(recentFeedback[0]?.userEmail).toBe("feedback-detail@example.com");
      expect(recentFeedback[0]?.message).toBe("The feedback form should not error after sending.");

      const detail = await asAdmin.query((api as any).admin.getUserDetail, {
        userId,
      });
      const recentReports = await asAdmin.query((api as any).admin.listRecentReports, {
        limit: 10,
      });

      const users = await asAdmin.query((api as any).admin.listAllUsers, {
        limit: 10,
      });

      expect(users.users).toHaveLength(2);
      const listedUser = users.users.find((row: any) => row._id === userId);
      expect(listedUser?.photoImage).toBeNull();
      expect(listedUser?.photoAssetId).toBeUndefined();

      expect(detail?.feedbackSubmissions).toHaveLength(1);
      expect(detail?.feedbackSubmissions[0]?.message).toBe("The feedback form should not error after sending.");
      expect(detail?.blocksCreated).toHaveLength(1);
      expect(detail?.blocksCreated[0]?.blockedId).toBe(reportedUserId);
      expect(detail?.reportsSubmitted).toHaveLength(1);
      expect(detail?.reportsSubmitted[0]?.reportedUserId).toBe(reportedUserId);
      expect(recentReports).toHaveLength(1);
      expect(recentReports[0]?.reporterId).toBe(userId);
      expect(recentReports[0]?.reportedUserId).toBe(reportedUserId);
      expect(detail?.userPhotoImage).toBeNull();
    } finally {
      process.env.ADMIN_EMAILS = previousAdminEmails;
      vi.resetModules();
    }
  });

  test("admin resetDatabase removes imageAssets variants and remains idempotent", async () => {
    const previousAdminEmails = process.env.ADMIN_EMAILS;
    process.env.ADMIN_EMAILS = "admin@example.com";

    try {
      const t = convexTest(schema, await adminFeedbackModules());

      const asAdmin = t.withIdentity({
        tokenIdentifier: "google|feedback-admin-reset-assets",
        email: "admin@example.com",
      });
      const asUser = t.withIdentity({
        tokenIdentifier: "google|feedback-user-reset-assets",
        email: "feedback-reset-assets@example.com",
      });

      const userId = await asUser.mutation(api.users.createProfile, {
        name: "Feedback Reset Assets User",
        city: "Toronto",
        province: "ON",
      });
      const taskerUserId = await t.run(async (ctx) =>
        await ctx.db.insert("users", {
          authId: "google|feedback-reset-assets-tasker",
          email: "feedback-reset-assets-tasker@example.com",
          emailVerified: true,
          name: "Feedback Reset Assets Tasker",
          photoAssetId: undefined,
          photo: undefined,
          location: {
            city: "Toronto",
            province: "ON",
          },
          roles: {
            isSeeker: true,
            isTasker: true,
          },
          settings: {
            notificationsEnabled: true,
            locationEnabled: false,
          },
          createdAt: Date.now(),
          updatedAt: Date.now(),
        })
      );

      await t.run(async (ctx) => {
        await ctx.db.insert("favouriteTaskers", {
          seekerId: userId,
          taskerUserId,
          createdAt: Date.now(),
          updatedAt: Date.now(),
        });
      });

      const [legacyPhotoStorageId, thumbStorageId, displayStorageId, largeStorageId] = await Promise.all([
        t.run(async (ctx) => await ctx.storage.store(new Blob([new Uint8Array(1_200)], { type: "image/jpeg" }))),
        t.run(async (ctx) => await ctx.storage.store(new Blob([new Uint8Array(12_000)], { type: "image/jpeg" }))),
        t.run(async (ctx) => await ctx.storage.store(new Blob([new Uint8Array(40_000)], { type: "image/jpeg" }))),
        t.run(async (ctx) => await ctx.storage.store(new Blob([new Uint8Array(80_000)], { type: "image/jpeg" }))),
      ]);

      const now = Date.now();
      const imageAssetId = await t.run(async (ctx) =>
        await ctx.db.insert("imageAssets", {
          ownerUserId: userId,
          purpose: "userPhoto",
          status: "active",
          sourceContentType: "image/jpeg",
          variants: {
            thumb: {
              storageId: thumbStorageId,
              contentType: "image/jpeg",
              width: 256,
              height: 256,
              byteSize: 12_000,
            },
            display: {
              storageId: displayStorageId,
              contentType: "image/jpeg",
              width: 900,
              height: 900,
              byteSize: 40_000,
            },
            large: {
              storageId: largeStorageId,
              contentType: "image/jpeg",
              width: 1400,
              height: 1400,
              byteSize: 80_000,
            },
          },
          createdAt: now,
          updatedAt: now,
        })
      );

      await t.run(async (ctx) => {
        await ctx.db.patch(userId, {
          photo: legacyPhotoStorageId,
          photoAssetId: imageAssetId,
          updatedAt: Date.now(),
        });
      });

      const firstReset = await asAdmin.action((api as any).admin.resetDatabase, {});
      expect(firstReset.deletedFavouriteTaskers).toBe(1);
      expect(firstReset.deletedImageAssets).toBe(1);
      expect(firstReset.deletedStorageFiles).toBe(4);
      expect(firstReset.failedStorageFiles).toBe(0);

      const secondReset = await asAdmin.action((api as any).admin.resetDatabase, {});
      expect(secondReset.deletedFavouriteTaskers).toBe(0);
      expect(secondReset.deletedImageAssets).toBe(0);
      expect(secondReset.deletedStorageFiles).toBe(0);
      expect(secondReset.failedStorageFiles).toBe(0);

      const [legacyUrl, thumbUrl, displayUrl, largeUrl] = await Promise.all([
        t.run(async (ctx) => await ctx.storage.getUrl(legacyPhotoStorageId)),
        t.run(async (ctx) => await ctx.storage.getUrl(thumbStorageId)),
        t.run(async (ctx) => await ctx.storage.getUrl(displayStorageId)),
        t.run(async (ctx) => await ctx.storage.getUrl(largeStorageId)),
      ]);
      expect(legacyUrl).toBeNull();
      expect(thumbUrl).toBeNull();
      expect(displayUrl).toBeNull();
      expect(largeUrl).toBeNull();
    } finally {
      process.env.ADMIN_EMAILS = previousAdminEmails;
      vi.resetModules();
    }
  });

  test("admin reseedAdminUser is idempotent and resetDatabaseAndReseed restores admin app user", async () => {
    const previousAdminEmails = process.env.ADMIN_EMAILS;
    process.env.ADMIN_EMAILS = "admin@example.com";

    try {
      const t = convexTest(schema, await adminFeedbackModules());

      const asAdmin = t.withIdentity({
        tokenIdentifier: "google|feedback-admin-reseed",
        email: "admin@example.com",
      });
      const asUser = t.withIdentity({
        tokenIdentifier: "google|feedback-admin-reseed-user",
        email: "feedback-admin-reseed-user@example.com",
      });

      const firstReseed = await asAdmin.mutation((api as any).admin.reseedAdminUser, {});
      expect(firstReseed.email).toBe("admin@example.com");
      expect(firstReseed.created).toBe(true);

      const secondReseed = await asAdmin.mutation((api as any).admin.reseedAdminUser, {});
      expect(secondReseed.appUserId).toBe(firstReseed.appUserId);
      expect(secondReseed.created).toBe(false);

      await asUser.mutation(api.users.createProfile, {
        name: "Admin Reseed Reset User",
        city: "Toronto",
        province: "ON",
      });

      const resetResult = await asAdmin.action((api as any).admin.resetDatabaseAndReseed, {});
      expect(resetResult.deletedUsers).toBe(2);
      expect(resetResult.adminUser.email).toBe("admin@example.com");
      expect(resetResult.adminUser.created).toBe(true);
      expect(resetResult.reviewAccess.enabled).toBe(true);

      const users = await t.run(async (ctx) => await ctx.db.query("users").collect());
      expect(users).toHaveLength(1);
      expect(users[0]?.email).toBe("admin@example.com");

      const seekerProfile = await t.run(async (ctx) =>
        await ctx.db
          .query("seekerProfiles")
          .withIndex("by_userId", (q) => q.eq("userId", resetResult.adminUser.appUserId))
          .unique()
      );
      expect(seekerProfile?.userId).toBe(resetResult.adminUser.appUserId);
    } finally {
      process.env.ADMIN_EMAILS = previousAdminEmails;
      vi.resetModules();
    }
  });

  test("admin resetDatabase does not wipe app data if auth cleanup fails first", async () => {
    const previousAdminEmails = process.env.ADMIN_EMAILS;
    process.env.ADMIN_EMAILS = "admin@example.com";

    try {
      vi.resetModules();
      vi.doMock("../auth", () => ({
        authComponent: {
          adapter: () =>
            async () => ({
              findOne: async ({ where }: { where?: Array<{ value?: string }> }) => {
                const email = where?.[0]?.value;
                if (email === "admin@example.com") {
                  return { id: "admin-auth-user-id" };
                }
                return null;
              },
              deleteMany: async ({ model }: { model: string }) => {
                if (model === "session") {
                  throw new Error("session cleanup failed");
                }
              },
            }),
        },
      }));
      vi.doMock("../reviewAccess", () => ({
        APP_REVIEW_EMAIL: "review@apple.com",
        APP_REVIEW_SEEKER_EMAIL: "seeker@apple.com",
        getReviewAccessStatus: vi.fn(),
        setReviewAccessEnabled: vi.fn(),
      }));
      vi.doMock("../geospatial", () => ({
        taskerGeo: {
          remove: vi.fn(async () => undefined),
        },
      }));

      const adminModule = await import("../admin");
      const modules = await feedbackModules();
      const t = convexTest(schema, {
        ...modules,
        "../admin.ts": async () => adminModule,
      });

      const asAdmin = t.withIdentity({
        tokenIdentifier: "google|feedback-admin-reset-fail",
        email: "admin@example.com",
      });
      const asUser = t.withIdentity({
        tokenIdentifier: "google|feedback-user-reset-fail",
        email: "feedback-reset-fail@example.com",
      });

      const userId = await asUser.mutation(api.users.createProfile, {
        name: "Feedback Reset Failure User",
        city: "Toronto",
        province: "ON",
      });

      await asUser.mutation(api.feedback.submit, {
        message: "This feedback should survive a failed reset.",
      });

      await expect(
        asAdmin.action((api as any).admin.resetDatabase, {})
      ).rejects.toThrow("session cleanup failed");

      const user = await t.run(async (ctx) => await ctx.db.get(userId));
      expect(user?.email).toBe("feedback-reset-fail@example.com");

      const feedbackRows = await t.run(async (ctx) =>
        await ctx.db
          .query("feedbackSubmissions")
          .withIndex("by_userId_createdAt", (q) => q.eq("userId", userId))
          .order("desc")
          .take(5)
      );
      expect(feedbackRows).toHaveLength(1);
      expect(feedbackRows[0]?.userId).toBe(userId);
      expect(feedbackRows[0]?.message).toBe("This feedback should survive a failed reset.");
    } finally {
      process.env.ADMIN_EMAILS = previousAdminEmails;
      vi.resetModules();
    }
  });

  test("admin resetDatabaseAndRevenueCat resets and reports skipped RevenueCat cleanup when secret is missing", async () => {
    const previousAdminEmails = process.env.ADMIN_EMAILS;
    const previousRevenueCatSecret = process.env.REVENUECAT_SECRET_API_KEY;
    process.env.ADMIN_EMAILS = "admin@example.com";
    delete process.env.REVENUECAT_SECRET_API_KEY;

    try {
      const t = convexTest(schema, await adminFeedbackModules());

      const asAdmin = t.withIdentity({
        tokenIdentifier: "google|feedback-admin-reset-revenuecat-preflight",
        email: "admin@example.com",
      });
      const asUser = t.withIdentity({
        tokenIdentifier: "google|feedback-user-reset-revenuecat-preflight",
        email: "feedback-reset-revenuecat-preflight@example.com",
      });

      const userId = await asUser.mutation(api.users.createProfile, {
        name: "RevenueCat Preflight User",
        city: "Toronto",
        province: "ON",
      });

      const result = await asAdmin.action((api as any).admin.resetDatabaseAndRevenueCat, {});

      expect(result.revenueCatCleanup.status).toBe("skipped");
      expect(result.revenueCatCleanup.attemptedCustomers).toBe(1);
      expect(result.revenueCatCleanup.message).toContain("REVENUECAT_SECRET_API_KEY is not configured");
      expect(result.deletedUsers).toBe(1);
      expect(result.adminUser.email).toBe("admin@example.com");
      expect(result.reviewAccess.enabled).toBe(true);

      const user = await t.run(async (ctx) => await ctx.db.get(userId));
      expect(user).toBeNull();
    } finally {
      process.env.ADMIN_EMAILS = previousAdminEmails;
      if (previousRevenueCatSecret === undefined) {
        delete process.env.REVENUECAT_SECRET_API_KEY;
      } else {
        process.env.REVENUECAT_SECRET_API_KEY = previousRevenueCatSecret;
      }
      vi.resetModules();
    }
  });

  test("admin resetDatabaseAndRevenueCat sends JSON content type when deleting RevenueCat customers", async () => {
    const previousAdminEmails = process.env.ADMIN_EMAILS;
    const previousRevenueCatSecret = process.env.REVENUECAT_SECRET_API_KEY;
    const originalFetch = globalThis.fetch;
    process.env.ADMIN_EMAILS = "admin@example.com";
    process.env.REVENUECAT_SECRET_API_KEY = "secret_test_key";
    const fetchMock = vi.fn(async () => new Response(JSON.stringify({ deleted: true }), { status: 200 }));
    globalThis.fetch = fetchMock;

    try {
      const t = convexTest(schema, await adminFeedbackModules());

      const asAdmin = t.withIdentity({
        tokenIdentifier: "google|feedback-admin-reset-revenuecat-delete",
        email: "admin@example.com",
      });
      const asUser = t.withIdentity({
        tokenIdentifier: "google|feedback-user-reset-revenuecat-delete",
        email: "feedback-reset-revenuecat-delete@example.com",
      });

      await asUser.mutation(api.users.createProfile, {
        name: "RevenueCat Delete User",
        city: "Toronto",
        province: "ON",
      });

      const result = await asAdmin.action((api as any).admin.resetDatabaseAndRevenueCat, {});

      expect(result.revenueCatCleanup.status).toBe("completed");
      expect(fetchMock).toHaveBeenCalledOnce();
      const [, init] = fetchMock.mock.calls[0]!;
      expect(init?.method).toBe("DELETE");
      expect(init?.headers).toMatchObject({
        Authorization: "Bearer secret_test_key",
        "Content-Type": "application/json",
      });
    } finally {
      globalThis.fetch = originalFetch;
      process.env.ADMIN_EMAILS = previousAdminEmails;
      if (previousRevenueCatSecret === undefined) {
        delete process.env.REVENUECAT_SECRET_API_KEY;
      } else {
        process.env.REVENUECAT_SECRET_API_KEY = previousRevenueCatSecret;
      }
      vi.resetModules();
    }
  });
});
