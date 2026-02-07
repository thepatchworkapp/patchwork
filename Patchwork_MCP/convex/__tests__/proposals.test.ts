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

describe("proposals", () => {
  test("unauthenticated user cannot send proposal", async () => {
    const t = convexTest(schema, modules);
    
    // Create seeker and tasker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker1",
      email: "seeker1@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 1",
      city: "Toronto",
      province: "ON",
    });

    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker1",
      email: "tasker1@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 1",
      city: "Toronto",
      province: "ON",
    });

    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    // Try to send proposal without auth
    await expect(
      t.mutation(api.proposals.sendProposal, {
        conversationId,
        rate: 5000,
        rateType: "hourly",
        startDateTime: "2026-02-15T10:00:00Z",
      })
    ).rejects.toThrow("Unauthorized");
  });

  test("can send proposal in conversation", async () => {
    const t = convexTest(schema, modules);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker2",
      email: "seeker2@example.com",
    });
    
    const seekerId = await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 2",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker2",
      email: "tasker2@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 2",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    // Send proposal from tasker
    const proposalId = await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 5000,
      rateType: "hourly",
      startDateTime: "2026-02-15T10:00:00Z",
      notes: "I can help with this",
    });

    expect(proposalId).toBeDefined();

    // Verify proposal was created
    const proposal = (await t.run(async (ctx) => {
      const p = await ctx.db.get(proposalId);
      return p;
    })) as Doc<"proposals">;
    expect(proposal).toBeDefined();
    expect(proposal.status).toBe("pending");
    expect(proposal.rate).toBe(5000);
    expect(proposal.rateType).toBe("hourly");
    expect(proposal.senderId).toBe(taskerId);
    expect(proposal.receiverId).toBe(seekerId);
  });

  test("sending proposal creates proposal_sent system message", async () => {
    const t = convexTest(schema, modules);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker3",
      email: "seeker3@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 3",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker3",
      email: "tasker3@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 3",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    // Send proposal
    await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 5000,
      rateType: "flat",
      startDateTime: "2026-02-15T10:00:00Z",
    });

    // Check for system message
    const messages = await asSeeker.query(api.messages.listMessages, {
      conversationId,
    });
    
    const systemMessage = messages.page.find((m) => m.type === "system");
    expect(systemMessage).toBeDefined();
    expect(systemMessage?.content).toContain("proposal");
  });

  test("receiver can accept proposal", async () => {
    const t = convexTest(schema, modules);
    
    await t.mutation(api.categories.seedCategories);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker4",
      email: "seeker4@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 4",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker4",
      email: "tasker4@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 4",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    // Send proposal from tasker
    const proposalId = await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 5000,
      rateType: "hourly",
      startDateTime: "2026-02-15T10:00:00Z",
    });

    // Accept proposal as seeker (receiver)
    const result = await asSeeker.mutation(api.proposals.acceptProposal, {
      proposalId,
    });

    expect(result.jobId).toBeDefined();

    // Verify proposal status
    const proposal = (await t.run(async (ctx) => {
      const p = await ctx.db.get(proposalId);
      return p;
    })) as Doc<"proposals">;
    expect(proposal.status).toBe("accepted");
  });

  test("sender cannot accept their own proposal", async () => {
    const t = convexTest(schema, modules);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker5",
      email: "seeker5@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 5",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker5",
      email: "tasker5@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 5",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    // Send proposal from tasker
    const proposalId = await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 5000,
      rateType: "hourly",
      startDateTime: "2026-02-15T10:00:00Z",
    });

    // Try to accept as sender (should fail)
    await expect(
      asTasker.mutation(api.proposals.acceptProposal, {
        proposalId,
      })
    ).rejects.toThrow("Only the proposal receiver can accept");
  });

  test("acceptProposal creates proposal_accepted system message", async () => {
    const t = convexTest(schema, modules);
    
    await t.mutation(api.categories.seedCategories);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker6",
      email: "seeker6@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 6",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker6",
      email: "tasker6@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 6",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    // Send proposal
    const proposalId = await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 5000,
      rateType: "flat",
      startDateTime: "2026-02-15T10:00:00Z",
    });

    // Accept proposal
    await asSeeker.mutation(api.proposals.acceptProposal, {
      proposalId,
    });

    // Check for system message
    const messages = await asSeeker.query(api.messages.listMessages, {
      conversationId,
    });
    
    const acceptMessage = messages.page.find((m) => 
      m.type === "system" && m.content.includes("accepted")
    );
    expect(acceptMessage).toBeDefined();
  });

  test("receiver can decline proposal", async () => {
    const t = convexTest(schema, modules);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker7",
      email: "seeker7@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 7",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker7",
      email: "tasker7@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 7",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    // Send proposal from tasker
    const proposalId = await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 5000,
      rateType: "hourly",
      startDateTime: "2026-02-15T10:00:00Z",
    });

    // Decline proposal as seeker (receiver)
    await asSeeker.mutation(api.proposals.declineProposal, {
      proposalId,
    });

    // Verify proposal status
    const proposal = (await t.run(async (ctx) => {
      const p = await ctx.db.get(proposalId);
      return p;
    })) as Doc<"proposals">;
    expect(proposal.status).toBe("declined");
  });

  test("declineProposal creates proposal_declined system message", async () => {
    const t = convexTest(schema, modules);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker8",
      email: "seeker8@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 8",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker8",
      email: "tasker8@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 8",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    // Send proposal
    const proposalId = await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 5000,
      rateType: "flat",
      startDateTime: "2026-02-15T10:00:00Z",
    });

    // Decline proposal
    await asSeeker.mutation(api.proposals.declineProposal, {
      proposalId,
    });

    // Check for system message
    const messages = await asSeeker.query(api.messages.listMessages, {
      conversationId,
    });
    
    const declineMessage = messages.page.find((m) => 
      m.type === "system" && m.content.includes("declined")
    );
    expect(declineMessage).toBeDefined();
  });

  test("receiver can counter proposal", async () => {
    const t = convexTest(schema, modules);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker9",
      email: "seeker9@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 9",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker9",
      email: "tasker9@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 9",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    // Send proposal from tasker
    const proposalId = await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 5000,
      rateType: "hourly",
      startDateTime: "2026-02-15T10:00:00Z",
    });

    // Counter proposal as seeker
    const counterProposalId = await asSeeker.mutation(api.proposals.counterProposal, {
      proposalId,
      rate: 4000,
      rateType: "hourly",
      startDateTime: "2026-02-15T10:00:00Z",
      notes: "Can we do $40/hour?",
    });

    expect(counterProposalId).toBeDefined();

    // Verify original proposal status
    const originalProposal = (await t.run(async (ctx) => {
      const p = await ctx.db.get(proposalId);
      return p;
    })) as Doc<"proposals">;
    expect(originalProposal.status).toBe("countered");
    expect(originalProposal.counterProposalId).toBe(counterProposalId);

    // Verify counter proposal
    const counterProposal = (await t.run(async (ctx) => {
      const p = await ctx.db.get(counterProposalId);
      return p;
    })) as Doc<"proposals">;
    expect(counterProposal.status).toBe("pending");
    expect(counterProposal.rate).toBe(4000);
    expect(counterProposal.previousProposalId).toBe(proposalId);
  });

  test("counterProposal creates proposal_countered system message", async () => {
    const t = convexTest(schema, modules);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker10",
      email: "seeker10@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 10",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker10",
      email: "tasker10@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 10",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    // Send proposal
    const proposalId = await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 5000,
      rateType: "flat",
      startDateTime: "2026-02-15T10:00:00Z",
    });

    // Counter proposal
    await asSeeker.mutation(api.proposals.counterProposal, {
      proposalId,
      rate: 4000,
      rateType: "flat",
      startDateTime: "2026-02-15T10:00:00Z",
    });

    // Check for system message
    const messages = await asSeeker.query(api.messages.listMessages, {
      conversationId,
    });
    
    const counterMessage = messages.page.find((m) => 
      m.type === "system" && m.content.includes("counter")
    );
    expect(counterMessage).toBeDefined();
  });

  test("cannot accept already-declined proposal", async () => {
    const t = convexTest(schema, modules);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker11",
      email: "seeker11@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 11",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker11",
      email: "tasker11@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 11",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    // Send proposal from tasker
    const proposalId = await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 5000,
      rateType: "hourly",
      startDateTime: "2026-02-15T10:00:00Z",
    });

    // Decline proposal
    await asSeeker.mutation(api.proposals.declineProposal, {
      proposalId,
    });

    // Try to accept (should fail)
    await expect(
      asSeeker.mutation(api.proposals.acceptProposal, {
        proposalId,
      })
    ).rejects.toThrow("Proposal is not in pending status");
  });

  test("job created when proposal accepted", async () => {
    const t = convexTest(schema, modules);
    
    await t.mutation(api.categories.seedCategories);
    
    // Create seeker
    const asSeeker = t.withIdentity({
      tokenIdentifier: "google|seeker12",
      email: "seeker12@example.com",
    });
    
    await asSeeker.mutation(api.users.createProfile, {
      name: "Seeker 12",
      city: "Toronto",
      province: "ON",
    });

    // Create tasker
    const asTasker = t.withIdentity({
      tokenIdentifier: "google|tasker12",
      email: "tasker12@example.com",
    });
    
    const taskerId = await asTasker.mutation(api.users.createProfile, {
      name: "Tasker 12",
      city: "Toronto",
      province: "ON",
    });

    // Start conversation
    const conversationId = await asSeeker.mutation(api.conversations.startConversation, {
      taskerId,
    });

    // Send proposal from tasker
    const proposalId = await asTasker.mutation(api.proposals.sendProposal, {
      conversationId,
      rate: 5000,
      rateType: "hourly",
      startDateTime: "2026-02-15T10:00:00Z",
    });

    // Accept proposal
    const result = await asSeeker.mutation(api.proposals.acceptProposal, {
      proposalId,
    });

    // Verify job was created
    expect(result.jobId).toBeDefined();
    const job = (await t.run(async (ctx) => {
      const j = await ctx.db.get(result.jobId);
      return j;
    })) as Doc<"jobs">;
    expect(job).toBeDefined();
    expect(job.proposalId).toBe(proposalId);
    expect(job.rate).toBe(5000);
  });
});
