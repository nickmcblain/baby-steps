import { ConvexError } from "convex/values";
import type { Doc } from "../_generated/dataModel";
import type { MutationCtx, QueryCtx } from "../_generated/server";

type Ctx = QueryCtx | MutationCtx;

export async function getUserByToken(
  ctx: Ctx,
  tokenIdentifier: string,
): Promise<Doc<"users"> | null> {
  return await ctx.db
    .query("users")
    .withIndex("by_token", (q) => q.eq("tokenIdentifier", tokenIdentifier))
    .unique();
}

export async function requireIdentity(ctx: Ctx) {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) {
    throw new ConvexError("Not authenticated");
  }
  return identity;
}

export async function requireUser(ctx: Ctx): Promise<Doc<"users">> {
  const identity = await requireIdentity(ctx);
  const user = await getUserByToken(ctx, identity.tokenIdentifier);
  if (!user) {
    throw new ConvexError("User not provisioned");
  }
  return user;
}

export async function upsertUser(ctx: MutationCtx): Promise<Doc<"users">> {
  const identity = await requireIdentity(ctx);
  const existing = await getUserByToken(ctx, identity.tokenIdentifier);
  const name =
    identity.name?.trim() ||
    identity.email?.split("@")[0] ||
    "Parent";
  const email = identity.email ?? undefined;

  if (existing) {
    await ctx.db.patch(existing._id, { name, email });
    const updated = await ctx.db.get(existing._id);
    if (!updated) {
      throw new ConvexError("User missing after update");
    }
    return updated;
  }

  const userId = await ctx.db.insert("users", {
    tokenIdentifier: identity.tokenIdentifier,
    name,
    email,
  });
  const created = await ctx.db.get(userId);
  if (!created) {
    throw new ConvexError("User missing after insert");
  }
  return created;
}
