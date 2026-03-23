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
    expect(profile?.subscriptionStatus).toBe("inactive");
    expect(profile?.hasActiveSubscription).toBe(false);
    expect(profile?.ghostMode).toBe(true);
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
    const updatedProfile = await asUser.mutation(api.taskers.updateTaskerProfile, {
      displayName: "New Name",
      bio: "New and improved bio",
    });

    expect(updatedProfile.displayName).toBe("New Name");
    expect(updatedProfile.bio).toBe("New and improved bio");
    expect(updatedProfile.categories).toHaveLength(1);
    expect(updatedProfile.categories[0].categoryId).toBe(category!._id);

    // Verify updates
    const profile = await asUser.query(api.taskers.getTaskerProfile);
    expect(profile?.displayName).toBe("New Name");
    expect(profile?.bio).toBe("New and improved bio");
  });

  test("updateTaskerCategory updates public service details and clears inactive price fields", async () => {
    const t = convexTest(schema, modules);

    const asUser = t.withIdentity({
      tokenIdentifier: "google|353",
      email: "update-category@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Update Category Test",
      city: "Calgary",
      province: "AB",
    });

    await t.mutation(api.categories.seedCategories);
    const category = await t.query(api.categories.getCategoryBySlug, {
      slug: "painting",
    });

    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "Fresh Coats",
      categoryId: category!._id,
      categoryBio: "Interior painting and trim touch-ups",
      rateType: "hourly",
      hourlyRate: 7000,
      serviceRadius: 20,
    });

    const updatedProfile = await asUser.mutation(api.taskers.updateTaskerCategory, {
      categoryId: category!._id,
      categoryBio: "Premium interior painting and cabinet refinishing",
      rateType: "fixed",
      fixedRate: 22500,
      serviceRadius: 35,
    });

    const updatedCategory = updatedProfile.categories.find((entry) => entry.categoryId === category!._id);
    expect(updatedCategory).toBeDefined();
    expect(updatedCategory?.bio).toBe("Premium interior painting and cabinet refinishing");
    expect(updatedCategory?.rateType).toBe("fixed");
    expect(updatedCategory?.fixedRate).toBe(22500);
    expect(updatedCategory?.hourlyRate).toBeUndefined();
    expect(updatedCategory?.serviceRadius).toBe(35);

    const profile = await asUser.query(api.taskers.getTaskerProfile);
    const persistedCategory = profile?.categories.find((entry) => entry.categoryId === category!._id);
    expect(persistedCategory?.fixedRate).toBe(22500);
    expect(persistedCategory?.hourlyRate).toBeUndefined();
  });

  test("updateTaskerCategory rejects edits to another tasker's category", async () => {
    const t = convexTest(schema, modules);

    const asOwner = t.withIdentity({
      tokenIdentifier: "google|354",
      email: "owner@example.com",
    });
    const asOther = t.withIdentity({
      tokenIdentifier: "google|355",
      email: "other@example.com",
    });

    await asOwner.mutation(api.users.createProfile, {
      name: "Category Owner",
      city: "Montreal",
      province: "QC",
    });
    await asOther.mutation(api.users.createProfile, {
      name: "Another Tasker",
      city: "Montreal",
      province: "QC",
    });

    await t.mutation(api.categories.seedCategories);
    const plumbing = await t.query(api.categories.getCategoryBySlug, {
      slug: "plumbing",
    });
    const electrical = await t.query(api.categories.getCategoryBySlug, {
      slug: "electrical",
    });

    await asOwner.mutation(api.taskers.createTaskerProfile, {
      displayName: "Owner Profile",
      categoryId: plumbing!._id,
      categoryBio: "Plumbing services",
      rateType: "hourly",
      hourlyRate: 8000,
      serviceRadius: 25,
    });

    await asOther.mutation(api.taskers.createTaskerProfile, {
      displayName: "Other Profile",
      categoryId: electrical!._id,
      categoryBio: "Backup electrical services",
      rateType: "hourly",
      hourlyRate: 8200,
      serviceRadius: 20,
    });

    await expect(
      asOther.mutation(api.taskers.updateTaskerCategory, {
        categoryId: plumbing!._id,
        categoryBio: "Trying to overwrite someone else's category",
        rateType: "fixed",
        fixedRate: 19000,
        serviceRadius: 15,
      })
    ).rejects.toThrow("Category not found");
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

   test("updateSubscriptionPlan activates weekly tasker access", async () => {
     const t = convexTest(schema, modules);
     
     const asUser = t.withIdentity({
       tokenIdentifier: "google|601",
       email: "basic@example.com",
     });

     await asUser.mutation(api.users.createProfile, {
       name: "Basic Plan Test",
       city: "Toronto",
       province: "ON",
     });

     await t.mutation(api.categories.seedCategories);
     const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "plumbing",
     });

     // Create tasker profile
     await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "Basic Subscriber",
       categoryId: category!._id,
       categoryBio: "Plumbing services",
       rateType: "hourly",
       hourlyRate: 7000,
       serviceRadius: 20,
     });

     // Update to weekly tasker access
     const result = await asUser.mutation(api.taskers.updateSubscriptionPlan, {
       plan: "tasker",
       accessType: "weekly",
       endsAt: 1_900_000_000_000,
     });

     expect(result.subscriptionPlan).toBe("tasker");
     expect(result.subscriptionAccessType).toBe("weekly");
     expect(result.subscriptionStatus).toBe("active");
     expect(result.subscriptionEndsAt).toBe(1_900_000_000_000);
     expect(result.hasActiveSubscription).toBe(true);
     expect(result.ghostMode).toBe(false);
     expect(result.premiumPin).toBeUndefined();

     // Verify plan was set correctly
     const profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.subscriptionPlan).toBe("tasker");
     expect(profile?.subscriptionAccessType).toBe("weekly");
     expect(profile?.subscriptionStatus).toBe("active");
     expect(profile?.subscriptionEndsAt).toBe(1_900_000_000_000);
     expect(profile?.hasActiveSubscription).toBe(true);
     expect(profile?.ghostMode).toBe(false);
     expect(profile?.premiumPin).toBeUndefined();
   });

   test("updateSubscriptionPlan activates lifetime tasker access", async () => {
     const t = convexTest(schema, modules);
     
     const asUser = t.withIdentity({
       tokenIdentifier: "google|602",
       email: "premium@example.com",
     });

     await asUser.mutation(api.users.createProfile, {
       name: "Premium Plan Test",
       city: "Vancouver",
       province: "BC",
     });

     await t.mutation(api.categories.seedCategories);
     const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "electrical",
     });

     // Create tasker profile
     await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "Premium Subscriber",
       categoryId: category!._id,
       categoryBio: "Electrical services",
       rateType: "hourly",
       hourlyRate: 8000,
       serviceRadius: 25,
     });

     // Update to lifetime tasker access
     const result = await asUser.mutation(api.taskers.updateSubscriptionPlan, {
       plan: "tasker",
       accessType: "lifetime",
     });

     expect(result.subscriptionPlan).toBe("tasker");
     expect(result.subscriptionAccessType).toBe("lifetime");
     expect(result.subscriptionStatus).toBe("active");
     expect(result.subscriptionEndsAt).toBeUndefined();
     expect(result.hasActiveSubscription).toBe(true);
     expect(result.ghostMode).toBe(false);
     expect(result.premiumPin).toBeUndefined();

     // Verify plan was set correctly
     const profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.subscriptionPlan).toBe("tasker");
     expect(profile?.subscriptionAccessType).toBe("lifetime");
     expect(profile?.subscriptionStatus).toBe("active");
     expect(profile?.hasActiveSubscription).toBe(true);
     expect(profile?.ghostMode).toBe(false);
     expect(profile?.premiumPin).toBeUndefined();
   });

   test("updateSubscriptionPlan clears ghostMode when activating subscription", async () => {
     const t = convexTest(schema, modules);
     
     const asUser = t.withIdentity({
       tokenIdentifier: "google|603",
       email: "ghostclear@example.com",
     });

     await asUser.mutation(api.users.createProfile, {
       name: "Ghost Clear Test",
       city: "Calgary",
       province: "AB",
     });

     await t.mutation(api.categories.seedCategories);
     const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "handyman",
     });

     // Create tasker profile
     await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "Ghost Mode Tasker",
       categoryId: category!._id,
       categoryBio: "General handyman",
       rateType: "hourly",
       hourlyRate: 6500,
       serviceRadius: 15,
     });

     // First set to weekly tasker access
     await asUser.mutation(api.taskers.updateSubscriptionPlan, {
       plan: "tasker",
       accessType: "weekly",
       endsAt: 1_900_000_000_000,
     });

     // Verify ghostMode is false
     let profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.ghostMode).toBe(false);

     // Update to lifetime tasker access
     await asUser.mutation(api.taskers.updateSubscriptionPlan, {
       plan: "tasker",
       accessType: "lifetime",
     });

     // Verify ghostMode is still false
     profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.ghostMode).toBe(false);
   });

   test("cancelSubscription schedules term-end without immediately hiding the tasker", async () => {
     const t = convexTest(schema, modules);
     
     const asUser = t.withIdentity({
       tokenIdentifier: "google|603a",
       email: "cancel@example.com",
     });

     await asUser.mutation(api.users.createProfile, {
       name: "Cancel Test",
       city: "Calgary",
       province: "AB",
     });

     await t.mutation(api.categories.seedCategories);
     const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "handyman",
     });

     await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "Cancelable Tasker",
       categoryId: category!._id,
       categoryBio: "General handyman",
       rateType: "hourly",
       hourlyRate: 6500,
       serviceRadius: 15,
     });

     await asUser.mutation(api.taskers.updateSubscriptionPlan, {
       plan: "tasker",
       accessType: "weekly",
       endsAt: 1_900_000_000_000,
     });

     const result = await asUser.mutation(api.taskers.cancelSubscription, {});
     expect(result.subscriptionStatus).toBe("cancel_at_period_end");
     expect(result.hasActiveSubscription).toBe(true);
     expect(result.ghostMode).toBe(false);
     expect(typeof result.subscriptionEndsAt).toBe("number");

     const profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.subscriptionStatus).toBe("cancel_at_period_end");
     expect(profile?.hasActiveSubscription).toBe(true);
     expect(profile?.ghostMode).toBe(false);
   });

   test("expired subscriptions become inactive and force ghost mode", async () => {
     const t = convexTest(schema, modules);
     
     const asUser = t.withIdentity({
       tokenIdentifier: "google|603b",
       email: "expired@example.com",
     });

     await asUser.mutation(api.users.createProfile, {
       name: "Expired Test",
       city: "Calgary",
       province: "AB",
     });

     await t.mutation(api.categories.seedCategories);
     const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "handyman",
     });

     const profileId = await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "Expired Tasker",
       categoryId: category!._id,
       categoryBio: "General handyman",
       rateType: "hourly",
       hourlyRate: 6500,
       serviceRadius: 15,
     });

     await asUser.mutation(api.taskers.updateSubscriptionPlan, {
       plan: "tasker",
       accessType: "weekly",
       endsAt: Date.now() + 7 * 24 * 60 * 60 * 1000,
     });

     await t.run(async (ctx) => {
       await ctx.db.patch(profileId, {
         subscriptionStatus: "cancel_at_period_end",
         subscriptionEndsAt: Date.now() - 1_000,
         ghostMode: false,
       });
     });

     const profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.subscriptionPlan).toBe("none");
     expect(profile?.subscriptionStatus).toBe("expired");
     expect(profile?.hasActiveSubscription).toBe(false);
     expect(profile?.ghostMode).toBe(true);
   });

   test("setGhostMode fails without active subscription", async () => {
     const t = convexTest(schema, modules);
     
     const asUser = t.withIdentity({
       tokenIdentifier: "google|604",
       email: "noghost@example.com",
     });

     await asUser.mutation(api.users.createProfile, {
       name: "No Ghost Test",
       city: "Montreal",
       province: "QC",
     });

     await t.mutation(api.categories.seedCategories);
     const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "painting",
     });

     // Create tasker profile (subscriptionPlan defaults to "none")
     await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "No Subscription Tasker",
       categoryId: category!._id,
       categoryBio: "Painting services",
       rateType: "hourly",
       hourlyRate: 5500,
       serviceRadius: 20,
     });

     // Try to set ghost mode without subscription - should throw
     await expect(
       asUser.mutation(api.taskers.setGhostMode, {
         ghostMode: true,
       })
     ).rejects.toThrow("Active subscription required to toggle ghost mode");
   });

   test("setGhostMode succeeds with active subscription", async () => {
     const t = convexTest(schema, modules);
     
     const asUser = t.withIdentity({
       tokenIdentifier: "google|605",
       email: "withghost@example.com",
     });

     await asUser.mutation(api.users.createProfile, {
       name: "With Ghost Test",
       city: "Edmonton",
       province: "AB",
     });

     await t.mutation(api.categories.seedCategories);
     const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "hvac",
     });

     // Create tasker profile
     await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "Ghost Mode Enabled Tasker",
       categoryId: category!._id,
       categoryBio: "HVAC services",
       rateType: "hourly",
       hourlyRate: 9000,
       serviceRadius: 30,
     });

     // Set subscription to weekly tasker access
     await asUser.mutation(api.taskers.updateSubscriptionPlan, {
       plan: "tasker",
       accessType: "weekly",
       endsAt: 1_900_000_000_000,
     });

     // Enable ghost mode
     let result = await asUser.mutation(api.taskers.setGhostMode, {
       ghostMode: true,
     });
     expect(result.ghostMode).toBe(true);

     // Verify ghost mode is enabled
     let profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.ghostMode).toBe(true);

     // Disable ghost mode
     result = await asUser.mutation(api.taskers.setGhostMode, {
       ghostMode: false,
     });
     expect(result.ghostMode).toBe(false);

     // Verify ghost mode is disabled
     profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.ghostMode).toBe(false);
   });

   test("cancelSubscription rejects lifetime access", async () => {
     const t = convexTest(schema, modules);

     const asUser = t.withIdentity({
       tokenIdentifier: "google|605b",
       email: "lifetimecancel@example.com",
     });

     await asUser.mutation(api.users.createProfile, {
       name: "Lifetime Cancel Test",
       city: "Ottawa",
       province: "ON",
     });

     await t.mutation(api.categories.seedCategories);
     const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "hvac",
     });

     await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "Lifetime Tasker",
       categoryId: category!._id,
       categoryBio: "HVAC services",
       rateType: "hourly",
       hourlyRate: 9000,
       serviceRadius: 30,
     });

     await asUser.mutation(api.taskers.updateSubscriptionPlan, {
       plan: "tasker",
       accessType: "lifetime",
     });

     await expect(
       asUser.mutation(api.taskers.cancelSubscription, {}),
     ).rejects.toThrow("Lifetime access does not renew and cannot be cancelled");
   });
});
