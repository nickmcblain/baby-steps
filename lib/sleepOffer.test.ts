import { describe, expect, test } from "bun:test";
import {
  daytimeWakeGaps,
  personalWakeGap,
  predictedNapAt,
  predictedNapLabel,
  type SleepSegment,
} from "./sleepOffer";

function seg(
  year: number,
  month: number,
  day: number,
  hour: number,
  minute: number,
  durationMinutes: number,
): SleepSegment {
  const startMs = new Date(year, month, day, hour, minute).getTime();
  return {
    startMs,
    endMs: startMs + durationMinutes * 60_000,
    durationMinutes,
  };
}

/** Three days of night + two day naps. Morning wake 90m, inter-nap 75m. */
function threeDayPattern(): SleepSegment[] {
  const days = [10, 11, 12];
  const sleeps: SleepSegment[] = [];
  for (const d of days) {
    sleeps.push(seg(2026, 5, d - 1, 20, 0, 600)); // 20:00–06:00 night
    sleeps.push(seg(2026, 5, d, 7, 30, 60)); // 07:30–08:30 (90m after night)
    sleeps.push(seg(2026, 5, d, 9, 45, 60)); // 09:45–10:45 (75m after nap)
  }
  return sleeps;
}

describe("daytimeWakeGaps", () => {
  test("includes night → first day nap and nap → nap", () => {
    const gaps = daytimeWakeGaps([
      seg(2026, 5, 10, 20, 0, 600),
      seg(2026, 5, 11, 7, 30, 60),
      seg(2026, 5, 11, 9, 45, 60),
    ]);
    expect(gaps.map((g) => g.gapMs / 60_000)).toEqual([90, 75]);
  });

  test("excludes last nap → night", () => {
    const gaps = daytimeWakeGaps([
      seg(2026, 5, 11, 16, 0, 60),
      seg(2026, 5, 11, 19, 30, 600),
    ]);
    expect(gaps).toEqual([]);
  });

  test("skips gaps under 15 minutes", () => {
    const gaps = daytimeWakeGaps([
      seg(2026, 5, 11, 8, 0, 30),
      seg(2026, 5, 11, 8, 40, 30),
    ]);
    expect(gaps).toEqual([]);
  });
});

describe("personalWakeGap", () => {
  test("enough day gaps → median rounded to 5 minutes", () => {
    const result = personalWakeGap(threeDayPattern());
    expect(result.enough).toBe(true);
    // 90, 75, 90, 75, 90, 75 → median 82.5 → 85
    expect(result.medianMs).toBe(85 * 60_000);
  });

  test("sparse data is not enough", () => {
    const result = personalWakeGap([
      seg(2026, 5, 10, 20, 0, 600),
      seg(2026, 5, 11, 7, 30, 60),
      seg(2026, 5, 11, 9, 45, 60),
    ]);
    expect(result).toEqual({ enough: false, medianMs: null });
  });

  test("with 10+ gaps, drops the longest 10%", () => {
    const sleeps: SleepSegment[] = [];
    for (let d = 1; d <= 10; d++) {
      sleeps.push(seg(2026, 5, d - 1, 20, 0, 600));
      sleeps.push(d === 10 ? seg(2026, 5, d, 12, 0, 60) : seg(2026, 5, d, 7, 0, 60));
    }
    const result = personalWakeGap(sleeps);
    expect(result.enough).toBe(true);
    expect(result.medianMs).toBe(60 * 60_000);
  });
});

describe("predictedNapAt", () => {
  const pattern = threeDayPattern();
  const last = pattern[pattern.length - 1];

  test("last wake + personal median gap", () => {
    expect(predictedNapAt({ sleeps: pattern, lastSleepEndMs: last.endMs })).toBe(
      last.endMs + 85 * 60_000,
    );
  });

  test("null without enough pattern or last wake", () => {
    expect(predictedNapAt({ sleeps: pattern.slice(0, 3), lastSleepEndMs: last.endMs })).toBeNull();
    expect(predictedNapAt({ sleeps: pattern, lastSleepEndMs: null })).toBeNull();
  });
});

describe("predictedNapLabel", () => {
  const pattern = threeDayPattern();
  const last = pattern[pattern.length - 1];

  test("asleep hides an offer", () => {
    expect(
      predictedNapLabel({
        sleeps: pattern,
        lastSleepEndMs: last.endMs,
        lastSleepMinutes: last.durationMinutes,
        asleep: true,
        now: last.endMs + 10 * 60_000,
      }),
    ).toEqual({ label: "Asleep", subline: "" });
  });

  test("enough pattern offers around last wake + median", () => {
    const now = last.endMs + 10 * 60_000;
    const offer = predictedNapLabel({
      sleeps: pattern,
      lastSleepEndMs: last.endMs,
      lastSleepMinutes: last.durationMinutes,
      asleep: false,
      now,
    });
    expect(offer.label.startsWith("Often ready around")).toBe(true);
    expect(offer.subline).toBe("From their last two weeks");
  });

  test("past the usual gap says offer a nap", () => {
    const offer = predictedNapLabel({
      sleeps: pattern,
      lastSleepEndMs: last.endMs,
      lastSleepMinutes: last.durationMinutes,
      asleep: false,
      now: last.endMs + 3 * 60 * 60_000,
    });
    expect(offer).toEqual({
      label: "Offer a nap",
      subline: "A guess from their usual gap. Cues first.",
    });
  });

  test("short last nap does not fall back to an age-band clock", () => {
    const now = last.endMs + 10 * 60_000;
    const offer = predictedNapLabel({
      sleeps: pattern,
      lastSleepEndMs: last.endMs,
      lastSleepMinutes: 20,
      asleep: false,
      now,
    });
    expect(offer.label.startsWith("Often ready around")).toBe(true);
    expect(offer.subline).toBe("A short nap still counts.");
  });

  test("sparse logs show cues, not a made-up due time", () => {
    expect(
      predictedNapLabel({
        sleeps: [seg(2026, 5, 11, 8, 0, 60)],
        lastSleepEndMs: new Date(2026, 5, 11, 9, 0).getTime(),
        lastSleepMinutes: 60,
        asleep: false,
        now: new Date(2026, 5, 11, 10, 0).getTime(),
      }),
    ).toEqual({
      label: "Watch cues",
      subline: "Not enough of a daytime pattern yet.",
    });
  });
});
