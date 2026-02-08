import { convexTest } from "convex-test";
import { expect, test, describe } from "vitest";
import { api } from "../_generated/api";
import schema from "../schema";

// Module imports (no search/location — those require geospatial component setup)
import * as usersModule from "../users";
import * as categoriesModule from "../categories";
import * as filesModule from "../files";
import * as taskersModule from "../taskers";
import * as conversationsModule from "../conversations";
import * as messagesModule from "../messages";
import * as proposalsModule from "../proposals";
import * as jobsModule from "../jobs";
import * as jobRequestsModule from "../jobRequests";
import * as reviewsModule from "../reviews";
import * as authModule from "../auth";
import * as httpModule from "../http";

const modules: Record<string, () => Promise<any>> = {
  "../users.ts": async () => usersModule,
  "../categories.ts": async () => categoriesModule,
  "../files.ts": async () => filesModule,
  "../taskers.ts": async () => taskersModule,
  "../conversations.ts": async () => conversationsModule,
  "../messages.ts": async () => messagesModule,
  "../proposals.ts": async () => proposalsModule,
  "../jobs.ts": async () => jobsModule,
  "../jobRequests.ts": async () => jobRequestsModule,
  "../reviews.ts": async () => reviewsModule,
  "../auth.ts": async () => authModule,
  "../http.ts": async () => httpModule,
  "../_generated/api.ts": async () => ({ default: api }),
  "../schema.ts": async () => ({ default: schema }),
};

const seekerAuth = {
  tokenIdentifier: "google|seeker-security-test",
  email: "seeker-security@test.com",
};

const taskerAuth = {
  tokenIdentifier: "google|tasker-security-test",
  email: "tasker-security@test.com",
};

const outsiderAuth = {
  tokenIdentifier: "google|outsider-security-test",
  email: "outsider-security@test.com",
};

describe("Security: Input Validation", () => {
  test("createProfile rejects name longer than 100 chars", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity(seekerAuth);

    await expect(
      asUser.mutation(api.users.createProfile, {
        name: "A".repeat(101),
        city: "Toronto",
        province: "ON",
      })
    ).rejects.toThrow("Name must be 100 characters or less");
  });

  test("createProfile accepts name at exactly 100 chars", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity(seekerAuth);

    const result = await asUser.mutation(api.users.createProfile, {
      name: "A".repeat(100),
      city: "Toronto",
      province: "ON",
    });
    expect(result).toBeDefined();
  });

  test("sendMessage rejects content longer than 5000 chars", async () => {
    const t = convexTest(schema, modules);
    const asSeeker = t.withIdentity(seekerAuth);
    const asTasker = t.withIdentity(taskerAuth);

    // Setup: create users
    const seekerId = await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker",
      city: "Toronto",
      province: "ON",
    });

    await asTasker.mutation(api.users.createProfile, {
      name: "Tasker",
      city: "Toronto",
      province: "ON",
    });

    // Seed category and create tasker profile
    await t.run(async (ctx) => {
      await ctx.db.insert("categories", {
        name: "Cleaning",
        slug: "cleaning",
        isActive: true,
      });
    });

    const categories = await asSeeker.query(api.categories.listCategories);
    const categoryId = categories[0]._id;

    await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Test Tasker",
      categoryId,
      categoryBio: "I clean well",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 25,
    });

    // Get tasker user ID for conversation
    const taskerUser = await asTasker.query(api.users.getCurrentUser);
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId: taskerUser!._id,
    });

    // Try sending a message that's too long
    await expect(
      asSeeker.mutation(api.messages.sendMessage, {
        conversationId,
        content: "X".repeat(5001),
      })
    ).rejects.toThrow("Message must be 5000 characters or less");
  });

  test("sendMessage rejects empty content", async () => {
    const t = convexTest(schema, modules);
    const asSeeker = t.withIdentity(seekerAuth);
    const asTasker = t.withIdentity(taskerAuth);

    const seekerId = await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker",
      city: "Toronto",
      province: "ON",
    });

    await asTasker.mutation(api.users.createProfile, {
      name: "Tasker",
      city: "Toronto",
      province: "ON",
    });

    await t.run(async (ctx) => {
      await ctx.db.insert("categories", {
        name: "Cleaning",
        slug: "cleaning",
        isActive: true,
      });
    });

    const categories = await asSeeker.query(api.categories.listCategories);
    const categoryId = categories[0]._id;

    await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Test Tasker",
      categoryId,
      categoryBio: "I clean well",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 25,
    });

    const taskerUser = await asTasker.query(api.users.getCurrentUser);
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId: taskerUser!._id,
    });

    await expect(
      asSeeker.mutation(api.messages.sendMessage, {
        conversationId,
        content: "   ",
      })
    ).rejects.toThrow("Message cannot be empty");
  });

  test("createReview rejects non-integer rating", async () => {
    const t = convexTest(schema, modules);
    const asSeeker = t.withIdentity(seekerAuth);
    const asTasker = t.withIdentity(taskerAuth);

    // Setup users + conversation + proposal + accepted job
    const seekerId = await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker",
      city: "Toronto",
      province: "ON",
    });

    await asTasker.mutation(api.users.createProfile, {
      name: "Tasker",
      city: "Toronto",
      province: "ON",
    });

    await t.run(async (ctx) => {
      await ctx.db.insert("categories", {
        name: "Cleaning",
        slug: "cleaning",
        isActive: true,
      });
    });

    const categories = await asSeeker.query(api.categories.listCategories);
    const categoryId = categories[0]._id;

    await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Test Tasker",
      categoryId,
      categoryBio: "I clean well",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 25,
    });

    const taskerUser = await asTasker.query(api.users.getCurrentUser);
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId: taskerUser!._id,
    });

    // Create and accept proposal to get a job
    const proposalId = await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 5000,
      rateType: "hourly",
      startDateTime: "2026-03-01T10:00:00",
    });

    const { jobId } = await asSeeker.mutation(api.proposals.acceptProposal, {
      proposalId,
    });

    // Complete the job
    await asSeeker.mutation(api.jobs.completeJob, { jobId });

    // Try reviewing with non-integer rating
    await expect(
      asSeeker.mutation(api.reviews.createReview, {
        jobId,
        rating: 4.5,
        text: "Good job, would recommend this tasker",
      })
    ).rejects.toThrow("Rating must be a whole number");
  });

  test("updateLocation rejects invalid coordinates", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity(seekerAuth);

    await asUser.mutation(api.users.createProfile, {
      name: "Test User",
      city: "Toronto",
      province: "ON",
    });

    await expect(
      asUser.mutation(api.users.updateLocation, {
        lat: 100,
        lng: -79.3832,
        source: "gps",
      })
    ).rejects.toThrow("Latitude must be between -90 and 90");

    await expect(
      asUser.mutation(api.users.updateLocation, {
        lat: 43.6532,
        lng: -200,
        source: "gps",
      })
    ).rejects.toThrow("Longitude must be between -180 and 180");
  });

  test("createTaskerProfile rejects service radius out of range", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity(seekerAuth);

    await asUser.mutation(api.users.createProfile, {
      name: "Test User",
      city: "Toronto",
      province: "ON",
    });

    await t.run(async (ctx) => {
      await ctx.db.insert("categories", {
        name: "Cleaning",
        slug: "cleaning",
        isActive: true,
      });
    });

    const categories = await asUser.query(api.categories.listCategories);
    const categoryId = categories[0]._id;

    await expect(
      asUser.mutation(api.taskers.createTaskerProfile, {
        displayName: "Tasker",
        categoryId,
        categoryBio: "I clean well",
        rateType: "hourly",
        hourlyRate: 5000,
        serviceRadius: 300,
      })
    ).rejects.toThrow("Service radius must be between 1 and 250 km");
  });

  test("sendProposal rejects negative rate", async () => {
    const t = convexTest(schema, modules);
    const asSeeker = t.withIdentity(seekerAuth);
    const asTasker = t.withIdentity(taskerAuth);

    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker",
      city: "Toronto",
      province: "ON",
    });

    await asTasker.mutation(api.users.createProfile, {
      name: "Tasker",
      city: "Toronto",
      province: "ON",
    });

    await t.run(async (ctx) => {
      await ctx.db.insert("categories", {
        name: "Cleaning",
        slug: "cleaning",
        isActive: true,
      });
    });

    const categories = await asSeeker.query(api.categories.listCategories);
    const categoryId = categories[0]._id;

    await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Test Tasker",
      categoryId,
      categoryBio: "I clean well",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 25,
    });

    const taskerUser = await asTasker.query(api.users.getCurrentUser);
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId: taskerUser!._id,
    });

    await expect(
      asTasker.mutation(api.proposals.sendProposal, {
        conversationId,
        rate: -100,
        rateType: "hourly",
        startDateTime: "2026-03-01T10:00:00",
      })
    ).rejects.toThrow("Rate must be between 1 and 1,000,000");
  });
});

describe("Security: Authorization", () => {
  test("sendProposal rejects non-participant", async () => {
    const t = convexTest(schema, modules);
    const asSeeker = t.withIdentity(seekerAuth);
    const asTasker = t.withIdentity(taskerAuth);
    const asOutsider = t.withIdentity(outsiderAuth);

    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker",
      city: "Toronto",
      province: "ON",
    });

    await asTasker.mutation(api.users.createProfile, {
      name: "Tasker",
      city: "Toronto",
      province: "ON",
    });

    await asOutsider.mutation(api.users.createProfile, {
      name: "Outsider",
      city: "Toronto",
      province: "ON",
    });

    await t.run(async (ctx) => {
      await ctx.db.insert("categories", {
        name: "Cleaning",
        slug: "cleaning",
        isActive: true,
      });
    });

    const categories = await asSeeker.query(api.categories.listCategories);
    const categoryId = categories[0]._id;

    await asTasker.mutation(api.taskers.createTaskerProfile, {
      displayName: "Test Tasker",
      categoryId,
      categoryBio: "I clean well",
      rateType: "hourly",
      hourlyRate: 5000,
      serviceRadius: 25,
    });

    const taskerUser = await asTasker.query(api.users.getCurrentUser);
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId: taskerUser!._id,
    });

    // Outsider should NOT be able to send proposal in this conversation
    await expect(
      asOutsider.mutation(api.proposals.sendProposal, {
        conversationId,
        rate: 5000,
        rateType: "hourly",
        startDateTime: "2026-03-01T10:00:00",
      })
    ).rejects.toThrow("Not a participant in this conversation");
  });
});

describe("Security: Server-side Data Resolution", () => {
  test("createJobRequest resolves category name from server", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity(seekerAuth);

    await asUser.mutation(api.users.createProfile, {
      name: "Seeker",
      city: "Toronto",
      province: "ON",
    });

    await t.run(async (ctx) => {
      await ctx.db.insert("categories", {
        name: "Cleaning",
        slug: "cleaning",
        isActive: true,
      });
    });

    const categories = await asUser.query(api.categories.listCategories);
    const categoryId = categories[0]._id;

    // Pass a WRONG categoryName -- server should override it
    const jobRequestId = await asUser.mutation(api.jobRequests.createJobRequest, {
      categoryId,
      categoryName: "INJECTED SCAM TEXT",
      description: "I need my house cleaned",
      location: {
        address: "123 Main St",
        city: "Toronto",
        province: "ON",
        searchRadius: 25,
      },
      timing: {
        type: "asap",
      },
    });

    // Verify the stored categoryName is the real one, not the injected one
    const jobRequests = await asUser.query(api.jobRequests.listMyJobRequests, {});
    const created = jobRequests!.find((jr: any) => jr._id === jobRequestId);
    expect(created).toBeDefined();
    expect(created!.categoryName).toBe("Cleaning");
    expect(created!.categoryName).not.toBe("INJECTED SCAM TEXT");
  });

  test("createJobRequest rejects budget where min > max", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity(seekerAuth);

    await asUser.mutation(api.users.createProfile, {
      name: "Seeker",
      city: "Toronto",
      province: "ON",
    });

    await t.run(async (ctx) => {
      await ctx.db.insert("categories", {
        name: "Cleaning",
        slug: "cleaning",
        isActive: true,
      });
    });

    const categories = await asUser.query(api.categories.listCategories);
    const categoryId = categories[0]._id;

    await expect(
      asUser.mutation(api.jobRequests.createJobRequest, {
        categoryId,
        categoryName: "Cleaning",
        description: "I need my house cleaned",
        location: {
          address: "123 Main St",
          city: "Toronto",
          province: "ON",
          searchRadius: 25,
        },
        timing: { type: "asap" },
        budget: { min: 10000, max: 5000 },
      })
    ).rejects.toThrow("Budget minimum cannot exceed maximum");
  });
});

describe("Security: File Upload Validation", () => {
  test("generateUploadUrl rejects non-image content type", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity(seekerAuth);

    await expect(
      asUser.mutation(api.files.generateUploadUrl, {
        contentType: "application/javascript",
        fileSize: 1024,
      })
    ).rejects.toThrow('File type "application/javascript" is not allowed');
  });

  test("generateUploadUrl rejects HTML files", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity(seekerAuth);

    await expect(
      asUser.mutation(api.files.generateUploadUrl, {
        contentType: "text/html",
        fileSize: 1024,
      })
    ).rejects.toThrow("is not allowed");
  });

  test("generateUploadUrl rejects SVG files", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity(seekerAuth);

    await expect(
      asUser.mutation(api.files.generateUploadUrl, {
        contentType: "image/svg+xml",
        fileSize: 1024,
      })
    ).rejects.toThrow("is not allowed");
  });

  test("generateUploadUrl rejects file exceeding 5MB", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity(seekerAuth);

    await expect(
      asUser.mutation(api.files.generateUploadUrl, {
        contentType: "image/jpeg",
        fileSize: 6 * 1024 * 1024,
      })
    ).rejects.toThrow("File size must be 5 MB or less");
  });

  test("generateUploadUrl rejects zero-size file", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity(seekerAuth);

    await expect(
      asUser.mutation(api.files.generateUploadUrl, {
        contentType: "image/jpeg",
        fileSize: 0,
      })
    ).rejects.toThrow("File size must be greater than 0");
  });

  test("generateUploadUrl accepts valid JPEG under 5MB", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity(seekerAuth);

    const url = await asUser.mutation(api.files.generateUploadUrl, {
      contentType: "image/jpeg",
      fileSize: 1024 * 1024,
    });
    expect(url).toBeDefined();
    expect(typeof url).toBe("string");
  });

  test("generateUploadUrl accepts valid PNG", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity(seekerAuth);

    const url = await asUser.mutation(api.files.generateUploadUrl, {
      contentType: "image/png",
      fileSize: 2 * 1024 * 1024,
    });
    expect(url).toBeDefined();
  });

  test("generateUploadUrl accepts valid WebP", async () => {
    const t = convexTest(schema, modules);
    const asUser = t.withIdentity(seekerAuth);

    const url = await asUser.mutation(api.files.generateUploadUrl, {
      contentType: "image/webp",
      fileSize: 500 * 1024,
    });
    expect(url).toBeDefined();
  });

  test("generateUploadUrl rejects unauthenticated user", async () => {
    const t = convexTest(schema, modules);

    await expect(
      t.mutation(api.files.generateUploadUrl, {
        contentType: "image/jpeg",
        fileSize: 1024,
      })
    ).rejects.toThrow("Not authenticated");
  });
});
