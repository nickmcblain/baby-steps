import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { internalMutation, type MutationCtx } from "./_generated/server";
import { getUserByToken } from "./lib/auth";
import { mayClaim, subscriptionStateValidator, type SubscriptionState } from "./lib/appStore";
import { authedMutation } from "./lib/functions";

async function rowForUser(ctx: MutationCtx, userId: Id<"users">) {
  return await ctx.db
    .query("subscriptions")
    .withIndex("by_user", (q) => q.eq("userId", userId))
    .unique();
}

async function ensureRow(ctx: MutationCtx, userId: Id<"users">): Promise<Doc<"subscriptions">> {
  const existing = await rowForUser(ctx, userId);
  if (existing) return existing;
  const id = await ctx.db.insert("subscriptions", {
    userId,
    appAccountToken: crypto.randomUUID(),
    status: "none",
    updatedAt: Date.now(),
  });
  const created = await ctx.db.get(id);
  if (!created) throw new Error("Subscription row missing after insert");
  return created;
}

async function applyState(ctx: MutationCtx, row: Doc<"subscriptions">, state: SubscriptionState) {
  if (row.signedAt !== undefined && row.signedAt > state.signedAt) return;
  const { willAutoRenew, ...rest } = state;
  await ctx.db.patch(row._id, {
    ...rest,
    // Transactions from the app carry no renewal info; keep what the last notification said.
    ...(willAutoRenew === undefined ? {} : { willAutoRenew }),
    updatedAt: Date.now(),
  });
}

/** The stable UUID the app passes to StoreKit as appAccountToken. */
export const accountToken = authedMutation({
  args: {},
  returns: v.string(),
  handler: async (ctx) => (await ensureRow(ctx, ctx.user._id)).appAccountToken,
});

/** A verified transaction the signed-in user's app sent us. False if it belongs to someone else. */
export const applyForUser = internalMutation({
  args: {
    tokenIdentifier: v.string(),
    transactionToken: v.optional(v.string()),
    state: subscriptionStateValidator,
  },
  returns: v.boolean(),
  handler: async (ctx, args) => {
    const user = await getUserByToken(ctx, args.tokenIdentifier);
    if (!user) return false;
    const row = await ensureRow(ctx, user._id);
    const claimed = await ctx.db
      .query("subscriptions")
      .withIndex("by_original_transaction_id", (q) =>
        q.eq("originalTransactionId", args.state.originalTransactionId),
      )
      .take(10);
    const claimedBy = claimed.find((other) => other.userId !== user._id)?.userId ?? null;
    const allowed = mayClaim({
      familyShared: args.state.familyShared,
      transactionToken: args.transactionToken,
      myToken: row.appAccountToken,
      claimedBy,
      userId: user._id,
    });
    if (!allowed) {
      console.warn("Transaction belongs to a different Scrunch account");
      return false;
    }
    await applyState(ctx, row, args.state);
    return true;
  },
});

/** A verified App Store Server Notification. Returns how many rows it updated. */
export const applyFromNotification = internalMutation({
  args: { appAccountToken: v.optional(v.string()), state: subscriptionStateValidator },
  returns: v.number(),
  handler: async (ctx, args) => {
    // A family member's transaction may carry the purchaser's token, so match those by transaction.
    const token = args.state.familyShared ? undefined : args.appAccountToken;
    const byToken = token
      ? await ctx.db
          .query("subscriptions")
          .withIndex("by_app_account_token", (q) => q.eq("appAccountToken", token))
          .unique()
      : null;
    const rows = byToken
      ? [byToken]
      : await ctx.db
          .query("subscriptions")
          .withIndex("by_original_transaction_id", (q) =>
            q.eq("originalTransactionId", args.state.originalTransactionId),
          )
          .take(10);
    for (const row of rows) {
      await applyState(ctx, row, args.state);
    }
    return rows.length;
  },
});
