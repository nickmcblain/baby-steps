export type SleepSegment = {
  startMs: number;
  endMs: number;
  durationMinutes: number;
};

const MIN_GAP_MS = 15 * 60_000;
const FIVE_MIN_MS = 5 * 60_000;
const MIN_GAPS = 5;
const MIN_DAYS = 3;

function isNightStart(ms: number): boolean {
  const hour = new Date(ms).getHours();
  return hour >= 19 || hour < 7;
}

function localDayKey(ms: number): string {
  const d = new Date(ms);
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
}

export function daytimeWakeGaps(sleeps: SleepSegment[]): {
  gapMs: number;
  nextStartMs: number;
}[] {
  const sorted = [...sleeps].sort((a, b) => a.startMs - b.startMs);
  const gaps: { gapMs: number; nextStartMs: number }[] = [];
  for (let i = 0; i < sorted.length - 1; i++) {
    const next = sorted[i + 1];
    if (isNightStart(next.startMs)) continue;
    const gapMs = next.startMs - sorted[i].endMs;
    if (gapMs < MIN_GAP_MS) continue;
    gaps.push({ gapMs, nextStartMs: next.startMs });
  }
  return gaps;
}

function median(values: number[]): number {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 0) {
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }
  return sorted[mid];
}

function roundToFiveMinutes(ms: number): number {
  return Math.round(ms / FIVE_MIN_MS) * FIVE_MIN_MS;
}

export function personalWakeGap(sleeps: SleepSegment[]): {
  enough: boolean;
  medianMs: number | null;
} {
  let gaps = daytimeWakeGaps(sleeps);
  if (gaps.length >= 10) {
    const drop = Math.floor(gaps.length / 10);
    gaps = [...gaps].sort((a, b) => a.gapMs - b.gapMs).slice(0, gaps.length - drop);
  }
  const days = new Set(gaps.map((g) => localDayKey(g.nextStartMs)));
  if (gaps.length < MIN_GAPS || days.size < MIN_DAYS) {
    return { enough: false, medianMs: null };
  }
  return {
    enough: true,
    medianMs: roundToFiveMinutes(median(gaps.map((g) => g.gapMs))),
  };
}

function clock(ms: number): string {
  const d = new Date(ms);
  const hours = d.getHours();
  const minutes = String(d.getMinutes()).padStart(2, "0");
  const h12 = hours % 12 === 0 ? 12 : hours % 12;
  const suffix = hours < 12 ? "am" : "pm";
  return `${h12}:${minutes} ${suffix}`;
}

/** Predicted next nap start (last wake + personal median gap), or null without enough data. */
export function predictedNapAt(args: {
  sleeps: SleepSegment[];
  lastSleepEndMs: number | null | undefined;
}): number | null {
  if (args.lastSleepEndMs == null) return null;
  const { enough, medianMs } = personalWakeGap(args.sleeps);
  if (!enough || medianMs == null) return null;
  return args.lastSleepEndMs + medianMs;
}

export function predictedNapLabel(args: {
  sleeps: SleepSegment[];
  lastSleepEndMs: number | null | undefined;
  lastSleepMinutes: number | null | undefined;
  asleep: boolean;
  now: number;
}): { label: string; subline: string } {
  if (args.asleep || (args.lastSleepEndMs != null && args.lastSleepEndMs > args.now)) {
    return { label: "Asleep", subline: "" };
  }

  const nextOfferAt = predictedNapAt(args);
  if (nextOfferAt == null) {
    return {
      label: "Watch cues",
      subline: "Not enough of a daytime pattern yet.",
    };
  }

  const shortNap = args.lastSleepMinutes != null && args.lastSleepMinutes < 30;
  const shortLine = "A short nap still counts.";

  if (args.now >= nextOfferAt) {
    return {
      label: "Offer a nap",
      subline: shortNap ? shortLine : "A guess from their usual gap. Cues first.",
    };
  }

  return {
    label: `Often ready around ${clock(nextOfferAt)}`,
    subline: shortNap ? shortLine : "From their last two weeks",
  };
}
