import {
  paginationOptsValidator,
  paginationResultValidator,
} from "convex/server";
import { ConvexError, v } from "convex/values";
import type { MutationCtx } from "./_generated/server";
import type { Id } from "./_generated/dataModel";
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

const HALF_HOUR_MS = 30 * 60_000;

function snapLoggedAt(loggedAt: number): number {
  if (!Number.isFinite(loggedAt)) {
    throw new ConvexError("When is required");
  }
  const snapped = Math.round(loggedAt / HALF_HOUR_MS) * HALF_HOUR_MS;
  const now = Date.now() + HALF_HOUR_MS; // allow current half-hour slot
  if (snapped > now) {
    throw new ConvexError("Time can't be in the future");
  }
  return snapped;
}

async function syncBabyWeight(
  ctx: MutationCtx,
  babyId: Id<"babies">,
): Promise<void> {
  const latest = await ctx.db
    .query("events")
    .withIndex("by_baby_kind_loggedAt", (q) =>
      q.eq("babyId", babyId).eq("kind", "weight"),
    )
    .order("desc")
    .first();
  if (latest?.weightGrams != null) {
    await ctx.db.patch(babyId, { weightGrams: latest.weightGrams });
  }
}

async function syncBabyHeight(
  ctx: MutationCtx,
  babyId: Id<"babies">,
): Promise<void> {
  const latest = await ctx.db
    .query("events")
    .withIndex("by_baby_kind_loggedAt", (q) =>
      q.eq("babyId", babyId).eq("kind", "height"),
    )
    .order("desc")
    .first();
  if (latest?.heightCm != null) {
    await ctx.db.patch(babyId, { heightCm: latest.heightCm });
  }
}

export const dashboard = authedQuery({
  args: { babyId: v.id("babies") },
  returns: v.object({
    baby: babyValidator,
    lastFeed: v.union(eventValidator, v.null()),
    lastNappy: v.union(eventValidator, v.null()),
    lastSleep: v.union(eventValidator, v.null()),
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
    const lastSleep = await ctx.db
      .query("events")
      .withIndex("by_baby_kind_loggedAt", (q) =>
        q.eq("babyId", args.babyId).eq("kind", "sleep"),
      )
      .order("desc")
      .first();
    return { baby, lastFeed, lastNappy, lastSleep };
  },
});

const growthPointValidator = v.object({
  at: v.number(),
  value: v.number(),
});

export const growthSeries = authedQuery({
  args: {
    babyId: v.id("babies"),
    kind: v.union(v.literal("weight"), v.literal("height")),
  },
  returns: v.object({
    baby: babyValidator,
    points: v.array(growthPointValidator),
  }),
  handler: async (ctx, args) => {
    const baby = await requireBabyMember(ctx, args.babyId, ctx.user._id);
    const events = await ctx.db
      .query("events")
      .withIndex("by_baby_kind_loggedAt", (q) =>
        q.eq("babyId", args.babyId).eq("kind", args.kind),
      )
      .order("asc")
      .take(200);
    const points = [];
    for (const event of events) {
      if (args.kind === "weight" && event.weightGrams != null) {
        points.push({
          at: event.loggedAt,
          value: event.weightGrams / 1000,
        });
      }
      if (args.kind === "height" && event.heightCm != null) {
        points.push({
          at: event.loggedAt,
          value: event.heightCm,
        });
      }
    }
    return { baby, points };
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
      loggedAt: snapLoggedAt(args.loggedAt),
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
      loggedAt: snapLoggedAt(args.loggedAt),
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

export const logWeight = authedMutation({
  args: {
    babyId: v.id("babies"),
    loggedAt: v.number(),
    weightGrams: v.number(),
    note: v.optional(v.string()),
  },
  returns: v.id("events"),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    if (!Number.isFinite(args.weightGrams) || args.weightGrams <= 0) {
      throw new ConvexError("Weight must be greater than 0");
    }
    const weightGrams = Math.round(args.weightGrams);
    const eventId = await ctx.db.insert("events", {
      babyId: args.babyId,
      createdBy: ctx.user._id,
      loggedAt: snapLoggedAt(args.loggedAt),
      kind: "weight",
      weightGrams,
      note: args.note?.trim() || undefined,
    });
    await syncBabyWeight(ctx, args.babyId);
    return eventId;
  },
});

export const logSleep = authedMutation({
  args: {
    babyId: v.id("babies"),
    loggedAt: v.number(),
    durationMinutes: v.number(),
    note: v.optional(v.string()),
  },
  returns: v.id("events"),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    if (
      !Number.isFinite(args.durationMinutes) ||
      args.durationMinutes < 1 ||
      args.durationMinutes > 24 * 60
    ) {
      throw new ConvexError("Sleep duration must be between 1 minute and 24 hours");
    }
    return await ctx.db.insert("events", {
      babyId: args.babyId,
      createdBy: ctx.user._id,
      loggedAt: snapLoggedAt(args.loggedAt),
      kind: "sleep",
      durationMinutes: Math.round(args.durationMinutes),
      note: args.note?.trim() || undefined,
    });
  },
});

export const logHeight = authedMutation({
  args: {
    babyId: v.id("babies"),
    loggedAt: v.number(),
    heightCm: v.number(),
    note: v.optional(v.string()),
  },
  returns: v.id("events"),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    if (!Number.isFinite(args.heightCm) || args.heightCm <= 0) {
      throw new ConvexError("Height must be greater than 0");
    }
    if (args.heightCm < 30 || args.heightCm > 130) {
      throw new ConvexError("Height looks out of range");
    }
    const heightCm = Math.round(args.heightCm * 10) / 10;
    const eventId = await ctx.db.insert("events", {
      babyId: args.babyId,
      createdBy: ctx.user._id,
      loggedAt: snapLoggedAt(args.loggedAt),
      kind: "height",
      heightCm,
      note: args.note?.trim() || undefined,
    });
    await syncBabyHeight(ctx, args.babyId);
    return eventId;
  },
});
