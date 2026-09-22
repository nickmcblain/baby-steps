import { describe, expect, test } from "bun:test";
import { nextSleepCountdown, recommendedDay, type NightWindow, type RhythmSleep } from "./dayRhythm";

const DAY = 86_400_000;

function at(y: number, m: number, d: number, h: number, min = 0): number {
  return new Date(y, m, d, h, min).getTime();
}

function sleepMinutes(segments: { start: number; end: number; kind: string }[]): number {
  return segments
    .filter((s) => s.kind !== "awake")
    .reduce((n, s) => n + (s.end - s.start), 0);
}

function rhythmAtAge(days: number, sleeps: RhythmSleep[] = [], night?: NightWindow | null) {
  const now = at(2026, 7, 15, 12);
  return recommendedDay({ dateOfBirth: now - days * DAY, now, sleeps, night });
}

describe("recommendedDay", () => {
  test("newborn with no logs is an 18h NHS burst shape", () => {
    const day = rhythmAtAge(10);
    expect(day.source).toBe("nhs");
    expect(sleepMinutes(day.segments)).toBe(18 * 60);
    expect(day.segments.reduce((n, s) => n + (s.end - s.start), 0)).toBe(1440);
  });

  test("6–12 months NHS shape is 15h with a 12h night", () => {
    const day = rhythmAtAge(200);
    expect(day.source).toBe("nhs");
    expect(sleepMinutes(day.segments)).toBe(15 * 60);
    const night = day.segments.find((s) => s.kind === "night");
    expect(night && night.end - night.start).toBe(12 * 60);
  });

  test("three similar nights beat the NHS shape", () => {
    const sleeps = [1, 2, 3].map((day) => ({
      startMs: at(2026, 7, day, 19, 0),
      endMs: at(2026, 7, day + 1, 7, 0),
    }));
    const day = rhythmAtAge(200, sleeps);
    expect(day.source).toBe("logs");
    const night = day.segments.find((s) => s.kind === "night");
    expect(night).toEqual({ start: 12 * 60, end: 1440, kind: "night" });
  });

  test("a 9 week old with a set night gets one block instead of bursts", () => {
    const day = rhythmAtAge(63, [], { bedMin: 19 * 60, wakeMin: 7 * 60 });
    expect(day.segments.filter((s) => s.kind === "night")).toEqual([
      { start: 12 * 60, end: 1440, kind: "night" },
    ]);
    expect(day.segments.filter((s) => s.kind === "nap")).toHaveLength(3);
  });

  test("wake after 7am continues the night into the morning", () => {
    const day = rhythmAtAge(63, [], { bedMin: 19 * 60, wakeMin: 8 * 60 });
    expect(day.segments.filter((s) => s.kind === "night")).toEqual([
      { start: 0, end: 60, kind: "night" },
      { start: 12 * 60, end: 1440, kind: "night" },
    ]);
  });

  test("countdown is the next shaded block, or now when already inside one", () => {
    const segments = [
      { start: 0, end: 180, kind: "nap" as const },
      { start: 240, end: 420, kind: "nap" as const },
      { start: 720, end: 1440, kind: "night" as const },
    ];
    const at1030 = new Date(2026, 7, 15, 10, 30).getTime();
    expect(nextSleepCountdown(segments, at1030)).toEqual({ inMs: 30 * 60_000, kind: "nap" });
    const noon = new Date(2026, 7, 15, 12, 0).getTime();
    expect(nextSleepCountdown(segments, noon)).toEqual({ inMs: 0, kind: "nap" });
    const early = new Date(2026, 7, 15, 6, 30).getTime();
    expect(nextSleepCountdown([{ start: 60, end: 180, kind: "nap" }], early)).toEqual({
      inMs: 90 * 60_000,
      kind: "nap",
    });
  });

  test("one logged night is not a pattern", () => {
    const day = rhythmAtAge(200, [
      { startMs: at(2026, 7, 1, 19, 0), endMs: at(2026, 7, 2, 7, 0) },
    ]);
    expect(day.source).toBe("nhs");
  });
});
