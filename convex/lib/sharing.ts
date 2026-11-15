import { ConvexError } from "convex/values";
import type { Doc, Id } from "../_generated/dataModel";
import type { MutationCtx, QueryCtx } from "../_generated/server";
import { getMembership, requireBabyMember, uniqueInviteCode } from "./access.ts";
import { requireSubscribed, userSubscribed } from "./allowanceDb.ts";

/** Each carer needs their own subscription to share a baby, so codes are only shown to subscribers. */
export async function visibleBaby(ctx: QueryCtx, baby: Doc<"babies">, userId: Id<"users">): Promise<Doc<"babies">> {
  if (baby.inviteCode === undefined || (await userSubscribed(ctx, userId))) return baby;
  const { inviteCode: _hidden, ...rest } = baby;
  return rest;
}

/** The baby's share code, created on first use. Needs an active subscription. */
export async function createInvite(ctx: MutationCtx, userId: Id<"users">, babyId: Id<"babies">): Promise<string> {
  const baby = await requireBabyMember(ctx, babyId, userId);
  await requireSubscribed(ctx, userId, "sharing");
  if (baby.inviteCode) return baby.inviteCode;
  const inviteCode = await uniqueInviteCode(ctx);
  await ctx.db.patch(babyId, { inviteCode });
  return inviteCode;
}

/** Joins the baby behind a share code. The joining carer needs their own active subscription. */
export async function redeemInvite(ctx: MutationCtx, userId: Id<"users">, code: string): Promise<Id<"babies">> {
  const inviteCode = code.trim().toUpperCase();
  if (inviteCode.length < 4) {
    throw new ConvexError("Invite code looks too short");
  }
  const baby = await ctx.db
    .query("babies")
    .withIndex("by_invite_code", (q) => q.eq("inviteCode", inviteCode))
    .unique();
  if (baby && (await getMembership(ctx, baby._id, userId))) return baby._id;
  await requireSubscribed(ctx, userId, "sharing");
  if (!baby) {
    throw new ConvexError("No baby matches that code");
  }
  await ctx.db.insert("babyMembers", { babyId: baby._id, userId });
  return baby._id;
}
