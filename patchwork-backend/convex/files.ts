import { mutation, query } from "./_generated/server";
import { ConvexError, v } from "convex/values";
import {
  imageAssetContentTypeValidator,
  imageAssetPurposeValidator,
  imageAssetValidator,
} from "../lib/convex/validators";
import {
  assertImageContentType,
  assertRequiredAndUniqueVariantKinds,
  assertVariantShape,
  assertVariantStorageMetadataMatches,
  IMAGE_UPLOAD_CONSTRAINTS,
  toImageAssetDto,
  toVariantRecord,
} from "./imageAssetHelpers";
import { getAppUserOrNull, requireAppUser } from "./authHelpers";

const ALLOWED_IMAGE_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
  "image/heic",
  "image/heif",
];

const MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB

const imageAssetVariantKindValidator = v.union(
  v.literal("thumb"),
  v.literal("display"),
  v.literal("large")
);

const imageAssetVariantDescriptorValidator = v.object({
  kind: imageAssetVariantKindValidator,
  contentType: imageAssetContentTypeValidator,
  width: v.number(),
  height: v.number(),
  byteSize: v.number(),
});

const imageAssetCommittedVariantDescriptorValidator = v.object({
  kind: imageAssetVariantKindValidator,
  storageId: v.id("_storage"),
  contentType: imageAssetContentTypeValidator,
  width: v.number(),
  height: v.number(),
  byteSize: v.number(),
});

const imageUploadConstraintsValidator = v.object({
  allowedContentTypes: v.array(imageAssetContentTypeValidator),
  requiredVariants: v.array(imageAssetVariantKindValidator),
  variants: v.object({
    thumb: v.object({
      maxLongEdge: v.number(),
      maxByteSize: v.number(),
    }),
    display: v.object({
      maxLongEdge: v.number(),
      maxByteSize: v.number(),
    }),
    large: v.object({
      maxLongEdge: v.number(),
      maxByteSize: v.number(),
    }),
  }),
});

export const generateUploadUrl = mutation({
  args: {
    contentType: v.string(),
    fileSize: v.number(),
  },
  returns: v.string(),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("Not authenticated");

    // Validate file type
    if (!ALLOWED_IMAGE_TYPES.includes(args.contentType)) {
      throw new ConvexError(
        `File type "${args.contentType}" is not allowed. Accepted types: JPEG, PNG, WebP, GIF, HEIC`
      );
    }

    // Validate file size
    if (args.fileSize <= 0) {
      throw new ConvexError("File size must be greater than 0");
    }
    if (args.fileSize > MAX_FILE_SIZE_BYTES) {
      throw new ConvexError("File size must be 5 MB or less");
    }

    return await ctx.storage.generateUploadUrl();
  },
});

export const generateImageAssetUploadUrls = mutation({
  args: {
    purpose: imageAssetPurposeValidator,
    variants: v.array(imageAssetVariantDescriptorValidator),
  },
  returns: v.object({
    purpose: imageAssetPurposeValidator,
    uploadUrls: v.array(
      v.object({
        kind: imageAssetVariantKindValidator,
        uploadUrl: v.string(),
        contentType: imageAssetContentTypeValidator,
        width: v.number(),
        height: v.number(),
        byteSize: v.number(),
      })
    ),
    constraints: imageUploadConstraintsValidator,
  }),
  handler: async (ctx, args) => {
    await requireAppUser(ctx);

    assertRequiredAndUniqueVariantKinds(args.variants);
    for (const variant of args.variants) {
      assertVariantShape(variant);
    }

    const uploadUrls = await Promise.all(
      args.variants.map(async (variant) => {
        const uploadUrl = await ctx.storage.generateUploadUrl();
        return {
          kind: variant.kind,
          uploadUrl,
          contentType: variant.contentType,
          width: variant.width,
          height: variant.height,
          byteSize: variant.byteSize,
        };
      })
    );

    return {
      purpose: args.purpose,
      uploadUrls,
      constraints: IMAGE_UPLOAD_CONSTRAINTS,
    };
  },
});

export const commitImageAsset = mutation({
  args: {
    purpose: imageAssetPurposeValidator,
    sourceContentType: imageAssetContentTypeValidator,
    variants: v.array(imageAssetCommittedVariantDescriptorValidator),
  },
  returns: imageAssetValidator,
  handler: async (ctx, args) => {
    const { user } = await requireAppUser(ctx);

    assertImageContentType(args.sourceContentType);
    assertRequiredAndUniqueVariantKinds(args.variants);

    for (const variant of args.variants) {
      assertVariantShape(variant);
      await assertVariantStorageMetadataMatches(ctx, variant);
    }

    const now = Date.now();
    const imageAssetId = await ctx.db.insert("imageAssets", {
      ownerUserId: user._id,
      purpose: args.purpose,
      status: "active",
      sourceContentType: args.sourceContentType,
      variants: toVariantRecord(args.variants),
      createdAt: now,
      updatedAt: now,
    });

    const imageAsset = await ctx.db.get(imageAssetId);
    if (!imageAsset) {
      throw new ConvexError("Failed to create image asset");
    }

    return await toImageAssetDto(ctx, imageAsset, true);
  },
});

export const getImageAsset = query({
  args: {
    imageAssetId: v.id("imageAssets"),
  },
  returns: v.union(imageAssetValidator, v.null()),
  handler: async (ctx, args) => {
    const session = await getAppUserOrNull(ctx);
    if (!session) return null;

    const imageAsset = await ctx.db.get(args.imageAssetId);
    if (!imageAsset || imageAsset.ownerUserId !== session.user._id) {
      return null;
    }

    const includeUrls = imageAsset.status === "active";
    return await toImageAssetDto(ctx, imageAsset, includeUrls);
  },
});

export const deleteImageAsset = mutation({
  args: {
    imageAssetId: v.id("imageAssets"),
  },
  returns: v.union(imageAssetValidator, v.null()),
  handler: async (ctx, args) => {
    const { user } = await requireAppUser(ctx);

    const imageAsset = await ctx.db.get(args.imageAssetId);
    if (!imageAsset || imageAsset.ownerUserId !== user._id) {
      return null;
    }

    if (imageAsset.status !== "deleted") {
      await ctx.db.patch(imageAsset._id, {
        status: "deleted",
        updatedAt: Date.now(),
      });
    }

    const updatedImageAsset = await ctx.db.get(imageAsset._id);
    if (!updatedImageAsset) {
      return null;
    }

    return await toImageAssetDto(ctx, updatedImageAsset, false);
  },
});

export const getUrl = query({
  args: { storageId: v.id("_storage") },
  returns: v.union(v.string(), v.null()),
  handler: async (ctx, { storageId }) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new ConvexError("Not authenticated");
    }

    return await ctx.storage.getUrl(storageId);
  },
});
