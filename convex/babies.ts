import { ConvexError, v } from "convex/values";
import { authedMutation, authedQuery } from "./lib/functions";
import { requireBabyMember } from "./lib/access";
import { createInvite as createInviteCode, redeemInvite, visibleBaby } from "./lib/sharing";
import { patchRoomTemp } from "./lib/logEvents";
import {
  babyValidator,
  deliveryTypeValidator,
  feedingModeValidator,
  sexValidator,
} from "./lib/validators";

export const list = authedQuery({
  args: {},
  returns: v.array(babyValidator),
  handler: async (ctx) => {
    const memberships = await ctx.db
      .query("babyMembers")
      .withIndex("by_user", (q) => q.eq("userId", ctx.user._id))
      .collect();
    const babies = [];
    for (const membership of memberships) {
      const baby = await ctx.db.get(membership.babyId);
      if (baby) {
        babies.push(await visibleBaby(ctx, baby, ctx.user._id));
      }
    }
    babies.sort((a, b) => a.name.localeCompare(b.name));
    return babies;
  },
});

export const get = authedQuery({
  args: { babyId: v.id("babies") },
  returns: babyValidator,
  handler: async (ctx, args) => {
    const baby = await requireBabyMember(ctx, args.babyId, ctx.user._id);
    return await visibleBaby(ctx, baby, ctx.user._id);
  },
});

function normalizeHeightCm(heightCm: number | undefined): number | undefined {
  if (heightCm === undefined) return undefined;
  if (!Number.isFinite(heightCm) || heightCm <= 0) {
    throw new ConvexError("Height must be greater than 0");
  }
  if (heightCm < 30 || heightCm > 130) {
    throw new ConvexError("Height looks out of range");
  }
  return Math.round(heightCm * 10) / 10;
}

export const CARE_DATA_CONSENT_VERSION = "care-data-v1";

export const create = authedMutation({
  args: {
    name: v.string(),
    dateOfBirth: v.number(),
    weightGrams: v.number(),
    heightCm: v.optional(v.number()),
    sex: v.optional(sexValidator),
    notes: v.optional(v.string()),
    careDataConsent: v.literal(true),
  },
  returns: v.id("babies"),
  handler: async (ctx, args) => {
    const name = args.name.trim();
    if (!name) {
      throw new ConvexError("Name is required");
    }
    if (!Number.isFinite(args.dateOfBirth) || args.dateOfBirth <= 0) {
      throw new ConvexError("Date of birth is required");
    }
    if (!Number.isFinite(args.weightGrams) || args.weightGrams <= 0) {
      throw new ConvexError("Weight must be greater than 0");
    }
    const heightCm = normalizeHeightCm(args.heightCm);

    const weightGrams = Math.round(args.weightGrams);
    const babyId = await ctx.db.insert("babies", {
      name,
      dateOfBirth: args.dateOfBirth,
      weightGrams,
      heightCm,
      sex: args.sex,
      notes: args.notes?.trim() || undefined,
      createdBy: ctx.user._id,
      careDataConsentAt: Date.now(),
      careDataConsentVersion: CARE_DATA_CONSENT_VERSION,
    });
    await ctx.db.insert("babyMembers", {
      babyId,
      userId: ctx.user._id,
    });
    const loggedAt = Math.round(Date.now() / 60_000) * 60_000;
    await ctx.db.insert("events", {
      babyId,
      createdBy: ctx.user._id,
      loggedAt,
      kind: "weight",
      weightGrams,
    });
    if (heightCm != null) {
      await ctx.db.insert("events", {
        babyId,
        createdBy: ctx.user._id,
        loggedAt,
        kind: "height",
        heightCm,
      });
    }
    return babyId;
  },
});

export const update = authedMutation({
  args: {
    babyId: v.id("babies"),
    name: v.string(),
    dateOfBirth: v.number(),
    notes: v.optional(v.string()),
    sex: v.optional(sexValidator),
    deliveryType: v.optional(deliveryTypeValidator),
    gestationWeeks: v.optional(v.number()),
    feedingMode: v.optional(feedingModeValidator),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    const name = args.name.trim();
    if (!name) {
      throw new ConvexError("Name is required");
    }
    if (
      args.gestationWeeks !== undefined &&
      (!Number.isFinite(args.gestationWeeks) ||
        args.gestationWeeks < 22 ||
        args.gestationWeeks > 44)
    ) {
      throw new ConvexError("Gestation weeks look out of range");
    }
    await ctx.db.patch(args.babyId, {
      name,
      dateOfBirth: args.dateOfBirth,
      notes: args.notes?.trim() || undefined,
      sex: args.sex,
      deliveryType: args.deliveryType,
      gestationWeeks: args.gestationWeeks,
      feedingMode: args.feedingMode,
    });
    return null;
  },
});

export const setNightWindow = authedMutation({
  args: {
    babyId: v.id("babies"),
    bedMin: v.union(v.number(), v.null()),
    wakeMin: v.union(v.number(), v.null()),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    if (args.bedMin === null || args.wakeMin === null) {
      await ctx.db.patch(args.babyId, { nightBedMin: undefined, nightWakeMin: undefined });
      return null;
    }
    const length = (args.wakeMin - args.bedMin + 1440) % 1440;
    if (
      !Number.isInteger(args.bedMin) ||
      !Number.isInteger(args.wakeMin) ||
      args.bedMin < 0 ||
      args.bedMin >= 1440 ||
      args.wakeMin < 0 ||
      args.wakeMin >= 1440 ||
      length < 4 * 60 ||
      length > 14 * 60
    ) {
      throw new ConvexError("Night window looks out of range");
    }
    await ctx.db.patch(args.babyId, {
      nightBedMin: args.bedMin,
      nightWakeMin: args.wakeMin,
    });
    return null;
  },
});

export const saveRoomTemp = authedMutation({
  args: {
    babyId: v.id("babies"),
    tempC: v.number(),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    await patchRoomTemp(ctx, args.babyId, args.tempC);
    return null;
  },
});

/** A share code for this baby. Each carer needs their own subscription to share. */
export const createInvite = authedMutation({
  args: { babyId: v.id("babies") },
  returns: v.string(),
  handler: async (ctx, args) => await createInviteCode(ctx, ctx.user._id, args.babyId),
});

/** Redeems a share code. The joining carer needs their own subscription. */
export const joinByCode = authedMutation({
  args: { code: v.string() },
  returns: v.id("babies"),
  handler: async (ctx, args) => await redeemInvite(ctx, ctx.user._id, args.code),
});

const MAX_PHOTO_BYTES = 5 * 1024 * 1024;

export const photoUrl = authedQuery({
  args: { babyId: v.id("babies") },
  returns: v.union(v.string(), v.null()),
  handler: async (ctx, args) => {
    const baby = await requireBabyMember(ctx, args.babyId, ctx.user._id);
    return baby.photoId ? await ctx.storage.getUrl(baby.photoId) : null;
  },
});

export const generatePhotoUploadUrl = authedMutation({
  args: { babyId: v.id("babies") },
  returns: v.string(),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    return await ctx.storage.generateUploadUrl();
  },
});

export const setPhoto = authedMutation({
  args: { babyId: v.id("babies"), storageId: v.id("_storage") },
  returns: v.null(),
  handler: async (ctx, args) => {
    const baby = await requireBabyMember(ctx, args.babyId, ctx.user._id);
    const file = await ctx.db.system.get(args.storageId);
    if (!file) {
      throw new ConvexError("Photo upload not found");
    }
    if (!file.contentType?.startsWith("image/") || file.size > MAX_PHOTO_BYTES) {
      await ctx.storage.delete(args.storageId);
      throw new ConvexError("Photo must be an image under 5 MB");
    }
    if (baby.photoId && baby.photoId !== args.storageId) {
      await ctx.storage.delete(baby.photoId);
    }
    await ctx.db.patch(args.babyId, { photoId: args.storageId });
    return null;
  },
});

export const removePhoto = authedMutation({
  args: { babyId: v.id("babies") },
  returns: v.null(),
  handler: async (ctx, args) => {
    const baby = await requireBabyMember(ctx, args.babyId, ctx.user._id);
    if (baby.photoId) {
      await ctx.storage.delete(baby.photoId);
      await ctx.db.patch(args.babyId, { photoId: undefined });
    }
    return null;
  },
});

/** Kept in step with `Milestone` in ios-native ScrunchCore/Delight.swift. */
const MILESTONE_KEYS = new Set([
  "firstSmile",
  "firstLaugh",
  "rolledOver",
  "satUp",
  "firstTooth",
  "firstFood",
  "crawled",
  "firstSteps",
]);

const milestoneMarkValidator = v.object({
  key: v.string(),
  reachedAt: v.number(),
});

export const milestones = authedQuery({
  args: { babyId: v.id("babies") },
  returns: v.array(milestoneMarkValidator),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    const rows = await ctx.db
      .query("milestones")
      .withIndex("by_baby_and_key", (q) => q.eq("babyId", args.babyId))
      .take(MILESTONE_KEYS.size * 2);
    return rows.map((row) => ({ key: row.key, reachedAt: row.reachedAt }));
  },
});

export const setMilestone = authedMutation({
  args: { babyId: v.id("babies"), key: v.string(), reachedAt: v.number() },
  returns: v.null(),
  handler: async (ctx, args) => {
    const baby = await requireBabyMember(ctx, args.babyId, ctx.user._id);
    if (!MILESTONE_KEYS.has(args.key)) {
      throw new ConvexError("Unknown milestone");
    }
    if (
      !Number.isFinite(args.reachedAt) ||
      args.reachedAt < baby.dateOfBirth - 86_400_000 ||
      args.reachedAt > Date.now() + 60_000
    ) {
      throw new ConvexError("Pick a date between birth and today");
    }
    const existing = await ctx.db
      .query("milestones")
      .withIndex("by_baby_and_key", (q) =>
        q.eq("babyId", args.babyId).eq("key", args.key),
      )
      .unique();
    if (existing) {
      await ctx.db.patch(existing._id, { reachedAt: args.reachedAt });
    } else {
      await ctx.db.insert("milestones", {
        babyId: args.babyId,
        key: args.key,
        reachedAt: args.reachedAt,
        createdBy: ctx.user._id,
      });
    }
    return null;
  },
});

export const clearMilestone = authedMutation({
  args: { babyId: v.id("babies"), key: v.string() },
  returns: v.null(),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    const existing = await ctx.db
      .query("milestones")
      .withIndex("by_baby_and_key", (q) =>
        q.eq("babyId", args.babyId).eq("key", args.key),
      )
      .unique();
    if (existing) {
      await ctx.db.delete(existing._id);
    }
    return null;
  },
});
