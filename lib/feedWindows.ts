/** Rough UK-style feed windows — cues still matter; not medical advice. */

export type FeedingMode = "breast" | "bottle" | "mixed";

export type FeedWindow = {
  /** Suggested gap after a feed before a gentle check-in. */
  intervalMs: number;
  /** Human label, e.g. "about 2.5 hours". */
  label: string;
  /**
   * Younger / lighter babies are often still woken for feeds.
   * When false, an active sleep timer should suppress feed reminders.
   */
  shouldWakeForFeeds: boolean;
  reason: string;
};

const HOUR = 60 * 60_000;
const DAY = 24 * HOUR;

function ageDays(dateOfBirth: number, now: number): number {
  return Math.max(0, Math.floor((now - dateOfBirth) / DAY));
}

/**
 * Typical gaps (responsive feeding still preferred):
 * - newborn: ~2–3h
 * - 1–3 months: ~3h
 * - 3–6 months: ~3.5h
 * - 6+ months: ~4h
 * Bottle / mixed can stretch a little longer.
 */
export function feedWindow(args: {
  dateOfBirth: number;
  weightGrams: number;
  feedingMode?: FeedingMode | null;
  now?: number;
}): FeedWindow {
  const now = args.now ?? Date.now();
  const days = ageDays(args.dateOfBirth, now);
  const bottleBias =
    args.feedingMode === "bottle" || args.feedingMode === "mixed" ? 0.5 * HOUR : 0;

  let intervalMs: number;
  let label: string;
  if (days < 28) {
    intervalMs = 2.5 * HOUR + bottleBias;
    label = bottleBias ? "about 3 hours" : "about 2.5 hours";
  } else if (days < 84) {
    intervalMs = 3 * HOUR + bottleBias;
    label = bottleBias ? "about 3.5 hours" : "about 3 hours";
  } else if (days < 180) {
    intervalMs = 3.5 * HOUR + bottleBias * 0.5;
    label = "about 3.5 hours";
  } else {
    intervalMs = 4 * HOUR;
    label = "about 4 hours";
  }

  // Err on waking: under ~8 weeks or under ~5 kg — still check / wake.
  // Once older and heavier, night stretches are more often left alone.
  const shouldWakeForFeeds = days < 56 || args.weightGrams < 5000;
  const reason = shouldWakeForFeeds
    ? days < 56
      ? "Under 8 weeks — feed check-ins stay on even if they're asleep."
      : "Under 5 kg — feed check-ins stay on even if they're asleep."
    : "At this age and weight, an active sleep timer pauses feed reminders so you can leave them sleeping.";

  return { intervalMs, label, shouldWakeForFeeds, reason };
}

export function nextFeedDueAt(lastFeedAt: number, window: FeedWindow): number {
  return lastFeedAt + window.intervalMs;
}
