import { v } from "convex/values";
import { internalMutation } from "./_generated/server";

export const createJob = internalMutation({
  args: { proposalId: v.id("proposals") },
  handler: async (ctx, args) => {
    const proposal = await ctx.db.get(args.proposalId);
    if (!proposal) throw new Error("Proposal not found");

    const conversation = await ctx.db.get(proposal.conversationId);
    if (!conversation) throw new Error("Conversation not found");

    const category = await ctx.db.query("categories").first();
    if (!category) throw new Error("No categories available");

    const jobId = await ctx.db.insert("jobs", {
      seekerId: proposal.receiverId,
      taskerId: proposal.senderId,
      proposalId: args.proposalId,
      categoryId: category._id,
      categoryName: category.name,
      description: proposal.notes || "Job from proposal",
      rate: proposal.rate,
      rateType: proposal.rateType,
      startDate: proposal.startDateTime,
      status: "pending",
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await ctx.db.patch(conversation._id, {
      jobId,
      updatedAt: Date.now(),
    });

    return jobId;
  },
});
