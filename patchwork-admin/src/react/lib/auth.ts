import { createAuthClient } from "better-auth/react";
import { emailOTPClient } from "better-auth/client/plugins";
import {
  convexClient,
  crossDomainClient,
} from "@convex-dev/better-auth/client/plugins";
import { getConvexSiteUrl } from "./convexUrls";

const baseURL = getConvexSiteUrl();
if (!baseURL) {
  throw new Error(
    "Missing Convex site URL. Set PUBLIC_CONVEX_URL (preferred) or PUBLIC_CONVEX_SITE_URL."
  );
}

export const authClient = createAuthClient({
  baseURL,
  plugins: [emailOTPClient(), convexClient(), crossDomainClient()],
});

export const { useSession, signOut } = authClient;
