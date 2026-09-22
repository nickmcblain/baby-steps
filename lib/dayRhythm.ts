/**
 * 7:00–7:00 day bar.
 *
 * Enough logged days → shade the slots they are usually asleep.
 * Thin logs → an age shape sized from NHS totals. Clock placement is ours.
 * NHS does not publish a timetable.
 *
 * https://www.nhs.uk/baby/caring-for-a-newborn/helping-your-baby-to-sleep/
 * Newborn wake spacing (1–3h): Healthier Together
 * https://www.healthiertogether.nhs.uk/new-parent-and-baby/safe-and-healthy-sleep
 */

export type RhythmKind = "night" | "nap" | "awake";

export type RhythmSegment = {
  /** Minutes after 7:00, 0–1440. */
  start: number;
  end: number;
  kind: RhythmKind;
};

export type NightWindow = { bedMin: number; wakeMin: number };

export type DayRhythm = {
  segments: RhythmSegment[];
  source: "logs" | "nhs";
  caption: string;
};

/** Parent-set night. 7pm–7am is the starting point for "sleeps through". */
export const DEFAULT_NIGHT: NightWindow = { bedMin: 19 * 60, wakeMin: 7 * 60 };

const NIGHT_MIN = 4 * 60;
const NIGHT_MAX = 14 * 60;

export function nightLengthMin(bedMin: number, wakeMin: number): number {
  return (wakeMin - bedMin + 1440) % 1440;
}

export function validNight(bedMin: number, wakeMin: number): boolean {
  const length = nightLengthMin(bedMin, wakeMin);
  return length >= NIGHT_MIN && length <= NIGHT_MAX;
}

export type RhythmSleep = { startMs: number; endMs: number };

const DAY = 1440;
const DAY_START = 7 * 60;
const SLOT = 30;
const SLOTS = DAY / SLOT;
const MIN_DAYS = 3;
const MIN_OVERLAP_MS = 15 * 60_000;

export function dayBarOffset(ms: number): number {
  const d = new Date(ms);
  const min = d.getHours() * 60 + d.getMinutes();
  return (min - DAY_START + DAY) % DAY;
}

/** Time until the next nap or night block. `inMs` is 0 when that window has started. */
export function nextSleepCountdown(
  segments: RhythmSegment[],
  now: number,
): { inMs: number; kind: "nap" | "night" } | null {
  const sleep = segments.filter(
    (segment): segment is RhythmSegment & { kind: "nap" | "night" } => segment.kind !== "awake",
  );
  if (sleep.length === 0) return null;
  const offset = dayBarOffset(now);
  const current = sleep.find((segment) => offset >= segment.start && offset < segment.end);
  if (current) return { inMs: 0, kind: current.kind };
  let next: (typeof sleep)[number] | null = null;
  for (const segment of sleep) {
    if (segment.start > offset && (next == null || segment.start < next.start)) next = segment;
  }
  if (next) return { inMs: (next.start - offset) * 60_000, kind: next.kind };
  const first = sleep.reduce((earliest, segment) =>
    segment.start < earliest.start ? segment : earliest,
  );
  return { inMs: (DAY - offset + first.start) * 60_000, kind: first.kind };
}

export function recommendedDay(args: {
  dateOfBirth: number;
  now: number;
  sleeps: RhythmSleep[];
  /** Set bedtime and wake. Replaces the night stretch. Daytime naps stay. */
  night?: NightWindow | null;
}): DayRhythm {
  const days = Math.max(0, (args.now - args.dateOfBirth) / 86_400_000);
  const fromLogs = rhythmFromLogs(args.sleeps);
  const night = args.night && validNight(args.night.bedMin, args.night.wakeMin) ? args.night : null;
  if (night) {
    const base = fromLogs ?? nhsShape(days);
    return {
      segments: applyNightWindow(base, night),
      source: fromLogs ? "logs" : "nhs",
      caption: fromLogs
        ? "Their daytime sleep, with the night you set."
        : "Night you set. Daytime naps still follow the age shape.",
    };
  }
  if (fromLogs) {
    return {
      segments: fromLogs,
      source: "logs",
      caption: "Where they usually sleep. Last 2 weeks. Cues first.",
    };
  }
  return {
    segments: nhsShape(days),
    source: "nhs",
    caption: nhsCaption(days),
  };
}

function applyNightWindow(segments: RhythmSegment[], night: NightWindow): RhythmSegment[] {
  const cuts = nightBarRanges(night.bedMin, night.wakeMin);
  let kept = segments.filter((segment) => segment.kind !== "awake");
  for (const cut of cuts) {
    kept = kept.flatMap((segment) => subtract(segment, cut));
  }
  for (const cut of cuts) {
    kept.push({ start: cut.start, end: cut.end, kind: "night" });
  }
  return cover(kept);
}

function nightBarRanges(bedMin: number, wakeMin: number): { start: number; end: number }[] {
  const start = (bedMin - DAY_START + DAY) % DAY;
  let end = (wakeMin - DAY_START + DAY) % DAY;
  if (end === 0) end = DAY;
  if (end > start) return [{ start, end }];
  const ranges = [{ start, end: DAY }];
  if (end > 0) ranges.push({ start: 0, end });
  return ranges;
}

function subtract(
  segment: RhythmSegment,
  cut: { start: number; end: number },
): RhythmSegment[] {
  if (segment.end <= cut.start || segment.start >= cut.end) return [segment];
  const out: RhythmSegment[] = [];
  if (segment.start < cut.start) out.push({ ...segment, end: cut.start });
  if (segment.end > cut.end) out.push({ ...segment, start: cut.end });
  return out.filter((piece) => piece.end > piece.start);
}

function nhsCaption(days: number): string {
  if (days < 90) return "About 18h in short bursts. NHS, not a timetable.";
  if (days < 180) return "A longer night may start now. NHS, not a timetable.";
  if (days < 365) return "About 15h, mostly at night. NHS, not a timetable.";
  if (days < 730) return "About 12–15h, with a daytime nap. NHS, not a timetable.";
  return "About 12–14h, nap included. NHS, not a timetable.";
}

/** Clock minutes → bar minutes. End of 7:00 is 1440, not 0. */
function barSpan(startClock: number, endClock: number): { start: number; end: number } {
  const start = (startClock - DAY_START + DAY) % DAY;
  let end = (endClock - DAY_START + DAY) % DAY;
  if (end === 0) end = DAY;
  return { start, end };
}

function block(startClock: number, endClock: number, kind: RhythmKind): RhythmSegment {
  const span = barSpan(startClock, endClock);
  return { ...span, kind };
}

function nhsShape(days: number): RhythmSegment[] {
  if (days < 90) {
    const blocks: RhythmSegment[] = [];
    for (let t = 0; t < DAY; t += 240) {
      const clock = (DAY_START + t) % DAY;
      const kind: RhythmKind = clock >= 19 * 60 || clock < DAY_START ? "night" : "nap";
      blocks.push({ start: t, end: t + 180, kind });
    }
    return cover(blocks);
  }
  if (days < 180) {
    return cover([
      block(20 * 60, 4 * 60, "night"),
      block(9 * 60 + 30, 11 * 60, "nap"),
      block(13 * 60, 14 * 60 + 30, "nap"),
      block(16 * 60 + 30, 18 * 60, "nap"),
    ]);
  }
  if (days < 365) {
    return cover([
      block(19 * 60, DAY_START, "night"),
      block(9 * 60 + 30, 11 * 60, "nap"),
      block(14 * 60, 15 * 60 + 30, "nap"),
    ]);
  }
  if (days < 730) {
    return cover([
      block(19 * 60, 6 * 60 + 30, "night"),
      block(12 * 60 + 30, 14 * 60 + 30, "nap"),
    ]);
  }
  return cover([
    block(19 * 60 + 30, 6 * 60 + 30, "night"),
    block(13 * 60, 14 * 60 + 30, "nap"),
  ]);
}

function barDayOrigin(ms: number): number {
  const d = new Date(ms);
  const origin = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 7, 0, 0, 0);
  if (d.getTime() < origin.getTime()) origin.setDate(origin.getDate() - 1);
  return origin.getTime();
}

function nextBarDay(origin: number): number {
  const next = new Date(origin);
  next.setDate(next.getDate() + 1);
  next.setHours(7, 0, 0, 0);
  return next.getTime();
}

function rhythmFromLogs(sleeps: RhythmSleep[]): RhythmSegment[] | null {
  const slotDays: Set<number>[] = Array.from({ length: SLOTS }, () => new Set());
  const anyDay = new Set<number>();

  for (const sleep of sleeps) {
    if (sleep.endMs <= sleep.startMs) continue;
    let origin = barDayOrigin(sleep.startMs);
    const last = barDayOrigin(sleep.endMs - 1);
    while (origin <= last) {
      anyDay.add(origin);
      for (let i = 0; i < SLOTS; i++) {
        const slotStart = origin + i * SLOT * 60_000;
        const slotEnd = slotStart + SLOT * 60_000;
        const overlap =
          Math.min(sleep.endMs, slotEnd) - Math.max(sleep.startMs, slotStart);
        if (overlap >= MIN_OVERLAP_MS) slotDays[i].add(origin);
      }
      const stepped = nextBarDay(origin);
      if (stepped <= origin) break;
      origin = stepped;
    }
  }

  if (anyDay.size < MIN_DAYS) return null;

  const asleep = slotDays.map((days) => days.size * 2 >= anyDay.size);
  if (!asleep.some(Boolean)) return null;

  const blocks: RhythmSegment[] = [];
  let i = 0;
  while (i < SLOTS) {
    if (!asleep[i]) {
      i += 1;
      continue;
    }
    const start = i * SLOT;
    const night = start >= 12 * 60;
    let j = i + 1;
    while (j < SLOTS && asleep[j] && (j * SLOT >= 12 * 60) === night) j += 1;
    blocks.push({ start, end: j * SLOT, kind: night ? "night" : "nap" });
    i = j;
  }
  return cover(blocks);
}

function cover(blocks: RhythmSegment[]): RhythmSegment[] {
  const sorted = [...blocks].sort((a, b) => a.start - b.start);
  const out: RhythmSegment[] = [];
  let cursor = 0;
  for (const block of sorted) {
    if (block.start > cursor) out.push({ start: cursor, end: block.start, kind: "awake" });
    out.push(block);
    cursor = block.end;
  }
  if (cursor < DAY) out.push({ start: cursor, end: DAY, kind: "awake" });
  return out;
}
