"use node";

import { OpenRouter, stepCountIs, tool } from "@openrouter/agent";
import { ConvexError, v } from "convex/values";
import { z } from "zod";
import { internal } from "./_generated/api";
import { action } from "./_generated/server";
import { searchGuidance } from "./guidance/corpus";
import type { BabyContextSnapshot } from "./lib/babyContext";
import { clothingAdvice } from "./lib/clothingAdvice";

const INSTRUCTIONS = `You are Baby Steps Ask — a practical newborn-care helper inside the Baby Steps app.

IMPORTANT — Baby Steps is NOT a medical or healthcare service. You are NOT a clinician, midwife, GP, or triage nurse. You must never act like one.

What you may help with (general, practical only):
- Safer sleep basics, room temp / TOG / clothing layers, typical feeding patterns, nappy expectations, settling/crying tips, prematurity/corrected-age notes, and after c-section practical tips.
- Pointing parents to trusted public guidance (NHS, Lullaby Trust, etc.) via search_guidance.
- Using this baby's logged profile (age, weight, recent feeds/nappies) for context — not for clinical judgement.

Hard refusals (do these every time they apply):
- NEVER diagnose any condition (including jaundice, reflux, infection, allergy, failure to thrive, tongue-tie, etc.).
- NEVER give clinical interpretation of symptoms, growth, labs, or "what this means medically".
- NEVER triage how urgent something is beyond: emergency → call 999; otherwise suggest midwife / health visitor / GP / NHS 111 / pharmacist as appropriate. Do not rank severity, rule things in/out, or say "you're fine" / "this is serious" as a clinician would.
- NEVER give medicine names with doses, schedules, or whether a drug is appropriate (including Calpol/paracetamol/ibuprofen). Refuse and redirect to pharmacist, GP, midwife, or NHS 111.
- If the user describes an emergency (not breathing, blue/grey, unresponsive, seizure), tell them to call 999 immediately — then stop. No further clinical advice.
- If they ask for a diagnosis, clinical opinion, or triage ("is this normal?", "should I go to A&E?", "what does this symptom mean?"), refuse clearly: you cannot assess or advise clinically; contact a qualified professional.

Tools & style:
- Always call get_baby_context before advice that depends on this baby. Prefer tool facts over assumptions.
- Use get_memories for durable non-clinical facts from past chats (preferences, settling tricks, midwife instructions the parent already shared). Call remember_fact for short durable notes; forget_fact if outdated.
- Prefer search_guidance for trusted snippets. Cite sources by name (and URL when provided) at the end.
- For clothing/TOG questions, call get_clothing_advice and cite "Baby Steps clothing helper (Lullaby Trust-style)".
- Be calm, concise, and practical. Use the baby's name and age from tools.
- Keep answers short — a few tight paragraphs or bullets. Warm and empathetic, not gushing or over-reassuring.
- Say clearly this is general guidance in an app, not medical advice. If unsure, say so and recommend midwife / health visitor / NHS 111.`;

export const ask = action({
  args: {
    babyId: v.id("babies"),
    threadId: v.id("chatThreads"),
    message: v.string(),
  },
  returns: v.object({
    content: v.string(),
    citations: v.array(
      v.object({
        title: v.string(),
        url: v.optional(v.string()),
      }),
    ),
  }),
  handler: async (
    ctx,
    args,
  ): Promise<{
    content: string;
    citations: { title: string; url?: string }[];
  }> => {
    const message = args.message.trim();
    if (!message) {
      throw new ConvexError("Message is empty");
    }
    if (message.length > 4000) {
      throw new ConvexError("Message is too long");
    }

    const apiKey = process.env.OPENROUTER_API_KEY;
    if (!apiKey) {
      throw new ConvexError(
        "OPENROUTER_API_KEY is not set on the Convex deployment",
      );
    }

    const userId = await ctx.runQuery(internal.chat.currentUserId, {});
    const now = Date.now();
    const bundle = await ctx.runQuery(internal.chat.loadAgentBundle, {
      babyId: args.babyId,
      threadId: args.threadId,
      userId,
      now,
    });

    const context = bundle.context as BabyContextSnapshot;
    const citations: { title: string; url?: string }[] = [];
    const seen = new Set<string>();

    function addCitation(title: string, url?: string) {
      const key = `${title}|${url ?? ""}`;
      if (seen.has(key)) return;
      seen.add(key);
      citations.push(url ? { title, url } : { title });
    }

    const getBabyContextTool = tool({
      name: "get_baby_context",
      description:
        "Get this baby's current profile: age, weight, height, delivery, feeding mode, room temp, notes, recent feeds and nappies.",
      inputSchema: z.object({}),
      execute: async () => {
        return (await ctx.runQuery(internal.chat.getBabyForTools, {
          babyId: args.babyId,
          userId,
          now,
        })) as BabyContextSnapshot;
      },
    });

    const getRecentEventsTool = tool({
      name: "get_recent_events",
      description:
        "Get recent feed and nappy lines already included in baby context.",
      inputSchema: z.object({}),
      execute: async () => {
        const fresh = (await ctx.runQuery(internal.chat.getBabyForTools, {
          babyId: args.babyId,
          userId,
          now,
        })) as BabyContextSnapshot;
        return {
          recentFeeds: fresh.recentFeeds,
          recentNappies: fresh.recentNappies,
        };
      },
    });

    const getClothingAdviceTool = tool({
      name: "get_clothing_advice",
      description:
        "Get TOG / layer advice for a room temperature in °C for this baby.",
      inputSchema: z.object({
        tempC: z
          .number()
          .min(5)
          .max(40)
          .describe("Room temperature in Celsius"),
      }),
      execute: async ({ tempC }) => {
        const fresh = (await ctx.runQuery(internal.chat.getBabyForTools, {
          babyId: args.babyId,
          userId,
          now,
        })) as BabyContextSnapshot;
        const advice = clothingAdvice({
          tempC,
          dateOfBirth: fresh.dateOfBirth,
          weightGrams: fresh.weightGrams,
          now,
        });
        addCitation("Baby Steps clothing helper (Lullaby Trust-style)");
        return {
          ...advice,
          usedTempC: tempC,
          babySummary: fresh.summaryLine,
          citation: "Baby Steps clothing helper (Lullaby Trust-style)",
        };
      },
    });

    const searchGuidanceTool = tool({
      name: "search_guidance",
      description:
        "Search curated newborn-care guidance snippets with source titles and URLs.",
      inputSchema: z.object({
        query: z.string().describe("What the parent is asking about"),
      }),
      execute: async ({ query }) => {
        const docs = searchGuidance(query, 4);
        for (const doc of docs) {
          addCitation(`${doc.title} — ${doc.source}`, doc.url);
        }
        return docs.map((d) => ({
          title: d.title,
          source: d.source,
          url: d.url ?? null,
          body: d.body,
        }));
      },
    });

    const getMemoriesTool = tool({
      name: "get_memories",
      description:
        "List durable facts remembered about this baby from past Ask chats.",
      inputSchema: z.object({}),
      execute: async () => {
        return await ctx.runQuery(internal.chat.getMemoriesForTools, {
          babyId: args.babyId,
          userId,
        });
      },
    });

    const rememberFactTool = tool({
      name: "remember_fact",
      description:
        "Save a short durable fact for future chats (e.g. prefers side-lying feed, cow's milk protein allergy mentioned, midwife said wake every 3h).",
      inputSchema: z.object({
        key: z
          .string()
          .describe("Short snake_case label, e.g. settling_tip or allergy_note"),
        content: z.string().describe("One clear sentence to remember"),
      }),
      execute: async ({ key, content }) => {
        await ctx.runMutation(internal.chat.upsertMemory, {
          babyId: args.babyId,
          userId,
          threadId: args.threadId,
          key,
          content,
        });
        return { ok: true, key, content };
      },
    });

    const forgetFactTool = tool({
      name: "forget_fact",
      description: "Remove a remembered fact by key when the parent says it is outdated.",
      inputSchema: z.object({
        key: z.string().describe("The memory key to delete"),
      }),
      execute: async ({ key }) => {
        await ctx.runMutation(internal.chat.deleteMemory, {
          babyId: args.babyId,
          userId,
          key,
        });
        return { ok: true, key };
      },
    });

    const openrouter = new OpenRouter({ apiKey });
    const model =
      process.env.OPENROUTER_MODEL?.trim() || "google/gemini-2.5-flash";

    const memoryBlock =
      bundle.memories.length === 0
        ? ""
        : `\n\nRemembered facts across chats:\n${bundle.memories
            .map((m: { key: string; content: string }) => `- ${m.key}: ${m.content}`)
            .join("\n")}`;

    const historyBlock =
      bundle.history.length === 0
        ? ""
        : `\n\nRecent conversation:\n${bundle.history
            .map((m: { role: string; content: string }) => `${m.role.toUpperCase()}: ${m.content}`)
            .join("\n\n")}`;

    const result = openrouter.callModel({
      model,
      instructions: `${INSTRUCTIONS}\n\nCurrent baby snapshot (may refresh via tools):\n${JSON.stringify(context, null, 2)}${memoryBlock}${historyBlock}`,
      input: message,
      tools: [
        getBabyContextTool,
        getRecentEventsTool,
        getClothingAdviceTool,
        searchGuidanceTool,
        getMemoriesTool,
        rememberFactTool,
        forgetFactTool,
      ],
      stopWhen: stepCountIs(8),
    });

    let content: string;
    try {
      content = (await result.getText()).trim();
    } catch (error) {
      throw new ConvexError(
        error instanceof Error ? error.message : "Ask failed",
      );
    }

    if (!content) {
      content =
        "I couldn’t form an answer just now. Try again, or contact your midwife / NHS 111 if you’re worried.";
    }

    await ctx.runMutation(internal.chat.appendTurn, {
      threadId: args.threadId,
      babyId: args.babyId,
      userContent: message,
      assistantContent: content,
      citations: citations.length > 0 ? citations : undefined,
    });

    return { content, citations };
  },
});
