import { getEnv } from "./env";

function deriveSiteUrlFromCloudUrl(cloudUrl: string): string {
  if (cloudUrl.includes(".convex.site")) return cloudUrl;
  if (cloudUrl.includes(".convex.cloud")) return cloudUrl.replace(".convex.cloud", ".convex.site");
  return cloudUrl;
}

export function getConvexCloudUrl(): string {
  return (
    getEnv("VITE_CONVEX_URL") ||
    getEnv("PUBLIC_CONVEX_URL") ||
    ""
  );
}

export function getConvexSiteUrl(): string {
  const explicit =
    getEnv("VITE_CONVEX_SITE_URL") ||
    getEnv("PUBLIC_CONVEX_SITE_URL");
  if (explicit) return explicit;

  const cloud = getConvexCloudUrl();
  return cloud ? deriveSiteUrlFromCloudUrl(cloud) : "";
}

