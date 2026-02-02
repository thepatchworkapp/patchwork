import { convexTest } from "convex-test";
import { expect, test, describe } from "vitest";
import { readdirSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import geospatialSchema from "../../node_modules/@convex-dev/geospatial/dist/component/schema.js";
import { api } from "../_generated/api";
import schema from "../schema";
import * as usersModule from "../users";
import * as categoriesModule from "../categories";
import * as taskersModule from "../taskers";
import * as filesModule from "../files";

const modules: Record<string, () => Promise<any>> = {
  "../users.ts": async () => usersModule,
  "../categories.ts": async () => categoriesModule,
  "../taskers.ts": async () => taskersModule,
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

describe("searchTaskers", () => {
  test("returns taskers in category", async () => {
    const t = createTest();

    // Seed categories
    await t.mutation(api.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "cleaning");
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

    await asTasker.mutation(api.location.updateTaskerLocation, {
      lat: 43.65107,
      lng: -79.347015,
    });

    // Search for cleaning taskers
    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "cleaning",
      lat: 43.65,
      lng: -79.38,
      radiusKm: 50,
    });

    expect(results).toBeDefined();
    expect(results.length).toBe(1);
    expect(results[0].name).toBe("Tasker 1 Pro");
    expect(results[0].category).toBe("Cleaning");
  });

  test("excludes ghostMode=true taskers", async () => {
    const t = createTest();

    // Seed categories
    await t.mutation(api.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "cleaning");

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

    await asTasker.mutation(api.location.updateTaskerLocation, {
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
      categorySlug: "cleaning",
      lat: 43.65,
      lng: -79.38,
      radiusKm: 50,
    });

    // Should not find the tasker with ghost mode enabled
    expect(results.length).toBe(0);
  });

  test("excludes isOnboarded=false taskers", async () => {
    const t = createTest();

    await t.mutation(api.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "cleaning");

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
        isOnboarded: false,
        rating: 0,
        reviewCount: 0,
        completedJobs: 0,
        verified: false,
        subscriptionPlan: "none",
        ghostMode: false,
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

    await asTasker.mutation(api.location.updateTaskerLocation, {
      lat: 43.65107,
      lng: -79.347015,
    });

    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "cleaning",
      lat: 43.65,
      lng: -79.38,
      radiusKm: 50,
    });

    expect(results.length).toBe(0);
  });

  test("returns empty array when no matches", async () => {
    const t = createTest();

    // Seed categories
    await t.mutation(api.categories.seedCategories);

    // Search for taskers in a category with no taskers
    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "plumbing",
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
    await t.mutation(api.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "cleaning");

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

    await asTasker.mutation(api.location.updateTaskerLocation, {
      lat: 43.65107,
      lng: -79.347015,
    });

    // Search for cleaning taskers
    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "cleaning",
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
    expect(tasker.category).toBe("Cleaning");
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
    await t.mutation(api.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "cleaning");

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

    await asTasker.mutation(api.location.updateTaskerLocation, {
      lat: 43.65107,
      lng: -79.347015,
    });

    // Search for cleaning taskers
    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "cleaning",
      lat: 43.65,
      lng: -79.38,
      radiusKm: 50,
    });

    expect(results.length).toBe(1);
    expect(results[0].price).toBe("$150 flat"); // Formatted from 15000 cents fixed
  });

  test("matches when service area overlaps seeker radius", async () => {
    const t = createTest();

    await t.mutation(api.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "cleaning");

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

    const seekerLat = 43.65;
    const seekerLng = -79.38;

    await asTasker.mutation(api.location.updateTaskerLocation, {
      lat: seekerLat + 1.7,
      lng: seekerLng,
    });

    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "cleaning",
      lat: seekerLat,
      lng: seekerLng,
      radiusKm: 5,
    });

    expect(results.length).toBe(1);
  });

  test("excludes when outside combined service areas", async () => {
    const t = createTest();

    await t.mutation(api.categories.seedCategories);
    const categories = await t.query(api.categories.listCategories);
    const cleaningCategory = categories.find((c) => c.slug === "cleaning");

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
      serviceRadius: 200,
    });

    const seekerLat = 43.65;
    const seekerLng = -79.38;

    await asTasker.mutation(api.location.updateTaskerLocation, {
      lat: seekerLat + 2.0,
      lng: seekerLng,
    });

    const results = await t.query(api.search.searchTaskers, {
      categorySlug: "cleaning",
      lat: seekerLat,
      lng: seekerLng,
      radiusKm: 5,
    });

    expect(results.length).toBe(0);
  });
});
