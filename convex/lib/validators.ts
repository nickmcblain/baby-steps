import { v } from "convex/values";

export const eventKindValidator = v.union(
  v.literal("feed"),
  v.literal("nappy"),
  v.literal("weight"),
  v.literal("height"),
  v.literal("sleep"),
  v.literal("tummy"),
  v.literal("custom"),
  v.literal("pump"),
  v.literal("medicine"),
  v.literal("potty"),
  v.literal("activity"),
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

export const sexValidator = v.union(v.literal("boy"), v.literal("girl"));

export const sizeValidator = v.union(
  v.literal("small"),
  v.literal("medium"),
  v.literal("large"),
);

export const deliveryTypeValidator = v.union(
  v.literal("vaginal"),
  v.literal("c_section"),
);

export const feedingModeValidator = v.union(
  v.literal("breast"),
  v.literal("bottle"),
  v.literal("mixed"),
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
  sex: v.optional(sexValidator),
  notes: v.optional(v.string()),
  inviteCode: v.string(),
  lastRoomTempC: v.optional(v.number()),
  deliveryType: v.optional(deliveryTypeValidator),
  gestationWeeks: v.optional(v.number()),
  feedingMode: v.optional(feedingModeValidator),
  createdBy: v.id("users"),
  careDataConsentAt: v.optional(v.number()),
  careDataConsentVersion: v.optional(v.string()),
});

export const citationValidator = v.object({
  title: v.string(),
  url: v.optional(v.string()),
});

export const chatRoleValidator = v.union(
  v.literal("user"),
  v.literal("assistant"),
  v.literal("system"),
);

export const chatThreadValidator = v.object({
  _id: v.id("chatThreads"),
  _creationTime: v.number(),
  babyId: v.id("babies"),
  createdBy: v.id("users"),
  title: v.optional(v.string()),
  updatedAt: v.number(),
});

export const chatMessageValidator = v.object({
  _id: v.id("chatMessages"),
  _creationTime: v.number(),
  threadId: v.id("chatThreads"),
  babyId: v.id("babies"),
  role: chatRoleValidator,
  content: v.string(),
  citations: v.optional(v.array(citationValidator)),
  createdAt: v.number(),
});

export const babyMemoryValidator = v.object({
  _id: v.id("babyMemories"),
  _creationTime: v.number(),
  babyId: v.id("babies"),
  key: v.string(),
  content: v.string(),
  sourceThreadId: v.optional(v.id("chatThreads")),
  updatedAt: v.number(),
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
  weightGrams: v.optional(v.number()),
  heightCm: v.optional(v.number()),
  title: v.optional(v.string()),
  note: v.optional(v.string()),
});
