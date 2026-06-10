/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as admin from "../admin.js";
import type * as adminOtp from "../adminOtp.js";
import type * as analytics from "../analytics.js";
import type * as auth from "../auth.js";
import type * as authHelpers from "../authHelpers.js";
import type * as categories from "../categories.js";
import type * as conversations from "../conversations.js";
import type * as feedback from "../feedback.js";
import type * as files from "../files.js";
import type * as geospatial from "../geospatial.js";
import type * as http from "../http.js";
import type * as imageAssetHelpers from "../imageAssetHelpers.js";
import type * as jobRequests from "../jobRequests.js";
import type * as jobs from "../jobs.js";
import type * as location from "../location.js";
import type * as messages from "../messages.js";
import type * as moderation from "../moderation.js";
import type * as notifications from "../notifications.js";
import type * as proposals from "../proposals.js";
import type * as resend from "../resend.js";
import type * as reviewAccess from "../reviewAccess.js";
import type * as reviewAccessInternal from "../reviewAccessInternal.js";
import type * as reviews from "../reviews.js";
import type * as search from "../search.js";
import type * as taskers from "../taskers.js";
import type * as taskersInternal from "../taskersInternal.js";
import type * as testing from "../testing.js";
import type * as testingPhotos from "../testingPhotos.js";
import type * as testingTasker from "../testingTasker.js";
import type * as users from "../users.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  admin: typeof admin;
  adminOtp: typeof adminOtp;
  analytics: typeof analytics;
  auth: typeof auth;
  authHelpers: typeof authHelpers;
  categories: typeof categories;
  conversations: typeof conversations;
  feedback: typeof feedback;
  files: typeof files;
  geospatial: typeof geospatial;
  http: typeof http;
  imageAssetHelpers: typeof imageAssetHelpers;
  jobRequests: typeof jobRequests;
  jobs: typeof jobs;
  location: typeof location;
  messages: typeof messages;
  moderation: typeof moderation;
  notifications: typeof notifications;
  proposals: typeof proposals;
  resend: typeof resend;
  reviewAccess: typeof reviewAccess;
  reviewAccessInternal: typeof reviewAccessInternal;
  reviews: typeof reviews;
  search: typeof search;
  taskers: typeof taskers;
  taskersInternal: typeof taskersInternal;
  testing: typeof testing;
  testingPhotos: typeof testingPhotos;
  testingTasker: typeof testingTasker;
  users: typeof users;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {
  betterAuth: import("@convex-dev/better-auth/_generated/component.js").ComponentApi<"betterAuth">;
  geospatial: import("@convex-dev/geospatial/_generated/component.js").ComponentApi<"geospatial">;
  resend: import("@convex-dev/resend/_generated/component.js").ComponentApi<"resend">;
};
