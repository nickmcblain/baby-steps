import { ConvexError } from "convex/values";
import type { Doc, Id } from "../_generated/dataModel";
import type { MutationCtx, QueryCtx } from "../_generated/server";

type Ctx = QueryCtx | MutationCtx;

export async function getMembership(
  ctx: Ctx,
  babyId: Id<"babies">,
  userId: Id<"users">,
) {
  return await ctx.db
    .query("babyMembers")
    .withIndex("by_baby_and_user", (q) =>
      q.eq("babyId", babyId).eq("userId", userId),
    )
    .unique();
}

export async function requireBabyMember(
  ctx: Ctx,
  babyId: Id<"babies">,
  userId: Id<"users">,
): Promise<Doc<"babies">> {
  const baby = await ctx.db.get(babyId);
  if (!baby) {
    throw new ConvexError("Baby not found");
  }
  const membership = await getMembership(ctx, babyId, userId);
  if (!membership) {
    throw new ConvexError("Not a member of this baby");
  }
  return baby;
}

export function randomInviteCode(): string {
  const alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
  let code = "";
  for (let i = 0; i < 6; i += 1) {
    code += alphabet[Math.floor(Math.random() * alphabet.length)];
  }
  return code;
}

export async function uniqueInviteCode(ctx: MutationCtx): Promise<string> {
  for (let attempt = 0; attempt < 12; attempt += 1) {
    const inviteCode = randomInviteCode();
    const existing = await ctx.db
      .query("babies")
      .withIndex("by_invite_code", (q) => q.eq("inviteCode", inviteCode))
      .unique();
    if (!existing) {
      return inviteCode;
    }
  }
  throw new ConvexError("Could not allocate invite code");
}
