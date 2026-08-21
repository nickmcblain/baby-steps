import { v } from "convex/values";
import { internalMutation } from "./_generated/server";
import { requireBabyMember } from "./lib/access";
import {
  insertCustom,
  insertFeed,
  insertHeight,
  insertNappy,
  insertSleep,
  insertTummy,
  insertWeight,
  patchRoomTemp,
} from "./lib/logEvents";
import {
  feedKindValidator,
  milkValidator,
  nappyKindValidator,
  sideValidator,
  sizeValidator,
} from "./lib/validators";

export const logFeed = internalMutation({
  args: {
    userId: v.id("users"),
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
    const { userId, ...rest } = args;
    await requireBabyMember(ctx, rest.babyId, userId);
    return await insertFeed(ctx, userId, rest);
  },
});

export const logNappy = internalMutation({
  args: {
    userId: v.id("users"),
    babyId: v.id("babies"),
    loggedAt: v.number(),
    nappy: nappyKindValidator,
    weeSize: v.optional(sizeValidator),
    pooSize: v.optional(sizeValidator),
    note: v.optional(v.string()),
  },
  returns: v.id("events"),
  handler: async (ctx, args) => {
    const { userId, ...rest } = args;
    await requireBabyMember(ctx, rest.babyId, userId);
    return await insertNappy(ctx, userId, rest);
  },
});

export const logWeight = internalMutation({
  args: {
    userId: v.id("users"),
    babyId: v.id("babies"),
    loggedAt: v.number(),
    weightGrams: v.number(),
    note: v.optional(v.string()),
  },
  returns: v.id("events"),
  handler: async (ctx, args) => {
    const { userId, ...rest } = args;
    await requireBabyMember(ctx, rest.babyId, userId);
    return await insertWeight(ctx, userId, rest);
  },
});

export const logSleep = internalMutation({
  args: {
    userId: v.id("users"),
    babyId: v.id("babies"),
    loggedAt: v.number(),
    durationMinutes: v.number(),
    note: v.optional(v.string()),
  },
  returns: v.id("events"),
  handler: async (ctx, args) => {
    const { userId, ...rest } = args;
    await requireBabyMember(ctx, rest.babyId, userId);
    return await insertSleep(ctx, userId, rest);
  },
});

export const logTummy = internalMutation({
  args: {
    userId: v.id("users"),
    babyId: v.id("babies"),
    loggedAt: v.number(),
    durationMinutes: v.number(),
    note: v.optional(v.string()),
  },
  returns: v.id("events"),
  handler: async (ctx, args) => {
    const { userId, ...rest } = args;
    await requireBabyMember(ctx, rest.babyId, userId);
    return await insertTummy(ctx, userId, rest);
  },
});

export const logHeight = internalMutation({
  args: {
    userId: v.id("users"),
    babyId: v.id("babies"),
    loggedAt: v.number(),
    heightCm: v.number(),
    note: v.optional(v.string()),
  },
  returns: v.id("events"),
  handler: async (ctx, args) => {
    const { userId, ...rest } = args;
    await requireBabyMember(ctx, rest.babyId, userId);
    return await insertHeight(ctx, userId, rest);
  },
});

export const logCustom = internalMutation({
  args: {
    userId: v.id("users"),
    babyId: v.id("babies"),
    loggedAt: v.number(),
    title: v.string(),
    note: v.optional(v.string()),
  },
  returns: v.id("events"),
  handler: async (ctx, args) => {
    const { userId, ...rest } = args;
    await requireBabyMember(ctx, rest.babyId, userId);
    return await insertCustom(ctx, userId, rest);
  },
});

export const saveRoomTemp = internalMutation({
  args: {
    userId: v.id("users"),
    babyId: v.id("babies"),
    tempC: v.number(),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, args.userId);
    await patchRoomTemp(ctx, args.babyId, args.tempC);
    return null;
  },
});
