"use node";

import { convexTest } from "convex-test";
import { expect, test, describe } from "vitest";
import { readdirSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import geospatialSchema from "../../node_modules/@convex-dev/geospatial/dist/component/schema.js";
import { api, internal } from "../_generated/api";
import schema from "../schema";
import * as usersModule from "../users";
import * as categoriesModule from "../categories";
import * as taskersModule from "../taskers";
import * as taskersInternalModule from "../taskersInternal";
import * as filesModule from "../files";

const modules: Record<string, () => Promise<any>> = {
  "../users.ts": async () => usersModule,
  "../categories.ts": async () => categoriesModule,
  "../taskers.ts": async () => taskersModule,
  "../taskersInternal.ts": async () => taskersInternalModule,
  "../location.ts": async () => await import("../location"),
  "../search.ts": async () => await import("../search"),
  "../files.ts": async () => filesModule,
  "../_generated/api.ts": async () => ({ default: api }),
  "../schema.ts": async () => ({ default: schema }),
};

const geospatialRoot = fileURLToPath(
  new URL(
    "../../node_modules/@convex-dev/geospatial/dist/component/",
    import.meta.url
  )
);
const geospatialModules = buildComponentModules(geospatialRoot);

function buildComponentModules(
  rootDir: string
): Record<string, () => Promise<unknown>> {
  const modules: Record<string, () => Promise<unknown>> = {};
  const walk = (dir: string) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const fullPath = join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(fullPath);
        continue;
      }
      if (!entry.name.endsWith(".js")) {
        continue;
      }
      const relPath = relative(rootDir, fullPath).replaceAll("\\", "/");
      const key = `./component/${relPath}`;
      modules[key] = () => import(pathToFileURL(fullPath).href);
    }
  };

  walk(rootDir);
  return modules;
}

const registerGeospatial = (t: ReturnType<typeof convexTest>) => {
  t.registerComponent("geospatial", geospatialSchema, geospatialModules);
};

const createTest = () => {
  const t = convexTest(schema, modules);
  registerGeospatial(t);
  return t;
};

const PATCHWORK_REVENUECAT_APP_ID = "app6be2ab0fb8";
const PATCHWORK_BASIC_MONTHLY_PRODUCT_ID = "ltd.ddga.patchwork.tasker.subscription.basic.monthly";
const PATCHWORK_ANNUAL_PRODUCT_ID = "ltd.ddga.patchwork.tasker.subscription.yearly";

async function applyAnnualRevenueCatAccess(
  t: ReturnType<typeof convexTest>,
  userId: string,
  expirationAtMs?: number,
) {
  return await t.mutation(internal.taskersInternal.applyRevenueCatWebhookEvent, {
    type: "INITIAL_PURCHASE",
    appId: PATCHWORK_REVENUECAT_APP_ID,
    productId: PATCHWORK_ANNUAL_PRODUCT_ID,
    appUserId: userId,
    aliases: [],
    expirationAtMs: expirationAtMs ?? null,
  });
}

async function applyBasicRevenueCatAccess(
  t: ReturnType<typeof convexTest>,
  userId: string,
  expirationAtMs?: number,
) {
  return await t.mutation(internal.taskersInternal.applyRevenueCatWebhookEvent, {
    type: "INITIAL_PURCHASE",
    appId: PATCHWORK_REVENUECAT_APP_ID,
    productId: PATCHWORK_BASIC_MONTHLY_PRODUCT_ID,
    appUserId: userId,
    aliases: [],
    expirationAtMs: expirationAtMs ?? null,
  });
}

describe("searchTaskers", () => {
  test("returns taskers in category", async () => {
    const t = createTest();

    // Seed categories
    await t.mutation(internal.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "interior-cleaning-services");
    expect(cleaningCategory).toBeDefined();

    // Create tasker user
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker1",
      email: "tasker1@example.com",
    });

    await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 1",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker profile with cleaning category
    await asTasker.mutation(
      api.taskers.createTaskerProfile,
      {
        displayName: "Tasker 1 Pro",
        categoryId: cleaningCategory!._id,
        categoryBio: "I clean houses",
        rateType: "hourly",
        hourlyRate: 5000,
        serviceRadius: 10,
      }
    );

    const taskerUser = await asTasker.query(api.users.getCurrentUser);
    expect(taskerUser).not.toBeNull();
    await applyAnnualRevenueCatAccess(t, taskerUser!._id);

    await asTasker.mutation(api.users.checkInGpsLocation, {
      lat: 43.65107,
      lng: -79.347015,
    });

    // Search for cleaning taskers
    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "interior-cleaning-services",
      lat: 43.65,
      lng: -79.38,
      radiusKm: 50,
    });

    expect(results).toBeDefined();
    expect(results.length).toBe(1);
    expect(results[0].name).toBe("Tasker 1 Pro");
    expect(results[0].category).toBe("Interior Cleaning Services");
  });

  test("returns taskers matching any requested category slug", async () => {
    const t = createTest();

    await t.mutation(internal.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "interior-cleaning-services");
    const plumbingCategory = categories.find((c) => c.slug === "plumber");
    const paintingCategory = categories.find((c) => c.slug === "interior-painter");
    expect(cleaningCategory).toBeDefined();
    expect(plumbingCategory).toBeDefined();
    expect(paintingCategory).toBeDefined();

    const asCleaner = t.withIdentity({
      tokenIdentifier: "google|multi-category-cleaner",
      email: "multi-category-cleaner@example.com",
    });
    await asCleaner.mutation(api.users.createProfile, {
      name: "Cleaner",
      city: "Toronto",
      province: "ON",
    });
    await asCleaner.mutation(api.taskers.createTaskerProfile, {
      displayName: "Cleaner Pro",
      categoryId: cleaningCategory!._id,
      categoryBio: "I clean houses",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 10,
    });
    const cleanerUser = await asCleaner.query(api.users.getCurrentUser);
    await applyAnnualRevenueCatAccess(t, cleanerUser!._id);
    await asCleaner.mutation(api.users.checkInGpsLocation, {
      lat: 43.65107,
      lng: -79.347015,
    });

    const asPlumber = t.withIdentity({
      tokenIdentifier: "google|multi-category-plumber",
      email: "multi-category-plumber@example.com",
    });
    await asPlumber.mutation(api.users.createProfile, {
      name: "Plumber",
      city: "Toronto",
      province: "ON",
    });
    await asPlumber.mutation(api.taskers.createTaskerProfile, {
      displayName: "Plumber Pro",
      categoryId: plumbingCategory!._id,
      categoryBio: "I fix pipes",
      rateType: "hourly",
      hourlyRate: 6000,
      serviceRadius: 10,
    });
    const plumberUser = await asPlumber.query(api.users.getCurrentUser);
    await applyAnnualRevenueCatAccess(t, plumberUser!._id);
    await asPlumber.mutation(api.users.checkInGpsLocation, {
      lat: 43.65107,
      lng: -79.347015,
    });

    const results = await t.query(api.search.searchTaskers, {
      categorySlugs: ["interior-cleaning-services", "plumber"],
      lat: 43.65,
      lng: -79.38,
      radiusKm: 50,
    });

    expect(results.map((result) => result.name).sort()).toEqual(["Cleaner Pro", "Plumber Pro"]);

    const narrowedResults = await t.query(api.search.searchTaskers, {
      categorySlugs: ["interior-painter"],
      lat: 43.65,
      lng: -79.38,
      radiusKm: 50,
    });
    expect(narrowedResults).toHaveLength(0);

    const explicitEmptyResults = await t.query(api.search.searchTaskers, {
      categorySlugs: [],
      lat: 43.65,
      lng: -79.38,
      radiusKm: 50,
    });
    expect(explicitEmptyResults).toHaveLength(0);
  });

  test("preserves index-order category selection for multi-category taskers", async () => {
    const t = createTest();

    await t.mutation(internal.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "interior-cleaning-services");
    const plumbingCategory = categories.find((c) => c.slug === "plumber");
    expect(cleaningCategory).toBeDefined();
    expect(plumbingCategory).toBeDefined();

    const matchingCategories = [cleaningCategory!, plumbingCategory!].sort((a, b) =>
      a._id < b._id ? -1 : a._id > b._id ? 1 : 0
    );
    const requestedSlugs = [...matchingCategories].reverse().map((category) => category.slug);

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|multi-category-order",
      email: "multi-category-order@example.com",
    });
    await asTasker.mutation(api.users.createProfile, {
      name: "Multi Category Tasker",
      city: "Toronto",
      province: "ON",
    });
    await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Multi Category Pro",
      categoryId: cleaningCategory!._id,
      categoryBio: "I clean houses",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 25,
    });
    await asTasker.mutation(api.taskers.addTaskerCategory, {
      categoryId: plumbingCategory!._id,
      categoryBio: "I fix pipes",
      rateType: "hourly",
      hourlyRate: 6000,
      serviceRadius: 25,
    });

    const taskerUser = await asTasker.query(api.users.getCurrentUser);
    await applyAnnualRevenueCatAccess(t, taskerUser!._id);
    await asTasker.mutation(api.users.checkInGpsLocation, {
      lat: 43.65107,
      lng: -79.347015,
    });

    const results = await t.query(api.search.searchTaskers, {
      categorySlugs: requestedSlugs,
      lat: 43.65,
      lng: -79.38,
      radiusKm: 50,
    });

    expect(results).toHaveLength(1);
    expect(results[0].name).toBe("Multi Category Pro");
    expect(results[0].category).toBe(matchingCategories[0].name);
  });

  test("syncs tasker geo from prior GPS check-in when a seeker creates a tasker profile", async () => {
    const t = createTest();

    await t.mutation(internal.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "interior-cleaning-services");
    expect(cleaningCategory).toBeDefined();

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker-existing-location",
      email: "tasker-existing-location@example.com",
    });

    await asTasker.mutation(api.users.createProfile, {
      name: "Located Tasker",
      city: "Toronto",
      province: "ON",
    });

    const taskerLat = 43.65107;
    const taskerLng = -79.347015;
    await asTasker.mutation(api.users.checkInGpsLocation, {
      lat: taskerLat,
      lng: taskerLng,
    });

    await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Located Tasker Pro",
      categoryId: cleaningCategory!._id,
      categoryBio: "I clean houses",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 10,
    });

    const profile = await asTasker.query(api.taskers.getTaskerProfile);
    expect(profile?.location?.lat).toBe(taskerLat);
    expect(profile?.location?.lng).toBe(taskerLng);

    const taskerUser = await asTasker.query(api.users.getCurrentUser);
    expect(taskerUser).not.toBeNull();
    await applyAnnualRevenueCatAccess(t, taskerUser!._id);

    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "interior-cleaning-services",
      lat: taskerLat,
      lng: taskerLng,
      radiusKm: 5,
    });

    expect(results.map((result) => result.name)).toContain("Located Tasker Pro");
  });

  test("does not sync tasker geo when RevenueCat activates a profile with only manual coordinates", async () => {
    const t = createTest();

    await t.mutation(internal.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "interior-cleaning-services");
    expect(cleaningCategory).toBeDefined();

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker-activation-location",
      email: "tasker-activation-location@example.com",
    });

    await asTasker.mutation(api.users.createProfile, {
      name: "Activation Tasker",
      city: "Toronto",
      province: "ON",
    });

    await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Activation Tasker Pro",
      categoryId: cleaningCategory!._id,
      categoryBio: "I clean houses",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 10,
    });

    const taskerUser = await asTasker.query(api.users.getCurrentUser);
    expect(taskerUser).not.toBeNull();

    const manualLat = 43.65107;
    const manualLng = -79.347015;
    await t.run(async (ctx) => {
      const user = await ctx.db.get(taskerUser!._id);
      expect(user).not.toBeNull();
      await ctx.db.patch(taskerUser!._id, {
        location: {
          ...user!.location,
          coordinates: {
            lat: manualLat,
            lng: manualLng,
          },
        },
        settings: {
          ...user!.settings,
          locationEnabled: true,
        },
        updatedAt: Date.now(),
      });
    });

    const profileBeforeActivation = await asTasker.query(api.taskers.getTaskerProfile);
    expect(profileBeforeActivation?.location).toBeUndefined();

    await applyAnnualRevenueCatAccess(t, taskerUser!._id);

    const profileAfterActivation = await asTasker.query(api.taskers.getTaskerProfile);
    expect(profileAfterActivation?.location).toBeUndefined();
    expect(profileAfterActivation?.locationCheckedInAt).toBeUndefined();

    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "interior-cleaning-services",
      lat: manualLat,
      lng: manualLng,
      radiusKm: 5,
    });

    expect(results.map((result) => result.name)).not.toContain("Activation Tasker Pro");
  });

  test("excludes indexed taskers without a GPS check-in marker", async () => {
    const t = createTest();

    await t.mutation(internal.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "interior-cleaning-services");
    expect(cleaningCategory).toBeDefined();

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker-stale-indexed-location",
      email: "tasker-stale-indexed-location@example.com",
    });

    await asTasker.mutation(api.users.createProfile, {
      name: "Stale Indexed Tasker",
      city: "Toronto",
      province: "ON",
    });

    await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Stale Indexed Pro",
      categoryId: cleaningCategory!._id,
      categoryBio: "I clean houses",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 10,
    });

    const taskerUser = await asTasker.query(api.users.getCurrentUser);
    expect(taskerUser).not.toBeNull();
    await applyAnnualRevenueCatAccess(t, taskerUser!._id);

    const taskerLat = 43.65107;
    const taskerLng = -79.347015;
    await asTasker.mutation(api.users.checkInGpsLocation, {
      lat: taskerLat,
      lng: taskerLng,
    });

    const profile = await asTasker.query(api.taskers.getTaskerProfile);
    expect(profile?.locationCheckedInAt).toBeDefined();

    await t.run(async (ctx) => {
      await ctx.db.patch(profile!._id, {
        locationCheckedInAt: undefined,
      });
    });

    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "interior-cleaning-services",
      lat: taskerLat,
      lng: taskerLng,
      radiusKm: 5,
    });

    expect(results.map((result) => result.name)).not.toContain("Stale Indexed Pro");
  });

  test("excludes ghostMode=true taskers", async () => {
    const t = createTest();

    // Seed categories
    await t.mutation(internal.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "interior-cleaning-services");

    // Create tasker user
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker2",
      email: "tasker2@example.com",
    });

    await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 2",
      city: "Toronto",
      province: "ON",
    });

    const taskerProfileId = await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Tasker 2 Pro",
      categoryId: cleaningCategory!._id,
      categoryBio: "I clean houses",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 10,
    });

    const taskerUser = await asTasker.query(api.users.getCurrentUser);
    expect(taskerUser).not.toBeNull();
    await applyAnnualRevenueCatAccess(t, taskerUser!._id);

    await asTasker.mutation(api.users.checkInGpsLocation, {
      lat: 43.65107,
      lng: -79.347015,
    });

    await t.run(async (ctx) => {
      await ctx.db.patch(taskerProfileId, {
        ghostMode: true,
      });
    });

    // Search for cleaning taskers
    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "interior-cleaning-services",
      lat: 43.65,
      lng: -79.38,
      radiusKm: 50,
    });

    // Should not find the tasker with ghost mode enabled
    expect(results.length).toBe(0);
  });

  test("excludes taskers without an active subscription", async () => {
    const t = createTest();

    await t.mutation(internal.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "interior-cleaning-services");

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker2b",
      email: "tasker2b@example.com",
    });

    await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 2B",
      city: "Toronto",
      province: "ON",
    });

    await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Tasker 2B Pro",
      categoryId: cleaningCategory!._id,
      categoryBio: "I clean houses",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 10,
    });

    await asTasker.mutation(api.users.checkInGpsLocation, {
      lat: 43.65107,
      lng: -79.347015,
    });

    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "interior-cleaning-services",
      lat: 43.65,
      lng: -79.38,
      radiusKm: 50,
    });

    expect(results.length).toBe(0);
  });

  test("excludes isOnboarded=false taskers", async () => {
    const t = createTest();

    await t.mutation(internal.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "interior-cleaning-services");

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker3",
      email: "tasker3@example.com",
    });

    const userId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 3",
      city: "Toronto",
      province: "ON",
    });

    await t.run(async (ctx) => {
      const profileId = await ctx.db.insert("taskerProfiles", {
        userId,
        displayName: "Tasker 3 Pro",
        websiteLinks: [],
        socialLinks: [],
        isOnboarded: false,
        rating: 0,
        reviewCount: 0,
        completedJobs: 0,
        verified: false,
        subscriptionPlan: "none",
        subscriptionStatus: "inactive",
        ghostMode: true,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });

      await ctx.db.insert("taskerCategories", {
        taskerProfileId: profileId,
        userId,
        categoryId: cleaningCategory!._id,
        bio: "I clean houses",
        photos: [],
        rateType: "hourly",
        hourlyRate: 5000,
        serviceRadius: 10,
        rating: 0,
        reviewCount: 0,
        completedJobs: 0,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });

      return profileId;
    });

    await asTasker.mutation(api.users.checkInGpsLocation, {
      lat: 43.65107,
      lng: -79.347015,
    });

    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "interior-cleaning-services",
      lat: 43.65,
      lng: -79.38,
      radiusKm: 50,
    });

    expect(results.length).toBe(0);
  });

  test("returns empty array when no matches", async () => {
    const t = createTest();

    // Seed categories
    await t.mutation(internal.categories.seedCategories);

    // Search for taskers in a category with no taskers
    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "plumber",
      lat: 43.65,
      lng: -79.38,
      radiusKm: 50,
    });

    expect(results).toBeDefined();
    expect(results.length).toBe(0);
  });

  test("returns formatted data with expected fields", async () => {
    const t = createTest();

    // Seed categories
    await t.mutation(internal.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "interior-cleaning-services");

    // Create tasker user
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker4",
      email: "tasker4@example.com",
    });

    const userId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 4",
      city: "Toronto",
      province: "ON",
    });

    await asTasker.mutation(
      api.taskers.createTaskerProfile,
      {
        displayName: "Tasker 4 Pro",
        categoryId: cleaningCategory!._id,
        categoryBio: "I clean houses professionally",
        rateType: "hourly",
        hourlyRate: 5000,
        serviceRadius: 10,
      }
    );

    const taskerUser = await asTasker.query(api.users.getCurrentUser);
    expect(taskerUser).not.toBeNull();
    await applyAnnualRevenueCatAccess(t, taskerUser!._id);

    await asTasker.mutation(api.users.checkInGpsLocation, {
      lat: 43.65107,
      lng: -79.347015,
    });

    // Search for cleaning taskers
    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "interior-cleaning-services",
      lat: 43.65,
      lng: -79.38,
      radiusKm: 50,
    });

    expect(results.length).toBe(1);
    const tasker = results[0];

    // Verify all required fields
    expect(tasker.id).toBeDefined();
    expect(tasker.userId).toBe(userId);
    expect(tasker.name).toBe("Tasker 4 Pro");
    expect(tasker.category).toBe("Interior Cleaning Services");
    expect(tasker.rating).toBe(0); // Default rating
    expect(tasker.reviews).toBe(0); // Default review count
    expect(tasker.price).toBe("$50/hr"); // Formatted from 5000 cents hourly
    expect(tasker.distance).toBeDefined();
    expect(typeof tasker.distance).toBe("string");
    expect(tasker.verified).toBe(false); // Default verification status
    expect(tasker.bio).toBe("I clean houses professionally");
    expect(tasker.completedJobs).toBe(0); // Default completed jobs
  });

  test("formats fixed rate correctly", async () => {
    const t = createTest();

    // Seed categories
    await t.mutation(internal.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "interior-cleaning-services");

    // Create tasker user
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker5",
      email: "tasker5@example.com",
    });

    await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 5",
      city: "Toronto",
      province: "ON",
    });

    await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Tasker 5 Pro",
      categoryId: cleaningCategory!._id,
      categoryBio: "I clean houses",
      rateType: "fixed",
      fixedRate: 15000,
      serviceRadius: 10,
    });

    const taskerUser = await asTasker.query(api.users.getCurrentUser);
    expect(taskerUser).not.toBeNull();
    await applyAnnualRevenueCatAccess(t, taskerUser!._id);

    await asTasker.mutation(api.users.checkInGpsLocation, {
      lat: 43.65107,
      lng: -79.347015,
    });

    // Search for cleaning taskers
    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "interior-cleaning-services",
      lat: 43.65,
      lng: -79.38,
      radiusKm: 50,
    });

    expect(results.length).toBe(1);
    expect(results[0].price).toBe("$150 flat"); // Formatted from 15000 cents fixed
  });

  test("excludes when outside seeker search radius even if tasker service radius reaches", async () => {
    const t = createTest();

    await t.mutation(internal.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "interior-cleaning-services");

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker6",
      email: "tasker6@example.com",
    });

    await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 6",
      city: "Toronto",
      province: "ON",
    });

    await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Tasker 6 Pro",
      categoryId: cleaningCategory!._id,
      categoryBio: "I clean houses",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 200,
    });

    const taskerUser = await asTasker.query(api.users.getCurrentUser);
    expect(taskerUser).not.toBeNull();
    await applyAnnualRevenueCatAccess(t, taskerUser!._id);

    const seekerLat = 43.65;
    const seekerLng = -79.38;

    await asTasker.mutation(api.users.checkInGpsLocation, {
      lat: seekerLat + 1.7,
      lng: seekerLng,
    });

    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "interior-cleaning-services",
      lat: seekerLat,
      lng: seekerLng,
      radiusKm: 5,
    });

    expect(results.length).toBe(0);
  });

  test("excludes when outside tasker service radius even if seeker search radius reaches", async () => {
    const t = createTest();

    await t.mutation(internal.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "interior-cleaning-services");

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker7",
      email: "tasker7@example.com",
    });

    await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 7",
      city: "Toronto",
      province: "ON",
    });

    await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Tasker 7 Pro",
      categoryId: cleaningCategory!._id,
      categoryBio: "I clean houses",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 5,
    });

    const taskerUser = await asTasker.query(api.users.getCurrentUser);
    expect(taskerUser).not.toBeNull();
    await applyAnnualRevenueCatAccess(t, taskerUser!._id);

    const seekerLat = 43.65;
    const seekerLng = -79.38;

    await asTasker.mutation(api.users.checkInGpsLocation, {
      lat: seekerLat + 0.09,
      lng: seekerLng,
    });

    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "interior-cleaning-services",
      lat: seekerLat,
      lng: seekerLng,
      radiusKm: 100,
    });

    expect(results.length).toBe(0);
  });

  test("matches only when both seeker radius and tasker service radius include the distance", async () => {
    const t = createTest();

    await t.mutation(internal.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "interior-cleaning-services");

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker8",
      email: "tasker8@example.com",
    });

    await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 8",
      city: "Toronto",
      province: "ON",
    });

    await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Tasker 8 Pro",
      categoryId: cleaningCategory!._id,
      categoryBio: "I clean houses",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 20,
    });

    const taskerUser = await asTasker.query(api.users.getCurrentUser);
    expect(taskerUser).not.toBeNull();
    await applyAnnualRevenueCatAccess(t, taskerUser!._id);

    const seekerLat = 43.65;
    const seekerLng = -79.38;

    await asTasker.mutation(api.users.checkInGpsLocation, {
      lat: seekerLat + 0.09,
      lng: seekerLng,
    });

    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "interior-cleaning-services",
      lat: seekerLat,
      lng: seekerLng,
      radiusKm: 100,
    });

    expect(results.length).toBe(1);
    expect(results[0].name).toBe("Tasker 8 Pro");
  });

  test("searchTaskerByPremiumPin bypasses location and category filters for active premium taskers", async () => {
    const t = createTest();

    await t.mutation(internal.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const plumbingCategory = categories.find((c) => c.slug === "plumber");
    expect(plumbingCategory).toBeDefined();

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|pin-premium",
      email: "pin-premium@example.com",
    });

    await asTasker.mutation(api.users.createProfile, {
      name: "Pin Premium",
      city: "Toronto",
      province: "ON",
    });

    await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Pin Premium Pro",
      categoryId: plumbingCategory!._id,
      categoryBio: "I fix pipes",
      rateType: "hourly",
      hourlyRate: 6000,
      serviceRadius: 1,
    });

    const taskerUser = await asTasker.query(api.users.getCurrentUser);
    expect(taskerUser).not.toBeNull();
    await applyAnnualRevenueCatAccess(t, taskerUser!._id);

    const profile = await asTasker.query(api.taskers.getTaskerProfile);
    expect(profile?.premiumPin?.code).toMatch(/^[0-9A-Z]{8}$/);

    const normalResults = await t.query(api.search.searchTaskers, {
      categorySlug: "interior-cleaning-services",
      lat: 0,
      lng: 0,
      radiusKm: 1,
    });
    expect(normalResults).toHaveLength(0);

    const pinResults = await t.query(api.search.searchTaskerByPremiumPin, {
      pin: profile!.premiumPin!.code.toLowerCase(),
    });
    expect(pinResults).toHaveLength(1);
    expect(pinResults[0].name).toBe("Pin Premium Pro");
    expect(pinResults[0].category).toBe("Plumber");
    expect(pinResults[0].distance).toBe("Premium match");
    expect(Object.prototype.hasOwnProperty.call(pinResults[0], "premiumPin")).toBe(false);
  });

  test("searchTaskerByPremiumPin blocks inactive, ghosted, basic, and self matches", async () => {
    const t = createTest();

    await t.mutation(internal.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "interior-cleaning-services");
    expect(cleaningCategory).toBeDefined();

    const asPremium = t.withIdentity({
      tokenIdentifier: "google|pin-block-premium",
      email: "pin-block-premium@example.com",
    });
    await asPremium.mutation(api.users.createProfile, {
      name: "Pin Block Premium",
      city: "Toronto",
      province: "ON",
    });
    await asPremium.mutation(api.taskers.createTaskerProfile, {
      displayName: "Pin Block Premium Pro",
      categoryId: cleaningCategory!._id,
      categoryBio: "I clean houses",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 10,
    });
    const premiumUser = await asPremium.query(api.users.getCurrentUser);
    expect(premiumUser).not.toBeNull();
    await applyAnnualRevenueCatAccess(t, premiumUser!._id);
    const premiumProfile = await asPremium.query(api.taskers.getTaskerProfile);
    expect(premiumProfile?.premiumPin?.code).toMatch(/^[0-9A-Z]{8}$/);

    const selfResults = await t.query(api.search.searchTaskerByPremiumPin, {
      pin: premiumProfile!.premiumPin!.code,
      excludeUserId: premiumUser!._id,
    });
    expect(selfResults).toHaveLength(0);

    await t.run(async (ctx) => {
      await ctx.db.patch(premiumProfile!._id, {
        ghostMode: true,
      });
    });
    const ghostResults = await t.query(api.search.searchTaskerByPremiumPin, {
      pin: premiumProfile!.premiumPin!.code,
    });
    expect(ghostResults).toHaveLength(0);

    await t.run(async (ctx) => {
      await ctx.db.patch(premiumProfile!._id, {
        ghostMode: false,
      });
    });
    await t.mutation(internal.taskersInternal.applyRevenueCatWebhookEvent, {
      type: "EXPIRATION",
      appId: PATCHWORK_REVENUECAT_APP_ID,
      productId: PATCHWORK_ANNUAL_PRODUCT_ID,
      appUserId: premiumUser!._id,
      aliases: [],
      expirationAtMs: Date.now() - 1_000,
    });
    const expiredResults = await t.query(api.search.searchTaskerByPremiumPin, {
      pin: premiumProfile!.premiumPin!.code,
    });
    expect(expiredResults).toHaveLength(0);

    const asBasic = t.withIdentity({
      tokenIdentifier: "google|pin-block-basic",
      email: "pin-block-basic@example.com",
    });
    await asBasic.mutation(api.users.createProfile, {
      name: "Pin Block Basic",
      city: "Toronto",
      province: "ON",
    });
    await asBasic.mutation(api.taskers.createTaskerProfile, {
      displayName: "Pin Block Basic Pro",
      categoryId: cleaningCategory!._id,
      categoryBio: "I clean houses",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 10,
    });
    const basicUser = await asBasic.query(api.users.getCurrentUser);
    expect(basicUser).not.toBeNull();
    await applyBasicRevenueCatAccess(t, basicUser!._id);
    const basicProfile = await asBasic.query(api.taskers.getTaskerProfile);
    expect(basicProfile?.premiumPin).toBeUndefined();
  });
});
