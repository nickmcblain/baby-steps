const MINUTE_MS = 60_000;

/** Snap a timestamp to the nearest minute. */
export function snapToMinute(ms: number): number {
  return Math.round(ms / MINUTE_MS) * MINUTE_MS;
}

/** @deprecated Use snapToMinute — kept so older timer screens compile. */
export function snapToHalfHour(ms: number): number {
  return snapToMinute(ms);
}

export function nowSnapped(): number {
  return snapToMinute(Date.now());
}

export type LoggedAtParts = {
  year: number;
  month: number; // 0–11
  day: number;
  hour: number; // 0–23
  minute: number; // 0–59
};

export function partsFromLoggedAt(ms: number): LoggedAtParts {
  const d = new Date(ms);
  return {
    year: d.getFullYear(),
    month: d.getMonth(),
    day: d.getDate(),
    hour: d.getHours(),
    minute: d.getMinutes(),
  };
}

export function loggedAtFromParts(parts: LoggedAtParts): number {
  return new Date(
    parts.year,
    parts.month,
    parts.day,
    parts.hour,
    parts.minute,
    0,
    0,
  ).getTime();
}

export const HOUR_SLOTS = Array.from({ length: 24 }, (_, i) =>
  String(i).padStart(2, "0"),
);
export const MINUTE_SLOTS = Array.from({ length: 60 }, (_, i) =>
  String(i).padStart(2, "0"),
);

const MONTHS_SHORT = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec",
] as const;

/** Absolute local time for timelines, e.g. "20 Aug · 14:30". */
export function formatLoggedAt(ms: number): string {
  const d = new Date(ms);
  const day = d.getDate();
  const month = MONTHS_SHORT[d.getMonth()];
  const hours = String(d.getHours()).padStart(2, "0");
  const minutes = String(d.getMinutes()).padStart(2, "0");
  return `${day} ${month} · ${hours}:${minutes}`;
}

/** Day header for timeline grouping, e.g. "Today", "Yesterday", "18 Aug 2026". */
export function formatTimelineDay(ms: number, now: number): string {
  const d = new Date(ms);
  const n = new Date(now);
  const startOf = (x: Date) =>
    new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
  const dayStart = startOf(d);
  const todayStart = startOf(n);
  const yesterdayStart = todayStart - 86_400_000;
  if (dayStart === todayStart) return "Today";
  if (dayStart === yesterdayStart) return "Yesterday";
  if (dayStart === todayStart + 86_400_000) return "Tomorrow";
  return `${d.getDate()} ${MONTHS_SHORT[d.getMonth()]} ${d.getFullYear()}`;
}

export function timelineDayKey(ms: number): string {
  const d = new Date(ms);
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
}
