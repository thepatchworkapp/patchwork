import { convexTest } from "convex-test";
import { describe, expect, test, vi } from "vitest";
import { v } from "convex/values";
import { api } from "../_generated/api";
import { internalMutation } from "../_generated/server";
import schema from "../schema";

async function analyticsModules() {
  const analyticsModule = await import("../analytics");
  const usersModule = await import("../users");
  const authModule = await import("../auth");

  return {
    "../analytics.ts": async () => analyticsModule,
    "../users.ts": async () => usersModule,
    "../auth.ts": async () => authModule,
    "../_generated/api.ts": async () => ({ default: api }),
    "../schema.ts": async () => ({ default: schema }),
  };
}

async function adminAnalyticsModules() {
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
          deleteMany: async () => undefined,
        }),
    },
  }));
  vi.doMock("../reviewAccess", () => ({
    APP_REVIEW_EMAIL: "review@apple.com",
    APP_REVIEW_SEEKER_EMAIL: "seeker@apple.com",
    getReviewAccessStatus: vi.fn(async () => ({
      email: "review@apple.com",
      allowedEmails: ["review@apple.com", "seeker@apple.com"],
      enabled: true,
      betterAuthUserId: null,
      appUserId: null,
      lastEnabledAt: Date.now(),
      lastDisabledAt: null,
      updatedAt: Date.now(),
    })),
    setReviewAccessEnabled: vi.fn(),
  }));
  vi.doMock("../geospatial", () => ({
    taskerGeo: {
      nearest: vi.fn(async () => []),
      remove: vi.fn(async () => false),
    },
  }));
  vi.doMock("../resend", () => ({
    sendOtpEmail: internalMutation({
      args: {
        email: v.string(),
        otp: v.string(),
        purpose: v.union(v.literal("admin-login"), v.literal("email-login"), v.literal("email-signup")),
      },
      handler: async () => undefined,
    }),
    cleanupEmailArtifacts: internalMutation({
      args: {},
      returns: v.object({ cleanupPasses: v.number() }),
      handler: async () => ({ cleanupPasses: 0 }),
    }),
  }));

  const baseModules = await analyticsModules();
  const adminModule = await import("../admin");
  const resendModule = await import("../resend");

  return {
    ...baseModules,
    "../admin.ts": async () => adminModule,
    "../resend.ts": async () => resendModule,
  };
}

function dayKey(offsetDays = 0): string {
  return new Date(Date.now() + offsetDays * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

async function insertCategory(t: any, overrides: Partial<{
  name: string;
  slug: string;
  isActive: boolean;
}> = {}) {
  const name = overrides.name ?? "Interior Cleaning Services";
  const slug = overrides.slug ?? "interior-cleaning-services";
  return await t.run(async (ctx: any) =>
    await ctx.db.insert("categories", {
      name,
      slug,
      emoji: "🧹",
      group: "Home & Garden",
      isActive: overrides.isActive ?? true,
      sortOrder: 1,
    })
  );
}

async function createUser(asUser: any, name: string) {
  return await asUser.mutation((api as any).users.createProfile, {
    name,
    city: "Toronto",
    province: "ON",
  });
}

describe("discover analytics", () => {
  test("records one category selection per user, category, and day", async () => {
    const t = convexTest(schema, await analyticsModules());
    const cleaningId = await insertCategory(t);
    const paintingId = await insertCategory(t, { name: "Interior Painter", slug: "interior-painter" });

    const asFirstUser = t.withIdentity({
      tokenIdentifier: "google|analytics-user-1",
      email: "analytics-user-1@example.com",
    });
    const asSecondUser = t.withIdentity({
      tokenIdentifier: "google|analytics-user-2",
      email: "analytics-user-2@example.com",
    });
    await createUser(asFirstUser, "Analytics User 1");
    await createUser(asSecondUser, "Analytics User 2");

    await asFirstUser.mutation((api as any).analytics.recordDiscoverCategorySelection, {
      categorySlug: "interior-cleaning-services",
    });
    const duplicate = await asFirstUser.mutation((api as any).analytics.recordDiscoverCategorySelection, {
      categorySlug: "interior-cleaning-services",
    });
    await asFirstUser.mutation((api as any).analytics.recordDiscoverCategorySelection, {
      categorySlug: "interior-painter",
    });
    await asSecondUser.mutation((api as any).analytics.recordDiscoverCategorySelection, {
      categorySlug: "interior-cleaning-services",
    });

    expect(duplicate).toEqual({ recorded: false, reason: "already_recorded_today" });

    const buckets = await t.run(async (ctx: any) =>
      await ctx.db.query("discoverCategoryDailyViews").withIndex("by_day_category").take(10)
    );
    const cleaning = buckets.find((bucket: any) => bucket.categoryId === cleaningId);
    const painting = buckets.find((bucket: any) => bucket.categoryId === paintingId);
    expect(cleaning?.viewCount).toBe(2);
    expect(cleaning?.uniqueUserCount).toBe(2);
    expect(painting?.viewCount).toBe(1);
    expect(painting?.uniqueUserCount).toBe(1);

    const dedupeRows = await t.run(async (ctx: any) =>
      await ctx.db.query("discoverCategoryUserDailyViews").withIndex("by_category_day").take(10)
    );
    expect(dedupeRows).toHaveLength(3);
  });

  test("does not create category analytics for unknown or inactive categories", async () => {
    const t = convexTest(schema, await analyticsModules());
    await insertCategory(t, { name: "Inactive", slug: "inactive", isActive: false });

    const asUser = t.withIdentity({
      tokenIdentifier: "google|analytics-inactive-user",
      email: "analytics-inactive-user@example.com",
    });
    await createUser(asUser, "Analytics Inactive User");

    await expect(
      asUser.mutation((api as any).analytics.recordDiscoverCategorySelection, {
        categorySlug: "missing",
      })
    ).rejects.toThrow("Category not found");

    const inactive = await asUser.mutation((api as any).analytics.recordDiscoverCategorySelection, {
      categorySlug: "inactive",
    });
    expect(inactive).toEqual({ recorded: false, reason: "inactive_category" });

    const buckets = await t.run(async (ctx: any) =>
      await ctx.db.query("discoverCategoryDailyViews").withIndex("by_day_category").take(10)
    );
    expect(buckets).toHaveLength(0);
  });

  test("records explicit category search submissions as normalized daily buckets", async () => {
    const t = convexTest(schema, await analyticsModules());
    const asUser = t.withIdentity({
      tokenIdentifier: "google|analytics-search-user",
      email: "analytics-search-user@example.com",
    });
    await createUser(asUser, "Analytics Search User");

    await asUser.mutation((api as any).analytics.recordDiscoverCategorySearchSubmit, {
      term: "  Cleaning   Help  ",
    });
    await asUser.mutation((api as any).analytics.recordDiscoverCategorySearchSubmit, {
      term: "cleaning help",
    });
    await expect(
      asUser.mutation((api as any).analytics.recordDiscoverCategorySearchSubmit, {
        term: "   ",
      })
    ).rejects.toThrow("Search term is required");

    const longTerm = "x".repeat(150);
    await asUser.mutation((api as any).analytics.recordDiscoverCategorySearchSubmit, {
      term: longTerm,
    });

    const buckets = await t.run(async (ctx: any) =>
      await ctx.db.query("discoverCategorySearchDailyTerms").withIndex("by_day_term").take(10)
    );
    const cleaning = buckets.find((bucket: any) => bucket.normalizedTerm === "cleaning help");
    const capped = buckets.find((bucket: any) => bucket.normalizedTerm === "x".repeat(120));
    expect(cleaning?.searchCount).toBe(2);
    expect(cleaning?.displayTerm).toBe("cleaning help");
    expect(capped?.displayTerm).toHaveLength(120);
    expect(capped?.searchCount).toBe(1);
  });

  test("admin query returns 1, 7, and 30 day Discover analytics windows", async () => {
    const previousAdminEmails = process.env.ADMIN_EMAILS;
    process.env.ADMIN_EMAILS = "admin@example.com";

    try {
      const t = convexTest(schema, await adminAnalyticsModules());
      const categoryId = await insertCategory(t);
      const now = Date.now();
      await t.run(async (ctx: any) => {
        const rows = [
          { dayKey: dayKey(0), viewCount: 1, uniqueUserCount: 1 },
          { dayKey: dayKey(-6), viewCount: 6, uniqueUserCount: 6 },
          { dayKey: dayKey(-29), viewCount: 29, uniqueUserCount: 29 },
          { dayKey: dayKey(-30), viewCount: 30, uniqueUserCount: 30 },
        ];
        for (const row of rows) {
          await ctx.db.insert("discoverCategoryDailyViews", {
            categoryId,
            categoryName: "Interior Cleaning Services",
            categorySlug: "interior-cleaning-services",
            dayKey: row.dayKey,
            viewCount: row.viewCount,
            uniqueUserCount: row.uniqueUserCount,
            createdAt: now,
            updatedAt: now,
          });
        }
        for (const row of [
          { dayKey: dayKey(0), searchCount: 2 },
          { dayKey: dayKey(-6), searchCount: 3 },
          { dayKey: dayKey(-30), searchCount: 5 },
        ]) {
          await ctx.db.insert("discoverCategorySearchDailyTerms", {
            normalizedTerm: "interior-cleaning-services",
            displayTerm: "Interior Cleaning Services",
            dayKey: row.dayKey,
            searchCount: row.searchCount,
            createdAt: now,
            updatedAt: now,
          });
        }
      });

      const asAdmin = t.withIdentity({
        tokenIdentifier: "google|analytics-admin",
        email: "admin@example.com",
      });
      const analytics = await asAdmin.query((api as any).admin.getDiscoverAnalytics, { limit: 10 });

      expect(analytics.categories).toHaveLength(1);
      expect(analytics.categories[0]).toMatchObject({
        categoryName: "Interior Cleaning Services",
        oneDayCount: 1,
        sevenDayCount: 7,
        thirtyDayCount: 36,
        oneDayUniqueUsers: 1,
        sevenDayUniqueUsers: 7,
        thirtyDayUniqueUsers: 36,
      });
      expect(analytics.categories[0].sevenDayAverage).toBe(1);
      expect(analytics.categories[0].thirtyDayAverage).toBe(1.2);
      expect(analytics.searchTerms).toHaveLength(1);
      expect(analytics.searchTerms[0]).toMatchObject({
        displayTerm: "Interior Cleaning Services",
        normalizedTerm: "interior-cleaning-services",
        oneDayCount: 2,
        sevenDayCount: 5,
        thirtyDayCount: 5,
      });
    } finally {
      process.env.ADMIN_EMAILS = previousAdminEmails;
      vi.resetModules();
    }
  });

  test("admin reset clears Discover analytics tables", async () => {
    const previousAdminEmails = process.env.ADMIN_EMAILS;
    process.env.ADMIN_EMAILS = "admin@example.com";

    try {
      const t = convexTest(schema, await adminAnalyticsModules());
      const categoryId = await insertCategory(t);
      const userId = await t.run(async (ctx: any) =>
        await ctx.db.insert("users", {
          authId: "google|analytics-reset-user",
          email: "analytics-reset-user@example.com",
          emailVerified: true,
          name: "Analytics Reset User",
          photo: undefined,
          photoAssetId: undefined,
          location: {
            city: "Toronto",
            province: "ON",
          },
          roles: {
            isSeeker: true,
            isTasker: false,
          },
          settings: {
            notificationsEnabled: true,
            locationEnabled: false,
          },
          createdAt: Date.now(),
          updatedAt: Date.now(),
        })
      );

      await t.run(async (ctx: any) => {
        await ctx.db.insert("discoverCategoryDailyViews", {
          categoryId,
          categoryName: "Interior Cleaning Services",
          categorySlug: "interior-cleaning-services",
          dayKey: dayKey(0),
          viewCount: 1,
          uniqueUserCount: 1,
          createdAt: Date.now(),
          updatedAt: Date.now(),
        });
        await ctx.db.insert("discoverCategoryUserDailyViews", {
          userId,
          categoryId,
          dayKey: dayKey(0),
          createdAt: Date.now(),
        });
        await ctx.db.insert("discoverCategorySearchDailyTerms", {
          normalizedTerm: "interior-cleaning-services",
          displayTerm: "Interior Cleaning Services",
          dayKey: dayKey(0),
          searchCount: 1,
          createdAt: Date.now(),
          updatedAt: Date.now(),
        });
      });

      const asAdmin = t.withIdentity({
        tokenIdentifier: "google|analytics-reset-admin",
        email: "admin@example.com",
      });
      const result = await asAdmin.action((api as any).admin.resetDatabase, {});
      expect(result.deletedDiscoverCategoryDailyViews).toBe(1);
      expect(result.deletedDiscoverCategoryUserDailyViews).toBe(1);
      expect(result.deletedDiscoverCategorySearchDailyTerms).toBe(1);

      const remaining = await t.run(async (ctx: any) => ({
        dailyViews: await ctx.db.query("discoverCategoryDailyViews").take(10),
        userDailyViews: await ctx.db.query("discoverCategoryUserDailyViews").take(10),
        searchTerms: await ctx.db.query("discoverCategorySearchDailyTerms").take(10),
      }));
      expect(remaining.dailyViews).toHaveLength(0);
      expect(remaining.userDailyViews).toHaveLength(0);
      expect(remaining.searchTerms).toHaveLength(0);
    } finally {
      process.env.ADMIN_EMAILS = previousAdminEmails;
      vi.resetModules();
    }
  });
});
