import { ConvexError, v } from "convex/values";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import {
  action,
  internalMutation,
  type MutationCtx,
} from "./_generated/server";
import { getUserByToken } from "./lib/auth";

const BATCH = 400;

const deletedDataValidator = v.object({
  deletedBabies: v.number(),
  leftSharedBabies: v.number(),
});

/**
 * Deletes the signed-in user's Scrunch data, then their Clerk user when
 * CLERK_SECRET_KEY is set. `signInDeleted: false` tells the app to delete the
 * Clerk user itself with the client SDK.
 */
export const deleteAccount = action({
  args: {},
  returns: deletedDataValidator.extend({ signInDeleted: v.boolean() }),
  handler: async (
    ctx,
  ): Promise<{
    deletedBabies: number;
    leftSharedBabies: number;
    signInDeleted: boolean;
  }> => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      throw new ConvexError("Not authenticated");
    }
    const result = await ctx.runMutation(internal.account.deleteUserData, {
      tokenIdentifier: identity.tokenIdentifier,
    });
    const signInDeleted = await deleteClerkUser(identity.subject);
    return { ...result, signInDeleted };
  },
});

async function deleteClerkUser(clerkUserId: string): Promise<boolean> {
  const secret = process.env.CLERK_SECRET_KEY;
  if (!secret) return false;
  const response = await fetch(
    `https://api.clerk.com/v1/users/${encodeURIComponent(clerkUserId)}`,
    { method: "DELETE", headers: { Authorization: `Bearer ${secret}` } },
  );
  if (response.ok || response.status === 404) return true;
  console.error("Clerk user deletion failed", response.status);
  return false;
}

/**
 * Babies only this user can see are deleted with all their logs and chats.
 * Babies shared with a partner stay for the partner; this user's membership,
 * Ask chats and remembered facts go.
 */
export const deleteUserData = internalMutation({
  args: { tokenIdentifier: v.string() },
  returns: deletedDataValidator,
  handler: async (ctx, args) => {
    const user = await getUserByToken(ctx, args.tokenIdentifier);
    if (!user) {
      return { deletedBabies: 0, leftSharedBabies: 0 };
    }

    let deletedBabies = 0;
    let leftSharedBabies = 0;
    const memberships = await ctx.db
      .query("babyMembers")
      .withIndex("by_user", (q) => q.eq("userId", user._id))
      .collect();

    for (const membership of memberships) {
      await ctx.db.delete(membership._id);
      await deleteOwnAllowances(ctx, membership.babyId, user._id);
      const baby = await ctx.db.get(membership.babyId);
      if (!baby) continue;

      const others = await ctx.db
        .query("babyMembers")
        .withIndex("by_baby", (q) => q.eq("babyId", baby._id))
        .take(1);

      if (others.length === 0) {
        // Deleting the baby first revokes access and its invite code straight away.
        await ctx.db.delete(baby._id);
        if (baby.photoId) await ctx.storage.delete(baby.photoId);
        await ctx.scheduler.runAfter(0, internal.account.purgeBabyData, {
          babyId: baby._id,
        });
        deletedBabies += 1;
        continue;
      }

      if (baby.createdBy === user._id) {
        await ctx.db.patch(baby._id, { createdBy: others[0].userId });
      }
      const milestones = await ctx.db
        .query("milestones")
        .withIndex("by_baby_and_key", (q) => q.eq("babyId", baby._id))
        .collect();
      for (const milestone of milestones) {
        if (milestone.createdBy === user._id) {
          await ctx.db.patch(milestone._id, { createdBy: others[0].userId });
        }
      }
      await deleteOwnChats(ctx, baby._id, user._id);
      leftSharedBabies += 1;
    }

    // The App Store subscription itself is managed (and cancelled) in the user's Apple account.
    const subscriptions = await ctx.db
      .query("subscriptions")
      .withIndex("by_user", (q) => q.eq("userId", user._id))
      .collect();
    for (const subscription of subscriptions) await ctx.db.delete(subscription._id);

    await ctx.db.delete(user._id);
    return { deletedBabies, leftSharedBabies };
  },
});

/** Free-entry counts for this carer on one baby (one row per log type). */
async function deleteOwnAllowances(
  ctx: MutationCtx,
  babyId: Id<"babies">,
  userId: Id<"users">,
) {
  const rows = await ctx.db
    .query("logAllowances")
    .withIndex("by_baby_and_user_and_type", (q) => q.eq("babyId", babyId).eq("userId", userId))
    .collect();
  for (const row of rows) await ctx.db.delete(row._id);
}

async function deleteOwnChats(
  ctx: MutationCtx,
  babyId: Id<"babies">,
  userId: Id<"users">,
) {
  const threads = await ctx.db
    .query("chatThreads")
    .withIndex("by_baby", (q) => q.eq("babyId", babyId))
    .collect();
  for (const thread of threads) {
    if (thread.createdBy !== userId) continue;
    await ctx.db.delete(thread._id);
    await ctx.scheduler.runAfter(0, internal.account.purgeThreadMessages, {
      threadId: thread._id,
    });
  }
  const memories = await ctx.db
    .query("babyMemories")
    .withIndex("by_baby", (q) => q.eq("babyId", babyId))
    .collect();
  for (const memory of memories) {
    if (memory.createdBy === userId) {
      await ctx.db.delete(memory._id);
    }
  }
}

/** Deletes a removed baby's logs, chats and memories in batches. */
export const purgeBabyData = internalMutation({
  args: { babyId: v.id("babies") },
  returns: v.null(),
  handler: async (ctx, args) => {
    const again = () =>
      ctx.scheduler.runAfter(0, internal.account.purgeBabyData, args);

    const events = await ctx.db
      .query("events")
      .withIndex("by_baby_and_loggedAt", (q) => q.eq("babyId", args.babyId))
      .take(BATCH);
    for (const event of events) await ctx.db.delete(event._id);
    if (events.length === BATCH) {
      await again();
      return null;
    }

    const threads = await ctx.db
      .query("chatThreads")
      .withIndex("by_baby", (q) => q.eq("babyId", args.babyId))
      .take(20);
    for (const thread of threads) {
      await ctx.db.delete(thread._id);
      await ctx.scheduler.runAfter(0, internal.account.purgeThreadMessages, {
        threadId: thread._id,
      });
    }
    if (threads.length === 20) {
      await again();
      return null;
    }

    const memories = await ctx.db
      .query("babyMemories")
      .withIndex("by_baby", (q) => q.eq("babyId", args.babyId))
      .take(BATCH);
    for (const memory of memories) await ctx.db.delete(memory._id);
    if (memories.length === BATCH) {
      await again();
      return null;
    }

    const milestones = await ctx.db
      .query("milestones")
      .withIndex("by_baby_and_key", (q) => q.eq("babyId", args.babyId))
      .take(BATCH);
    for (const milestone of milestones) await ctx.db.delete(milestone._id);
    if (milestones.length === BATCH) {
      await again();
      return null;
    }

    // Counts left by carers who had already left this baby.
    const allowances = await ctx.db
      .query("logAllowances")
      .withIndex("by_baby_and_user_and_type", (q) => q.eq("babyId", args.babyId))
      .take(BATCH);
    for (const row of allowances) await ctx.db.delete(row._id);
    if (allowances.length === BATCH) {
      await again();
    }
    return null;
  },
});

export const purgeThreadMessages = internalMutation({
  args: { threadId: v.id("chatThreads") },
  returns: v.null(),
  handler: async (ctx, args) => {
    const messages = await ctx.db
      .query("chatMessages")
      .withIndex("by_thread", (q) => q.eq("threadId", args.threadId))
      .take(BATCH);
    for (const message of messages) await ctx.db.delete(message._id);
    if (messages.length === BATCH) {
      await ctx.scheduler.runAfter(0, internal.account.purgeThreadMessages, args);
    }
    return null;
  },
});
