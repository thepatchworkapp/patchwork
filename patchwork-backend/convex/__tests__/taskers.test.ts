// convex/__tests__/taskers.test.ts
import { convexTest } from "convex-test";
import { afterEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "../_generated/api";
import schema from "../schema";
import * as taskersModule from "../taskers";
import * as taskersInternalModule from "../taskersInternal";
import * as usersModule from "../users";
import * as categoriesModule from "../categories";
import * as filesModule from "../files";
import * as authModule from "../auth";
import * as httpModule from "../http";

const modules: Record<string, () => Promise<any>> = {
  "../taskers.ts": async () => taskersModule,
  "../taskersInternal.ts": async () => taskersInternalModule,
  "../users.ts": async () => usersModule,
  "../categories.ts": async () => categoriesModule,
  "../files.ts": async () => filesModule,
  "../auth.ts": async () => authModule,
  "../http.ts": async () => httpModule,
  "../_generated/api.ts": async () => ({ default: api }),
  "../schema.ts": async () => ({ default: schema }),
};

const PATCHWORK_REVENUECAT_APP_ID = "app6be2ab0fb8";
const PATCHWORK_BASIC_MONTHLY_PRODUCT_ID = "ltd.ddga.patchwork.tasker.subscription.basic.monthly";
const PATCHWORK_ANNUAL_PRODUCT_ID = "ltd.ddga.patchwork.tasker.subscription.yearly";
const PATCHWORK_LIFETIME_PRODUCT_ID = "ltd.ddga.patchwork.tasker.lifetime";
const originalRevenueCatSecretApiKey = process.env.REVENUECAT_SECRET_API_KEY;

async function applyRevenueCatEvent(
  t: ReturnType<typeof convexTest>,
  args: {
    type: string;
    userId: string;
    productId: string;
    expirationAtMs?: number | null;
  },
) {
  return await t.mutation(internal.taskersInternal.applyRevenueCatWebhookEvent, {
    type: args.type,
    appId: PATCHWORK_REVENUECAT_APP_ID,
    productId: args.productId,
    appUserId: args.userId,
    aliases: [],
    expirationAtMs: args.expirationAtMs ?? null,
  });
}

afterEach(() => {
  vi.unstubAllGlobals();
  process.env.REVENUECAT_SECRET_API_KEY = originalRevenueCatSecretApiKey;
});

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
    await t.mutation(internal.categories.seedCategories);
    
    // Get plumbing category
    const plumbingCategory = await t.query(api.categories.getCategoryBySlug, {
      slug: "plumber",
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
    expect(profile?.websiteLinks).toEqual([]);
    expect(profile?.socialLinks).toEqual([]);
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

    await t.mutation(internal.categories.seedCategories);
    const category = await t.query(api.categories.getCategoryBySlug, {
      slug: "electrician",
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

    await t.mutation(internal.categories.seedCategories);
    const category = await t.query(api.categories.getCategoryBySlug, {
      slug: "general-handy-man",
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

  test("createTaskerProfile rejects category bios over 500 characters", async () => {
    const t = convexTest(schema, modules);

    const asUser = t.withIdentity({
      tokenIdentifier: "google|790",
      email: "longbio@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Long Bio Tasker",
      city: "Regina",
      province: "SK",
    });

    await t.mutation(internal.categories.seedCategories);
    const category = await t.query(api.categories.getCategoryBySlug, {
      slug: "interior-cleaning-services",
    });

    await expect(
      asUser.mutation(api.taskers.createTaskerProfile, {
        displayName: "Over Limit",
        categoryId: category!._id,
        categoryBio: "x".repeat(501),
        rateType: "hourly",
        hourlyRate: 6000,
        serviceRadius: 20,
      })
    ).rejects.toThrow("Category bio must be 500 characters or less");
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

    await t.mutation(internal.categories.seedCategories);
    const plumbing = await t.query(api.categories.getCategoryBySlug, {
      slug: "plumber",
    });
    const electrical = await t.query(api.categories.getCategoryBySlug, {
      slug: "electrician",
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

  test("setFavouriteTasker adds, lists, reflects detail status, and removes favourites", async () => {
    const t = convexTest(schema, modules);

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|fav-tasker",
      email: "fav-tasker@example.com",
    });
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|fav-seeker",
      email: "fav-seeker@example.com",
    });

    await asTasker.mutation(api.users.createProfile, {
      name: "Favourite Tasker",
      city: "Toronto",
      province: "ON",
    });
    await asSeeker.mutation(api.users.createProfile, {
      name: "Favourite Seeker",
      city: "Toronto",
      province: "ON",
    });

    await t.mutation(internal.categories.seedCategories);
    const category = await t.query(api.categories.getCategoryBySlug, {
      slug: "plumber",
    });

    const taskerId = await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Favourite Pro",
      categoryId: category!._id,
      categoryBio: "Reliable plumbing help",
      rateType: "hourly",
      hourlyRate: 8500,
      serviceRadius: 20,
    });

    const firstStatus = await asSeeker.mutation(api.taskers.setFavouriteTasker, {
      taskerId,
      isFavourite: true,
    });
    const secondStatus = await asSeeker.mutation(api.taskers.setFavouriteTasker, {
      taskerId,
      isFavourite: true,
    });

    expect(firstStatus).toEqual({ isFavourite: true });
    expect(secondStatus).toEqual({ isFavourite: true });

    const favouriteTaskers = await asSeeker.query(api.taskers.listFavouriteTaskers, {});
    expect(favouriteTaskers).toHaveLength(1);
    expect(favouriteTaskers[0].id).toBe(taskerId);
    expect(favouriteTaskers[0].name).toBe("Favourite Pro");

    const taskerDetail = await asSeeker.query(api.taskers.getTaskerById, {
      taskerId,
    });
    expect(taskerDetail?.isFavourite).toBe(true);

    const removeStatus = await asSeeker.mutation(api.taskers.setFavouriteTasker, {
      taskerId,
      isFavourite: false,
    });
    expect(removeStatus).toEqual({ isFavourite: false });
    await expect(
      asSeeker.query(api.taskers.listFavouriteTaskers, {})
    ).resolves.toEqual([]);

    const updatedDetail = await asSeeker.query(api.taskers.getTaskerById, {
      taskerId,
    });
    expect(updatedDetail?.isFavourite).toBe(false);
  });

  test("setFavouriteTasker rejects favouriting yourself", async () => {
    const t = convexTest(schema, modules);

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|fav-self",
      email: "fav-self@example.com",
    });

    await asTasker.mutation(api.users.createProfile, {
      name: "Self Favourite",
      city: "Toronto",
      province: "ON",
    });

    await t.mutation(internal.categories.seedCategories);
    const category = await t.query(api.categories.getCategoryBySlug, {
      slug: "plumber",
    });

    const taskerId = await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Self Favourite Pro",
      categoryId: category!._id,
      categoryBio: "Plumbing help",
      rateType: "hourly",
      hourlyRate: 8500,
      serviceRadius: 20,
    });

    await expect(
      asTasker.mutation(api.taskers.setFavouriteTasker, {
        taskerId,
        isFavourite: true,
      })
    ).rejects.toThrow("You cannot favourite yourself");
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

    await t.mutation(internal.categories.seedCategories);
    const category = await t.query(api.categories.getCategoryBySlug, {
      slug: "interior-painter",
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

  test("createTaskerProfile and updateTaskerProfile preserve website and social link ordering", async () => {
    const t = convexTest(schema, modules);

    const asUser = t.withIdentity({
      tokenIdentifier: "google|link-order",
      email: "links@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Links Test",
      city: "Toronto",
      province: "ON",
    });

    await t.mutation(internal.categories.seedCategories);
    const category = await t.query(api.categories.getCategoryBySlug, {
      slug: "interior-cleaning-services",
    });

    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "Links Tasker",
      bio: "Profile with links",
      websiteLinks: [" https://first.example.com ", "", "https://second.example.com"],
      socialLinks: ["https://instagram.com/links", "  ", "https://tiktok.com/@links"],
      categoryId: category!._id,
      categoryBio: "Cleaning services",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 20,
    });

    let profile = await asUser.query(api.taskers.getTaskerProfile);
    expect(profile?.websiteLinks).toEqual(["https://first.example.com", "https://second.example.com"]);
    expect(profile?.socialLinks).toEqual(["https://instagram.com/links", "https://tiktok.com/@links"]);

    const updatedProfile = await asUser.mutation(api.taskers.updateTaskerProfile, {
      websiteLinks: ["https://third.example.com", "https://first.example.com"],
      socialLinks: ["https://youtube.com/@links", "https://instagram.com/links"],
    });

    expect(updatedProfile.websiteLinks).toEqual(["https://third.example.com", "https://first.example.com"]);
    expect(updatedProfile.socialLinks).toEqual(["https://youtube.com/@links", "https://instagram.com/links"]);

    profile = await asUser.query(api.taskers.getTaskerProfile);
    expect(profile?.websiteLinks).toEqual(["https://third.example.com", "https://first.example.com"]);
    expect(profile?.socialLinks).toEqual(["https://youtube.com/@links", "https://instagram.com/links"]);
  });

  test("tasker profile link inputs reject more than 10 website or social links", async () => {
    const t = convexTest(schema, modules);

    const asUser = t.withIdentity({
      tokenIdentifier: "google|link-limit",
      email: "link-limit@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Link Limit Test",
      city: "Toronto",
      province: "ON",
    });

    await t.mutation(internal.categories.seedCategories);
    const category = await t.query(api.categories.getCategoryBySlug, {
      slug: "interior-cleaning-services",
    });
    const elevenLinks = Array.from({ length: 11 }, (_, index) => `https://example.com/${index}`);

    await expect(
      asUser.mutation(api.taskers.createTaskerProfile, {
        displayName: "Too Many Links",
        bio: "Profile with too many links",
        websiteLinks: elevenLinks,
        categoryId: category!._id,
        categoryBio: "Cleaning services",
        rateType: "hourly",
        hourlyRate: 5000,
        serviceRadius: 20,
      })
    ).rejects.toThrow("Maximum 10 website links allowed");

    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "Valid Links",
      bio: "Profile with valid links",
      categoryId: category!._id,
      categoryBio: "Cleaning services",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 20,
    });

    await expect(
      asUser.mutation(api.taskers.updateTaskerProfile, {
        socialLinks: elevenLinks,
      })
    ).rejects.toThrow("Maximum 10 social links allowed");
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

    await t.mutation(internal.categories.seedCategories);
    const category = await t.query(api.categories.getCategoryBySlug, {
      slug: "interior-painter",
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

    await expect(
      asUser.mutation(api.taskers.updateTaskerCategory, {
        categoryId: category!._id,
        categoryBio: "z".repeat(501),
        rateType: "hourly",
        hourlyRate: 21000,
        serviceRadius: 30,
      })
    ).rejects.toThrow("Category bio must be 500 characters or less");
  });

  test("addTaskerCategory rejects category bios over 500 characters", async () => {
    const t = convexTest(schema, modules);

    const asUser = t.withIdentity({
      tokenIdentifier: "google|791",
      email: "add-longbio@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Add Long Bio Tasker",
      city: "Kingston",
      province: "ON",
    });

    await t.mutation(internal.categories.seedCategories);
    const plumbing = await t.query(api.categories.getCategoryBySlug, {
      slug: "plumber",
    });
    const electrical = await t.query(api.categories.getCategoryBySlug, {
      slug: "electrician",
    });

    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "Base Profile",
      categoryId: plumbing!._id,
      categoryBio: "Base category bio",
      rateType: "hourly",
      hourlyRate: 8000,
      serviceRadius: 25,
    });

    await expect(
      asUser.mutation(api.taskers.addTaskerCategory, {
        categoryId: electrical!._id,
        categoryBio: "y".repeat(501),
        rateType: "fixed",
        fixedRate: 18000,
        serviceRadius: 20,
      })
    ).rejects.toThrow("Category bio must be 500 characters or less");
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

    await t.mutation(internal.categories.seedCategories);
    const plumbing = await t.query(api.categories.getCategoryBySlug, {
      slug: "plumber",
    });
    const electrical = await t.query(api.categories.getCategoryBySlug, {
      slug: "electrician",
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

    await t.mutation(internal.categories.seedCategories);
    const plumbing = await t.query(api.categories.getCategoryBySlug, {
      slug: "plumber",
    });
    const electrician = await t.query(api.categories.getCategoryBySlug, {
      slug: "electrician",
    });

    // Create profile with plumbing
    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "Electrical & Plumbing Pro",
      categoryId: plumbing!._id,
      categoryBio: "Plumbing work",
      rateType: "hourly",
      hourlyRate: 8500,
      serviceRadius: 25,
    });

    // Add electrician category
    await asUser.mutation(api.taskers.addTaskerCategory, {
      categoryId: electrician!._id,
      categoryBio: "Electrical installation and repair",
      rateType: "fixed",
      fixedRate: 25000,
      serviceRadius: 30,
    });

    // Verify both categories exist
    const profile = await asUser.query(api.taskers.getTaskerProfile);
    expect(profile?.categories).toHaveLength(2);
    
    const electricianCategory = profile?.categories.find(c => c.categoryId === electrician!._id);
    expect(electricianCategory).toBeDefined();
    expect(electricianCategory?.bio).toBe("Electrical installation and repair");
    expect(electricianCategory?.rateType).toBe("fixed");
    expect(electricianCategory?.fixedRate).toBe(25000);
  });

  test("addTaskerCategory supports a third category on the same profile", async () => {
    const t = convexTest(schema, modules);

    const asUser = t.withIdentity({
      tokenIdentifier: "google|404-third",
      email: "addcat-third@example.com",
    });

    await asUser.mutation(api.users.createProfile, {
      name: "Three Category Test",
      city: "Kitchener",
      province: "ON",
    });

    await t.mutation(internal.categories.seedCategories);
    const autoMechanic = await t.query(api.categories.getCategoryBySlug, {
      slug: "auto-mechanic",
    });
    const makeupArtist = await t.query(api.categories.getCategoryBySlug, {
      slug: "makeup-artist",
    });
    const hairStylist = await t.query(api.categories.getCategoryBySlug, {
      slug: "hair-stylist",
    });

    await asUser.mutation(api.taskers.createTaskerProfile, {
      displayName: "Multi-service Pro",
      categoryId: autoMechanic!._id,
      categoryBio: "Auto mechanic services",
      rateType: "hourly",
      hourlyRate: 2200,
      serviceRadius: 15,
    });

    await asUser.mutation(api.taskers.addTaskerCategory, {
      categoryId: makeupArtist!._id,
      categoryBio: "Makeup services",
      rateType: "fixed",
      fixedRate: 12500,
      serviceRadius: 30,
    });

    await asUser.mutation(api.taskers.addTaskerCategory, {
      categoryId: hairStylist!._id,
      categoryBio: "Hair styling services",
      rateType: "fixed",
      fixedRate: 9500,
      serviceRadius: 20,
    });

    const profile = await asUser.query(api.taskers.getTaskerProfile);
    expect(profile?.categories).toHaveLength(3);
    expect(profile?.categories.map((category) => category.categoryId).sort()).toEqual(
      [autoMechanic!._id, makeupArtist!._id, hairStylist!._id].sort()
    );
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

     await t.mutation(internal.categories.seedCategories);
     const plumbing = await t.query(api.categories.getCategoryBySlug, {
       slug: "plumber",
     });
     const electrical = await t.query(api.categories.getCategoryBySlug, {
       slug: "electrician",
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

   test("updateTaskerProfile works after replacing the only tasker category", async () => {
     const t = convexTest(schema, modules);

     const asUser = t.withIdentity({
       tokenIdentifier: "google|replace-only-category",
       email: "replace-only-category@example.com",
     });

     await asUser.mutation(api.users.createProfile, {
       name: "Replace Category Test",
       city: "Waterloo",
       province: "ON",
     });

     await t.mutation(internal.categories.seedCategories);
     const barber = await t.query(api.categories.getCategoryBySlug, {
       slug: "barber",
     });
     const tutor = await t.query(api.categories.getCategoryBySlug, {
       slug: "tutor",
     });

     await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "Barber Dave",
       websiteLinks: ["https://ddga.ltd"],
       socialLinks: ["dja29"],
       categoryId: barber!._id,
       categoryBio: "Barber services",
       rateType: "hourly",
       hourlyRate: 4000,
       serviceRadius: 25,
     });

     const user = await asUser.query(api.users.getCurrentUser);
     expect(user).not.toBeNull();
     await applyRevenueCatEvent(t, {
       type: "INITIAL_PURCHASE",
       userId: user!._id,
       productId: PATCHWORK_BASIC_MONTHLY_PRODUCT_ID,
       expirationAtMs: 1_900_000_000_000,
     });
     await asUser.mutation(api.taskers.setGhostMode, {
       ghostMode: false,
     });

     await asUser.mutation(api.taskers.removeTaskerCategory, {
       categoryId: barber!._id,
     });

     let profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile).not.toBeNull();
     expect(profile?.categories).toHaveLength(0);

     await asUser.mutation(api.taskers.addTaskerCategory, {
       categoryId: tutor!._id,
       categoryBio: "Tutor 2",
       rateType: "hourly",
       hourlyRate: 4000,
       serviceRadius: 25,
     });

     profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile).not.toBeNull();
     const beforeNoOpSaveUpdatedAt = profile!.updatedAt;

     const noOpProfile = await asUser.mutation(api.taskers.updateTaskerProfile, {
       displayName: "Barber Dave",
       websiteLinks: ["https://ddga.ltd"],
       socialLinks: ["dja29"],
     });

     expect(noOpProfile.updatedAt).toBe(beforeNoOpSaveUpdatedAt);
     expect(noOpProfile.categories).toHaveLength(1);
     expect(noOpProfile.categories[0].categoryId).toBe(tutor!._id);

     const updatedProfile = await asUser.mutation(api.taskers.updateTaskerProfile, {
       displayName: "Tutor Dave",
       websiteLinks: ["https://ddga.ltd"],
       socialLinks: ["dja29"],
     });

     expect(updatedProfile.displayName).toBe("Tutor Dave");
     expect(updatedProfile.categories).toHaveLength(1);
     expect(updatedProfile.categories[0].categoryId).toBe(tutor!._id);
     expect(updatedProfile.categories[0].portfolioImages).toEqual([]);
     expect(updatedProfile.categories[0].coverImage).toBeNull();

     profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.displayName).toBe("Tutor Dave");
   });

   test("applyRevenueCatWebhookEvent activates subscription tasker access", async () => {
     const t = convexTest(schema, modules);
     
     const asUser = t.withIdentity({
       tokenIdentifier: "google|601",
       email: "subscription@example.com",
     });

     await asUser.mutation(api.users.createProfile, {
       name: "Subscription Plan Test",
       city: "Toronto",
       province: "ON",
     });

     await t.mutation(internal.categories.seedCategories);
     const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "plumber",
     });

     // Create tasker profile
     await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "Subscription Subscriber",
       categoryId: category!._id,
       categoryBio: "Plumbing services",
       rateType: "hourly",
       hourlyRate: 7000,
       serviceRadius: 20,
     });

     const user = await asUser.query(api.users.getCurrentUser);
     expect(user).not.toBeNull();

     const result = await applyRevenueCatEvent(t, {
       type: "INITIAL_PURCHASE",
       userId: user!._id,
       productId: PATCHWORK_ANNUAL_PRODUCT_ID,
       expirationAtMs: 1_900_000_000_000,
     });

     expect(result).toEqual({ applied: true, reason: "activated" });

     // Verify plan was set correctly
     const profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.subscriptionPlan).toBe("tasker");
     expect(profile?.subscriptionAccessType).toBe("subscription");
     expect(profile?.subscriptionTier).toBe("premium");
     expect(profile?.subscriptionStatus).toBe("active");
     expect(profile?.subscriptionEndsAt).toBe(1_900_000_000_000);
     expect(profile?.hasActiveSubscription).toBe(true);
     expect(profile?.ghostMode).toBe(false);
     expect(profile?.premiumPin?.code).toMatch(/^[0-9A-Z]{8}$/);
     expect(profile?.premiumPin?.status).toBe("active");
     expect(profile?.premiumPin?.tier).toBe("premium");
   });

   test("applyRevenueCatWebhookEvent activates basic monthly without a premium pin", async () => {
     const t = convexTest(schema, modules);

     const asUser = t.withIdentity({
       tokenIdentifier: "google|601-basic",
       email: "basic-subscription@example.com",
     });

     await asUser.mutation(api.users.createProfile, {
       name: "Basic Plan Test",
       city: "Toronto",
       province: "ON",
     });

     await t.mutation(internal.categories.seedCategories);
     const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "plumber",
     });

     await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "Basic Subscriber",
       categoryId: category!._id,
       categoryBio: "Plumbing services",
       rateType: "hourly",
       hourlyRate: 7000,
       serviceRadius: 20,
     });

     const user = await asUser.query(api.users.getCurrentUser);
     expect(user).not.toBeNull();

     const result = await applyRevenueCatEvent(t, {
       type: "INITIAL_PURCHASE",
       userId: user!._id,
       productId: PATCHWORK_BASIC_MONTHLY_PRODUCT_ID,
       expirationAtMs: 1_900_000_000_000,
     });

     expect(result).toEqual({ applied: true, reason: "activated" });

     const profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.subscriptionPlan).toBe("tasker");
     expect(profile?.subscriptionAccessType).toBe("subscription");
     expect(profile?.subscriptionTier).toBe("basic");
     expect(profile?.subscriptionStatus).toBe("active");
     expect(profile?.hasActiveSubscription).toBe(true);
     expect(profile?.premiumPin).toBeUndefined();
   });

   test("applyRevenueCatWebhookEvent activates lifetime tasker access", async () => {
     const t = convexTest(schema, modules);
     
     const asUser = t.withIdentity({
       tokenIdentifier: "google|602",
       email: "lifetime@example.com",
     });

     await asUser.mutation(api.users.createProfile, {
       name: "Lifetime Plan Test",
       city: "Vancouver",
       province: "BC",
     });

     await t.mutation(internal.categories.seedCategories);
     const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "electrician",
     });

     // Create tasker profile
     await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "Lifetime Subscriber",
       categoryId: category!._id,
       categoryBio: "Electrical services",
       rateType: "hourly",
       hourlyRate: 8000,
       serviceRadius: 25,
     });

     const user = await asUser.query(api.users.getCurrentUser);
     expect(user).not.toBeNull();

     const result = await applyRevenueCatEvent(t, {
       type: "INITIAL_PURCHASE",
       userId: user!._id,
       productId: PATCHWORK_LIFETIME_PRODUCT_ID,
     });

     expect(result).toEqual({ applied: true, reason: "activated" });

     // Verify plan was set correctly
     const profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.subscriptionPlan).toBe("tasker");
     expect(profile?.subscriptionAccessType).toBe("lifetime");
     expect(profile?.subscriptionTier).toBe("founders");
     expect(profile?.subscriptionStatus).toBe("active");
     expect(profile?.hasActiveSubscription).toBe(true);
     expect(profile?.ghostMode).toBe(false);
     expect(profile?.premiumPin?.code).toMatch(/^[0-9A-Z]{8}$/);
     expect(profile?.premiumPin?.status).toBe("active");
     expect(profile?.premiumPin?.tier).toBe("founders");
   });

   test("applyRevenueCatWebhookEvent clears ghostMode when activating subscription", async () => {
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

     await t.mutation(internal.categories.seedCategories);
     const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "general-handy-man",
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

     const user = await asUser.query(api.users.getCurrentUser);
     expect(user).not.toBeNull();

     await applyRevenueCatEvent(t, {
       type: "INITIAL_PURCHASE",
       userId: user!._id,
       productId: PATCHWORK_ANNUAL_PRODUCT_ID,
       expirationAtMs: 1_900_000_000_000,
     });

     // Verify ghostMode is false
     let profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.ghostMode).toBe(false);

     // Update to lifetime tasker access
     await applyRevenueCatEvent(t, {
       type: "PRODUCT_CHANGE",
       userId: user!._id,
       productId: PATCHWORK_LIFETIME_PRODUCT_ID,
     });

     // Verify ghostMode is still false
     profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.ghostMode).toBe(false);
   });

   test("applyRevenueCatWebhookEvent schedules term-end without immediately hiding the tasker", async () => {
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

     await t.mutation(internal.categories.seedCategories);
     const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "general-handy-man",
     });

     await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "Cancelable Tasker",
       categoryId: category!._id,
       categoryBio: "General handyman",
       rateType: "hourly",
       hourlyRate: 6500,
       serviceRadius: 15,
     });

     const user = await asUser.query(api.users.getCurrentUser);
     expect(user).not.toBeNull();

     await applyRevenueCatEvent(t, {
       type: "INITIAL_PURCHASE",
       userId: user!._id,
       productId: PATCHWORK_ANNUAL_PRODUCT_ID,
       expirationAtMs: 1_900_000_000_000,
     });
     const activeProfile = await asUser.query(api.taskers.getTaskerProfile);
     const activePin = activeProfile?.premiumPin?.code;
     expect(activePin).toMatch(/^[0-9A-Z]{8}$/);

     const result = await applyRevenueCatEvent(t, {
       type: "CANCELLATION",
       userId: user!._id,
       productId: PATCHWORK_ANNUAL_PRODUCT_ID,
       expirationAtMs: 1_900_000_000_000,
     });
     expect(result).toEqual({ applied: true, reason: "cancellation_scheduled" });

     const profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.subscriptionStatus).toBe("cancel_at_period_end");
     expect(profile?.hasActiveSubscription).toBe(true);
     expect(profile?.ghostMode).toBe(false);
     expect(profile?.premiumPin).toBeUndefined();
     const storedProfile = await t.run(async (ctx) => ctx.db.get(profile!._id));
     expect(storedProfile?.premiumPin).toBe(activePin);
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

     await t.mutation(internal.categories.seedCategories);
     const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "general-handy-man",
     });

     await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "Expired Tasker",
       categoryId: category!._id,
       categoryBio: "General handyman",
       rateType: "hourly",
       hourlyRate: 6500,
       serviceRadius: 15,
     });

     const user = await asUser.query(api.users.getCurrentUser);
     expect(user).not.toBeNull();

     await applyRevenueCatEvent(t, {
       type: "INITIAL_PURCHASE",
       userId: user!._id,
       productId: PATCHWORK_ANNUAL_PRODUCT_ID,
       expirationAtMs: Date.now() + 7 * 24 * 60 * 60 * 1000,
     });

     const result = await applyRevenueCatEvent(t, {
       type: "EXPIRATION",
       userId: user!._id,
       productId: PATCHWORK_ANNUAL_PRODUCT_ID,
       expirationAtMs: Date.now() - 1_000,
     });

     expect(result).toEqual({ applied: true, reason: "expired" });

     const profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.subscriptionPlan).toBe("none");
     expect(profile?.subscriptionStatus).toBe("expired");
     expect(profile?.hasActiveSubscription).toBe(false);
     expect(profile?.ghostMode).toBe(true);
     expect(profile?.premiumPin).toBeUndefined();
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

     await t.mutation(internal.categories.seedCategories);
     const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "interior-painter",
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

    await t.mutation(internal.categories.seedCategories);
    const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "electrician",
     });

     // Create tasker profile
     await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "Ghost Mode Enabled Tasker",
       categoryId: category!._id,
       categoryBio: "Electrical services",
       rateType: "hourly",
       hourlyRate: 9000,
       serviceRadius: 30,
     });

     const user = await asUser.query(api.users.getCurrentUser);
     expect(user).not.toBeNull();

     await applyRevenueCatEvent(t, {
       type: "INITIAL_PURCHASE",
       userId: user!._id,
       productId: PATCHWORK_ANNUAL_PRODUCT_ID,
       expirationAtMs: 1_900_000_000_000,
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

   test("applyRevenueCatWebhookEvent expires lifetime access on cancellation", async () => {
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

    await t.mutation(internal.categories.seedCategories);
    const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "electrician",
     });

     await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "Lifetime Tasker",
       categoryId: category!._id,
       categoryBio: "Electrical services",
       rateType: "hourly",
       hourlyRate: 9000,
       serviceRadius: 30,
     });

     const user = await asUser.query(api.users.getCurrentUser);
     expect(user).not.toBeNull();

     const result = await applyRevenueCatEvent(t, {
       type: "CANCELLATION",
       userId: user!._id,
       productId: PATCHWORK_LIFETIME_PRODUCT_ID,
     });

     expect(result).toEqual({ applied: true, reason: "expired" });

     const profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.subscriptionStatus).toBe("expired");
     expect(profile?.premiumPin).toBeUndefined();
     expect(profile?.hasActiveSubscription).toBe(false);
   });

   test("applyRevenueCatWebhookEvent activates annual subscription access", async () => {
     const t = convexTest(schema, modules);

     const asUser = t.withIdentity({
       tokenIdentifier: "google|606",
       email: "revenuecat-subscription@example.com",
     });

     await asUser.mutation(api.users.createProfile, {
       name: "RevenueCat Subscription Test",
       city: "Toronto",
       province: "ON",
     });

     await t.mutation(internal.categories.seedCategories);
     const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "plumber",
     });

     await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "Webhook Tasker",
       categoryId: category!._id,
       categoryBio: "Plumbing services",
       rateType: "hourly",
       hourlyRate: 7000,
       serviceRadius: 20,
     });

     const user = await asUser.query(api.users.getCurrentUser);
     expect(user).not.toBeNull();

     const result = await t.mutation(internal.taskersInternal.applyRevenueCatWebhookEvent, {
       type: "INITIAL_PURCHASE",
       appId: "app6be2ab0fb8",
       productId: "ltd.ddga.patchwork.tasker.subscription.yearly",
       appUserId: user!._id,
       aliases: [],
       expirationAtMs: 1_900_000_000_000,
     });

     expect(result).toEqual({ applied: true, reason: "activated" });

     const profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.subscriptionPlan).toBe("tasker");
     expect(profile?.subscriptionAccessType).toBe("subscription");
     expect(profile?.subscriptionStatus).toBe("active");
     expect(profile?.subscriptionEndsAt).toBe(1_900_000_000_000);
     expect(profile?.ghostMode).toBe(false);
   });

   test("applyRevenueCatWebhookEvent ignores the retired weekly product", async () => {
     const t = convexTest(schema, modules);

     const asUser = t.withIdentity({
       tokenIdentifier: "google|607",
       email: "revenuecat-weekly@example.com",
     });

     await asUser.mutation(api.users.createProfile, {
       name: "RevenueCat Weekly Test",
       city: "Toronto",
       province: "ON",
     });

     await t.mutation(internal.categories.seedCategories);
     const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "plumber",
     });

     await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "Retired Weekly Tasker",
       categoryId: category!._id,
       categoryBio: "Plumbing services",
       rateType: "hourly",
       hourlyRate: 7000,
       serviceRadius: 20,
     });

     const user = await asUser.query(api.users.getCurrentUser);
     expect(user).not.toBeNull();

     const result = await t.mutation(internal.taskersInternal.applyRevenueCatWebhookEvent, {
       type: "INITIAL_PURCHASE",
       appId: "app6be2ab0fb8",
       productId: "ltd.ddga.patchwork.tasker.weekly",
       appUserId: user!._id,
       aliases: [],
       expirationAtMs: 1_900_000_000_000,
     });

     expect(result).toEqual({ applied: false, reason: "legacy_weekly_ignored" });

     const profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.subscriptionPlan).toBe("none");
     expect(profile?.subscriptionAccessType).toBeUndefined();
     expect(profile?.subscriptionStatus).toBe("inactive");
     expect(profile?.ghostMode).toBe(true);
   });

   test("reconcileRevenueCatWebhookEvent repairs transfer events by fetching canonical customer state", async () => {
     const t = convexTest(schema, modules);

     process.env.REVENUECAT_SECRET_API_KEY = "secret_test_key";
     vi.stubGlobal("fetch", vi.fn(async () => ({
       ok: true,
       status: 200,
       json: async () => ({
         subscriber: {
           entitlements: {
             tasker_access: {
               product_identifier: PATCHWORK_ANNUAL_PRODUCT_ID,
               purchase_date_ms: 1_890_000_000_000,
               expires_date_ms: 1_900_000_000_000,
             },
           },
           subscriptions: {
             [PATCHWORK_ANNUAL_PRODUCT_ID]: {
               purchase_date_ms: 1_890_000_000_000,
               expires_date_ms: 1_900_000_000_000,
             },
           },
         },
       }),
       text: async () => "",
     })) as typeof fetch);

     const asUser = t.withIdentity({
       tokenIdentifier: "google|608",
       email: "transfer@example.com",
     });

     await asUser.mutation(api.users.createProfile, {
       name: "Transfer Test",
       city: "Toronto",
       province: "ON",
     });

     await t.mutation(internal.categories.seedCategories);
     const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "plumber",
     });

     await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "Transferred Tasker",
       categoryId: category!._id,
       categoryBio: "Plumbing services",
       rateType: "hourly",
       hourlyRate: 7000,
       serviceRadius: 20,
     });

     const user = await asUser.query(api.users.getCurrentUser);
     expect(user).not.toBeNull();

     const result = await t.action(internal.taskersInternal.reconcileRevenueCatWebhookEvent, {
       type: "TRANSFER",
       appId: PATCHWORK_REVENUECAT_APP_ID,
       appUserId: undefined,
       originalAppUserId: undefined,
       aliases: [],
       transferredFrom: ["$RCAnonymousID:source-transfer-user"],
       transferredTo: [user!._id],
       expirationAtMs: null,
     });

     expect(result).toEqual({ applied: true, reason: "canonical_state_applied" });

     const profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.subscriptionPlan).toBe("tasker");
     expect(profile?.subscriptionAccessType).toBe("subscription");
     expect(profile?.subscriptionActiveAccessTypes).toEqual(["subscription"]);
     expect(profile?.subscriptionStatus).toBe("active");
     expect(profile?.subscriptionEndsAt).toBe(1_900_000_000_000);
     expect(profile?.hasActiveSubscription).toBe(true);
     expect(profile?.ghostMode).toBe(false);
   });

   test("reconcileRevenueCatWebhookEvent keeps lifetime active when yearly and lifetime coexist", async () => {
     const t = convexTest(schema, modules);

     process.env.REVENUECAT_SECRET_API_KEY = "secret_test_key";
     vi.stubGlobal("fetch", vi.fn(async () => ({
       ok: true,
       status: 200,
       json: async () => ({
         subscriber: {
           entitlements: {
             tasker_access: {
               product_identifier: PATCHWORK_LIFETIME_PRODUCT_ID,
               purchase_date_ms: 1_880_000_000_000,
             },
           },
           subscriptions: {
             [PATCHWORK_ANNUAL_PRODUCT_ID]: {
               purchase_date_ms: 1_890_000_000_000,
               expires_date_ms: 1_900_000_000_000,
             },
           },
           non_subscriptions: {
             [PATCHWORK_LIFETIME_PRODUCT_ID]: [
               {
                 purchase_date_ms: 1_880_000_000_000,
               },
             ],
           },
         },
       }),
       text: async () => "",
     })) as typeof fetch);

     const asUser = t.withIdentity({
       tokenIdentifier: "google|609",
       email: "mixed@example.com",
     });

     await asUser.mutation(api.users.createProfile, {
       name: "Mixed Access Test",
       city: "Toronto",
       province: "ON",
     });

     await t.mutation(internal.categories.seedCategories);
     const category = await t.query(api.categories.getCategoryBySlug, {
       slug: "plumber",
     });

     await asUser.mutation(api.taskers.createTaskerProfile, {
       displayName: "Mixed Access Tasker",
       categoryId: category!._id,
       categoryBio: "Plumbing services",
       rateType: "hourly",
       hourlyRate: 7000,
       serviceRadius: 20,
     });

     const user = await asUser.query(api.users.getCurrentUser);
     expect(user).not.toBeNull();

     const result = await t.action(internal.taskersInternal.reconcileRevenueCatWebhookEvent, {
       type: "EXPIRATION",
       appId: PATCHWORK_REVENUECAT_APP_ID,
       productId: PATCHWORK_ANNUAL_PRODUCT_ID,
       appUserId: user!._id,
       originalAppUserId: user!._id,
       aliases: [],
       transferredFrom: [],
       transferredTo: [],
       expirationAtMs: 1_900_000_000_000,
     });

     expect(result).toEqual({ applied: true, reason: "canonical_state_applied" });

     const profile = await asUser.query(api.taskers.getTaskerProfile);
     expect(profile?.subscriptionPlan).toBe("tasker");
     expect(profile?.subscriptionAccessType).toBe("lifetime");
     expect(profile?.subscriptionActiveAccessTypes).toEqual(["subscription", "lifetime"]);
     expect(profile?.subscriptionStatus).toBe("active");
     expect(profile?.hasActiveSubscription).toBe(true);
     expect(profile?.ghostMode).toBe(false);
   });
});
