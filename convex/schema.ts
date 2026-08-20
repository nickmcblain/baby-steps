import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";
import {
  eventKindValidator,
  feedKindValidator,
  milkValidator,
  nappyKindValidator,
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
    notes: v.optional(v.string()),
    inviteCode: v.string(),
    lastRoomTempC: v.optional(v.number()),
    createdBy: v.id("users"),
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
    note: v.optional(v.string()),
  })
    .index("by_baby_kind_loggedAt", ["babyId", "kind", "loggedAt"])
    .index("by_baby_and_loggedAt", ["babyId", "loggedAt"]),
});
