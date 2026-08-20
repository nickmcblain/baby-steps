import { v } from "convex/values";
import { ConvexError } from "convex/values";
import {
  internalMutation,
  internalQuery,
} from "./_generated/server";
import { buildBabyContext } from "./lib/babyContext";
import { requireBabyMember } from "./lib/access";
import { requireUser } from "./lib/auth";
import { authedMutation, authedQuery } from "./lib/functions";
import {
  chatMessageValidator,
  citationValidator,
} from "./lib/validators";

export const ensureThread = authedMutation({
  args: { babyId: v.id("babies") },
  returns: v.id("chatThreads"),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    const existing = await ctx.db
      .query("chatThreads")
      .withIndex("by_baby", (q) => q.eq("babyId", args.babyId))
      .order("desc")
      .first();
    if (existing) return existing._id;
    return await ctx.db.insert("chatThreads", {
      babyId: args.babyId,
      createdBy: ctx.user._id,
      updatedAt: Date.now(),
    });
  },
});

export const listMessages = authedQuery({
  args: {
    threadId: v.id("chatThreads"),
  },
  returns: v.array(chatMessageValidator),
  handler: async (ctx, args) => {
    const thread = await ctx.db.get(args.threadId);
    if (!thread) throw new ConvexError("Thread not found");
    await requireBabyMember(ctx, thread.babyId, ctx.user._id);
    const messages = await ctx.db
      .query("chatMessages")
      .withIndex("by_thread", (q) => q.eq("threadId", args.threadId))
      .collect();
    messages.sort((a, b) => a.createdAt - b.createdAt);
    return messages;
  },
});

export const contextChip = authedQuery({
  args: { babyId: v.id("babies"), now: v.number() },
  returns: v.object({
    summaryLine: v.string(),
    name: v.string(),
  }),
  handler: async (ctx, args) => {
    const baby = await requireBabyMember(ctx, args.babyId, ctx.user._id);
    const feeds = await ctx.db
      .query("events")
      .withIndex("by_baby_kind_loggedAt", (q) =>
        q.eq("babyId", args.babyId).eq("kind", "feed"),
      )
      .order("desc")
      .take(5);
    const nappies = await ctx.db
      .query("events")
      .withIndex("by_baby_kind_loggedAt", (q) =>
        q.eq("babyId", args.babyId).eq("kind", "nappy"),
      )
      .order("desc")
      .take(5);
    const snapshot = buildBabyContext({
      baby,
      feeds,
      nappies,
      now: args.now,
    });
    return { summaryLine: snapshot.summaryLine, name: baby.name };
  },
});

export const loadAgentBundle = internalQuery({
  args: {
    babyId: v.id("babies"),
    threadId: v.id("chatThreads"),
    userId: v.id("users"),
    now: v.number(),
  },
  returns: v.object({
    context: v.any(),
    history: v.array(
      v.object({
        role: v.union(v.literal("user"), v.literal("assistant")),
        content: v.string(),
      }),
    ),
  }),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, args.userId);
    const thread = await ctx.db.get(args.threadId);
    if (!thread || thread.babyId !== args.babyId) {
      throw new ConvexError("Thread not found");
    }
    const baby = await ctx.db.get(args.babyId);
    if (!baby) throw new ConvexError("Baby not found");
    const feeds = await ctx.db
      .query("events")
      .withIndex("by_baby_kind_loggedAt", (q) =>
        q.eq("babyId", args.babyId).eq("kind", "feed"),
      )
      .order("desc")
      .take(5);
    const nappies = await ctx.db
      .query("events")
      .withIndex("by_baby_kind_loggedAt", (q) =>
        q.eq("babyId", args.babyId).eq("kind", "nappy"),
      )
      .order("desc")
      .take(5);
    const context = buildBabyContext({
      baby,
      feeds,
      nappies,
      now: args.now,
    });
    const messages = await ctx.db
      .query("chatMessages")
      .withIndex("by_thread", (q) => q.eq("threadId", args.threadId))
      .collect();
    messages.sort((a, b) => a.createdAt - b.createdAt);
    const history = messages
      .filter((m) => m.role === "user" || m.role === "assistant")
      .slice(-20)
      .map((m) => ({
        role: m.role as "user" | "assistant",
        content: m.content,
      }));
    return { context, history };
  },
});

export const appendTurn = internalMutation({
  args: {
    threadId: v.id("chatThreads"),
    babyId: v.id("babies"),
    userContent: v.string(),
    assistantContent: v.string(),
    citations: v.optional(v.array(citationValidator)),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const now = Date.now();
    await ctx.db.insert("chatMessages", {
      threadId: args.threadId,
      babyId: args.babyId,
      role: "user",
      content: args.userContent,
      createdAt: now,
    });
    await ctx.db.insert("chatMessages", {
      threadId: args.threadId,
      babyId: args.babyId,
      role: "assistant",
      content: args.assistantContent,
      citations: args.citations,
      createdAt: now + 1,
    });
    await ctx.db.patch(args.threadId, { updatedAt: now + 1 });
    return null;
  },
});

/** Resolve current user id for actions (auth propagated). */
export const currentUserId = internalQuery({
  args: {},
  returns: v.id("users"),
  handler: async (ctx) => {
    const user = await requireUser(ctx);
    return user._id;
  },
});

export const getBabyForTools = internalQuery({
  args: {
    babyId: v.id("babies"),
    userId: v.id("users"),
    now: v.number(),
  },
  returns: v.any(),
  handler: async (ctx, args) => {
    const baby = await requireBabyMember(ctx, args.babyId, args.userId);
    const feeds = await ctx.db
      .query("events")
      .withIndex("by_baby_kind_loggedAt", (q) =>
        q.eq("babyId", args.babyId).eq("kind", "feed"),
      )
      .order("desc")
      .take(5);
    const nappies = await ctx.db
      .query("events")
      .withIndex("by_baby_kind_loggedAt", (q) =>
        q.eq("babyId", args.babyId).eq("kind", "nappy"),
      )
      .order("desc")
      .take(5);
    return buildBabyContext({
      baby,
      feeds,
      nappies,
      now: args.now,
    });
  },
});
