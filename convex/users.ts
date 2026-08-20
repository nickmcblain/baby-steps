import { v } from "convex/values";
import { mutation, query } from "./_generated/server";
import { getUserByToken, requireIdentity, upsertUser } from "./lib/auth";
import { authedQuery } from "./lib/functions";
import { userValidator } from "./lib/validators";

export const current = query({
  args: {},
  returns: v.union(userValidator, v.null()),
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) {
      return null;
    }
    return await getUserByToken(ctx, identity.tokenIdentifier);
  },
});

export const store = mutation({
  args: {},
  returns: userValidator,
  handler: async (ctx) => {
    await requireIdentity(ctx);
    return await upsertUser(ctx);
  },
});

export const me = authedQuery({
  args: {},
  returns: userValidator,
  handler: async (ctx) => ctx.user,
});
