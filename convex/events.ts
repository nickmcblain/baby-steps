import {
  paginationOptsValidator,
  paginationResultValidator,
} from "convex/server";
import { ConvexError, v } from "convex/values";
import type { Id } from "./_generated/dataModel";
import { authedMutation, authedQuery } from "./lib/functions";
import { requireBabyMember } from "./lib/access";
import {
  insertActivity,
  insertCustom,
  insertFeed,
  insertHeight,
  insertMedicine,
  insertNappy,
  insertPotty,
  insertPump,
  insertSleep,
  insertTummy,
  insertWeight,
  syncBabyHeight,
  syncBabyWeight,
} from "./lib/logEvents";
import {
  babyValidator,
  eventKindValidator,
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
    lastSleep: v.union(eventValidator, v.null()),
    lastTummy: v.union(eventValidator, v.null()),
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
    const lastTummy = await ctx.db
      .query("events")
      .withIndex("by_baby_kind_loggedAt", (q) =>
        q.eq("babyId", args.babyId).eq("kind", "tummy"),
      )
      .order("desc")
      .first();
    return { baby, lastFeed, lastNappy, lastSleep, lastTummy };
  },
});

const dayEventValidator = v.object({
  _id: v.id("events"),
  kind: eventKindValidator,
  loggedAt: v.number(),
  feedKind: v.optional(feedKindValidator),
  side: v.optional(sideValidator),
  durationMinutes: v.optional(v.number()),
  amountMl: v.optional(v.number()),
  milk: v.optional(milkValidator),
    nappy: v.optional(nappyKindValidator),
    weeSize: v.optional(sizeValidator),
    pooSize: v.optional(sizeValidator),
    weightGrams: v.optional(v.number()),
    heightCm: v.optional(v.number()),
    title: v.optional(v.string()),
    note: v.optional(v.string()),
  });

export const daySummary = authedQuery({
  args: {
    babyId: v.id("babies"),
    dayStart: v.number(),
    dayEnd: v.number(),
  },
  returns: v.object({
    baby: babyValidator,
    sleepMinutes: v.number(),
    feedCount: v.number(),
    nappyCount: v.number(),
    tummyMinutes: v.number(),
    lastSleepEndMs: v.union(v.number(), v.null()),
    events: v.array(dayEventValidator),
    recentLoggedAts: v.array(v.number()),
  }),
  handler: async (ctx, args) => {
    const baby = await requireBabyMember(ctx, args.babyId, ctx.user._id);
    if (!(args.dayEnd > args.dayStart)) {
      throw new ConvexError("Day range is invalid");
    }

    const dayEvents = await ctx.db
      .query("events")
      .withIndex("by_baby_and_loggedAt", (q) =>
        q
          .eq("babyId", args.babyId)
          .gte("loggedAt", args.dayStart)
          .lt("loggedAt", args.dayEnd),
      )
      .order("desc")
      .take(80);

    let sleepMinutes = 0;
    let feedCount = 0;
    let nappyCount = 0;
    let tummyMinutes = 0;
    const events = [];
    for (const event of dayEvents) {
      if (event.kind === "sleep") {
        sleepMinutes += event.durationMinutes ?? 0;
      } else if (event.kind === "feed") {
        feedCount += 1;
      } else if (event.kind === "nappy") {
        nappyCount += 1;
      } else if (event.kind === "tummy") {
        tummyMinutes += event.durationMinutes ?? 0;
      }
      events.push({
        _id: event._id,
        kind: event.kind,
        loggedAt: event.loggedAt,
        feedKind: event.feedKind,
        side: event.side,
        durationMinutes: event.durationMinutes,
        amountMl: event.amountMl,
        milk: event.milk,
        nappy: event.nappy,
        weeSize: event.weeSize,
        pooSize: event.pooSize,
        weightGrams: event.weightGrams,
        heightCm: event.heightCm,
        title: event.title,
        note: event.note,
      });
    }

    const recent = await ctx.db
      .query("events")
      .withIndex("by_baby_and_loggedAt", (q) => q.eq("babyId", args.babyId))
      .order("desc")
      .take(200);

    let lastSleepEndMs: number | null = null;
    for (const event of recent) {
      if (event.kind === "sleep" && event.durationMinutes != null) {
        lastSleepEndMs = event.loggedAt + event.durationMinutes * 60_000;
        break;
      }
    }

    return {
      baby,
      sleepMinutes,
      feedCount,
      nappyCount,
      tummyMinutes,
      lastSleepEndMs,
      events,
      recentLoggedAts: recent.map((event) => event.loggedAt),
    };
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
    return await insertFeed(ctx, ctx.user._id, args);
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
    return await insertNappy(ctx, ctx.user._id, args);
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
    return await insertWeight(ctx, ctx.user._id, args);
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
    return await insertSleep(ctx, ctx.user._id, args);
  },
});

export const logTummy = authedMutation({
  args: {
    babyId: v.id("babies"),
    loggedAt: v.number(),
    durationMinutes: v.number(),
    note: v.optional(v.string()),
  },
  returns: v.id("events"),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    return await insertTummy(ctx, ctx.user._id, args);
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
    return await insertHeight(ctx, ctx.user._id, args);
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
    return await insertCustom(ctx, ctx.user._id, args);
  },
});

export const logPump = authedMutation({
  args: {
    babyId: v.id("babies"),
    loggedAt: v.number(),
    side: sideValidator,
    durationMinutes: v.number(),
    amountMl: v.optional(v.number()),
    note: v.optional(v.string()),
  },
  returns: v.id("events"),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    return await insertPump(ctx, ctx.user._id, args);
  },
});

export const logMedicine = authedMutation({
  args: {
    babyId: v.id("babies"),
    loggedAt: v.number(),
    title: v.string(),
    note: v.optional(v.string()),
  },
  returns: v.id("events"),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    return await insertMedicine(ctx, ctx.user._id, args);
  },
});

export const logPotty = authedMutation({
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
    return await insertPotty(ctx, ctx.user._id, args);
  },
});

export const logActivity = authedMutation({
  args: {
    babyId: v.id("babies"),
    loggedAt: v.number(),
    title: v.string(),
    durationMinutes: v.optional(v.number()),
    note: v.optional(v.string()),
  },
  returns: v.id("events"),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    return await insertActivity(ctx, ctx.user._id, args);
  },
});

export const remove = authedMutation({
  args: { eventId: v.id("events") },
  returns: v.null(),
  handler: async (ctx, args) => {
    const event = await ctx.db.get(args.eventId);
    if (!event) {
      throw new ConvexError("Event not found");
    }
    await requireBabyMember(ctx, event.babyId, ctx.user._id);
    const kind = event.kind;
    const babyId = event.babyId;
    await ctx.db.delete(args.eventId);
    if (kind === "weight") {
      await syncBabyWeight(ctx, babyId);
    }
    if (kind === "height") {
      await syncBabyHeight(ctx, babyId);
    }
    return null;
  },
});

const weekSleepSegmentValidator = v.object({
  kind: v.literal("sleep"),
  eventId: v.id("events"),
  startMs: v.number(),
  endMs: v.number(),
});

const weekTummySegmentValidator = v.object({
  kind: v.literal("tummy"),
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
  v.literal("pump"),
  v.literal("medicine"),
  v.literal("potty"),
  v.literal("activity"),
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
    tummies: v.array(weekTummySegmentValidator),
    markers: v.array(weekMarkerValidator),
  }),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    const weekStartMs = args.weekStartMs;
    const weekEndMs = weekStartMs + 7 * 86_400_000;
    // Include duration blocks that may have started slightly before the week.
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
    const tummies: {
      kind: "tummy";
      eventId: Id<"events">;
      startMs: number;
      endMs: number;
    }[] = [];
    const markers: {
      kind:
        | "feed"
        | "nappy"
        | "weight"
        | "height"
        | "custom"
        | "pump"
        | "medicine"
        | "potty"
        | "activity";
      eventId: Id<"events">;
      atMs: number;
    }[] = [];

    for (const event of events) {
      if (
        (event.kind === "sleep" || event.kind === "tummy") &&
        event.durationMinutes != null
      ) {
        const startMs = event.loggedAt;
        const endMs = startMs + event.durationMinutes * 60_000;
        if (endMs <= weekStartMs || startMs >= weekEndMs) continue;
        const segment = {
          eventId: event._id,
          startMs,
          endMs,
        };
        if (event.kind === "sleep") {
          sleeps.push({ kind: "sleep", ...segment });
        } else {
          tummies.push({ kind: "tummy", ...segment });
        }
        continue;
      }
      if (
        event.kind === "feed" ||
        event.kind === "nappy" ||
        event.kind === "weight" ||
        event.kind === "height" ||
        event.kind === "custom" ||
        event.kind === "pump" ||
        event.kind === "medicine" ||
        event.kind === "potty" ||
        event.kind === "activity"
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

    return { weekStartMs, sleeps, tummies, markers };
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

/** Bottle feeds without a timer still plot as a short mark on the day chart. */
const FEED_POINT_MINUTES = 5;

export const feedPatterns = authedQuery({
  args: {
    babyId: v.id("babies"),
    days: v.union(v.literal(7), v.literal(14), v.literal(30)),
    rangeEndMs: v.number(),
  },
  returns: v.object({
    feeds: v.array(sleepPatternItemValidator),
    stats: v.object({
      avgFeedMinutesPerDay: v.number(),
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
          .eq("kind", "feed")
          .gte("loggedAt", rangeStartMs - 86_400_000)
          .lt("loggedAt", rangeEndMs),
      )
      .order("asc")
      .take(400);

    const feeds: {
      startMs: number;
      endMs: number;
      durationMinutes: number;
    }[] = [];
    let totalTimedMinutes = 0;

    for (const event of events) {
      const hasTimer =
        event.durationMinutes != null && event.durationMinutes > 0;
      const durationMinutes = hasTimer
        ? event.durationMinutes!
        : FEED_POINT_MINUTES;
      const startMs = event.loggedAt;
      const endMs = startMs + durationMinutes * 60_000;
      if (endMs <= rangeStartMs || startMs >= rangeEndMs) continue;
      feeds.push({ startMs, endMs, durationMinutes });
      if (hasTimer) {
        const clippedStart = Math.max(startMs, rangeStartMs);
        const clippedEnd = Math.min(endMs, rangeEndMs);
        totalTimedMinutes += Math.max(
          0,
          (clippedEnd - clippedStart) / 60_000,
        );
      }
    }

    const days = args.days;
    return {
      feeds,
      stats: {
        avgFeedMinutesPerDay: days > 0 ? totalTimedMinutes / days : 0,
        avgSessionsPerDay: days > 0 ? feeds.length / days : 0,
      },
    };
  },
});

const NAPPY_POINT_MINUTES = 5;

export const nappyPatterns = authedQuery({
  args: {
    babyId: v.id("babies"),
    days: v.union(v.literal(7), v.literal(14), v.literal(30)),
    rangeEndMs: v.number(),
  },
  returns: v.object({
    nappies: v.array(sleepPatternItemValidator),
    stats: v.object({
      avgSessionsPerDay: v.number(),
      weeCount: v.number(),
      pooCount: v.number(),
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
          .eq("kind", "nappy")
          .gte("loggedAt", rangeStartMs)
          .lt("loggedAt", rangeEndMs),
      )
      .order("asc")
      .take(400);

    const nappies: {
      startMs: number;
      endMs: number;
      durationMinutes: number;
    }[] = [];
    let weeCount = 0;
    let pooCount = 0;

    for (const event of events) {
      const startMs = event.loggedAt;
      const endMs = startMs + NAPPY_POINT_MINUTES * 60_000;
      nappies.push({
        startMs,
        endMs,
        durationMinutes: NAPPY_POINT_MINUTES,
      });
      if (event.nappy === "wee" || event.nappy === "both") weeCount += 1;
      if (event.nappy === "poo" || event.nappy === "both") pooCount += 1;
    }

    const days = args.days;
    return {
      nappies,
      stats: {
        avgSessionsPerDay: days > 0 ? nappies.length / days : 0,
        weeCount,
        pooCount,
      },
    };
  },
});

export const tummyPatterns = authedQuery({
  args: {
    babyId: v.id("babies"),
    days: v.union(v.literal(7), v.literal(14), v.literal(30)),
    rangeEndMs: v.number(),
  },
  returns: v.object({
    tummies: v.array(sleepPatternItemValidator),
    stats: v.object({
      avgTummyMinutesPerDay: v.number(),
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
          .eq("kind", "tummy")
          .gte("loggedAt", rangeStartMs - 86_400_000)
          .lt("loggedAt", rangeEndMs),
      )
      .order("asc")
      .take(300);

    const tummies: {
      startMs: number;
      endMs: number;
      durationMinutes: number;
    }[] = [];

    for (const event of events) {
      if (event.durationMinutes == null) continue;
      const startMs = event.loggedAt;
      const endMs = startMs + event.durationMinutes * 60_000;
      if (endMs <= rangeStartMs || startMs >= rangeEndMs) continue;
      tummies.push({
        startMs,
        endMs,
        durationMinutes: event.durationMinutes,
      });
    }

    let totalMinutes = 0;
    for (const item of tummies) {
      const clippedStart = Math.max(item.startMs, rangeStartMs);
      const clippedEnd = Math.min(item.endMs, rangeEndMs);
      totalMinutes += Math.max(0, (clippedEnd - clippedStart) / 60_000);
    }
    const days = args.days;
    return {
      tummies,
      stats: {
        avgTummyMinutesPerDay: days > 0 ? totalMinutes / days : 0,
        avgSessionsPerDay: days > 0 ? tummies.length / days : 0,
      },
    };
  },
});
