"use node";

import { OpenRouter, stepCountIs, tool } from "@openrouter/agent";
import { ConvexError, v } from "convex/values";
import { z } from "zod";
import { internal } from "./_generated/api";
import { action } from "./_generated/server";
import type { BabyContextSnapshot } from "./lib/babyContext";

const INSTRUCTIONS = `You are Baby Steps Voice Log — you turn a parent's spoken note into logged baby activities.

You ONLY log. You do NOT give medical advice, diagnose, triage, or delete anything.

Rules:
- Call get_baby_context if you need age/weight for sanity checks.
- Prefer tools for every concrete activity mentioned.
- You may log multiple activities from one utterance.
- Use loggedAtMs = the provided "nowMs" unless the parent clearly said a relative time (e.g. "an hour ago", "this morning"). Snap relative times yourself to epoch ms.
- Never invent amounts or durations the parent did not say. If a required field is missing (e.g. bottle ml, breast side, nappy size), ask a short clarifying question in your reply and DO NOT call the incomplete tool.
- For breast feeds, side is required (left/right/both).
- For bottle feeds, amountMl is required; milk is formula or expressed (default formula if unclear).
- For nappies, size is required for each relevant type (wee/poo/both).
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
  }),
  handler: async (
    ctx,
    args,
  ): Promise<{ transcript: string; confirmation: string }> => {
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

    const getBabyContextTool = tool({
      name: "get_baby_context",
      description: "Baby profile and recent feeds/nappies.",
      inputSchema: z.object({}),
      execute: async () => {
        return (await ctx.runQuery(internal.chat.getBabyForTools, {
          babyId: args.babyId,
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
          babyId: args.babyId,
          loggedAt: input.loggedAtMs,
          feedKind: input.feedKind,
          side: input.side,
          durationMinutes: input.durationMinutes,
          amountMl: input.amountMl,
          milk: input.milk,
          note: input.note,
        });
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
          babyId: args.babyId,
          loggedAt: input.loggedAtMs,
          durationMinutes: input.durationMinutes,
          note: input.note,
        });
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
          babyId: args.babyId,
          loggedAt: input.loggedAtMs,
          durationMinutes: input.durationMinutes,
          note: input.note,
        });
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
          babyId: args.babyId,
          loggedAt: input.loggedAtMs,
          nappy: input.nappy,
          weeSize: input.weeSize,
          pooSize: input.pooSize,
          note: input.note,
        });
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
          babyId: args.babyId,
          loggedAt: input.loggedAtMs,
          weightGrams: input.weightGrams,
          note: input.note,
        });
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
          babyId: args.babyId,
          loggedAt: input.loggedAtMs,
          heightCm: input.heightCm,
          note: input.note,
        });
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
          babyId: args.babyId,
          loggedAt: input.loggedAtMs,
          title: input.title,
          note: input.note,
        });
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
          babyId: args.babyId,
          tempC: input.tempC,
        });
        return { ok: true };
      },
    });

    const openrouter = new OpenRouter({ apiKey });
    const model =
      process.env.OPENROUTER_MODEL?.trim() || "google/gemini-2.5-flash";

    const result = openrouter.callModel({
      model,
      instructions: `${INSTRUCTIONS}\n\nnowMs=${nowMs}\nBaby snapshot:\n${JSON.stringify(context, null, 2)}`,
      input: `Parent said (transcript):\n"${transcript}"`,
      tools: [
        getBabyContextTool,
        logFeedTool,
        logSleepTool,
        logTummyTool,
        logNappyTool,
        logWeightTool,
        logHeightTool,
        logCustomTool,
        saveRoomTempTool,
      ],
      stopWhen: stepCountIs(10),
    });

    let confirmation: string;
    try {
      confirmation = (await result.getText()).trim();
    } catch (error) {
      throw new ConvexError(
        error instanceof Error ? error.message : "Voice log failed",
      );
    }

    if (!confirmation) {
      confirmation = "Done.";
    }

    return { transcript, confirmation };
  },
});
