import { ConvexError } from "convex/values";
import type { Id } from "../_generated/dataModel";
import type { MutationCtx } from "../_generated/server";

const MINUTE_MS = 60_000;
/** Appointments can be scheduled up to ~18 months ahead. */
const MAX_FUTURE_MS = 550 * 86_400_000;

export function snapLoggedAt(loggedAt: number, allowFuture = false): number {
  if (!Number.isFinite(loggedAt)) {
    throw new ConvexError("When is required");
  }
  const snapped = Math.round(loggedAt / MINUTE_MS) * MINUTE_MS;
  const now = Date.now() + MINUTE_MS;
  if (!allowFuture && snapped > now) {
    throw new ConvexError("Time can't be in the future");
  }
  if (allowFuture && snapped > Date.now() + MAX_FUTURE_MS) {
    throw new ConvexError("Date is too far in the future");
  }
  return snapped;
}

export async function syncBabyWeight(
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

export async function syncBabyHeight(
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

export async function insertFeed(
  ctx: MutationCtx,
  userId: Id<"users">,
  args: {
    babyId: Id<"babies">;
    loggedAt: number;
    feedKind: "breast" | "bottle";
    side?: "left" | "right" | "both";
    durationMinutes?: number;
    amountMl?: number;
    milk?: "formula" | "expressed";
    note?: string;
  },
): Promise<Id<"events">> {
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
    createdBy: userId,
    loggedAt: snapLoggedAt(args.loggedAt),
    kind: "feed",
    feedKind: args.feedKind,
    side: args.feedKind === "breast" ? args.side : undefined,
    durationMinutes: args.durationMinutes,
    amountMl: args.feedKind === "bottle" ? args.amountMl : undefined,
    milk: args.feedKind === "bottle" ? args.milk : undefined,
    note: args.note?.trim() || undefined,
  });
}

export async function insertNappy(
  ctx: MutationCtx,
  userId: Id<"users">,
  args: {
    babyId: Id<"babies">;
    loggedAt: number;
    nappy: "wee" | "poo" | "both";
    weeSize?: "small" | "medium" | "large";
    pooSize?: "small" | "medium" | "large";
    note?: string;
  },
): Promise<Id<"events">> {
  if ((args.nappy === "wee" || args.nappy === "both") && !args.weeSize) {
    throw new ConvexError("Wee size is required");
  }
  if ((args.nappy === "poo" || args.nappy === "both") && !args.pooSize) {
    throw new ConvexError("Poo size is required");
  }
  return await ctx.db.insert("events", {
    babyId: args.babyId,
    createdBy: userId,
    loggedAt: snapLoggedAt(args.loggedAt),
    kind: "nappy",
    nappy: args.nappy,
    weeSize:
      args.nappy === "wee" || args.nappy === "both" ? args.weeSize : undefined,
    pooSize:
      args.nappy === "poo" || args.nappy === "both" ? args.pooSize : undefined,
    note: args.note?.trim() || undefined,
  });
}

export async function insertWeight(
  ctx: MutationCtx,
  userId: Id<"users">,
  args: {
    babyId: Id<"babies">;
    loggedAt: number;
    weightGrams: number;
    note?: string;
  },
): Promise<Id<"events">> {
  if (!Number.isFinite(args.weightGrams) || args.weightGrams <= 0) {
    throw new ConvexError("Weight must be greater than 0");
  }
  const weightGrams = Math.round(args.weightGrams);
  const eventId = await ctx.db.insert("events", {
    babyId: args.babyId,
    createdBy: userId,
    loggedAt: snapLoggedAt(args.loggedAt),
    kind: "weight",
    weightGrams,
    note: args.note?.trim() || undefined,
  });
  await syncBabyWeight(ctx, args.babyId);
  return eventId;
}

export async function insertSleep(
  ctx: MutationCtx,
  userId: Id<"users">,
  args: {
    babyId: Id<"babies">;
    loggedAt: number;
    durationMinutes: number;
    note?: string;
  },
): Promise<Id<"events">> {
  if (
    !Number.isFinite(args.durationMinutes) ||
    args.durationMinutes < 1 ||
    args.durationMinutes > 24 * 60
  ) {
    throw new ConvexError("Sleep duration must be between 1 minute and 24 hours");
  }
  return await ctx.db.insert("events", {
    babyId: args.babyId,
    createdBy: userId,
    loggedAt: snapLoggedAt(args.loggedAt),
    kind: "sleep",
    durationMinutes: Math.round(args.durationMinutes),
    note: args.note?.trim() || undefined,
  });
}

export async function insertTummy(
  ctx: MutationCtx,
  userId: Id<"users">,
  args: {
    babyId: Id<"babies">;
    loggedAt: number;
    durationMinutes: number;
    note?: string;
  },
): Promise<Id<"events">> {
  if (
    !Number.isFinite(args.durationMinutes) ||
    args.durationMinutes < 1 ||
    args.durationMinutes > 3 * 60
  ) {
    throw new ConvexError("Tummy time must be between 1 minute and 3 hours");
  }
  return await ctx.db.insert("events", {
    babyId: args.babyId,
    createdBy: userId,
    loggedAt: snapLoggedAt(args.loggedAt),
    kind: "tummy",
    durationMinutes: Math.round(args.durationMinutes),
    note: args.note?.trim() || undefined,
  });
}

export async function insertHeight(
  ctx: MutationCtx,
  userId: Id<"users">,
  args: {
    babyId: Id<"babies">;
    loggedAt: number;
    heightCm: number;
    note?: string;
  },
): Promise<Id<"events">> {
  if (!Number.isFinite(args.heightCm) || args.heightCm <= 0) {
    throw new ConvexError("Height must be greater than 0");
  }
  if (args.heightCm < 30 || args.heightCm > 130) {
    throw new ConvexError("Height looks out of range");
  }
  const heightCm = Math.round(args.heightCm * 10) / 10;
  const eventId = await ctx.db.insert("events", {
    babyId: args.babyId,
    createdBy: userId,
    loggedAt: snapLoggedAt(args.loggedAt),
    kind: "height",
    heightCm,
    note: args.note?.trim() || undefined,
  });
  await syncBabyHeight(ctx, args.babyId);
  return eventId;
}

export async function insertPump(
  ctx: MutationCtx,
  userId: Id<"users">,
  args: {
    babyId: Id<"babies">;
    loggedAt: number;
    side: "left" | "right" | "both";
    durationMinutes: number;
    amountMl?: number;
    note?: string;
  },
): Promise<Id<"events">> {
  if (
    !Number.isFinite(args.durationMinutes) ||
    args.durationMinutes < 1 ||
    args.durationMinutes > 3 * 60
  ) {
    throw new ConvexError("Pump time must be between 1 minute and 3 hours");
  }
  if (args.amountMl != null && (!Number.isFinite(args.amountMl) || args.amountMl <= 0)) {
    throw new ConvexError("Amount must be greater than 0");
  }
  return await ctx.db.insert("events", {
    babyId: args.babyId,
    createdBy: userId,
    loggedAt: snapLoggedAt(args.loggedAt),
    kind: "pump",
    side: args.side,
    durationMinutes: Math.round(args.durationMinutes),
    amountMl: args.amountMl != null ? Math.round(args.amountMl) : undefined,
    note: args.note?.trim() || undefined,
  });
}

export async function insertMedicine(
  ctx: MutationCtx,
  userId: Id<"users">,
  args: {
    babyId: Id<"babies">;
    loggedAt: number;
    title: string;
    note?: string;
  },
): Promise<Id<"events">> {
  const title = args.title.trim();
  if (title.length < 1 || title.length > 80) {
    throw new ConvexError("Give the medicine a name");
  }
  return await ctx.db.insert("events", {
    babyId: args.babyId,
    createdBy: userId,
    loggedAt: snapLoggedAt(args.loggedAt),
    kind: "medicine",
    title,
    note: args.note?.trim() || undefined,
  });
}

export async function insertPotty(
  ctx: MutationCtx,
  userId: Id<"users">,
  args: {
    babyId: Id<"babies">;
    loggedAt: number;
    nappy: "wee" | "poo" | "both";
    weeSize?: "small" | "medium" | "large";
    pooSize?: "small" | "medium" | "large";
    note?: string;
  },
): Promise<Id<"events">> {
  if ((args.nappy === "wee" || args.nappy === "both") && !args.weeSize) {
    throw new ConvexError("Wee size is required");
  }
  if ((args.nappy === "poo" || args.nappy === "both") && !args.pooSize) {
    throw new ConvexError("Poo size is required");
  }
  return await ctx.db.insert("events", {
    babyId: args.babyId,
    createdBy: userId,
    loggedAt: snapLoggedAt(args.loggedAt),
    kind: "potty",
    nappy: args.nappy,
    weeSize:
      args.nappy === "wee" || args.nappy === "both" ? args.weeSize : undefined,
    pooSize:
      args.nappy === "poo" || args.nappy === "both" ? args.pooSize : undefined,
    note: args.note?.trim() || undefined,
  });
}

export async function insertActivity(
  ctx: MutationCtx,
  userId: Id<"users">,
  args: {
    babyId: Id<"babies">;
    loggedAt: number;
    title: string;
    durationMinutes?: number;
    note?: string;
  },
): Promise<Id<"events">> {
  const title = args.title.trim();
  if (title.length < 1 || title.length > 80) {
    throw new ConvexError("Pick an activity");
  }
  if (
    args.durationMinutes != null &&
    (!Number.isFinite(args.durationMinutes) ||
      args.durationMinutes < 1 ||
      args.durationMinutes > 6 * 60)
  ) {
    throw new ConvexError("Duration must be between 1 minute and 6 hours");
  }
  return await ctx.db.insert("events", {
    babyId: args.babyId,
    createdBy: userId,
    loggedAt: snapLoggedAt(args.loggedAt),
    kind: "activity",
    title,
    durationMinutes:
      args.durationMinutes != null ? Math.round(args.durationMinutes) : undefined,
    note: args.note?.trim() || undefined,
  });
}

export async function insertCustom(
  ctx: MutationCtx,
  userId: Id<"users">,
  args: {
    babyId: Id<"babies">;
    loggedAt: number;
    title: string;
    note?: string;
  },
): Promise<Id<"events">> {
  const title = args.title.trim();
  if (title.length < 1 || title.length > 80) {
    throw new ConvexError("Give the event a short title");
  }
  return await ctx.db.insert("events", {
    babyId: args.babyId,
    createdBy: userId,
    loggedAt: snapLoggedAt(args.loggedAt, true),
    kind: "custom",
    title,
    note: args.note?.trim() || undefined,
  });
}

export async function patchRoomTemp(
  ctx: MutationCtx,
  babyId: Id<"babies">,
  tempC: number,
): Promise<void> {
  if (!Number.isFinite(tempC) || tempC < 5 || tempC > 40) {
    throw new ConvexError("Room temperature must be between 5 and 40°C");
  }
  await ctx.db.patch(babyId, { lastRoomTempC: tempC });
}
