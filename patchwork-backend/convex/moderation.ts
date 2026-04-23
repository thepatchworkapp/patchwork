import { ConvexError, v } from "convex/values";
import { mutation, query } from "./_generated/server";
import { getAppUserOrNull, requireAppUser } from "./authHelpers";
import { getUserPhotoImageAssetDto } from "./imageAssetHelpers";

const REPORT_MIN_LENGTH = 100;
const REPORT_MAX_LENGTH = 4000;

const blockStatusValidator = v.object({
  otherUserId: v.id("users"),
  currentUserBlockedOther: v.boolean(),
  currentUserBlockedByOther: v.boolean(),
  isBlocked: v.boolean(),
  blockId: v.union(v.id("userBlocks"), v.null()),
});

const blockedUserValidator = v.object({
  blockId: v.id("userBlocks"),
  blockedUserId: v.id("users"),
  name: v.string(),
  email: v.union(v.string(), v.null()),
  photoUrl: v.union(v.string(), v.null()),
  photoImage: v.union(v.any(), v.null()),
  conversationId: v.union(v.id("conversations"), v.null()),
  createdAt: v.number(),
});

const reportResultValidator = v.object({
  reportId: v.id("userReports"),
  blockId: v.union(v.id("userBlocks"), v.null()),
});

export async function getUserBlock(ctx: any, blockerId: any, blockedId: any) {
  return await ctx.db
    .query("userBlocks")
    .withIndex("by_blocker_blocked", (q: any) =>
      q.eq("blockerId", blockerId).eq("blockedId", blockedId)
    )
    .unique();
}

async function getBlockStatusForUsers(ctx: any, currentUserId: any, otherUserId: any) {
  const [currentUserBlock, otherUserBlock] = await Promise.all([
    getUserBlock(ctx, currentUserId, otherUserId),
    getUserBlock(ctx, otherUserId, currentUserId),
  ]);

  return {
    otherUserId,
    currentUserBlockedOther: !!currentUserBlock,
    currentUserBlockedByOther: !!otherUserBlock,
    isBlocked: !!currentUserBlock || !!otherUserBlock,
    blockId: currentUserBlock?._id ?? null,
  };
}

export async function assertUsersCanMessage(ctx: any, senderId: any, recipientId: any) {
  const [senderBlock, recipientBlock] = await Promise.all([
    getUserBlock(ctx, senderId, recipientId),
    getUserBlock(ctx, recipientId, senderId),
  ]);

  if (senderBlock || recipientBlock) {
    throw new ConvexError("This conversation is unavailable.");
  }
}

async function getOtherConversationUserId(ctx: any, conversationId: any, currentUserId: any) {
  const conversation = await ctx.db.get(conversationId);
  if (!conversation) throw new ConvexError("Conversation not found");

  if (conversation.seekerId === currentUserId) {
    return { conversation, otherUserId: conversation.taskerId };
  }
  if (conversation.taskerId === currentUserId) {
    return { conversation, otherUserId: conversation.seekerId };
  }

  throw new ConvexError("Not a participant in this conversation");
}

async function validateConversationTarget(ctx: any, conversationId: any | undefined, currentUserId: any, otherUserId: any) {
  if (!conversationId) return;

  const { otherUserId: conversationOtherUserId } = await getOtherConversationUserId(ctx, conversationId, currentUserId);
  if (conversationOtherUserId !== otherUserId) {
    throw new ConvexError("User is not the other participant in this conversation");
  }
}

async function createBlockIfNeeded(ctx: any, blockerId: any, blockedId: any, conversationId?: any) {
  const existing = await getUserBlock(ctx, blockerId, blockedId);
  if (existing) return existing._id;

  const now = Date.now();
  return await ctx.db.insert("userBlocks", {
    blockerId,
    blockedId,
    conversationId,
    createdAt: now,
    updatedAt: now,
  });
}

export const getBlockStatus = query({
  args: {
    otherUserId: v.id("users"),
  },
  returns: v.union(blockStatusValidator, v.null()),
  handler: async (ctx, args) => {
    const session = await getAppUserOrNull(ctx);
    if (!session) return null;

    return await getBlockStatusForUsers(ctx, session.user._id, args.otherUserId);
  },
});

export const getConversationSafetyStatus = query({
  args: {
    conversationId: v.id("conversations"),
  },
  returns: v.union(blockStatusValidator, v.null()),
  handler: async (ctx, args) => {
    const session = await getAppUserOrNull(ctx);
    if (!session) return null;

    const { otherUserId } = await getOtherConversationUserId(ctx, args.conversationId, session.user._id);
    return await getBlockStatusForUsers(ctx, session.user._id, otherUserId);
  },
});

export const listBlockedUsers = query({
  args: {
    limit: v.optional(v.number()),
  },
  returns: v.array(blockedUserValidator),
  handler: async (ctx, args) => {
    const session = await getAppUserOrNull(ctx);
    if (!session) return [];

    const limit = Math.max(1, Math.min(args.limit ?? 50, 100));
    const blocks = await ctx.db
      .query("userBlocks")
      .withIndex("by_blocker_createdAt", (q) => q.eq("blockerId", session.user._id))
      .order("desc")
      .take(limit);

    const rows = await Promise.all(
      blocks.map(async (block) => {
        const blockedUser = await ctx.db.get(block.blockedId);
        if (!blockedUser) return null;
        return {
          blockId: block._id,
          blockedUserId: blockedUser._id,
          name: blockedUser.name,
          email: blockedUser.email ?? null,
          photoUrl: blockedUser.photo ? await ctx.storage.getUrl(blockedUser.photo) : null,
          photoImage: await getUserPhotoImageAssetDto(ctx, blockedUser, true),
          conversationId: block.conversationId ?? null,
          createdAt: block.createdAt,
        };
      })
    );

    return rows.filter((row): row is NonNullable<typeof row> => row !== null);
  },
});

export const blockUser = mutation({
  args: {
    blockedUserId: v.id("users"),
    conversationId: v.optional(v.id("conversations")),
  },
  returns: blockStatusValidator,
  handler: async (ctx, args) => {
    const { user } = await requireAppUser(ctx);
    if (user._id === args.blockedUserId) {
      throw new ConvexError("You cannot block yourself");
    }

    const blockedUser = await ctx.db.get(args.blockedUserId);
    if (!blockedUser) throw new ConvexError("User not found");

    await validateConversationTarget(ctx, args.conversationId, user._id, args.blockedUserId);
    await createBlockIfNeeded(ctx, user._id, args.blockedUserId, args.conversationId);

    return await getBlockStatusForUsers(ctx, user._id, args.blockedUserId);
  },
});

export const unblockUser = mutation({
  args: {
    blockedUserId: v.id("users"),
  },
  returns: blockStatusValidator,
  handler: async (ctx, args) => {
    const { user } = await requireAppUser(ctx);
    const existing = await getUserBlock(ctx, user._id, args.blockedUserId);
    if (existing) {
      await ctx.db.delete(existing._id);
    }

    return await getBlockStatusForUsers(ctx, user._id, args.blockedUserId);
  },
});

export const reportUser = mutation({
  args: {
    reportedUserId: v.id("users"),
    conversationId: v.optional(v.id("conversations")),
    reason: v.string(),
    block: v.optional(v.boolean()),
  },
  returns: reportResultValidator,
  handler: async (ctx, args) => {
    const { user } = await requireAppUser(ctx);
    if (user._id === args.reportedUserId) {
      throw new ConvexError("You cannot report yourself");
    }

    const reportedUser = await ctx.db.get(args.reportedUserId);
    if (!reportedUser) throw new ConvexError("User not found");

    await validateConversationTarget(ctx, args.conversationId, user._id, args.reportedUserId);

    const reason = args.reason.trim();
    if (reason.length < REPORT_MIN_LENGTH) {
      throw new ConvexError(`Report must be at least ${REPORT_MIN_LENGTH} characters`);
    }
    if (reason.length > REPORT_MAX_LENGTH) {
      throw new ConvexError(`Report must be ${REPORT_MAX_LENGTH} characters or less`);
    }

    const blockId = args.block
      ? await createBlockIfNeeded(ctx, user._id, args.reportedUserId, args.conversationId)
      : null;
    const now = Date.now();
    const reportId = await ctx.db.insert("userReports", {
      reporterId: user._id,
      reportedUserId: args.reportedUserId,
      conversationId: args.conversationId,
      reason,
      action: args.block ? "block_and_report" : "report",
      status: "open",
      createdAt: now,
      updatedAt: now,
    });

    return { reportId, blockId };
  },
});
