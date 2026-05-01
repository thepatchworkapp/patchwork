import { Doc } from "../../convex/_generated/dataModel";
import { QueryCtx } from "../../convex/_generated/server";
import {
  getTaskerCategoryPortfolioImageDtos,
  getTaskerProfileImageAssetDto,
} from "../../convex/imageAssetHelpers";

type CtxWithStorageAndDb = Pick<QueryCtx, "db" | "storage">;

export function formatTaskerSummaryPrice(
  rateType: "hourly" | "fixed",
  hourlyRate: number | undefined,
  fixedRate: number | undefined
): string {
  if (rateType === "hourly" && hourlyRate) {
    const dollars = hourlyRate / 100;
    return `$${dollars}/hr`;
  }
  if (rateType === "fixed" && fixedRate) {
    const dollars = fixedRate / 100;
    return `$${dollars} flat`;
  }
  return "$0/hr";
}

export async function buildTaskerSummaryDto(
  ctx: CtxWithStorageAndDb,
  args: {
    profile: Doc<"taskerProfiles">;
    user: Doc<"users">;
    category: Doc<"categories">;
    categoryData: Doc<"taskerCategories">;
    distance: string;
    completedJobs: number;
    includeUrls: boolean;
  }
) {
  const { profile, user, category, categoryData, distance, completedJobs, includeUrls } = args;
  const avatarUrl = includeUrls && user.photo ? await ctx.storage.getUrl(user.photo) : null;
  const avatarImage = await getTaskerProfileImageAssetDto(ctx, user, profile, includeUrls);
  const categoryImages = await getTaskerCategoryPortfolioImageDtos(ctx, categoryData, includeUrls);
  const categoryPhotoStorageId = categoryData.photos?.[0];
  const categoryPhotoUrl = categoryImages.coverImage?.variants.display.url
    ?? (includeUrls && categoryPhotoStorageId
      ? await ctx.storage.getUrl(categoryPhotoStorageId)
      : null);

  return {
    id: profile._id,
    userId: profile.userId,
    name: profile.displayName,
    category: category.name,
    rating: categoryData.rating,
    reviews: categoryData.reviewCount,
    price: formatTaskerSummaryPrice(categoryData.rateType, categoryData.hourlyRate, categoryData.fixedRate),
    distance,
    verified: profile.verified,
    bio: categoryData.bio,
    completedJobs,
    avatarUrl,
    categoryPhotoUrl,
    avatarImage,
    categoryCoverImage: categoryImages.coverImage,
  };
}
