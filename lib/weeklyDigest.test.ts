import { describe, expect, test } from "bun:test";
import { weekStats, type WeekStats } from "@/convex/lib/weeklyStats";
import { digestSentence } from "./weeklyDigest";

function week(over: Partial<WeekStats> = {}): WeekStats {
  return {
    loggedDays: 7,
    sleepMinutesPerDay: 14 * 60,
    feedsPerDay: 7,
    nappiesPerDay: 6,
    longestNightStretchMin: 300,
    ...over,
  };
}

describe("digestSentence", () => {
  test("null when this week is sparse", () => {
    expect(digestSentence({ thisWeek: week({ loggedDays: 3 }), lastWeek: week() }, "Eliza")).toBeNull();
  });

  test("flat summary when nothing moved 10%", () => {
    const d = digestSentence({ thisWeek: week(), lastWeek: week({ sleepMinutesPerDay: 14 * 60 + 20 }) }, "Eliza");
    expect(d?.text).toBe("Eliza's week: 14h sleep, 7 feeds and 6 nappies a day.");
  });

  test("flat summary when last week is sparse", () => {
    const d = digestSentence({ thisWeek: week(), lastWeek: week({ loggedDays: 1, sleepMinutesPerDay: 60 }) }, "Eliza");
    expect(d?.text.startsWith("Eliza's week:")).toBe(true);
  });

  test("picks the biggest change: night stretch", () => {
    const d = digestSentence(
      { thisWeek: week({ longestNightStretchMin: 310 }), lastWeek: week({ longestNightStretchMin: 270 }) },
      "Eliza",
    );
    expect(d).toEqual({
      target: "sleep",
      text: "Eliza's longest night stretch grew to 5h 10m — 40 min more than last week.",
    });
  });

  test("less sleep per day", () => {
    const d = digestSentence(
      { thisWeek: week({ sleepMinutesPerDay: 12 * 60 }), lastWeek: week({ sleepMinutesPerDay: 14 * 60 }) },
      "Eliza",
    );
    expect(d?.text).toBe("Eliza slept 2h less a day than last week.");
  });

  test("feeds change", () => {
    const d = digestSentence({ thisWeek: week({ feedsPerDay: 8.6 }), lastWeek: week({ feedsPerDay: 7 }) }, "Eliza");
    expect(d).toEqual({ target: "feed", text: "Eliza fed 8.6 times a day this week, up from 7." });
  });
});

describe("weekStats", () => {
  const DAY = 86_400_000;
  const start = new Date(2026, 8, 1, 0, 0).getTime();
  const end = start + 7 * DAY;
  const tz = new Date(start).getTimezoneOffset();

  test("counts per day, clips sleep, finds night stretch", () => {
    const events = [
      { kind: "feed", loggedAt: start + 1 * DAY },
      { kind: "feed", loggedAt: start + 1 * DAY + 3_600_000 },
      { kind: "nappy", loggedAt: start + 2 * DAY },
      // Day nap: 60 min at 13:00 local on day 3
      { kind: "sleep", loggedAt: new Date(2026, 8, 4, 13, 0).getTime(), durationMinutes: 60 },
      // Night: 20:00 local on day 5, 5h
      { kind: "sleep", loggedAt: new Date(2026, 8, 6, 20, 0).getTime(), durationMinutes: 300 },
      // Spans the window end: 2h starting 1h before end → 60 clipped
      { kind: "sleep", loggedAt: end - 3_600_000, durationMinutes: 120 },
      // Outside window entirely
      { kind: "feed", loggedAt: end + 1 },
    ];
    const s = weekStats(events, start, end, tz);
    expect(s.loggedDays).toBe(5);
    expect(s.feedsPerDay).toBeCloseTo(2 / 7);
    expect(s.nappiesPerDay).toBeCloseTo(1 / 7);
    expect(s.sleepMinutesPerDay).toBeCloseTo((60 + 300 + 60) / 7);
    expect(s.longestNightStretchMin).toBe(300);
  });
});
