"use node";

import { OpenRouter, stepCountIs, tool } from "@openrouter/agent";
import { ConvexError, v } from "convex/values";
import { z } from "zod";
import { internal } from "./_generated/api";
import { action, type ActionCtx } from "./_generated/server";
import type { Id } from "./_generated/dataModel";
import type { BabyContextSnapshot } from "./lib/babyContext";

const INSTRUCTIONS = `You are Baby Steps Voice Log — you turn a parent's spoken note into logged baby activities.

You log activities. You do NOT give medical advice, diagnose, triage, or delete anything. Care questions go to Ask via handoff_to_ask.

Rules:
- Call get_baby_context if you need age/weight for sanity checks.
- Prefer tools for every concrete activity mentioned.
- You may log multiple activities from one utterance.
- If the parent asked a care question (advice, "is this normal", clothing/TOG, how much should they sleep/feed, why are they crying) rather than reporting something that happened, call handoff_to_ask and do not log.
- Use loggedAtMs = the provided "nowMs" unless the parent clearly said a relative time (e.g. "an hour ago", "this morning"). Snap relative times yourself to epoch ms.
- Never invent amounts or durations the parent did not say. If a required field is missing (e.g. bottle ml, breast side, nappy size), ask a short clarifying question in your reply and DO NOT call the incomplete tool.
- For breast feeds, side is required (left/right/both).
- For bottle feeds, amountMl is required; milk is formula or expressed (default formula if unclear).
- For nappies and potty, size is required for each relevant type (wee/poo/both).
- Pump: side is required; duration minutes required; ml optional.
- Medicine: name required; dose goes in note.
- Activity: title required (Bath/Play/Walk or what they said); minutes optional.
- Weight: convert kg to grams (e.g. 4.2 kg → 4200).
- Height: centimetres.
- After tools succeed, reply with one short confirmation line listing what was logged (e.g. "Logged sleep · 45 min").
- If nothing to log / unclear, say briefly what you need.
- Never delete or edit past events.`;

const MAX_AUDIO_CHARS = 900_000; // ~base64 for short clips under Convex arg limits

async function transcribeAudio(args: {
  apiKey: string;
  audioBase64: string;
  format: string;
}): Promise<string> {
  const response = await fetch(
    "https://openrouter.ai/api/v1/audio/transcriptions",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${args.apiKey}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://babysteps.app",
        "X-OpenRouter-Title": "Baby Steps Voice Log",
      },
      body: JSON.stringify({
        model: "openai/whisper-large-v3-turbo",
        language: "en",
        input_audio: {
          data: args.audioBase64,
          format: args.format,
        },
      }),
    },
  );

  const raw = await response.text();
  if (!response.ok) {
    throw new ConvexError(
      `Transcription failed (${response.status}): ${raw.slice(0, 200)}`,
    );
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new ConvexError("Transcription returned invalid JSON");
  }

  const text =
    parsed &&
    typeof parsed === "object" &&
    "text" in parsed &&
    typeof (parsed as { text: unknown }).text === "string"
      ? (parsed as { text: string }).text.trim()
      : "";

  if (!text) {
    throw new ConvexError(
      "Could not hear anything — speak clearly for a couple of seconds (simulator mic is often silent).",
    );
  }
  return text;
}

export const logFromAudio = action({
  args: {
    babyId: v.id("babies"),
    audioBase64: v.string(),
    format: v.union(
      v.literal("m4a"),
      v.literal("mp3"),
      v.literal("wav"),
      v.literal("webm"),
      v.literal("ogg"),
      v.literal("flac"),
    ),
  },
  returns: v.object({
    transcript: v.string(),
    confirmation: v.string(),
    handoff: v.union(v.literal("ask"), v.null()),
  }),
  handler: async (
    ctx,
    args,
  ): Promise<{
    transcript: string;
    confirmation: string;
    handoff: "ask" | null;
  }> => {
    if (!args.audioBase64 || args.audioBase64.length < 64) {
      throw new ConvexError("Recording is empty");
    }
    if (args.audioBase64.length > MAX_AUDIO_CHARS) {
      throw new ConvexError("Recording is too long — keep it under ~30 seconds");
    }

    const apiKey = process.env.OPENROUTER_API_KEY;
    if (!apiKey) {
      throw new ConvexError(
        "OPENROUTER_API_KEY is not set on the Convex deployment",
      );
    }

    const userId = await ctx.runQuery(internal.chat.currentUserId, {});
    const nowMs = Date.now();
    const context = (await ctx.runQuery(internal.chat.getBabyForTools, {
      babyId: args.babyId,
      userId,
      now: nowMs,
    })) as BabyContextSnapshot;

    const transcript = await transcribeAudio({
      apiKey,
      audioBase64: args.audioBase64,
      format: args.format,
    });

    const result = await runLogFromNote({
      ctx,
      apiKey,
      userId,
      babyId: args.babyId,
      nowMs,
      context,
      note: transcript,
      sourceLabel: "transcript",
    });

    return { transcript, ...result };
  },
});

export const logFromText = action({
  args: {
    babyId: v.id("babies"),
    note: v.string(),
  },
  returns: v.object({
    transcript: v.string(),
    confirmation: v.string(),
    handoff: v.union(v.literal("ask"), v.null()),
  }),
  handler: async (ctx, args) => {
    const note = args.note.trim();
    if (note.length < 2) {
      throw new ConvexError("Write what happened");
    }
    if (note.length > 2000) {
      throw new ConvexError("Keep it under a couple of sentences");
    }
    const apiKey = process.env.OPENROUTER_API_KEY;
    if (!apiKey) {
      throw new ConvexError(
        "OPENROUTER_API_KEY is not set on the Convex deployment",
      );
    }
    const userId = await ctx.runQuery(internal.chat.currentUserId, {});
    const nowMs = Date.now();
    const context = (await ctx.runQuery(internal.chat.getBabyForTools, {
      babyId: args.babyId,
      userId,
      now: nowMs,
    })) as BabyContextSnapshot;
    const result = await runLogFromNote({
      ctx,
      apiKey,
      userId,
      babyId: args.babyId,
      nowMs,
      context,
      note,
      sourceLabel: "typed note",
    });
    return { transcript: note, ...result };
  },
});

export const logFromImage = action({
  args: {
    babyId: v.id("babies"),
    imageBase64: v.string(),
    mime: v.union(
      v.literal("image/jpeg"),
      v.literal("image/png"),
      v.literal("image/webp"),
    ),
    note: v.optional(v.string()),
  },
  returns: v.object({
    transcript: v.string(),
    confirmation: v.string(),
    handoff: v.union(v.literal("ask"), v.null()),
  }),
  handler: async (ctx, args) => {
    if (!args.imageBase64 || args.imageBase64.length < 64) {
      throw new ConvexError("Photo is empty");
    }
    if (args.imageBase64.length > 900_000) {
      throw new ConvexError("Photo is too large — try a closer crop");
    }
    const apiKey = process.env.OPENROUTER_API_KEY;
    if (!apiKey) {
      throw new ConvexError(
        "OPENROUTER_API_KEY is not set on the Convex deployment",
      );
    }
    const extracted = await noteFromImage({
      apiKey,
      imageBase64: args.imageBase64,
      mime: args.mime,
      extra: args.note?.trim(),
    });
    const userId = await ctx.runQuery(internal.chat.currentUserId, {});
    const nowMs = Date.now();
    const context = (await ctx.runQuery(internal.chat.getBabyForTools, {
      babyId: args.babyId,
      userId,
      now: nowMs,
    })) as BabyContextSnapshot;
    const result = await runLogFromNote({
      ctx,
      apiKey,
      userId,
      babyId: args.babyId,
      nowMs,
      context,
      note: extracted,
      sourceLabel: "photo",
    });
    return { transcript: extracted, ...result };
  },
});

async function noteFromImage(args: {
  apiKey: string;
  imageBase64: string;
  mime: string;
  extra?: string;
}): Promise<string> {
  const extra = args.extra ? `\nParent also wrote: ${args.extra}` : "";
  const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${args.apiKey}`,
      "Content-Type": "application/json",
      "HTTP-Referer": "https://babysteps.app",
      "X-OpenRouter-Title": "Baby Steps Photo Log",
    },
    body: JSON.stringify({
      model: process.env.OPENROUTER_MODEL?.trim() || "google/gemini-2.5-flash",
      messages: [
        {
          role: "user",
          content: [
            {
              type: "text",
              text: `Turn this photo into a short parent care note we can log (feed, bottle ml, sleep, nappy, medicine, pump, etc). If a bottle or label is visible, read the amount. One or two sentences. Do not give medical advice.${extra}`,
            },
            {
              type: "image_url",
              image_url: {
                url: `data:${args.mime};base64,${args.imageBase64}`,
              },
            },
          ],
        },
      ],
    }),
  });
  const raw = await response.text();
  if (!response.ok) {
    throw new ConvexError(
      `Could not read photo (${response.status}): ${raw.slice(0, 160)}`,
    );
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new ConvexError("Photo read returned invalid JSON");
  }
  const text =
    parsed &&
    typeof parsed === "object" &&
    "choices" in parsed &&
    Array.isArray((parsed as { choices: unknown }).choices)
      ? String(
          (
            (parsed as { choices: { message?: { content?: unknown } }[] })
              .choices[0]?.message?.content ?? ""
          ),
        ).trim()
      : "";
  if (!text) {
    throw new ConvexError("Could not see anything to log in that photo");
  }
  return text;
}

async function runLogFromNote(args: {
  ctx: ActionCtx;
  apiKey: string;
  userId: Id<"users">;
  babyId: Id<"babies">;
  nowMs: number;
  context: BabyContextSnapshot;
  note: string;
  sourceLabel: string;
}): Promise<{ confirmation: string; handoff: "ask" | null }> {
  const { ctx, apiKey, userId, babyId, nowMs, context, note, sourceLabel } =
    args;
  let loggedCount = 0;
  let askHandoff = false;

    const getBabyContextTool = tool({
      name: "get_baby_context",
      description: "Baby profile and recent feeds/nappies.",
      inputSchema: z.object({}),
      execute: async () => {
        return (await ctx.runQuery(internal.chat.getBabyForTools, {
          babyId,
          userId,
          now: Date.now(),
        })) as BabyContextSnapshot;
      },
    });

    const logFeedTool = tool({
      name: "log_feed",
      description: "Log a breast or bottle feed.",
      inputSchema: z.object({
        loggedAtMs: z.number(),
        feedKind: z.enum(["breast", "bottle"]),
        side: z.enum(["left", "right", "both"]).optional(),
        durationMinutes: z.number().optional(),
        amountMl: z.number().optional(),
        milk: z.enum(["formula", "expressed"]).optional(),
        note: z.string().optional(),
      }),
      execute: async (input) => {
        const id = await ctx.runMutation(internal.voiceTools.logFeed, {
          userId,
          babyId,
          loggedAt: input.loggedAtMs,
          feedKind: input.feedKind,
          side: input.side,
          durationMinutes: input.durationMinutes,
          amountMl: input.amountMl,
          milk: input.milk,
          note: input.note,
        });
        loggedCount += 1;
        return { ok: true, eventId: id };
      },
    });

    const logSleepTool = tool({
      name: "log_sleep",
      description: "Log a sleep / nap with duration in minutes.",
      inputSchema: z.object({
        loggedAtMs: z.number(),
        durationMinutes: z.number(),
        note: z.string().optional(),
      }),
      execute: async (input) => {
        const id = await ctx.runMutation(internal.voiceTools.logSleep, {
          userId,
          babyId,
          loggedAt: input.loggedAtMs,
          durationMinutes: input.durationMinutes,
          note: input.note,
        });
        loggedCount += 1;
        return { ok: true, eventId: id };
      },
    });

    const logTummyTool = tool({
      name: "log_tummy",
      description: "Log tummy time with duration in minutes.",
      inputSchema: z.object({
        loggedAtMs: z.number(),
        durationMinutes: z.number(),
        note: z.string().optional(),
      }),
      execute: async (input) => {
        const id = await ctx.runMutation(internal.voiceTools.logTummy, {
          userId,
          babyId,
          loggedAt: input.loggedAtMs,
          durationMinutes: input.durationMinutes,
          note: input.note,
        });
        loggedCount += 1;
        return { ok: true, eventId: id };
      },
    });

    const logNappyTool = tool({
      name: "log_nappy",
      description: "Log a nappy change.",
      inputSchema: z.object({
        loggedAtMs: z.number(),
        nappy: z.enum(["wee", "poo", "both"]),
        weeSize: z.enum(["small", "medium", "large"]).optional(),
        pooSize: z.enum(["small", "medium", "large"]).optional(),
        note: z.string().optional(),
      }),
      execute: async (input) => {
        const id = await ctx.runMutation(internal.voiceTools.logNappy, {
          userId,
          babyId,
          loggedAt: input.loggedAtMs,
          nappy: input.nappy,
          weeSize: input.weeSize,
          pooSize: input.pooSize,
          note: input.note,
        });
        loggedCount += 1;
        return { ok: true, eventId: id };
      },
    });

    const logWeightTool = tool({
      name: "log_weight",
      description: "Log a weigh-in in grams.",
      inputSchema: z.object({
        loggedAtMs: z.number(),
        weightGrams: z.number(),
        note: z.string().optional(),
      }),
      execute: async (input) => {
        const id = await ctx.runMutation(internal.voiceTools.logWeight, {
          userId,
          babyId,
          loggedAt: input.loggedAtMs,
          weightGrams: input.weightGrams,
          note: input.note,
        });
        loggedCount += 1;
        return { ok: true, eventId: id };
      },
    });

    const logHeightTool = tool({
      name: "log_height",
      description: "Log height in centimetres.",
      inputSchema: z.object({
        loggedAtMs: z.number(),
        heightCm: z.number(),
        note: z.string().optional(),
      }),
      execute: async (input) => {
        const id = await ctx.runMutation(internal.voiceTools.logHeight, {
          userId,
          babyId,
          loggedAt: input.loggedAtMs,
          heightCm: input.heightCm,
          note: input.note,
        });
        loggedCount += 1;
        return { ok: true, eventId: id };
      },
    });

    const logCustomTool = tool({
      name: "log_custom",
      description: "Log an appointment or other custom event.",
      inputSchema: z.object({
        loggedAtMs: z.number(),
        title: z.string(),
        note: z.string().optional(),
      }),
      execute: async (input) => {
        const id = await ctx.runMutation(internal.voiceTools.logCustom, {
          userId,
          babyId,
          loggedAt: input.loggedAtMs,
          title: input.title,
          note: input.note,
        });
        loggedCount += 1;
        return { ok: true, eventId: id };
      },
    });

    const logPumpTool = tool({
      name: "log_pump",
      description: "Log a pump session.",
      inputSchema: z.object({
        loggedAtMs: z.number(),
        side: z.enum(["left", "right", "both"]),
        durationMinutes: z.number(),
        amountMl: z.number().optional(),
        note: z.string().optional(),
      }),
      execute: async (input) => {
        const id = await ctx.runMutation(internal.voiceTools.logPump, {
          userId,
          babyId,
          loggedAt: input.loggedAtMs,
          side: input.side,
          durationMinutes: input.durationMinutes,
          amountMl: input.amountMl,
          note: input.note,
        });
        loggedCount += 1;
        return { ok: true, eventId: id };
      },
    });

    const logMedicineTool = tool({
      name: "log_medicine",
      description: "Log a medicine dose. Put the dose in note.",
      inputSchema: z.object({
        loggedAtMs: z.number(),
        title: z.string(),
        note: z.string().optional(),
      }),
      execute: async (input) => {
        const id = await ctx.runMutation(internal.voiceTools.logMedicine, {
          userId,
          babyId,
          loggedAt: input.loggedAtMs,
          title: input.title,
          note: input.note,
        });
        loggedCount += 1;
        return { ok: true, eventId: id };
      },
    });

    const logPottyTool = tool({
      name: "log_potty",
      description: "Log a potty visit.",
      inputSchema: z.object({
        loggedAtMs: z.number(),
        nappy: z.enum(["wee", "poo", "both"]),
        weeSize: z.enum(["small", "medium", "large"]).optional(),
        pooSize: z.enum(["small", "medium", "large"]).optional(),
        note: z.string().optional(),
      }),
      execute: async (input) => {
        const id = await ctx.runMutation(internal.voiceTools.logPotty, {
          userId,
          babyId,
          loggedAt: input.loggedAtMs,
          nappy: input.nappy,
          weeSize: input.weeSize,
          pooSize: input.pooSize,
          note: input.note,
        });
        loggedCount += 1;
        return { ok: true, eventId: id };
      },
    });

    const logActivityTool = tool({
      name: "log_activity",
      description: "Log bath, play, walk, or another activity.",
      inputSchema: z.object({
        loggedAtMs: z.number(),
        title: z.string(),
        durationMinutes: z.number().optional(),
        note: z.string().optional(),
      }),
      execute: async (input) => {
        const id = await ctx.runMutation(internal.voiceTools.logActivity, {
          userId,
          babyId,
          loggedAt: input.loggedAtMs,
          title: input.title,
          durationMinutes: input.durationMinutes,
          note: input.note,
        });
        loggedCount += 1;
        return { ok: true, eventId: id };
      },
    });

    const saveRoomTempTool = tool({
      name: "save_room_temp",
      description: "Save the current room temperature in °C.",
      inputSchema: z.object({
        tempC: z.number(),
      }),
      execute: async (input) => {
        await ctx.runMutation(internal.voiceTools.saveRoomTemp, {
          userId,
          babyId,
          tempC: input.tempC,
        });
        loggedCount += 1;
        return { ok: true };
      },
    });

    const handoffAskTool = tool({
      name: "handoff_to_ask",
      description:
        "Parent asked a care question that cannot be logged as an activity. Use this instead of logging.",
      inputSchema: z.object({}),
      execute: async () => {
        askHandoff = true;
        return { ok: true };
      },
    });

    const openrouter = new OpenRouter({ apiKey });
    const model =
      process.env.OPENROUTER_MODEL?.trim() || "google/gemini-2.5-flash";

    const result = openrouter.callModel({
      model,
      instructions: `${INSTRUCTIONS}\n\nnowMs=${nowMs}\nBaby snapshot:\n${JSON.stringify(context, null, 2)}`,
      input: `Parent ${sourceLabel}:\n"${note}"`,
      tools: [
        getBabyContextTool,
        logFeedTool,
        logSleepTool,
        logTummyTool,
        logNappyTool,
        logWeightTool,
        logHeightTool,
        logCustomTool,
        logPumpTool,
        logMedicineTool,
        logPottyTool,
        logActivityTool,
        saveRoomTempTool,
        handoffAskTool,
      ],
      stopWhen: stepCountIs(10),
    });

    let confirmation: string;
    try {
      confirmation = (await result.getText()).trim();
    } catch (error) {
      throw new ConvexError(
        error instanceof Error ? error.message : "Log failed",
      );
    }

    return {
      confirmation: confirmation || "Done.",
      handoff: askHandoff && loggedCount === 0 ? "ask" : null,
    };
}
