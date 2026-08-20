import {
  paginationOptsValidator,
  paginationResultValidator,
} from "convex/server";
import { ConvexError, v } from "convex/values";
import { authedMutation, authedQuery } from "./lib/functions";
import { requireBabyMember } from "./lib/access";
import {
  babyValidator,
  eventValidator,
  feedKindValidator,
  milkValidator,
  nappyKindValidator,
  sideValidator,
  sizeValidator,
} from "./lib/validators";

export const dashboard = authedQuery({
  args: { babyId: v.id("babies") },
  returns: v.object({
    baby: babyValidator,
    lastFeed: v.union(eventValidator, v.null()),
    lastNappy: v.union(eventValidator, v.null()),
  }),
  handler: async (ctx, args) => {
    const baby = await requireBabyMember(ctx, args.babyId, ctx.user._id);
    const lastFeed = await ctx.db
      .query("events")
      .withIndex("by_baby_kind_loggedAt", (q) =>
        q.eq("babyId", args.babyId).eq("kind", "feed"),
      )
      .order("desc")
      .first();
    const lastNappy = await ctx.db
      .query("events")
      .withIndex("by_baby_kind_loggedAt", (q) =>
        q.eq("babyId", args.babyId).eq("kind", "nappy"),
      )
      .order("desc")
      .first();
    return { baby, lastFeed, lastNappy };
  },
});

export const list = authedQuery({
  args: {
    babyId: v.id("babies"),
    paginationOpts: paginationOptsValidator,
  },
  returns: paginationResultValidator(eventValidator),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    return await ctx.db
      .query("events")
      .withIndex("by_baby_and_loggedAt", (q) => q.eq("babyId", args.babyId))
      .order("desc")
      .paginate(args.paginationOpts);
  },
});

export const logFeed = authedMutation({
  args: {
    babyId: v.id("babies"),
    loggedAt: v.number(),
    feedKind: feedKindValidator,
    side: v.optional(sideValidator),
    durationMinutes: v.optional(v.number()),
    amountMl: v.optional(v.number()),
    milk: v.optional(milkValidator),
    note: v.optional(v.string()),
  },
  returns: v.id("events"),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    if (args.feedKind === "breast" && !args.side) {
      throw new ConvexError("Choose a breast side");
    }
    if (args.feedKind === "bottle") {
      if (!args.amountMl || args.amountMl <= 0) {
        throw new ConvexError("Bottle amount is required");
      }
    }
    return await ctx.db.insert("events", {
      babyId: args.babyId,
      createdBy: ctx.user._id,
      loggedAt: args.loggedAt,
      kind: "feed",
      feedKind: args.feedKind,
      side: args.feedKind === "breast" ? args.side : undefined,
      durationMinutes: args.durationMinutes,
      amountMl: args.feedKind === "bottle" ? args.amountMl : undefined,
      milk: args.feedKind === "bottle" ? args.milk : undefined,
      note: args.note?.trim() || undefined,
    });
  },
});

export const logNappy = authedMutation({
  args: {
    babyId: v.id("babies"),
    loggedAt: v.number(),
    nappy: nappyKindValidator,
    weeSize: v.optional(sizeValidator),
    pooSize: v.optional(sizeValidator),
    note: v.optional(v.string()),
  },
  returns: v.id("events"),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    if ((args.nappy === "wee" || args.nappy === "both") && !args.weeSize) {
      throw new ConvexError("Wee size is required");
    }
    if ((args.nappy === "poo" || args.nappy === "both") && !args.pooSize) {
      throw new ConvexError("Poo size is required");
    }
    return await ctx.db.insert("events", {
      babyId: args.babyId,
      createdBy: ctx.user._id,
      loggedAt: args.loggedAt,
      kind: "nappy",
      nappy: args.nappy,
      weeSize:
        args.nappy === "wee" || args.nappy === "both" ? args.weeSize : undefined,
      pooSize:
        args.nappy === "poo" || args.nappy === "both" ? args.pooSize : undefined,
      note: args.note?.trim() || undefined,
    });
  },
});
