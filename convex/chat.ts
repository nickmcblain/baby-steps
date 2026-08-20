import { ConvexError, v } from "convex/values";
import { internalMutation, internalQuery } from "./_generated/server";
import { buildBabyContext } from "./lib/babyContext";
import { requireBabyMember } from "./lib/access";
import { requireUser } from "./lib/auth";
import { authedMutation, authedQuery } from "./lib/functions";
import {
  babyMemoryValidator,
  chatMessageValidator,
  chatThreadValidator,
  citationValidator,
} from "./lib/validators";

function titleFromMessage(text: string): string {
  const cleaned = text.replace(/\s+/g, " ").trim();
  if (!cleaned) return "New chat";
  // Prefer first sentence / clause as a short chat name.
  const sentence = cleaned.split(/(?<=[.!?])\s+/)[0] ?? cleaned;
  const base = sentence.length > 0 && sentence.length <= cleaned.length ? sentence : cleaned;
  if (base.length <= 56) return base;
  const clipped = base.slice(0, 53);
  const lastSpace = clipped.lastIndexOf(" ");
  const soft = lastSpace > 24 ? clipped.slice(0, lastSpace) : clipped;
  return `${soft.trim()}…`;
}

/** Open the most recent thread, or create one. */
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

export const createThread = authedMutation({
  args: { babyId: v.id("babies") },
  returns: v.id("chatThreads"),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    return await ctx.db.insert("chatThreads", {
      babyId: args.babyId,
      createdBy: ctx.user._id,
      updatedAt: Date.now(),
    });
  },
});

export const listThreads = authedQuery({
  args: { babyId: v.id("babies") },
  returns: v.array(chatThreadValidator),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    const threads = await ctx.db
      .query("chatThreads")
      .withIndex("by_baby", (q) => q.eq("babyId", args.babyId))
      .order("desc")
      .take(50);

    // Fill missing titles from the first user message (chat name = first query).
    const withTitles = [];
    for (const thread of threads) {
      if (thread.title?.trim()) {
        withTitles.push(thread);
        continue;
      }
      const firstUser = await ctx.db
        .query("chatMessages")
        .withIndex("by_thread", (q) => q.eq("threadId", thread._id))
        .collect();
      firstUser.sort((a, b) => a.createdAt - b.createdAt);
      const first = firstUser.find((m) => m.role === "user");
      withTitles.push({
        ...thread,
        title: first ? titleFromMessage(first.content) : thread.title,
      });
    }
    return withTitles;
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

export const listMemories = authedQuery({
  args: { babyId: v.id("babies") },
  returns: v.array(babyMemoryValidator),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, ctx.user._id);
    return await ctx.db
      .query("babyMemories")
      .withIndex("by_baby", (q) => q.eq("babyId", args.babyId))
      .collect();
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
    memories: v.array(
      v.object({
        key: v.string(),
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
    const memoryDocs = await ctx.db
      .query("babyMemories")
      .withIndex("by_baby", (q) => q.eq("babyId", args.babyId))
      .collect();
    const memories = memoryDocs.map((m) => ({
      key: m.key,
      content: m.content,
    }));
    return { context, history, memories };
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
    const thread = await ctx.db.get(args.threadId);
    if (!thread) throw new ConvexError("Thread not found");
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
    const patch: { updatedAt: number; title?: string } = {
      updatedAt: now + 1,
    };
    if (!thread.title) {
      patch.title = titleFromMessage(args.userContent);
    }
    await ctx.db.patch(args.threadId, patch);
    return null;
  },
});

export const upsertMemory = internalMutation({
  args: {
    babyId: v.id("babies"),
    userId: v.id("users"),
    threadId: v.optional(v.id("chatThreads")),
    key: v.string(),
    content: v.string(),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, args.userId);
    const key = args.key
      .trim()
      .toLowerCase()
      .replace(/\s+/g, "_")
      .slice(0, 64);
    const content = args.content.trim().slice(0, 500);
    if (!key || !content) {
      throw new ConvexError("Memory key and content required");
    }
    const existing = await ctx.db
      .query("babyMemories")
      .withIndex("by_baby_and_key", (q) =>
        q.eq("babyId", args.babyId).eq("key", key),
      )
      .unique();
    const now = Date.now();
    if (existing) {
      await ctx.db.patch(existing._id, {
        content,
        updatedAt: now,
        sourceThreadId: args.threadId,
      });
    } else {
      await ctx.db.insert("babyMemories", {
        babyId: args.babyId,
        key,
        content,
        sourceThreadId: args.threadId,
        updatedAt: now,
        createdBy: args.userId,
      });
    }
    return null;
  },
});

export const deleteMemory = internalMutation({
  args: {
    babyId: v.id("babies"),
    userId: v.id("users"),
    key: v.string(),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, args.userId);
    const key = args.key.trim().toLowerCase().replace(/\s+/g, "_");
    const existing = await ctx.db
      .query("babyMemories")
      .withIndex("by_baby_and_key", (q) =>
        q.eq("babyId", args.babyId).eq("key", key),
      )
      .unique();
    if (existing) {
      await ctx.db.delete(existing._id);
    }
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

export const getMemoriesForTools = internalQuery({
  args: {
    babyId: v.id("babies"),
    userId: v.id("users"),
  },
  returns: v.array(
    v.object({
      key: v.string(),
      content: v.string(),
    }),
  ),
  handler: async (ctx, args) => {
    await requireBabyMember(ctx, args.babyId, args.userId);
    const docs = await ctx.db
      .query("babyMemories")
      .withIndex("by_baby", (q) => q.eq("babyId", args.babyId))
      .collect();
    return docs.map((m) => ({ key: m.key, content: m.content }));
  },
});
