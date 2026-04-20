import { ConvexError } from "convex/values";
import { Doc, Id } from "./_generated/dataModel";
import { MutationCtx, QueryCtx } from "./_generated/server";

export const IMAGE_ASSET_PURPOSES = [
  "userPhoto",
  "taskerPhoto",
  "taskerCategoryPortfolio",
] as const;

export const IMAGE_CONTENT_TYPES = [
  "image/jpeg",
  "image/heic",
  "image/heif",
] as const;

export const IMAGE_VARIANT_KINDS = ["thumb", "display", "large"] as const;
export const REQUIRED_IMAGE_VARIANT_KINDS = ["thumb", "display"] as const;

export type ImageAssetPurpose = (typeof IMAGE_ASSET_PURPOSES)[number];
export type ImageAssetContentType = (typeof IMAGE_CONTENT_TYPES)[number];
export type ImageAssetVariantKind = (typeof IMAGE_VARIANT_KINDS)[number];

export type ImageAssetVariantInput = {
  kind: ImageAssetVariantKind;
  contentType: ImageAssetContentType;
  width: number;
  height: number;
  byteSize: number;
};

export type ImageAssetCommittedVariantInput = ImageAssetVariantInput & {
  storageId: Id<"_storage">;
};

type CtxWithStorageAndDb = Pick<QueryCtx, "db" | "storage"> | Pick<MutationCtx, "db" | "storage">;

export const IMAGE_VARIANT_CONSTRAINTS: Record<
  ImageAssetVariantKind,
  { maxLongEdge: number; maxByteSize: number }
> = {
  thumb: {
    maxLongEdge: 320,
    maxByteSize: 200 * 1024,
  },
  display: {
    maxLongEdge: 1280,
    maxByteSize: Math.floor(1.5 * 1024 * 1024),
  },
  large: {
    maxLongEdge: 2048,
    maxByteSize: 3 * 1024 * 1024,
  },
};

export const IMAGE_UPLOAD_CONSTRAINTS = {
  allowedContentTypes: IMAGE_CONTENT_TYPES,
  requiredVariants: REQUIRED_IMAGE_VARIANT_KINDS,
  variants: {
    thumb: {
      maxLongEdge: IMAGE_VARIANT_CONSTRAINTS.thumb.maxLongEdge,
      maxByteSize: IMAGE_VARIANT_CONSTRAINTS.thumb.maxByteSize,
    },
    display: {
      maxLongEdge: IMAGE_VARIANT_CONSTRAINTS.display.maxLongEdge,
      maxByteSize: IMAGE_VARIANT_CONSTRAINTS.display.maxByteSize,
    },
    large: {
      maxLongEdge: IMAGE_VARIANT_CONSTRAINTS.large.maxLongEdge,
      maxByteSize: IMAGE_VARIANT_CONSTRAINTS.large.maxByteSize,
    },
  },
} as const;

function assertPositiveNumber(fieldName: string, value: number) {
  if (!Number.isFinite(value) || value <= 0) {
    throw new ConvexError(`${fieldName} must be greater than 0`);
  }
}

export function assertImageContentType(contentType: string) {
  if (!IMAGE_CONTENT_TYPES.includes(contentType as ImageAssetContentType)) {
    throw new ConvexError(
      `Unsupported image content type \"${contentType}\". Allowed: ${IMAGE_CONTENT_TYPES.join(", ")}`
    );
  }
}

export function assertVariantShape(variant: {
  kind: ImageAssetVariantKind;
  contentType: string;
  width: number;
  height: number;
  byteSize: number;
}) {
  assertImageContentType(variant.contentType);
  assertPositiveNumber(`${variant.kind} width`, variant.width);
  assertPositiveNumber(`${variant.kind} height`, variant.height);
  assertPositiveNumber(`${variant.kind} byteSize`, variant.byteSize);

  const longEdge = Math.max(variant.width, variant.height);
  const { maxLongEdge, maxByteSize } = IMAGE_VARIANT_CONSTRAINTS[variant.kind];

  if (longEdge > maxLongEdge) {
    throw new ConvexError(`${variant.kind} long edge must be ${maxLongEdge}px or less`);
  }

  if (variant.byteSize > maxByteSize) {
    throw new ConvexError(`${variant.kind} byte size must be ${maxByteSize} bytes or less`);
  }
}

export function assertRequiredAndUniqueVariantKinds(variants: Array<{ kind: ImageAssetVariantKind }>) {
  const seenKinds = new Set<ImageAssetVariantKind>();
  for (const variant of variants) {
    if (seenKinds.has(variant.kind)) {
      throw new ConvexError(`Duplicate variant kind: ${variant.kind}`);
    }
    seenKinds.add(variant.kind);
  }

  for (const requiredKind of REQUIRED_IMAGE_VARIANT_KINDS) {
    if (!seenKinds.has(requiredKind)) {
      throw new ConvexError(`Missing required variant kind: ${requiredKind}`);
    }
  }
}

export function toVariantRecord(
  variants: ImageAssetCommittedVariantInput[]
): Doc<"imageAssets">["variants"] {
  assertRequiredAndUniqueVariantKinds(variants);

  const variantRecord: Partial<Doc<"imageAssets">["variants"]> = {};
  for (const variant of variants) {
    assertVariantShape(variant);
    variantRecord[variant.kind] = {
      storageId: variant.storageId,
      contentType: variant.contentType,
      width: variant.width,
      height: variant.height,
      byteSize: variant.byteSize,
    };
  }

  return {
    thumb: variantRecord.thumb!,
    display: variantRecord.display!,
    large: variantRecord.large,
  };
}

export async function assertVariantStorageMetadataMatches(
  ctx: CtxWithStorageAndDb,
  variant: ImageAssetCommittedVariantInput
) {
  const metadata = await (ctx as any).db.system.get("_storage", variant.storageId);
  if (!metadata) {
    throw new ConvexError(`Storage metadata not found for variant: ${variant.kind}`);
  }

  if (metadata.contentType && metadata.contentType !== variant.contentType) {
    throw new ConvexError(
      `Stored content type mismatch for ${variant.kind}: expected ${variant.contentType}, got ${metadata.contentType}`
    );
  }

  if (metadata.size !== variant.byteSize) {
    throw new ConvexError(
      `Stored byte size mismatch for ${variant.kind}: expected ${variant.byteSize}, got ${metadata.size}`
    );
  }
}

export async function getOwnedImageAsset(
  ctx: CtxWithStorageAndDb,
  imageAssetId: Id<"imageAssets">,
  ownerUserId: Id<"users">,
  options?: {
    purpose?: ImageAssetPurpose;
    requireActive?: boolean;
  }
) {
  const imageAsset = await ctx.db.get(imageAssetId);
  if (!imageAsset || imageAsset.ownerUserId !== ownerUserId) {
    throw new ConvexError("Image asset not found");
  }

  if (options?.requireActive && imageAsset.status !== "active") {
    throw new ConvexError("Image asset is not active");
  }

  if (options?.purpose && imageAsset.purpose !== options.purpose) {
    throw new ConvexError(`Image asset purpose must be ${options.purpose}`);
  }

  return imageAsset;
}

export async function getOwnedImageAssets(
  ctx: CtxWithStorageAndDb,
  imageAssetIds: Id<"imageAssets">[],
  ownerUserId: Id<"users">,
  purpose: ImageAssetPurpose
) {
  const assets = await Promise.all(
    imageAssetIds.map((imageAssetId) => getOwnedImageAsset(ctx, imageAssetId, ownerUserId, {
      purpose,
      requireActive: true,
    }))
  );

  return assets;
}

function toImageVariantDto(
  variant: Doc<"imageAssets">["variants"]["thumb"],
  url: string | null
) {
  return {
    storageId: variant.storageId,
    contentType: variant.contentType,
    width: variant.width,
    height: variant.height,
    byteSize: variant.byteSize,
    url,
  };
}

export async function toImageAssetDto(
  ctx: CtxWithStorageAndDb,
  imageAsset: Doc<"imageAssets">,
  includeUrls: boolean
) {
  const thumbUrl = includeUrls ? await ctx.storage.getUrl(imageAsset.variants.thumb.storageId) : null;
  const displayUrl = includeUrls ? await ctx.storage.getUrl(imageAsset.variants.display.storageId) : null;
  const largeUrl = imageAsset.variants.large && includeUrls
    ? await ctx.storage.getUrl(imageAsset.variants.large.storageId)
    : null;

  return {
    _id: imageAsset._id,
    ownerUserId: imageAsset.ownerUserId,
    purpose: imageAsset.purpose,
    status: imageAsset.status,
    sourceContentType: imageAsset.sourceContentType,
    variants: {
      thumb: toImageVariantDto(imageAsset.variants.thumb, thumbUrl),
      display: toImageVariantDto(imageAsset.variants.display, displayUrl),
      large: imageAsset.variants.large
        ? toImageVariantDto(imageAsset.variants.large, largeUrl)
        : undefined,
    },
    createdAt: imageAsset.createdAt,
    updatedAt: imageAsset.updatedAt,
  };
}

export async function getUserPhotoImageAssetDto(
  ctx: CtxWithStorageAndDb,
  user: Doc<"users">,
  includeUrls: boolean
) {
  if (!user.photoAssetId) {
    return null;
  }

  const imageAsset = await ctx.db.get(user.photoAssetId);
  if (
    !imageAsset ||
    imageAsset.ownerUserId !== user._id ||
    imageAsset.status !== "active" ||
    imageAsset.purpose !== "userPhoto"
  ) {
    return null;
  }

  return await toImageAssetDto(ctx, imageAsset, includeUrls);
}

export async function getTaskerProfileImageAssetDto(
  ctx: CtxWithStorageAndDb,
  user: Doc<"users">,
  taskerProfile: Doc<"taskerProfiles">,
  includeUrls: boolean
) {
  const photoSource = taskerProfile.photoSource ?? "user";
  if (photoSource === "custom" && taskerProfile.photoAssetId) {
    const imageAsset = await ctx.db.get(taskerProfile.photoAssetId);
    if (
      imageAsset &&
      imageAsset.ownerUserId === user._id &&
      imageAsset.status === "active" &&
      imageAsset.purpose === "taskerPhoto"
    ) {
      return await toImageAssetDto(ctx, imageAsset, includeUrls);
    }
  }

  return await getUserPhotoImageAssetDto(ctx, user, includeUrls);
}

export async function getTaskerCategoryPortfolioImageDtos(
  ctx: CtxWithStorageAndDb,
  taskerCategory: Doc<"taskerCategories">,
  includeUrls: boolean
) {
  const portfolioAssetIds = taskerCategory.portfolioAssetIds ?? [];
  if (portfolioAssetIds.length === 0) {
    return {
      coverAssetId: undefined,
      coverImage: null,
      portfolioImages: [],
    };
  }

  const portfolioImages: Array<Awaited<ReturnType<typeof toImageAssetDto>>> = [];
  let coverImage: Awaited<ReturnType<typeof toImageAssetDto>> | null = null;
  let coverAssetId: Id<"imageAssets"> | undefined;

  for (const imageAssetId of portfolioAssetIds) {
    const imageAsset = await ctx.db.get(imageAssetId);
    if (
      !imageAsset ||
      imageAsset.ownerUserId !== taskerCategory.userId ||
      imageAsset.status !== "active" ||
      imageAsset.purpose !== "taskerCategoryPortfolio"
    ) {
      continue;
    }

    const dto = await toImageAssetDto(ctx, imageAsset, includeUrls);
    portfolioImages.push(dto);

    if (!coverImage && imageAssetId === taskerCategory.coverAssetId) {
      coverImage = dto;
      coverAssetId = imageAssetId;
    }
  }

  if (!coverImage) {
    coverImage = portfolioImages[0] ?? null;
    coverAssetId = coverImage?._id;
  }

  return {
    coverAssetId,
    coverImage,
    portfolioImages,
  };
}

export function getDisplayStorageId(imageAsset: Doc<"imageAssets">) {
  return imageAsset.variants.display.storageId;
}

export function toCompatibilityPhotos(
  portfolioAssets: Doc<"imageAssets">[],
  coverAssetId?: Id<"imageAssets">,
): Id<"_storage">[] {
  const dedupedAssetIds = new Set<string>();
  const orderedAssets: Doc<"imageAssets">[] = [];

  const coverAsset = coverAssetId
    ? portfolioAssets.find((asset) => asset._id === coverAssetId)
    : undefined;

  if (coverAsset) {
    orderedAssets.push(coverAsset);
    dedupedAssetIds.add(String(coverAsset._id));
  }

  for (const asset of portfolioAssets) {
    if (dedupedAssetIds.has(String(asset._id))) {
      continue;
    }
    orderedAssets.push(asset);
    dedupedAssetIds.add(String(asset._id));
  }

  const dedupedStorageIds = new Set<string>();
  const photos: Id<"_storage">[] = [];

  for (const asset of orderedAssets) {
    const displayStorageId = asset.variants.display.storageId;
    const key = String(displayStorageId);
    if (dedupedStorageIds.has(key)) {
      continue;
    }
    dedupedStorageIds.add(key);
    photos.push(displayStorageId);
  }

  return photos;
}
