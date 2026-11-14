import { ConvexError } from "convex/values";
import type { Id } from "../_generated/dataModel";
import type { MutationCtx, QueryCtx } from "../_generated/server";
import { FREE_LIMIT, FREE_LIMIT_REACHED, canLog, type LogType } from "./allowance.ts";
import { isSubscribed } from "./appStore.ts";

/** A subscription from anyone the baby is shared with unlocks logging for all of them. */
export async function babyUnlocked(ctx: QueryCtx, babyId: Id<"babies">): Promise<boolean> {
  const members = await ctx.db
    .query("babyMembers")
    .withIndex("by_baby", (q) => q.eq("babyId", babyId))
    .take(50);
  const now = Date.now();
  for (const member of members) {
    const row = await ctx.db
      .query("subscriptions")
      .withIndex("by_user", (q) => q.eq("userId", member.userId))
      .unique();
    if (row && isSubscribed(row, now)) return true;
  }
  return false;
}

export async function usedForBaby(
  ctx: QueryCtx,
  babyId: Id<"babies">,
): Promise<Partial<Record<LogType, number>>> {
  const rows = await ctx.db
    .query("logAllowances")
    .withIndex("by_baby_and_type", (q) => q.eq("babyId", babyId))
    .take(20);
  return Object.fromEntries(rows.map((row) => [row.type, row.used]));
}

/** Counts one entry, or throws FREE_LIMIT_REACHED once the free entries are used and nobody subscribes. */
export async function chargeAllowance(
  ctx: MutationCtx,
  babyId: Id<"babies">,
  type: LogType | null,
): Promise<void> {
  if (type === null) return;
  const row = await ctx.db
    .query("logAllowances")
    .withIndex("by_baby_and_type", (q) => q.eq("babyId", babyId).eq("type", type))
    .unique();
  const used = row?.used ?? 0;
  if (!canLog(type, used, false) && !(await babyUnlocked(ctx, babyId))) {
    throw new ConvexError({ code: FREE_LIMIT_REACHED, type, limit: FREE_LIMIT });
  }
  if (row) {
    await ctx.db.patch(row._id, { used: used + 1 });
  } else {
    await ctx.db.insert("logAllowances", { babyId, type, used: 1 });
  }
}
