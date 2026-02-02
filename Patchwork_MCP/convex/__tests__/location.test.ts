import { convexTest } from "convex-test";
import { expect, test, describe } from "vitest";
import { api } from "../_generated/api";
import schema from "../schema";
import * as usersModule from "../users";
import * as categoriesModule from "../categories";
import * as filesModule from "../files";
import * as taskersModule from "../taskers";
import * as locationModule from "../location";
import * as authModule from "../auth";
import * as httpModule from "../http";

const modules: Record<string, () => Promise<any>> = {
  "../users.ts": async () => usersModule,
  "../categories.ts": async () => categoriesModule,
  "../files.ts": async () => filesModule,
  "../taskers.ts": async () => taskersModule,
  "../location.ts": async () => locationModule,
  "../auth.ts": async () => authModule,
  "../http.ts": async () => httpModule,
  "../_generated/api.ts": async () => ({ default: api }),
  "../schema.ts": async () => ({ default: schema }),
};

describe("location", () => {
  test("updateUserLocation stores coordinates", async () => {
    const t = convexTest(schema, modules);
    
    const asUser = t.withIdentity({
      tokenIdentifier: "google|location-test-1",
      email: "location1@example.com",
    });

    // Create a user first
    const userId = await asUser.mutation(api.users.createProfile, {
      name: "Location Test User",
      city: "Toronto",
      province: "ON",
    });

    // Update user location
    await asUser.mutation(api.location.updateUserLocation, {
      lat: 43.65107,
      lng: -79.347015,
      source: "manual",
    });

    // Verify location was stored
    const user = await asUser.query(api.users.getCurrentUser);
    expect(user).not.toBeNull();
    expect(user?.location.coordinates).toBeDefined();
    expect(user?.location.coordinates?.lat).toBe(43.65107);
    expect(user?.location.coordinates?.lng).toBe(-79.347015);
  });

  test("updateUserLocation rejects if not authenticated", async () => {
    const t = convexTest(schema, modules);
    
    await expect(
      t.mutation(api.location.updateUserLocation, {
        lat: 43.65107,
        lng: -79.347015,
        source: "manual",
      })
    ).rejects.toThrow("Unauthorized");
  });

  test("updateTaskerLocation updates taskerProfiles.location", async () => {
    const t = convexTest(schema, modules);
    
    const asUser = t.withIdentity({
      tokenIdentifier: "google|location-test-2",
      email: "location2@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Tasker Location User",
      city: "Vancouver",
      province: "BC",
    });

    await asUser.mutation(api.categories.seedCategories, {});
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

    await asUser.mutation(api.location.updateTaskerLocation, {
      lat: 49.2827,
      lng: -123.1207,
    });

    const taskerProfile = await asUser.query(api.taskers.getTaskerProfile);
    expect(taskerProfile).not.toBeNull();
    expect(taskerProfile?.location).toBeDefined();
    expect(taskerProfile?.location?.lat).toBe(49.2827);
    expect(taskerProfile?.location?.lng).toBe(-123.1207);
  });

  test("Location update respects 500m threshold (skip if too close)", async () => {
    const t = convexTest(schema, modules);
    
    const asUser = t.withIdentity({
      tokenIdentifier: "google|location-test-3",
      email: "location3@example.com",
    });

    // Create a user
    await asUser.mutation(api.users.createProfile, {
      name: "Threshold Test User",
      city: "Montreal",
      province: "QC",
    });

    // Set initial location
    await asUser.mutation(api.location.updateUserLocation, {
      lat: 45.5017,
      lng: -73.5673,
      source: "manual",
    });

    const user1 = await asUser.query(api.users.getCurrentUser);
    const updatedAt1 = user1?.updatedAt;

    // Wait a bit to ensure timestamp would change if update happens
    await new Promise((resolve) => setTimeout(resolve, 10));

    // Try to update location less than 500m away (about 100m away)
    // Moving ~0.001 degrees latitude ≈ 111m
    await asUser.mutation(api.location.updateUserLocation, {
      lat: 45.5027, // ~111m north
      lng: -73.5673,
      source: "manual",
    });

    // Verify location was NOT updated (still the same as before)
    const user2 = await asUser.query(api.users.getCurrentUser);
    expect(user2?.location.coordinates?.lat).toBe(45.5017);
    expect(user2?.location.coordinates?.lng).toBe(-73.5673);
    expect(user2?.updatedAt).toBe(updatedAt1); // Timestamp unchanged

    // Now move more than 500m away (~600m)
    // Moving ~0.006 degrees latitude ≈ 666m
    await asUser.mutation(api.location.updateUserLocation, {
      lat: 45.5077, // ~666m north
      lng: -73.5673,
      source: "manual",
    });

    // Verify location WAS updated
    const user3 = await asUser.query(api.users.getCurrentUser);
    expect(user3?.location.coordinates?.lat).toBe(45.5077);
    expect(user3?.location.coordinates?.lng).toBe(-73.5673);
    expect(user3?.updatedAt).toBeGreaterThan(updatedAt1!); // Timestamp changed
  });
});
