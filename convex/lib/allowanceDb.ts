import { ConvexError } from "convex/values";
import type { Id } from "../_generated/dataModel";
import type { MutationCtx, QueryCtx } from "../_generated/server";
import { FREE_LIMIT, FREE_LIMIT_REACHED, SUBSCRIPTION_REQUIRED, canLog, type LogType } from "./allowance.ts";
import { isSubscribed } from "./appStore.ts";

/** Entitlement is per carer: a partner's subscription doesn't unlock anything for you. */
export async function userSubscribed(ctx: QueryCtx, userId: Id<"users">): Promise<boolean> {
  const row = await ctx.db
    .query("subscriptions")
    .withIndex("by_user", (q) => q.eq("userId", userId))
    .unique();
  return row !== null && isSubscribed(row, Date.now());
}

export async function requireSubscribed(
  ctx: QueryCtx,
  userId: Id<"users">,
  feature: "sharing",
): Promise<void> {
  if (!(await userSubscribed(ctx, userId))) {
    throw new ConvexError({ code: SUBSCRIPTION_REQUIRED, feature });
  }
}

/** This carer's free entries used on this baby, per log type. */
export async function usedFor(
  ctx: QueryCtx,
  babyId: Id<"babies">,
  userId: Id<"users">,
): Promise<Partial<Record<LogType, number>>> {
  const rows = await ctx.db
    .query("logAllowances")
    .withIndex("by_baby_and_user_and_type", (q) => q.eq("babyId", babyId).eq("userId", userId))
    .take(20);
  return Object.fromEntries(rows.map((row) => [row.type, row.used]));
}

/** Counts one entry for this carer, or throws FREE_LIMIT_REACHED once their free entries are used and they don't subscribe. */
export async function chargeAllowance(
  ctx: MutationCtx,
  babyId: Id<"babies">,
  userId: Id<"users">,
  type: LogType | null,
): Promise<void> {
  if (type === null) return;
  const row = await ctx.db
    .query("logAllowances")
    .withIndex("by_baby_and_user_and_type", (q) =>
      q.eq("babyId", babyId).eq("userId", userId).eq("type", type),
    )
    .unique();
  const used = row?.used ?? 0;
  if (!canLog(type, used, false) && !(await userSubscribed(ctx, userId))) {
    throw new ConvexError({ code: FREE_LIMIT_REACHED, type, limit: FREE_LIMIT });
  }
  if (row) {
    await ctx.db.patch(row._id, { used: used + 1 });
  } else {
    await ctx.db.insert("logAllowances", { babyId, userId, type, used: 1 });
  }
}
