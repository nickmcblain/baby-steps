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
/** Appointments can be scheduled up to ~18 months ahead. */
const MAX_FUTURE_MS = 550 * 86_400_000;

function snapLoggedAt(loggedAt: number, allowFuture = false): number {
  if (!Number.isFinite(loggedAt)) {
    throw new ConvexError("When is required");
  }
  const snapped = Math.round(loggedAt / HALF_HOUR_MS) * HALF_HOUR_MS;
  const now = Date.now() + HALF_HOUR_MS; // allow current half-hour slot
  if (!allowFuture && snapped > now) {
    throw new ConvexError("Time can't be in the future");
  }
  if (allowFuture && snapped > Date.now() + MAX_FUTURE_MS) {
    throw new ConvexError("Date is too far in the future");
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

export const logCustom = authedMutation({
  args: {
    babyId: v.id("babies"),
    loggedAt: v.number(),
    title: v.string(),
    note: v.optional(v.string()),
  },
  returns: v.id("events"),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    const title = args.title.trim();
    if (title.length < 1 || title.length > 80) {
      throw new ConvexError("Give the event a short title");
    }
    return await ctx.db.insert("events", {
      babyId: args.babyId,
      createdBy: ctx.user._id,
      loggedAt: snapLoggedAt(args.loggedAt, true),
      kind: "custom",
      title,
      note: args.note?.trim() || undefined,
    });
  },
});

const weekSleepSegmentValidator = v.object({
  kind: v.literal("sleep"),
  eventId: v.id("events"),
  startMs: v.number(),
  endMs: v.number(),
});

const weekMarkerKindValidator = v.union(
  v.literal("feed"),
  v.literal("nappy"),
  v.literal("weight"),
  v.literal("height"),
  v.literal("custom"),
);

const weekMarkerValidator = v.object({
  kind: weekMarkerKindValidator,
  eventId: v.id("events"),
  atMs: v.number(),
});

export const weekGrid = authedQuery({
  args: {
    babyId: v.id("babies"),
    weekStartMs: v.number(),
  },
  returns: v.object({
    weekStartMs: v.number(),
    sleeps: v.array(weekSleepSegmentValidator),
    markers: v.array(weekMarkerValidator),
  }),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    const weekStartMs = args.weekStartMs;
    const weekEndMs = weekStartMs + 7 * 86_400_000;
    // Include sleeps that may have started slightly before the week but still
    // show overnight spill — fetch a 24h lookback of sleeps.
    const lookback = weekStartMs - 86_400_000;
    const events = await ctx.db
      .query("events")
      .withIndex("by_baby_and_loggedAt", (q) =>
        q
          .eq("babyId", args.babyId)
          .gte("loggedAt", lookback)
          .lt("loggedAt", weekEndMs),
      )
      .take(500);

    const sleeps: {
      kind: "sleep";
      eventId: Id<"events">;
      startMs: number;
      endMs: number;
    }[] = [];
    const markers: {
      kind: "feed" | "nappy" | "weight" | "height" | "custom";
      eventId: Id<"events">;
      atMs: number;
    }[] = [];

    for (const event of events) {
      if (event.kind === "sleep" && event.durationMinutes != null) {
        const startMs = event.loggedAt;
        const endMs = startMs + event.durationMinutes * 60_000;
        if (endMs <= weekStartMs || startMs >= weekEndMs) continue;
        sleeps.push({
          kind: "sleep",
          eventId: event._id,
          startMs,
          endMs,
        });
        continue;
      }
      if (
        event.kind === "feed" ||
        event.kind === "nappy" ||
        event.kind === "weight" ||
        event.kind === "height" ||
        event.kind === "custom"
      ) {
        if (event.loggedAt < weekStartMs || event.loggedAt >= weekEndMs) {
          continue;
        }
        markers.push({
          kind: event.kind,
          eventId: event._id,
          atMs: event.loggedAt,
        });
      }
    }

    return { weekStartMs, sleeps, markers };
  },
});

const sleepPatternItemValidator = v.object({
  startMs: v.number(),
  endMs: v.number(),
  durationMinutes: v.number(),
});

export const sleepPatterns = authedQuery({
  args: {
    babyId: v.id("babies"),
    days: v.union(v.literal(7), v.literal(14), v.literal(30)),
    rangeEndMs: v.number(),
  },
  returns: v.object({
    sleeps: v.array(sleepPatternItemValidator),
    stats: v.object({
      avgSleepMinutesPerDay: v.number(),
      avgSessionsPerDay: v.number(),
    }),
  }),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    const rangeEndMs = args.rangeEndMs;
    const rangeStartMs = rangeEndMs - args.days * 86_400_000;
    const events = await ctx.db
      .query("events")
      .withIndex("by_baby_kind_loggedAt", (q) =>
        q
          .eq("babyId", args.babyId)
          .eq("kind", "sleep")
          .gte("loggedAt", rangeStartMs - 86_400_000)
          .lt("loggedAt", rangeEndMs),
      )
      .order("asc")
      .take(300);

    const sleeps: {
      startMs: number;
      endMs: number;
      durationMinutes: number;
    }[] = [];

    for (const event of events) {
      if (event.durationMinutes == null) continue;
      const startMs = event.loggedAt;
      const endMs = startMs + event.durationMinutes * 60_000;
      if (endMs <= rangeStartMs || startMs >= rangeEndMs) continue;
      sleeps.push({
        startMs,
        endMs,
        durationMinutes: event.durationMinutes,
      });
    }

    let totalMinutes = 0;
    for (const s of sleeps) {
      const clippedStart = Math.max(s.startMs, rangeStartMs);
      const clippedEnd = Math.min(s.endMs, rangeEndMs);
      totalMinutes += Math.max(0, (clippedEnd - clippedStart) / 60_000);
    }
    const days = args.days;
    return {
      sleeps,
      stats: {
        avgSleepMinutesPerDay: days > 0 ? totalMinutes / days : 0,
        avgSessionsPerDay: days > 0 ? sleeps.length / days : 0,
      },
    };
  },
});
