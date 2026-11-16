import { v } from "convex/values";
import { requireBabyMember } from "./lib/access";
import { authedQuery } from "./lib/functions";
import { babyValidator, eventValidator } from "./lib/validators";

export const EXPORT_LIMIT = 10_000;

/** Every log for one baby, oldest first, for CSV/PDF export on the device. */
export const babyCareLog = authedQuery({
  args: { babyId: v.id("babies") },
  returns: v.object({
    baby: babyValidator,
    events: v.array(eventValidator),
    truncated: v.boolean(),
  }),
  handler: async (ctx, args) => {
    const baby = await requireBabyMember(ctx, args.babyId, ctx.user._id);
    const events = await ctx.db
      .query("events")
      .withIndex("by_baby_and_loggedAt", (q) => q.eq("babyId", args.babyId))
      .order("asc")
      .take(EXPORT_LIMIT + 1);
    return {
      baby,
      events: events.slice(0, EXPORT_LIMIT),
      truncated: events.length > EXPORT_LIMIT,
    };
  },
});
