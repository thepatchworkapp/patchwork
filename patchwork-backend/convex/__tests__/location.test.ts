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
import * as filesModule from "../files";
import * as taskersModule from "../taskers";

const modules: Record<string, () => Promise<any>> = {
  "../users.ts": async () => usersModule,
  "../categories.ts": async () => categoriesModule,
  "../files.ts": async () => filesModule,
  "../taskers.ts": async () => taskersModule,
  "../location.ts": async () => await import("../location"),
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

describe("location", () => {
  test("updateUserLocation stores coordinates", async () => {
    const t = createTest();

    const asUser = t.withIdentity({
      tokenIdentifier: "google|location-test-1",
      email: "location1@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Location Test User",
      city: "Toronto",
      province: "ON",
    });

    await asUser.mutation(api.location.updateUserLocation, {
      lat: 43.65107,
      lng: -79.347015,
      source: "manual",
    });

    const user = await asUser.query(api.users.getCurrentUser);
    expect(user).not.toBeNull();
    expect(user?.location.coordinates).toBeDefined();
    expect(user?.location.coordinates?.lat).toBe(43.65107);
    expect(user?.location.coordinates?.lng).toBe(-79.347015);
  });

  test("updateUserLocation rejects if not authenticated", async () => {
    const t = createTest();

    await expect(
      t.mutation(api.location.updateUserLocation, {
        lat: 43.65107,
        lng: -79.347015,
        source: "manual",
      })
    ).rejects.toThrow("Unauthorized");
  });

  test("checkInGpsLocation updates taskerProfiles.location", async () => {
    const t = createTest();

    const asUser = t.withIdentity({
      tokenIdentifier: "google|location-test-2",
      email: "location2@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Tasker Location User",
      city: "Vancouver",
      province: "BC",
    });

    await asUser.mutation(internal.categories.seedCategories, {});
    const categories = await asUser.query(api.categories.listCategories);
    const categoryId = categories[0]._id;

    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "Test Tasker",
      bio: "Test bio",
      categoryId,
      categoryBio: "Category bio",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 10,
    });

    await asUser.mutation(api.users.checkInGpsLocation, {
      lat: 49.2827,
      lng: -123.1207,
    });

    const taskerProfile = await asUser.query(api.taskers.getTaskerProfile);
    expect(taskerProfile).not.toBeNull();
    expect(taskerProfile?.location).toBeDefined();
    expect(taskerProfile?.location?.lat).toBe(49.2827);
    expect(taskerProfile?.location?.lng).toBe(-123.1207);
    expect(taskerProfile?.locationCheckedInAt).toBeDefined();
  });

  test("manual user location updates do not update tasker discoverability location", async () => {
    const t = createTest();

    const asUser = t.withIdentity({
      tokenIdentifier: "google|location-test-manual-tasker",
      email: "manual-tasker-location@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Manual Location Tasker",
      city: "Toronto",
      province: "ON",
    });

    await asUser.mutation(internal.categories.seedCategories, {});
    const categories = await asUser.query(api.categories.listCategories);
    const categoryId = categories[0]._id;

    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "Manual Tasker",
      bio: "Test bio",
      categoryId,
      categoryBio: "Category bio",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 10,
    });

    await asUser.mutation(api.users.updateLocation, {
      lat: 45.4215,
      lng: -75.6972,
      source: "manual",
    });

    const taskerProfile = await asUser.query(api.taskers.getTaskerProfile);
    expect(taskerProfile?.location).toBeUndefined();
    expect(taskerProfile?.locationCheckedInAt).toBeUndefined();
  });

  test("GPS check-in updates user GPS coordinates and tasker discoverability location", async () => {
    const t = createTest();

    const asUser = t.withIdentity({
      tokenIdentifier: "google|location-test-gps-tasker",
      email: "gps-tasker-location@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "GPS Location Tasker",
      city: "Toronto",
      province: "ON",
    });

    await asUser.mutation(internal.categories.seedCategories, {});
    const categories = await asUser.query(api.categories.listCategories);
    const categoryId = categories[0]._id;

    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "GPS Tasker",
      bio: "Test bio",
      categoryId,
      categoryBio: "Category bio",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 10,
    });

    await asUser.mutation(api.users.checkInGpsLocation, {
      lat: 43.6532,
      lng: -79.3832,
    });

    const user = await asUser.query(api.users.getCurrentUser);
    expect(user?.location.gpsCoordinates?.lat).toBe(43.6532);
    expect(user?.location.gpsCoordinates?.lng).toBe(-79.3832);
    expect(user?.location.gpsCoordinates?.checkedInAt).toBeGreaterThan(0);

    const taskerProfile = await asUser.query(api.taskers.getTaskerProfile);
    expect(taskerProfile?.location?.lat).toBe(43.6532);
    expect(taskerProfile?.location?.lng).toBe(-79.3832);
    expect(taskerProfile?.locationCheckedInAt).toBe(user?.location.gpsCoordinates?.checkedInAt);
  });

  test("Location update respects 500m threshold (skip if too close)", async () => {
    const t = createTest();

    const asUser = t.withIdentity({
      tokenIdentifier: "google|location-test-3",
      email: "location3@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Threshold Test User",
      city: "Montreal",
      province: "QC",
    });

    await asUser.mutation(api.location.updateUserLocation, {
      lat: 45.5017,
      lng: -73.5673,
      source: "manual",
    });

    const user1 = await asUser.query(api.users.getCurrentUser);
    const updatedAt1 = user1?.updatedAt;

    await new Promise((resolve) => setTimeout(resolve, 10));

    await asUser.mutation(api.location.updateUserLocation, {
      lat: 45.5027,
      lng: -73.5673,
      source: "manual",
    });

    const user2 = await asUser.query(api.users.getCurrentUser);
    expect(user2?.location.coordinates?.lat).toBe(45.5017);
    expect(user2?.location.coordinates?.lng).toBe(-73.5673);
    expect(user2?.updatedAt).toBe(updatedAt1);

    await asUser.mutation(api.location.updateUserLocation, {
      lat: 45.5077,
      lng: -73.5673,
      source: "manual",
    });

    const user3 = await asUser.query(api.users.getCurrentUser);
    expect(user3?.location.coordinates?.lat).toBe(45.5077);
    expect(user3?.location.coordinates?.lng).toBe(-73.5673);
    expect(user3?.updatedAt).toBeGreaterThan(updatedAt1!);
  });
});
