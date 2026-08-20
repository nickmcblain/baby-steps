import { ConvexError, v } from "convex/values";
import { authedMutation, authedQuery } from "./lib/functions";
import { getMembership, requireBabyMember, uniqueInviteCode } from "./lib/access";
import { babyValidator } from "./lib/validators";

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
        babies.push(baby);
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
    return await requireBabyMember(ctx, args.babyId, ctx.user._id);
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

export const create = authedMutation({
  args: {
    name: v.string(),
    dateOfBirth: v.number(),
    weightGrams: v.number(),
    heightCm: v.optional(v.number()),
    notes: v.optional(v.string()),
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

    const inviteCode = await uniqueInviteCode(ctx);
    const babyId = await ctx.db.insert("babies", {
      name,
      dateOfBirth: args.dateOfBirth,
      weightGrams: Math.round(args.weightGrams),
      heightCm,
      notes: args.notes?.trim() || undefined,
      inviteCode,
      createdBy: ctx.user._id,
    });
    await ctx.db.insert("babyMembers", {
      babyId,
      userId: ctx.user._id,
    });
    return babyId;
  },
});

export const update = authedMutation({
  args: {
    babyId: v.id("babies"),
    name: v.string(),
    dateOfBirth: v.number(),
    weightGrams: v.number(),
    heightCm: v.optional(v.number()),
    notes: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    const name = args.name.trim();
    if (!name) {
      throw new ConvexError("Name is required");
    }
    if (!Number.isFinite(args.weightGrams) || args.weightGrams <= 0) {
      throw new ConvexError("Weight must be greater than 0");
    }
    const heightCm = normalizeHeightCm(args.heightCm);
    await ctx.db.patch(args.babyId, {
      name,
      dateOfBirth: args.dateOfBirth,
      weightGrams: Math.round(args.weightGrams),
      heightCm,
      notes: args.notes?.trim() || undefined,
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
    if (!Number.isFinite(args.tempC) || args.tempC < 5 || args.tempC > 40) {
      throw new ConvexError("Room temperature must be between 5 and 40°C");
    }
    await ctx.db.patch(args.babyId, { lastRoomTempC: args.tempC });
    return null;
  },
});

export const joinByCode = authedMutation({
  args: { code: v.string() },
  returns: v.id("babies"),
  handler: async (ctx, args) => {
    const inviteCode = args.code.trim().toUpperCase();
    if (inviteCode.length < 4) {
      throw new ConvexError("Invite code looks too short");
    }
    const baby = await ctx.db
      .query("babies")
      .withIndex("by_invite_code", (q) => q.eq("inviteCode", inviteCode))
      .unique();
    if (!baby) {
      throw new ConvexError("No baby matches that code");
    }
    const existing = await getMembership(ctx, baby._id, ctx.user._id);
    if (!existing) {
      await ctx.db.insert("babyMembers", {
        babyId: baby._id,
        userId: ctx.user._id,
      });
    }
    return baby._id;
  },
});
