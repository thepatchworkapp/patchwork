import { convexTest } from "convex-test";
import { expect, test, describe } from "vitest";
import { api } from "../_generated/api";
import schema from "../schema";
import * as conversationsModule from "../conversations";
import * as usersModule from "../users";
import * as messagesModule from "../messages";
import * as categoriesModule from "../categories";
import * as filesModule from "../files";
import * as taskersModule from "../taskers";
import * as authModule from "../auth";
import * as httpModule from "../http";
import * as proposalsModule from "../proposals";
import * as jobsModule from "../jobs";
import * as reviewsModule from "../reviews";

const modules: Record<string, () => Promise<any>> = {
  "../conversations.ts": async () => conversationsModule,
  "../users.ts": async () => usersModule,
  "../messages.ts": async () => messagesModule,
  "../categories.ts": async () => categoriesModule,
  "../files.ts": async () => filesModule,
  "../taskers.ts": async () => taskersModule,
  "../auth.ts": async () => authModule,
  "../http.ts": async () => httpModule,
  "../proposals.ts": async () => proposalsModule,
  "../jobs.ts": async () => jobsModule,
  "../reviews.ts": async () => reviewsModule,
  "../_generated/api.ts": async () => ({ default: api }),
  "../schema.ts": async () => ({ default: schema }),
};

// Helper to create a completed job
async function createCompletedJob(t: any, seekerAuth: any, taskerAuth: any) {
  await t.mutation(api.categories.seedCategories);

  // Create seeker
  const seekerId = await seekerAuth.mutation(api.users.createProfile, {
    name: "Seeker",
    city: "Toronto",
    province: "ON",
  });

  // Create tasker with profile
  const taskerId = await taskerAuth.mutation(api.users.createProfile, {
    name: "Tasker",
    city: "Toronto",
    province: "ON",
  });

  // Get first category
  const categories = await t.query(api.categories.listCategories);
  const category = categories[0];

  // Create tasker profile
  await taskerAuth.mutation(api.taskers.createTaskerProfile, {
    displayName: "Tasker Pro",
    categoryId: category._id,
    categoryBio: "Professional tasker",
    rateType: "hourly",
    hourlyRate: 5000,
    serviceRadius: 25,
  });

  // Create seeker profile if it doesn't exist
  const seekerProfile = await t.run(async (ctx: any) => {
    return await ctx.db
      .query("seekerProfiles")
      .withIndex("by_userId", (q: any) => q.eq("userId", seekerId))
      .first();
  });

  if (!seekerProfile) {
    await t.run(async (ctx: any) => {
      await ctx.db.insert("seekerProfiles", {
        userId: seekerId,
        jobsPosted: 0,
        completedJobs: 0,
        rating: 0,
        ratingCount: 0,
        favouriteTaskers: [],
        updatedAt: Date.now(),
      });
    });
  }

  // Start conversation
  const conversationId = await seekerAuth.mutation(
    api.conversations.startConversation,
    { taskerId }
  );

  // Send and accept proposal
  const proposalId = await taskerAuth.mutation(api.proposals.sendProposal, {
    conversationId,
    rate: 5000,
    rateType: "hourly",
    startDateTime: "2026-02-15T10:00:00Z",
  });

  const { jobId } = await seekerAuth.mutation(api.proposals.acceptProposal, {
    proposalId,
  });

  // Complete job
  await seekerAuth.mutation(api.jobs.completeJob, { jobId });

  return { jobId, seekerId, taskerId };
}

describe("reviews - rating aggregation", () => {
  test("first review sets profile rating to that rating", async () => {
    const t = convexTest(schema, modules);

    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_rating1",
      email: "seeker_rating1@example.com",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_rating1",
      email: "tasker_rating1@example.com",
    });

    const { jobId, taskerId } = await createCompletedJob(t, asSeeker, asTasker);

    // Seeker reviews tasker with rating 5
    await asSeeker.mutation(api.reviews.createReview, {
      jobId,
      rating: 5,
      text: "Excellent work!",
    });

    // Verify tasker profile rating updated
    const taskerProfile = await t.run(async (ctx: any) => {
      return await ctx.db
        .query("taskerProfiles")
        .withIndex("by_userId", (q: any) => q.eq("userId", taskerId))
        .first();
    });

    expect(taskerProfile).toBeDefined();
    expect(taskerProfile.rating).toBe(5);
    expect(taskerProfile.reviewCount).toBe(1);
  });

  test("second review calculates weighted average", async () => {
    const t = convexTest(schema, modules);

    const asSeeker1 = t.withIdentity({
      tokenIdentifier: "google|seeker_rating2a",
      email: "seeker_rating2a@example.com",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_rating2",
      email: "tasker_rating2@example.com",
    });

    // First job and review (rating 4)
    const { jobId: jobId1, taskerId } = await createCompletedJob(
      t,
      asSeeker1,
      asTasker
    );

    await asSeeker1.mutation(api.reviews.createReview, {
      jobId: jobId1,
      rating: 4,
      text: "Good work overall",
    });

    // Verify first rating
    let taskerProfile = await t.run(async (ctx: any) => {
      return await ctx.db
        .query("taskerProfiles")
        .withIndex("by_userId", (q: any) => q.eq("userId", taskerId))
        .first();
    });

    expect(taskerProfile.rating).toBe(4);
    expect(taskerProfile.reviewCount).toBe(1);

    // Second job with different seeker (rating 5)
    const asSeeker2 = t.withIdentity({
      tokenIdentifier: "google|seeker_rating2b",
      email: "seeker_rating2b@example.com",
    });

    const seekerId2 = await asSeeker2.mutation(api.users.createProfile, {
      name: "Seeker 2",
      city: "Toronto",
      province: "ON",
    });

    // Create seeker profile for second seeker
    await t.run(async (ctx: any) => {
      await ctx.db.insert("seekerProfiles", {
        userId: seekerId2,
        jobsPosted: 0,
        completedJobs: 0,
        rating: 0,
        ratingCount: 0,
        favouriteTaskers: [],
        updatedAt: Date.now(),
      });
    });

    const conversationId2 = await asSeeker2.mutation(
      api.conversations.startConversation,
      { taskerId }
    );

    const proposalId2 = await asTasker.mutation(api.proposals.sendProposal, {
      conversationId: conversationId2,
      rate: 5000,
      rateType: "hourly",
      startDateTime: "2026-02-16T10:00:00Z",
    });

    const { jobId: jobId2 } = await asSeeker2.mutation(
      api.proposals.acceptProposal,
      { proposalId: proposalId2 }
    );

    await asSeeker2.mutation(api.jobs.completeJob, { jobId: jobId2 });

    await asSeeker2.mutation(api.reviews.createReview, {
      jobId: jobId2,
      rating: 5,
      text: "Excellent work!",
    });

    // Verify weighted average: (4*1 + 5) / 2 = 4.5
    taskerProfile = await t.run(async (ctx: any) => {
      return await ctx.db
        .query("taskerProfiles")
        .withIndex("by_userId", (q: any) => q.eq("userId", taskerId))
        .first();
    });

    expect(taskerProfile.rating).toBe(4.5);
    expect(taskerProfile.reviewCount).toBe(2);
  });

  test("rating stays within 0-5 range", async () => {
    const t = convexTest(schema, modules);

    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_rating3",
      email: "seeker_rating3@example.com",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_rating3",
      email: "tasker_rating3@example.com",
    });

    const { jobId, taskerId } = await createCompletedJob(t, asSeeker, asTasker);

    // Create review with rating 1 (minimum)
    await asSeeker.mutation(api.reviews.createReview, {
      jobId,
      rating: 1,
      text: "Needs improvement",
    });

    const taskerProfile = await t.run(async (ctx: any) => {
      return await ctx.db
        .query("taskerProfiles")
        .withIndex("by_userId", (q: any) => q.eq("userId", taskerId))
        .first();
    });

    expect(taskerProfile.rating).toBeGreaterThanOrEqual(0);
    expect(taskerProfile.rating).toBeLessThanOrEqual(5);
    expect(taskerProfile.rating).toBe(1);
  });

  test("reviewCount increments on each review", async () => {
    const t = convexTest(schema, modules);

    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_rating4",
      email: "seeker_rating4@example.com",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_rating4",
      email: "tasker_rating4@example.com",
    });

    const { jobId, taskerId } = await createCompletedJob(t, asSeeker, asTasker);

    // Get initial count
    let taskerProfile = await t.run(async (ctx: any) => {
      return await ctx.db
        .query("taskerProfiles")
        .withIndex("by_userId", (q: any) => q.eq("userId", taskerId))
        .first();
    });

    const initialCount = taskerProfile.reviewCount;

    // Create review
    await asSeeker.mutation(api.reviews.createReview, {
      jobId,
      rating: 4,
      text: "Good work overall",
    });

    // Verify count incremented
    taskerProfile = await t.run(async (ctx: any) => {
      return await ctx.db
        .query("taskerProfiles")
        .withIndex("by_userId", (q: any) => q.eq("userId", taskerId))
        .first();
    });

    expect(taskerProfile.reviewCount).toBe(initialCount + 1);
  });

  test("tasker reviewing seeker updates seekerProfiles.ratingCount", async () => {
    const t = convexTest(schema, modules);

    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_rating5",
      email: "seeker_rating5@example.com",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_rating5",
      email: "tasker_rating5@example.com",
    });

    const { jobId, seekerId } = await createCompletedJob(t, asSeeker, asTasker);

    // Tasker reviews seeker with rating 4
    await asTasker.mutation(api.reviews.createReview, {
      jobId,
      rating: 4,
      text: "Great communication!",
    });

    // Verify seeker profile rating updated (note: ratingCount not reviewCount)
    const seekerProfile = await t.run(async (ctx: any) => {
      return await ctx.db
        .query("seekerProfiles")
        .withIndex("by_userId", (q: any) => q.eq("userId", seekerId))
        .first();
    });

    expect(seekerProfile).toBeDefined();
    expect(seekerProfile.rating).toBe(4);
    expect(seekerProfile.ratingCount).toBe(1);
  });

  test("multiple reviews create correct weighted average", async () => {
    const t = convexTest(schema, modules);

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_rating6",
      email: "tasker_rating6@example.com",
    });

    // Create tasker once
    await t.mutation(api.categories.seedCategories);
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Multi",
      city: "Toronto",
      province: "ON",
    });

    const categories = await t.query(api.categories.listCategories);
    const category = categories[0];

    await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Tasker Pro",
      categoryId: category._id,
      categoryBio: "Professional tasker",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 25,
    });

    // Create three jobs with different seekers
    const ratings = [5, 3, 4]; // Average should be (5+3+4)/3 = 4

    for (let i = 0; i < ratings.length; i++) {
      const asSeeker = t.withIdentity({
        tokenIdentifier: `google|seeker_rating6_${i}`,
        email: `seeker_rating6_${i}@example.com`,
      });

      const seekerId = await asSeeker.mutation(api.users.createProfile, {
        name: `Seeker ${i}`,
        city: "Toronto",
        province: "ON",
      });

      // Create seeker profile
      await t.run(async (ctx: any) => {
        await ctx.db.insert("seekerProfiles", {
          userId: seekerId,
          jobsPosted: 0,
          completedJobs: 0,
          rating: 0,
          ratingCount: 0,
          favouriteTaskers: [],
          updatedAt: Date.now(),
        });
      });

      // Start conversation
      const conversationId = await asSeeker.mutation(
        api.conversations.startConversation,
        { taskerId }
      );

      // Send and accept proposal
      const proposalId = await asTasker.mutation(api.proposals.sendProposal, {
        conversationId,
        rate: 5000,
        rateType: "hourly",
        startDateTime: `2026-02-${15 + i}T10:00:00Z`,
      });

      const { jobId } = await asSeeker.mutation(api.proposals.acceptProposal, {
        proposalId,
      });

      // Complete job
      await asSeeker.mutation(api.jobs.completeJob, { jobId });

      // Leave review
      await asSeeker.mutation(api.reviews.createReview, {
        jobId,
        rating: ratings[i],
        text: `Review number ${i + 1} with rating ${ratings[i]}`,
      });
    }

    // Verify final weighted average
    const taskerProfile = await t.run(async (ctx: any) => {
      return await ctx.db
        .query("taskerProfiles")
        .withIndex("by_userId", (q: any) => q.eq("userId", taskerId))
        .first();
    });

    expect(taskerProfile.rating).toBe(4);
    expect(taskerProfile.reviewCount).toBe(3);
  });
});

describe("reviews - basic functionality", () => {
  test("can create review for completed job", async () => {
    const t = convexTest(schema, modules);

    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_basic1",
      email: "seeker_basic1@example.com",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_basic1",
      email: "tasker_basic1@example.com",
    });

    const { jobId } = await createCompletedJob(t, asSeeker, asTasker);

    const reviewId = await asSeeker.mutation(api.reviews.createReview, {
      jobId,
      rating: 5,
      text: "Excellent work!",
    });

    expect(reviewId).toBeDefined();
  });

  test("cannot review non-completed job", async () => {
    const t = convexTest(schema, modules);

    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_basic2",
      email: "seeker_basic2@example.com",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_basic2",
      email: "tasker_basic2@example.com",
    });

    await t.mutation(api.categories.seedCategories);

    const seekerId = await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker",
      city: "Toronto",
      province: "ON",
    });

    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker",
      city: "Toronto",
      province: "ON",
    });

    const categories = await t.query(api.categories.listCategories);
    const category = categories[0];

    await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Tasker Pro",
      categoryId: category._id,
      categoryBio: "Professional tasker",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 25,
    });

    const conversationId = await asSeeker.mutation(
      api.conversations.startConversation,
      { taskerId }
    );

    const proposalId = await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 5000,
      rateType: "hourly",
      startDateTime: "2026-02-15T10:00:00Z",
    });

    const { jobId } = await asSeeker.mutation(api.proposals.acceptProposal, {
      proposalId,
    });

    // Try to review in_progress job (should fail)
    await expect(
      asSeeker.mutation(api.reviews.createReview, {
        jobId,
        rating: 5,
        text: "Excellent work!",
      })
    ).rejects.toThrow("Can only review completed jobs");
  });

  test("cannot review twice", async () => {
    const t = convexTest(schema, modules);

    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_basic3",
      email: "seeker_basic3@example.com",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_basic3",
      email: "tasker_basic3@example.com",
    });

    const { jobId } = await createCompletedJob(t, asSeeker, asTasker);

    // First review succeeds
    await asSeeker.mutation(api.reviews.createReview, {
      jobId,
      rating: 5,
      text: "Excellent work!",
    });

    // Second review fails
    await expect(
      asSeeker.mutation(api.reviews.createReview, {
        jobId,
        rating: 4,
        text: "Changed my mind",
      })
    ).rejects.toThrow("You have already reviewed this job");
  });

  test("rating must be 1-5", async () => {
    const t = convexTest(schema, modules);

    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_basic4",
      email: "seeker_basic4@example.com",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_basic4",
      email: "tasker_basic4@example.com",
    });

    const { jobId } = await createCompletedJob(t, asSeeker, asTasker);

    // Rating too low
    await expect(
      asSeeker.mutation(api.reviews.createReview, {
        jobId,
        rating: 0,
        text: "Terrible work",
      })
    ).rejects.toThrow("Rating must be between 1 and 5");

    // Rating too high
    await expect(
      asSeeker.mutation(api.reviews.createReview, {
        jobId,
        rating: 6,
        text: "Amazing work",
      })
    ).rejects.toThrow("Rating must be between 1 and 5");
  });

  test("text must be 10+ chars", async () => {
    const t = convexTest(schema, modules);

    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_basic5",
      email: "seeker_basic5@example.com",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_basic5",
      email: "tasker_basic5@example.com",
    });

    const { jobId } = await createCompletedJob(t, asSeeker, asTasker);

    // Text too short
    await expect(
      asSeeker.mutation(api.reviews.createReview, {
        jobId,
        rating: 5,
        text: "Good",
      })
    ).rejects.toThrow("Review text must be at least 10 characters");
  });
});
