import { convexTest } from "convex-test";
import { expect, test, describe } from "vitest";
import { api } from "../_generated/api";
import schema from "../schema";
import { Doc } from "../_generated/dataModel";
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
  "../_generated/api.ts": async () => ({ default: api }),
  "../schema.ts": async () => ({ default: schema }),
};

describe("jobs", () => {
  test("job created when proposal accepted", async () => {
    const t = convexTest(schema, modules);

    await t.mutation(api.categories.seedCategories);

    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_job1",
      email: "seeker_job1@example.com",
    });

    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker Job 1",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_job1",
      email: "tasker_job1@example.com",
    });

    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Job 1",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation
    const conversationId = await asSeeker.mutation(
      api.conversations.startConversation,
      {
        taskerId,
      }
    );

    // Send proposal from tasker
    const proposalId = await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 5000,
      rateType: "hourly",
      startDateTime: "2026-02-15T10:00:00Z",
      notes: "I can help with this task",
    });

    // Accept proposal as seeker (receiver)
    const result = await asSeeker.mutation(api.proposals.acceptProposal, {
      proposalId,
    });

    expect(result.jobId).toBeDefined();

    // Verify job was created with correct data
    const job = (await t.run(async (ctx) => {
      const j = await ctx.db.get(result.jobId);
      return j;
    })) as Doc<"jobs">;

    expect(job).toBeDefined();
    expect(job.status).toBe("in_progress");
    expect(job.rate).toBe(5000);
    expect(job.rateType).toBe("hourly");
    expect(job.proposalId).toBe(proposalId);
  });

  test("getJob returns job by ID", async () => {
    const t = convexTest(schema, modules);

    await t.mutation(api.categories.seedCategories);

    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_job2",
      email: "seeker_job2@example.com",
    });

    const seekerId = await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker Job 2",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_job2",
      email: "tasker_job2@example.com",
    });

    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Job 2",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation
    const conversationId = await asSeeker.mutation(
      api.conversations.startConversation,
      {
        taskerId,
      }
    );

    // Send and accept proposal
    const proposalId = await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 7500,
      rateType: "flat",
      startDateTime: "2026-02-20T14:00:00Z",
    });

    const result = await asSeeker.mutation(api.proposals.acceptProposal, {
      proposalId,
    });

    // Query job by ID
    const job = await asSeeker.query(api.jobs.getJob, {
      jobId: result.jobId,
    });

    expect(job).toBeDefined();
    expect(job?.status).toBe("in_progress");
    expect(job?.rate).toBe(7500);
    expect(job?.rateType).toBe("flat");
    expect(job?.seekerId).toBe(seekerId);
    expect(job?.taskerId).toBe(taskerId);
  });

  test("listJobs returns jobs for authenticated user as seeker", async () => {
    const t = convexTest(schema, modules);

    await t.mutation(api.categories.seedCategories);

    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_job3",
      email: "seeker_job3@example.com",
    });

    const seekerId = await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker Job 3",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_job3",
      email: "tasker_job3@example.com",
    });

    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Job 3",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation
    const conversationId = await asSeeker.mutation(
      api.conversations.startConversation,
      {
        taskerId,
      }
    );

    // Send and accept proposal
    const proposalId = await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 6000,
      rateType: "hourly",
      startDateTime: "2026-02-18T09:00:00Z",
    });

    const result = await asSeeker.mutation(api.proposals.acceptProposal, {
      proposalId,
    });

    // List jobs as seeker
    const jobs = await asSeeker.query(api.jobs.listJobs, {});

    expect(jobs.length).toBeGreaterThan(0);
    const createdJob = jobs.find((j) => j._id === result.jobId);
    expect(createdJob).toBeDefined();
    expect(createdJob?.seekerId).toBe(seekerId);
  });

  test("listJobs returns jobs for authenticated user as tasker", async () => {
    const t = convexTest(schema, modules);

    await t.mutation(api.categories.seedCategories);

    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_job4",
      email: "seeker_job4@example.com",
    });

    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker Job 4",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_job4",
      email: "tasker_job4@example.com",
    });

    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Job 4",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation
    const conversationId = await asSeeker.mutation(
      api.conversations.startConversation,
      {
        taskerId,
      }
    );

    // Send and accept proposal
    const proposalId = await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 8000,
      rateType: "hourly",
      startDateTime: "2026-02-22T11:00:00Z",
    });

    const result = await asSeeker.mutation(api.proposals.acceptProposal, {
      proposalId,
    });

    // List jobs as tasker
    const jobs = await asTasker.query(api.jobs.listJobs, {});

    expect(jobs.length).toBeGreaterThan(0);
    const createdJob = jobs.find((j) => j._id === result.jobId);
    expect(createdJob).toBeDefined();
    expect(createdJob?.taskerId).toBe(taskerId);
  });

  test("listJobs filters by status when provided", async () => {
    const t = convexTest(schema, modules);

    await t.mutation(api.categories.seedCategories);

    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_job5",
      email: "seeker_job5@example.com",
    });

    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker Job 5",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_job5",
      email: "tasker_job5@example.com",
    });

    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Job 5",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation
    const conversationId = await asSeeker.mutation(
      api.conversations.startConversation,
      {
        taskerId,
      }
    );

    // Send and accept proposal
    const proposalId = await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 4500,
      rateType: "flat",
      startDateTime: "2026-02-25T15:00:00Z",
    });

    const result = await asSeeker.mutation(api.proposals.acceptProposal, {
      proposalId,
    });

    // List jobs with in_progress status filter
    const inProgressJobs = await asSeeker.query(api.jobs.listJobs, {
      status: "in_progress",
    });

    expect(inProgressJobs.length).toBeGreaterThan(0);
    const createdJob = inProgressJobs.find((j) => j._id === result.jobId);
    expect(createdJob).toBeDefined();
    expect(createdJob?.status).toBe("in_progress");

    // List jobs with completed status filter (should not include our job)
    const completedJobs = await asSeeker.query(api.jobs.listJobs, {
      status: "completed",
    });

    const shouldNotExist = completedJobs.find((j) => j._id === result.jobId);
    expect(shouldNotExist).toBeUndefined();
  });

  test("seeker can complete in_progress job", async () => {
    const t = convexTest(schema, modules);

    await t.mutation(api.categories.seedCategories);

    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_complete1",
      email: "seeker_complete1@example.com",
    });

    const seekerId = await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker Complete 1",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_complete1",
      email: "tasker_complete1@example.com",
    });

    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Complete 1",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation, send proposal, accept
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

    // Complete job as seeker
    const result = await asSeeker.mutation(api.jobs.completeJob, { jobId });

    expect(result.jobId).toBe(jobId);

    // Verify job status changed
    const job = await asSeeker.query(api.jobs.getJob, { jobId });
    expect(job?.status).toBe("completed");
    expect(job?.completedDate).toBeDefined();
    expect(typeof job?.completedDate).toBe("string");
  });

  test("tasker cannot complete job (unauthorized)", async () => {
    const t = convexTest(schema, modules);

    await t.mutation(api.categories.seedCategories);

    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_complete2",
      email: "seeker_complete2@example.com",
    });

    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker Complete 2",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_complete2",
      email: "tasker_complete2@example.com",
    });

    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Complete 2",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation, send proposal, accept
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

    // Try to complete job as tasker (should fail)
    await expect(
      asTasker.mutation(api.jobs.completeJob, { jobId })
    ).rejects.toThrow("Only seeker can complete job");
  });

  test("cannot complete pending job", async () => {
    const t = convexTest(schema, modules);

    await t.mutation(api.categories.seedCategories);

    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_complete3",
      email: "seeker_complete3@example.com",
    });

    const seekerId = await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker Complete 3",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_complete3",
      email: "tasker_complete3@example.com",
    });

    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Complete 3",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation, send proposal, accept
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

    // Manually patch job to pending status (to test validation)
    await t.run(async (ctx) => {
      await ctx.db.patch(jobId, { status: "pending" });
    });

    // Try to complete pending job (should fail)
    await expect(
      asSeeker.mutation(api.jobs.completeJob, { jobId })
    ).rejects.toThrow("Job must be in_progress to complete");
  });

  test("cannot complete already completed job", async () => {
    const t = convexTest(schema, modules);

    await t.mutation(api.categories.seedCategories);

    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_complete4",
      email: "seeker_complete4@example.com",
    });

    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker Complete 4",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_complete4",
      email: "tasker_complete4@example.com",
    });

    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Complete 4",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation, send proposal, accept
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

    // Complete job first time (should succeed)
    await asSeeker.mutation(api.jobs.completeJob, { jobId });

    // Try to complete again (should fail)
    await expect(
      asSeeker.mutation(api.jobs.completeJob, { jobId })
    ).rejects.toThrow("Job must be in_progress to complete");
  });

  test("completeJob sets completedDate", async () => {
    const t = convexTest(schema, modules);

    await t.mutation(api.categories.seedCategories);

    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker_complete5",
      email: "seeker_complete5@example.com",
    });

    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker Complete 5",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker_complete5",
      email: "tasker_complete5@example.com",
    });

    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker Complete 5",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation, send proposal, accept
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

    const beforeComplete = new Date().toISOString();

    // Complete job
    await asSeeker.mutation(api.jobs.completeJob, { jobId });

    const afterComplete = new Date().toISOString();

    // Verify completedDate is set and in correct range
    const job = await asSeeker.query(api.jobs.getJob, { jobId });
    expect(job?.completedDate).toBeDefined();
    expect(typeof job?.completedDate).toBe("string");
    if (job?.completedDate) {
      expect(job.completedDate >= beforeComplete).toBe(true);
      expect(job.completedDate <= afterComplete).toBe(true);
    }
  });
});
