import { v } from "convex/values";

export const eventKindValidator = v.union(
  v.literal("feed"),
  v.literal("nappy"),
);

export const feedKindValidator = v.union(
  v.literal("breast"),
  v.literal("bottle"),
);

export const sideValidator = v.union(
  v.literal("left"),
  v.literal("right"),
  v.literal("both"),
);

export const milkValidator = v.union(
  v.literal("formula"),
  v.literal("expressed"),
);

export const nappyKindValidator = v.union(
  v.literal("wee"),
  v.literal("poo"),
  v.literal("both"),
);

export const sizeValidator = v.union(
  v.literal("small"),
  v.literal("medium"),
  v.literal("large"),
);

export const userValidator = v.object({
  _id: v.id("users"),
  _creationTime: v.number(),
  tokenIdentifier: v.string(),
  name: v.string(),
  email: v.optional(v.string()),
});

export const babyValidator = v.object({
  _id: v.id("babies"),
  _creationTime: v.number(),
  name: v.string(),
  dateOfBirth: v.number(),
  weightGrams: v.number(),
  heightCm: v.optional(v.number()),
  notes: v.optional(v.string()),
  inviteCode: v.string(),
  lastRoomTempC: v.optional(v.number()),
  createdBy: v.id("users"),
});

export const eventValidator = v.object({
  _id: v.id("events"),
  _creationTime: v.number(),
  babyId: v.id("babies"),
  createdBy: v.id("users"),
  loggedAt: v.number(),
  kind: eventKindValidator,
  feedKind: v.optional(feedKindValidator),
  side: v.optional(sideValidator),
  durationMinutes: v.optional(v.number()),
  amountMl: v.optional(v.number()),
  milk: v.optional(milkValidator),
  nappy: v.optional(nappyKindValidator),
  weeSize: v.optional(sizeValidator),
  pooSize: v.optional(sizeValidator),
  note: v.optional(v.string()),
});
