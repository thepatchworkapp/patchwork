import { ConvexError } from "convex/values";

export async function requireIdentity(ctx: any) {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) {
    throw new ConvexError("Unauthorized");
  }
  return identity;
}

export async function getAppUserOrNull(ctx: any) {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) {
    return null;
  }

  const user = await ctx.db
    .query("users")
    .withIndex("by_authId", (q: any) => q.eq("authId", identity.tokenIdentifier))
    .unique();

  if (!user) {
    return null;
  }

  return { identity, user };
}

export async function requireAppUser(ctx: any) {
  const identity = await requireIdentity(ctx);
  const user = await ctx.db
    .query("users")
    .withIndex("by_authId", (q: any) => q.eq("authId", identity.tokenIdentifier))
    .unique();

  if (!user) {
    throw new ConvexError("User not found");
  }

  return { identity, user };
}
