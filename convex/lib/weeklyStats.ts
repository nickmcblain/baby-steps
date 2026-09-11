const DAY_MS = 86_400_000;
const HOUR_MS = 3_600_000;

export type WeeklyEvent = {
  kind: string;
  loggedAt: number;
  durationMinutes?: number;
};

export type WeekStats = {
  /** Distinct 24h buckets with at least one log. */
  loggedDays: number;
  sleepMinutesPerDay: number;
  feedsPerDay: number;
  nappiesPerDay: number;
  /** Longest single sleep that started between 19:00 and 07:00 local time. */
  longestNightStretchMin: number;
};

function localHour(ms: number, tzOffsetMinutes: number): number {
  const local = ms - tzOffsetMinutes * 60_000;
  return Math.floor((local % DAY_MS) / HOUR_MS + 24) % 24;
}

/**
 * Aggregate one 7-day window [startMs, endMs). Sleep minutes are clipped to the
 * window; a sleep spanning the boundary contributes to both weeks proportionally.
 */
export function weekStats(
  events: WeeklyEvent[],
  startMs: number,
  endMs: number,
  tzOffsetMinutes: number,
): WeekStats {
  const days = new Set<number>();
  let sleepMinutes = 0;
  let feeds = 0;
  let nappies = 0;
  let longestNight = 0;
  const windowDays = (endMs - startMs) / DAY_MS;

  for (const e of events) {
    const inWindow = e.loggedAt >= startMs && e.loggedAt < endMs;
    if (inWindow) {
      days.add(Math.floor((e.loggedAt - startMs) / DAY_MS));
      if (e.kind === "feed") feeds += 1;
      if (e.kind === "nappy") nappies += 1;
    }
    if (e.kind !== "sleep" || e.durationMinutes == null) continue;
    const sleepEnd = e.loggedAt + e.durationMinutes * 60_000;
    const clippedStart = Math.max(e.loggedAt, startMs);
    const clippedEnd = Math.min(sleepEnd, endMs);
    if (clippedEnd > clippedStart) sleepMinutes += (clippedEnd - clippedStart) / 60_000;
    if (inWindow) {
      const hour = localHour(e.loggedAt, tzOffsetMinutes);
      if (hour >= 19 || hour < 7) longestNight = Math.max(longestNight, e.durationMinutes);
    }
  }

  return {
    loggedDays: days.size,
    sleepMinutesPerDay: sleepMinutes / windowDays,
    feedsPerDay: feeds / windowDays,
    nappiesPerDay: nappies / windowDays,
    longestNightStretchMin: longestNight,
  };
}
