import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";
import {
  chatRoleValidator,
  citationValidator,
  deliveryTypeValidator,
  eventKindValidator,
  feedKindValidator,
  feedingModeValidator,
  milkValidator,
  nappyKindValidator,
  sexValidator,
  sideValidator,
  sizeValidator,
} from "./lib/validators";

export default defineSchema({
  users: defineTable({
    tokenIdentifier: v.string(),
    name: v.string(),
    email: v.optional(v.string()),
  }).index("by_token", ["tokenIdentifier"]),

  babies: defineTable({
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
    /** Parent/guardian consented to store this baby's care details (UK GDPR). */
    careDataConsentAt: v.optional(v.number()),
    careDataConsentVersion: v.optional(v.string()),
  })
    .index("by_creator", ["createdBy"])
    .index("by_invite_code", ["inviteCode"]),

  babyMembers: defineTable({
    babyId: v.id("babies"),
    userId: v.id("users"),
  })
    .index("by_baby", ["babyId"])
    .index("by_user", ["userId"])
    .index("by_baby_and_user", ["babyId", "userId"]),

  events: defineTable({
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
  })
    .index("by_baby_kind_loggedAt", ["babyId", "kind", "loggedAt"])
    .index("by_baby_and_loggedAt", ["babyId", "loggedAt"]),

  chatThreads: defineTable({
    babyId: v.id("babies"),
    createdBy: v.id("users"),
    title: v.optional(v.string()),
    updatedAt: v.number(),
  }).index("by_baby", ["babyId"]),

  chatMessages: defineTable({
    threadId: v.id("chatThreads"),
    babyId: v.id("babies"),
    role: chatRoleValidator,
    content: v.string(),
    citations: v.optional(v.array(citationValidator)),
    createdAt: v.number(),
  }).index("by_thread", ["threadId"]),

  /** Durable facts the Ask agent should recall across chat threads. */
  babyMemories: defineTable({
    babyId: v.id("babies"),
    key: v.string(),
    content: v.string(),
    sourceThreadId: v.optional(v.id("chatThreads")),
    updatedAt: v.number(),
    createdBy: v.id("users"),
  })
    .index("by_baby", ["babyId"])
    .index("by_baby_and_key", ["babyId", "key"]),
});
