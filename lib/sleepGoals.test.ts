import { describe, expect, test } from "bun:test";
import { sleepDurationRange } from "./sleepGoals";

const DAY = 86_400_000;

function rangeAtAgeDays(days: number) {
  const now = new Date(2026, 5, 15, 12, 0).getTime();
  return sleepDurationRange(now - days * DAY, now);
}

describe("sleepDurationRange", () => {
  test("89 days is NSF newborn 14–17h", () => {
    expect(rangeAtAgeDays(89)).toEqual({ lowHours: 14, highHours: 17 });
  });

  test("90 days switches to AASM 12–16h", () => {
    expect(rangeAtAgeDays(90)).toEqual({ lowHours: 12, highHours: 16 });
  });

  test("364 days stays on 12–16h", () => {
    expect(rangeAtAgeDays(364)).toEqual({ lowHours: 12, highHours: 16 });
  });

  test("365 days is toddler 11–14h", () => {
    expect(rangeAtAgeDays(365)).toEqual({ lowHours: 11, highHours: 14 });
  });
});
