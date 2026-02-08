// convex/files.ts
import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

const ALLOWED_IMAGE_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
  "image/heic",
  "image/heif",
];

const MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB

export const generateUploadUrl = mutation({
  args: {
    contentType: v.string(),
    fileSize: v.number(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    // Validate file type
    if (!ALLOWED_IMAGE_TYPES.includes(args.contentType)) {
      throw new Error(
        `File type "${args.contentType}" is not allowed. Accepted types: JPEG, PNG, WebP, GIF, HEIC`
      );
    }

    // Validate file size
    if (args.fileSize <= 0) {
      throw new Error("File size must be greater than 0");
    }
    if (args.fileSize > MAX_FILE_SIZE_BYTES) {
      throw new Error("File size must be 5 MB or less");
    }

    return await ctx.storage.generateUploadUrl();
  },
});

export const getUrl = query({
  args: { storageId: v.id("_storage") },
  handler: async (ctx, { storageId }) => {
    return await ctx.storage.getUrl(storageId);
  },
});
