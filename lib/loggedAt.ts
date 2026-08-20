const HALF_HOUR_MS = 30 * 60_000;

/** Snap a timestamp to the nearest 30-minute increment. */
export function snapToHalfHour(ms: number): number {
  return Math.round(ms / HALF_HOUR_MS) * HALF_HOUR_MS;
}

export function nowSnapped(): number {
  return snapToHalfHour(Date.now());
}

export type LoggedAtParts = {
  year: number;
  month: number; // 0–11
  day: number;
  slot: number; // 0–47 → minutes from midnight / 30
};

export function partsFromLoggedAt(ms: number): LoggedAtParts {
  const d = new Date(ms);
  const minutes = d.getHours() * 60 + d.getMinutes();
  return {
    year: d.getFullYear(),
    month: d.getMonth(),
    day: d.getDate(),
    slot: Math.min(47, Math.max(0, Math.round(minutes / 30))),
  };
}

export function loggedAtFromParts(parts: LoggedAtParts): number {
  const hours = Math.floor(parts.slot / 2);
  const minutes = (parts.slot % 2) * 30;
  return new Date(
    parts.year,
    parts.month,
    parts.day,
    hours,
    minutes,
    0,
    0,
  ).getTime();
}

export function timeSlotLabel(slot: number): string {
  const hours = Math.floor(slot / 2);
  const minutes = (slot % 2) * 30;
  return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}`;
}

export const TIME_SLOTS = Array.from({ length: 48 }, (_, i) => timeSlotLabel(i));

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
  return `${d.getDate()} ${MONTHS_SHORT[d.getMonth()]} ${d.getFullYear()}`;
}

export function timelineDayKey(ms: number): string {
  const d = new Date(ms);
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
}
