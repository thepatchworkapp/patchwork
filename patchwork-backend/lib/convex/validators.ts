import { v } from "convex/values";

export const subscriptionPlanValidator = v.union(
  v.literal("none"),
  v.literal("tasker")
);

export const subscriptionAccessTypeValidator = v.union(
  v.literal("subscription"),
  v.literal("lifetime")
);

export const subscriptionStatusValidator = v.union(
  v.literal("inactive"),
  v.literal("active"),
  v.literal("cancel_at_period_end"),
  v.literal("expired")
);

export const locationCoordinatesValidator = v.object({
  lat: v.number(),
  lng: v.number(),
});

export const userLocationValidator = v.object({
  city: v.string(),
  province: v.string(),
  coordinates: v.optional(locationCoordinatesValidator),
});

export const userRolesValidator = v.object({
  isSeeker: v.boolean(),
  isTasker: v.boolean(),
});

export const userSettingsValidator = v.object({
  notificationsEnabled: v.boolean(),
  locationEnabled: v.boolean(),
});

export const imageAssetPurposeValidator = v.union(
  v.literal("userPhoto"),
  v.literal("taskerPhoto"),
  v.literal("taskerCategoryPortfolio")
);

export const imageAssetStatusValidator = v.union(
  v.literal("active"),
  v.literal("deleted")
);

export const imageAssetContentTypeValidator = v.union(
  v.literal("image/jpeg"),
  v.literal("image/heic"),
  v.literal("image/heif")
);

export const imageAssetVariantValidator = v.object({
  storageId: v.id("_storage"),
  contentType: imageAssetContentTypeValidator,
  width: v.number(),
  height: v.number(),
  byteSize: v.number(),
});

export const imageAssetVariantWithUrlValidator = v.object({
  storageId: v.id("_storage"),
  contentType: imageAssetContentTypeValidator,
  width: v.number(),
  height: v.number(),
  byteSize: v.number(),
  url: v.union(v.string(), v.null()),
});

export const imageAssetValidator = v.object({
  _id: v.id("imageAssets"),
  cacheKey: v.string(),
  ownerUserId: v.id("users"),
  purpose: imageAssetPurposeValidator,
  status: imageAssetStatusValidator,
  sourceContentType: imageAssetContentTypeValidator,
  variants: v.object({
    thumb: imageAssetVariantWithUrlValidator,
    display: imageAssetVariantWithUrlValidator,
    large: v.optional(imageAssetVariantWithUrlValidator),
  }),
  createdAt: v.number(),
  updatedAt: v.number(),
});

export const currentUserValidator = v.object({
  _id: v.id("users"),
  authId: v.string(),
  email: v.string(),
  emailVerified: v.boolean(),
  name: v.string(),
  photo: v.optional(v.id("_storage")),
  photoAssetId: v.optional(v.id("imageAssets")),
  photoImage: v.union(imageAssetValidator, v.null()),
  location: userLocationValidator,
  roles: userRolesValidator,
  settings: userSettingsValidator,
  createdAt: v.number(),
  updatedAt: v.number(),
});

export const categoryValidator = v.object({
  _id: v.id("categories"),
  name: v.string(),
  slug: v.string(),
  icon: v.optional(v.string()),
  emoji: v.optional(v.string()),
  group: v.optional(v.string()),
  description: v.optional(v.string()),
  isActive: v.boolean(),
  sortOrder: v.optional(v.number()),
});

export const taskerCategoryRateTypeValidator = v.union(
  v.literal("hourly"),
  v.literal("fixed")
);

export const feedbackSubmissionValidator = v.object({
  _id: v.id("feedbackSubmissions"),
  userId: v.id("users"),
  message: v.string(),
  createdAt: v.number(),
  updatedAt: v.number(),
});

export const taskerCategorySummaryValidator = v.object({
  _id: v.id("taskerCategories"),
  taskerProfileId: v.id("taskerProfiles"),
  userId: v.id("users"),
  categoryId: v.id("categories"),
  bio: v.string(),
  photos: v.array(v.id("_storage")),
  portfolioAssetIds: v.optional(v.array(v.id("imageAssets"))),
  coverAssetId: v.optional(v.id("imageAssets")),
  coverImage: v.union(imageAssetValidator, v.null()),
  portfolioImages: v.array(imageAssetValidator),
  rateType: taskerCategoryRateTypeValidator,
  hourlyRate: v.optional(v.number()),
  fixedRate: v.optional(v.number()),
  serviceRadius: v.number(),
  rating: v.number(),
  reviewCount: v.number(),
  completedJobs: v.number(),
  createdAt: v.number(),
  updatedAt: v.number(),
  categoryName: v.string(),
  categorySlug: v.string(),
});

export const taskerProfileResponseValidator = v.object({
  _id: v.id("taskerProfiles"),
  userId: v.id("users"),
  displayName: v.string(),
  bio: v.optional(v.string()),
  websiteLinks: v.array(v.string()),
  socialLinks: v.array(v.string()),
  isOnboarded: v.boolean(),
  rating: v.number(),
  reviewCount: v.number(),
  completedJobs: v.number(),
  responseTime: v.optional(v.string()),
  verified: v.boolean(),
  photoSource: v.union(v.literal("user"), v.literal("custom")),
  photoAssetId: v.optional(v.id("imageAssets")),
  photoImage: v.union(imageAssetValidator, v.null()),
  subscriptionPlan: subscriptionPlanValidator,
  subscriptionAccessType: v.optional(subscriptionAccessTypeValidator),
  subscriptionActiveAccessTypes: v.optional(v.array(subscriptionAccessTypeValidator)),
  subscriptionStatus: v.optional(subscriptionStatusValidator),
  subscriptionEndsAt: v.optional(v.number()),
  ghostMode: v.boolean(),
  foundersBadge: v.optional(
    v.object({
      categoryId: v.id("categories"),
      awardedAt: v.number(),
    })
  ),
  location: v.optional(locationCoordinatesValidator),
  geoPoint: v.optional(v.string()),
  createdAt: v.number(),
  updatedAt: v.number(),
  hasActiveSubscription: v.boolean(),
  categories: v.array(taskerCategorySummaryValidator),
});

export const taskerPublicCategoryValidator = v.object({
  id: v.id("taskerCategories"),
  categoryId: v.id("categories"),
  categoryName: v.string(),
  categorySlug: v.string(),
  bio: v.string(),
  photos: v.array(v.id("_storage")),
  firstPhotoUrl: v.union(v.string(), v.null()),
  coverAssetId: v.optional(v.id("imageAssets")),
  coverImage: v.union(imageAssetValidator, v.null()),
  portfolioImages: v.array(imageAssetValidator),
  rateType: taskerCategoryRateTypeValidator,
  hourlyRate: v.optional(v.number()),
  fixedRate: v.optional(v.number()),
  serviceRadius: v.number(),
  completedJobs: v.number(),
});

export const taskerReviewValidator = v.object({
  id: v.id("reviews"),
  rating: v.number(),
  text: v.string(),
  reviewerName: v.string(),
  reviewerPhotoUrl: v.union(v.string(), v.null()),
  reviewerImage: v.union(imageAssetValidator, v.null()),
  createdAt: v.number(),
});

export const taskerDetailValidator = v.object({
  id: v.id("taskerProfiles"),
  userId: v.id("users"),
  displayName: v.string(),
  bio: v.optional(v.string()),
  websiteLinks: v.array(v.string()),
  socialLinks: v.array(v.string()),
  rating: v.number(),
  reviewCount: v.number(),
  completedJobs: v.number(),
  verified: v.boolean(),
  userName: v.string(),
  userPhoto: v.optional(v.id("_storage")),
  userPhotoUrl: v.union(v.string(), v.null()),
  profileImage: v.union(imageAssetValidator, v.null()),
  isFavourite: v.boolean(),
  categories: v.array(taskerPublicCategoryValidator),
  reviews: v.array(taskerReviewValidator),
});

export const searchTaskerResultValidator = v.object({
  id: v.id("taskerProfiles"),
  userId: v.id("users"),
  name: v.string(),
  websiteLinks: v.array(v.string()),
  socialLinks: v.array(v.string()),
  category: v.string(),
  rating: v.number(),
  reviews: v.number(),
  price: v.string(),
  distance: v.string(),
  verified: v.boolean(),
  bio: v.string(),
  completedJobs: v.number(),
  avatarUrl: v.union(v.string(), v.null()),
  categoryPhotoUrl: v.union(v.string(), v.null()),
  avatarImage: v.union(imageAssetValidator, v.null()),
  categoryCoverImage: v.union(imageAssetValidator, v.null()),
});

export const proposalPayloadValidator = v.object({
  _id: v.id("proposals"),
  conversationId: v.id("conversations"),
  senderId: v.id("users"),
  receiverId: v.id("users"),
  clientProposalId: v.optional(v.string()),
  jobRequestId: v.optional(v.id("jobRequests")),
  rate: v.number(),
  rateType: v.union(v.literal("hourly"), v.literal("flat")),
  startDateTime: v.string(),
  notes: v.optional(v.string()),
  status: v.union(
    v.literal("pending"),
    v.literal("accepted"),
    v.literal("declined"),
    v.literal("countered"),
    v.literal("expired")
  ),
  previousProposalId: v.optional(v.id("proposals")),
  counterProposalId: v.optional(v.id("proposals")),
  createdAt: v.number(),
  updatedAt: v.number(),
  expiresAt: v.optional(v.number()),
});

export const messageWithProposalValidator = v.object({
  _id: v.id("messages"),
  conversationId: v.id("conversations"),
  senderId: v.id("users"),
  clientMessageId: v.optional(v.string()),
  type: v.union(v.literal("text"), v.literal("proposal"), v.literal("system")),
  content: v.string(),
  proposalId: v.optional(v.id("proposals")),
  proposal: v.union(proposalPayloadValidator, v.null()),
  attachments: v.optional(v.array(v.id("_storage"))),
  readAt: v.optional(v.number()),
  createdAt: v.number(),
  updatedAt: v.number(),
});

export const messagesPageValidator = v.object({
  page: v.array(messageWithProposalValidator),
  isDone: v.boolean(),
  continueCursor: v.string(),
});

export const messagesDeltaValidator = v.object({
  messages: v.array(messageWithProposalValidator),
  hasMore: v.boolean(),
  latestCursor: v.number(),
});

export const threadWatchValidator = v.object({
  messages: v.array(messageWithProposalValidator),
  hasMore: v.boolean(),
  latestCursor: v.number(),
  latestProposal: v.union(proposalPayloadValidator, v.null()),
});

export const reviewDocValidator = v.object({
  _id: v.id("reviews"),
  jobId: v.id("jobs"),
  reviewerId: v.id("users"),
  revieweeId: v.id("users"),
  rating: v.number(),
  text: v.string(),
  createdAt: v.number(),
});

export const conversationValidator = v.object({
  _id: v.id("conversations"),
  _creationTime: v.number(),
  seekerId: v.id("users"),
  taskerId: v.id("users"),
  jobRequestId: v.optional(v.id("jobRequests")),
  jobId: v.optional(v.id("jobs")),
  lastMessageAt: v.number(),
  lastMessageId: v.optional(v.id("messages")),
  lastMessagePreview: v.optional(v.string()),
  lastMessageSenderId: v.optional(v.id("users")),
  seekerUnreadCount: v.number(),
  taskerUnreadCount: v.number(),
  seekerLastReadAt: v.optional(v.number()),
  taskerLastReadAt: v.optional(v.number()),
  createdAt: v.number(),
  updatedAt: v.number(),
  seekerName: v.string(),
  taskerName: v.string(),
  seekerPhotoUrl: v.union(v.string(), v.null()),
  taskerPhotoUrl: v.union(v.string(), v.null()),
  seekerImage: v.union(imageAssetValidator, v.null()),
  taskerImage: v.union(imageAssetValidator, v.null()),
  participantName: v.union(v.string(), v.null()),
  participantPhotoUrl: v.union(v.string(), v.null()),
  participantImage: v.union(imageAssetValidator, v.null()),
});

export const locationUpdateResultValidator = v.object({
  updated: v.boolean(),
  reason: v.optional(v.literal("threshold")),
  distance: v.union(v.number(), v.null()),
});

export const jobValidator = v.object({
  _id: v.id("jobs"),
  _creationTime: v.number(),
  seekerId: v.id("users"),
  taskerId: v.id("users"),
  requestId: v.optional(v.id("jobRequests")),
  proposalId: v.id("proposals"),
  categoryId: v.id("categories"),
  categoryName: v.string(),
  description: v.string(),
  rate: v.number(),
  rateType: v.union(v.literal("hourly"), v.literal("flat")),
  startDate: v.string(),
  completedDate: v.optional(v.string()),
  notes: v.optional(v.string()),
  status: v.union(
    v.literal("pending"),
    v.literal("in_progress"),
    v.literal("completed"),
    v.literal("cancelled"),
    v.literal("disputed")
  ),
  seekerReviewId: v.optional(v.id("reviews")),
  taskerReviewId: v.optional(v.id("reviews")),
  createdAt: v.number(),
  updatedAt: v.number(),
});

export const listedJobValidator = v.object({
  _id: v.id("jobs"),
  _creationTime: v.number(),
  seekerId: v.id("users"),
  taskerId: v.id("users"),
  requestId: v.optional(v.id("jobRequests")),
  proposalId: v.id("proposals"),
  categoryId: v.id("categories"),
  categoryName: v.string(),
  description: v.string(),
  rate: v.number(),
  rateType: v.union(v.literal("hourly"), v.literal("flat")),
  startDate: v.string(),
  completedDate: v.optional(v.string()),
  notes: v.optional(v.string()),
  status: v.union(
    v.literal("pending"),
    v.literal("in_progress"),
    v.literal("completed"),
    v.literal("cancelled"),
    v.literal("disputed")
  ),
  seekerReviewId: v.optional(v.id("reviews")),
  taskerReviewId: v.optional(v.id("reviews")),
  createdAt: v.number(),
  updatedAt: v.number(),
  counterpartyName: v.string(),
  counterpartyPhotoUrl: v.union(v.string(), v.null()),
  counterpartyImage: v.union(imageAssetValidator, v.null()),
});

export const jobRequestValidator = v.object({
  _id: v.id("jobRequests"),
  _creationTime: v.number(),
  seekerId: v.id("users"),
  categoryId: v.id("categories"),
  categoryName: v.string(),
  description: v.string(),
  photos: v.optional(v.array(v.id("_storage"))),
  location: v.object({
    address: v.string(),
    city: v.string(),
    province: v.string(),
    coordinates: v.optional(locationCoordinatesValidator),
    searchRadius: v.number(),
  }),
  geoPoint: v.optional(v.string()),
  timing: v.object({
    type: v.union(v.literal("asap"), v.literal("specific_date"), v.literal("flexible")),
    specificDate: v.optional(v.string()),
    specificTime: v.optional(v.string()),
  }),
  budget: v.optional(
    v.object({
      min: v.number(),
      max: v.number(),
    })
  ),
  status: v.union(
    v.literal("open"),
    v.literal("in_progress"),
    v.literal("completed"),
    v.literal("cancelled")
  ),
  createdAt: v.number(),
  updatedAt: v.number(),
});
