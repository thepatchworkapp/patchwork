// convex/__tests__/taskers.test.ts
import { convexTest } from "convex-test";
import { expect, test, describe } from "vitest";
import { api } from "../_generated/api";
import schema from "../schema";
import * as taskersModule from "../taskers";
import * as usersModule from "../users";
import * as categoriesModule from "../categories";
import * as filesModule from "../files";
import * as authModule from "../auth";
import * as httpModule from "../http";

const modules: Record<string, () => Promise<any>> = {
  "../taskers.ts": async () => taskersModule,
  "../users.ts": async () => usersModule,
  "../categories.ts": async () => categoriesModule,
  "../files.ts": async () => filesModule,
  "../auth.ts": async () => authModule,
  "../http.ts": async () => httpModule,
  "../_generated/api.ts": async () => ({ default: api }),
  "../schema.ts": async () => ({ default: schema }),
};

describe("taskers", () => {
  test("createTaskerProfile creates taskerProfile + first taskerCategory", async () => {
    const t = convexTest(schema, modules);
    
    // Create user first
    const asUser = t.withIdentity({
      tokenIdentifier: "google|123",
      email: "tasker@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Test Tasker",
      city: "Toronto",
      province: "ON",
    });

    // Seed categories
    await t.mutation(api.categories.seedCategories);
    
    // Get plumbing category
    const plumbingCategory = await t.query(api.categories.getCategoryBySlug, {
      slug: "plumbing",
    });
    expect(plumbingCategory).not.toBeNull();

    // Create tasker profile
    const profileId = await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "Bob the Plumber",
      bio: "Expert plumber with 10 years experience",
      categoryId: plumbingCategory!._id,
      categoryBio: "Specialized in residential plumbing",
      rateType: "hourly",
      hourlyRate: 8000, // $80/hr in cents
      serviceRadius: 25,
    });

    expect(profileId).toBeDefined();

    // Verify profile was created
    const profile = await asUser.query(api.taskers.getTaskerProfile);
    expect(profile).not.toBeNull();
    expect(profile?.displayName).toBe("Bob the Plumber");
    expect(profile?.bio).toBe("Expert plumber with 10 years experience");
    expect(profile?.isOnboarded).toBe(true);
    expect(profile?.rating).toBe(0);
    expect(profile?.reviewCount).toBe(0);
    expect(profile?.completedJobs).toBe(0);
    expect(profile?.verified).toBe(false);
    expect(profile?.subscriptionPlan).toBe("none");
    expect(profile?.ghostMode).toBe(false);
    expect(profile?.categories).toHaveLength(1);
    expect(profile?.categories[0].categoryId).toBe(plumbingCategory!._id);
    expect(profile?.categories[0].bio).toBe("Specialized in residential plumbing");
    expect(profile?.categories[0].rateType).toBe("hourly");
    expect(profile?.categories[0].hourlyRate).toBe(8000);
    expect(profile?.categories[0].serviceRadius).toBe(25);
  });

  test("createTaskerProfile throws if user already has tasker profile", async () => {
    const t = convexTest(schema, modules);
    
    const asUser = t.withIdentity({
      tokenIdentifier: "google|456",
      email: "duplicate@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Duplicate Tasker",
      city: "Vancouver",
      province: "BC",
    });

    await t.mutation(api.categories.seedCategories);
    const category = await t.query(api.categories.getCategoryBySlug, {
      slug: "electrical",
    });

    // Create first profile
    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "First Profile",
      categoryId: category!._id,
      categoryBio: "First bio",
      rateType: "fixed",
      fixedRate: 15000,
      serviceRadius: 10,
    });

    // Try to create second profile - should throw
    await expect(
      asUser.mutation(api.taskers.createTaskerProfile, {
        displayName: "Second Profile",
        categoryId: category!._id,
        categoryBio: "Second bio",
        rateType: "hourly",
        hourlyRate: 5000,
        serviceRadius: 20,
      })
    ).rejects.toThrow();
  });

  test("createTaskerProfile updates user.roles.isTasker to true", async () => {
    const t = convexTest(schema, modules);
    
    const asUser = t.withIdentity({
      tokenIdentifier: "google|789",
      email: "newTasker@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "New Tasker",
      city: "Montreal",
      province: "QC",
    });

    // Verify user is not a tasker initially
    let user = await asUser.query(api.users.getCurrentUser);
    expect(user?.roles.isTasker).toBe(false);

    await t.mutation(api.categories.seedCategories);
    const category = await t.query(api.categories.getCategoryBySlug, {
      slug: "handyman",
    });

    // Create tasker profile
    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "Handyman Joe",
      categoryId: category!._id,
      categoryBio: "General repairs and maintenance",
      rateType: "hourly",
      hourlyRate: 7500,
      serviceRadius: 30,
    });

    // Verify user is now a tasker
    user = await asUser.query(api.users.getCurrentUser);
    expect(user?.roles.isTasker).toBe(true);
  });

  test("getTaskerProfile returns full profile with categories", async () => {
    const t = convexTest(schema, modules);
    
    const asUser = t.withIdentity({
      tokenIdentifier: "google|101",
      email: "multi@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Multi Category Tasker",
      city: "Calgary",
      province: "AB",
    });

    await t.mutation(api.categories.seedCategories);
    const plumbing = await t.query(api.categories.getCategoryBySlug, {
      slug: "plumbing",
    });
    const electrical = await t.query(api.categories.getCategoryBySlug, {
      slug: "electrical",
    });

    // Create profile with first category
    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "Jack of All Trades",
      bio: "Multi-skilled professional",
      categoryId: plumbing!._id,
      categoryBio: "Plumbing specialist",
      rateType: "hourly",
      hourlyRate: 9000,
      serviceRadius: 40,
    });

    // Add second category
    await asUser.mutation(api.taskers.addTaskerCategory, {
      categoryId: electrical!._id,
      categoryBio: "Electrical work",
      rateType: "fixed",
      fixedRate: 20000,
      serviceRadius: 35,
    });

    // Get full profile
    const profile = await asUser.query(api.taskers.getTaskerProfile);
    expect(profile).not.toBeNull();
    expect(profile?.displayName).toBe("Jack of All Trades");
    expect(profile?.bio).toBe("Multi-skilled professional");
    expect(profile?.categories).toHaveLength(2);
  });

  test("getTaskerProfile returns null if not a tasker", async () => {
    const t = convexTest(schema, modules);
    
    const asUser = t.withIdentity({
      tokenIdentifier: "google|202",
      email: "seeker@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Just a Seeker",
      city: "Ottawa",
      province: "ON",
    });

    // Should return null since user is not a tasker
    const profile = await asUser.query(api.taskers.getTaskerProfile);
    expect(profile).toBeNull();
  });

  test("updateTaskerProfile updates displayName and bio", async () => {
    const t = convexTest(schema, modules);
    
    const asUser = t.withIdentity({
      tokenIdentifier: "google|303",
      email: "update@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Update Test",
      city: "Edmonton",
      province: "AB",
    });

    await t.mutation(api.categories.seedCategories);
    const category = await t.query(api.categories.getCategoryBySlug, {
      slug: "painting",
    });

    // Create profile
    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "Old Name",
      bio: "Old bio",
      categoryId: category!._id,
      categoryBio: "Painting services",
      rateType: "hourly",
      hourlyRate: 6000,
      serviceRadius: 20,
    });

    // Update profile
    await asUser.mutation(api.taskers.updateTaskerProfile, {
      displayName: "New Name",
      bio: "New and improved bio",
    });

    // Verify updates
    const profile = await asUser.query(api.taskers.getTaskerProfile);
    expect(profile?.displayName).toBe("New Name");
    expect(profile?.bio).toBe("New and improved bio");
  });

  test("addTaskerCategory adds new category to existing profile", async () => {
    const t = convexTest(schema, modules);
    
    const asUser = t.withIdentity({
      tokenIdentifier: "google|404",
      email: "addcat@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Add Category Test",
      city: "Winnipeg",
      province: "MB",
    });

    await t.mutation(api.categories.seedCategories);
    const plumbing = await t.query(api.categories.getCategoryBySlug, {
      slug: "plumbing",
    });
    const hvac = await t.query(api.categories.getCategoryBySlug, {
      slug: "hvac",
    });

    // Create profile with plumbing
    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "HVAC & Plumbing Pro",
      categoryId: plumbing!._id,
      categoryBio: "Plumbing work",
      rateType: "hourly",
      hourlyRate: 8500,
      serviceRadius: 25,
    });

    // Add HVAC category
    await asUser.mutation(api.taskers.addTaskerCategory, {
      categoryId: hvac!._id,
      categoryBio: "HVAC installation and repair",
      rateType: "fixed",
      fixedRate: 25000,
      serviceRadius: 30,
    });

    // Verify both categories exist
    const profile = await asUser.query(api.taskers.getTaskerProfile);
    expect(profile?.categories).toHaveLength(2);
    
    const hvacCategory = profile?.categories.find(c => c.categoryId === hvac!._id);
    expect(hvacCategory).toBeDefined();
    expect(hvacCategory?.bio).toBe("HVAC installation and repair");
    expect(hvacCategory?.rateType).toBe("fixed");
    expect(hvacCategory?.fixedRate).toBe(25000);
  });

  test("removeTaskerCategory removes category (keeps profile if other categories exist)", async () => {
    const t = convexTest(schema, modules);
    
    const asUser = t.withIdentity({
      tokenIdentifier: "google|505",
      email: "removecat@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Remove Category Test",
      city: "Halifax",
      province: "NS",
    });

    await t.mutation(api.categories.seedCategories);
    const plumbing = await t.query(api.categories.getCategoryBySlug, {
      slug: "plumbing",
    });
    const electrical = await t.query(api.categories.getCategoryBySlug, {
      slug: "electrical",
    });

    // Create profile with plumbing
    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "Multi-Trade Worker",
      categoryId: plumbing!._id,
      categoryBio: "Plumbing services",
      rateType: "hourly",
      hourlyRate: 7000,
      serviceRadius: 20,
    });

    // Add electrical
    await asUser.mutation(api.taskers.addTaskerCategory, {
      categoryId: electrical!._id,
      categoryBio: "Electrical services",
      rateType: "hourly",
      hourlyRate: 8000,
      serviceRadius: 20,
    });

    // Remove plumbing category
    await asUser.mutation(api.taskers.removeTaskerCategory, {
      categoryId: plumbing!._id,
    });

    // Verify only electrical remains
    const profile = await asUser.query(api.taskers.getTaskerProfile);
    expect(profile).not.toBeNull();
    expect(profile?.categories).toHaveLength(1);
    expect(profile?.categories[0].categoryId).toBe(electrical!._id);
  });
});
