import { v } from "convex/values";
import { internalQuery } from "./_generated/server";
import { FREE_LIMIT, logTypeValidator, trialUsed, type LogType } from "./lib/allowance";
import { babyUnlocked, usedForBaby } from "./lib/allowanceDb";
import { authedQuery } from "./lib/functions";

const babyAllowanceValidator = v.object({
  babyId: v.id("babies"),
  unlocked: v.boolean(),
  used: v.array(v.object({ type: logTypeValidator, used: v.number() })),
});

/** Free entries used per log type for each of the user's babies. The app mirrors this for widgets and Siri. */
export const mine = authedQuery({
  args: {},
  returns: v.object({ limit: v.number(), babies: v.array(babyAllowanceValidator) }),
  handler: async (ctx) => {
    const memberships = await ctx.db
      .query("babyMembers")
      .withIndex("by_user", (q) => q.eq("userId", ctx.user._id))
      .take(50);
    const babies = [];
    for (const { babyId } of memberships) {
      const used = await usedForBaby(ctx, babyId);
      babies.push({
        babyId,
        unlocked: await babyUnlocked(ctx, babyId),
        used: Object.entries(used).map(([type, n]) => ({ type: type as LogType, used: n ?? 0 })),
      });
    }
    return { limit: FREE_LIMIT, babies };
  },
});

/** Ask is open during the free entries, then needs a subscription. */
export const askAllowed = internalQuery({
  args: { babyId: v.id("babies") },
  returns: v.boolean(),
  handler: async (ctx, args) => {
    if (!trialUsed(await usedForBaby(ctx, args.babyId))) return true;
    return await babyUnlocked(ctx, args.babyId);
  },
});
