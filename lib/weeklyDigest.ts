import type { WeekStats } from "@/convex/lib/weeklyStats";

export type WeeklySummary = { thisWeek: WeekStats; lastWeek: WeekStats };

export type Digest = {
  text: string;
  /** Which pattern screen the banner should open. */
  target: "sleep" | "feed" | "nappy";
};

const MIN_LOGGED_DAYS = 4;
const MIN_CHANGE = 0.1;

function fmtHours(minutes: number): string {
  const h = Math.round((minutes / 60) * 10) / 10;
  return `${h}h`;
}

function fmtMins(minutes: number): string {
  const m = Math.round(minutes);
  if (m < 60) return `${m} min`;
  const h = Math.floor(m / 60);
  const rest = m % 60;
  return rest === 0 ? `${h}h` : `${h}h ${rest}m`;
}

function fmtPerDay(n: number): string {
  return String(Math.round(n * 10) / 10);
}

/**
 * One plain sentence about the week. Picks the biggest relative change vs last
 * week; falls back to a flat summary. Null when there isn't enough logged data.
 */
export function digestSentence(summary: WeeklySummary, babyName: string): Digest | null {
  const { thisWeek: t, lastWeek: l } = summary;
  if (t.loggedDays < MIN_LOGGED_DAYS) return null;

  const compare = l.loggedDays >= MIN_LOGGED_DAYS;
  const candidates: { change: number; digest: Digest }[] = [];

  if (compare) {
    if (l.sleepMinutesPerDay > 0) {
      const diff = t.sleepMinutesPerDay - l.sleepMinutesPerDay;
      const change = Math.abs(diff) / l.sleepMinutesPerDay;
      candidates.push({
        change,
        digest: {
          target: "sleep",
          text: `${babyName} slept ${fmtMins(Math.abs(diff))} ${diff > 0 ? "more" : "less"} a day than last week.`,
        },
      });
    }
    if (l.longestNightStretchMin > 0) {
      const diff = t.longestNightStretchMin - l.longestNightStretchMin;
      const change = Math.abs(diff) / l.longestNightStretchMin;
      candidates.push({
        change,
        digest: {
          target: "sleep",
          text:
            diff > 0
              ? `${babyName}'s longest night stretch grew to ${fmtMins(t.longestNightStretchMin)} — ${fmtMins(diff)} more than last week.`
              : `${babyName}'s longest night stretch was ${fmtMins(t.longestNightStretchMin)}, ${fmtMins(-diff)} shorter than last week.`,
        },
      });
    }
    if (l.feedsPerDay > 0) {
      const diff = t.feedsPerDay - l.feedsPerDay;
      const change = Math.abs(diff) / l.feedsPerDay;
      candidates.push({
        change,
        digest: {
          target: "feed",
          text: `${babyName} fed ${fmtPerDay(t.feedsPerDay)} times a day this week, ${diff > 0 ? "up" : "down"} from ${fmtPerDay(l.feedsPerDay)}.`,
        },
      });
    }
  }

  const best = candidates
    .filter((c) => c.change >= MIN_CHANGE)
    .sort((a, b) => b.change - a.change)[0];
  if (best) return best.digest;

  return {
    target: "sleep",
    text: `${babyName}'s week: ${fmtHours(t.sleepMinutesPerDay)} sleep, ${fmtPerDay(t.feedsPerDay)} feeds and ${fmtPerDay(t.nappiesPerDay)} nappies a day.`,
  };
}
