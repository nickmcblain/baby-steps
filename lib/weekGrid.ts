/** Local-calendar helpers for week / sleep charts. */

const DAY_MS = 86_400_000;

/** Monday 00:00:00.000 local for the week containing `at`. */
export function startOfWeekMonday(at: number): number {
  const d = new Date(at);
  const day = d.getDay(); // 0 Sun … 6 Sat
  const daysFromMonday = day === 0 ? 6 : day - 1;
  const start = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  start.setDate(start.getDate() - daysFromMonday);
  return start.getTime();
}

export function startOfLocalDay(at: number): number {
  const d = new Date(at);
  return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
}

export function addDays(ms: number, days: number): number {
  return ms + days * DAY_MS;
}

export function minutesOfDay(ms: number): number {
  const d = new Date(ms);
  return d.getHours() * 60 + d.getMinutes() + d.getSeconds() / 60;
}

const DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"] as const;

export function weekDayLabels(weekStartMs: number): {
  label: string;
  dateNum: number;
  dayStartMs: number;
}[] {
  return DAY_NAMES.map((label, i) => {
    const dayStartMs = addDays(weekStartMs, i);
    const d = new Date(dayStartMs);
    return { label, dateNum: d.getDate(), dayStartMs };
  });
}

export function formatWeekRange(weekStartMs: number): string {
  const end = new Date(addDays(weekStartMs, 6));
  const start = new Date(weekStartMs);
  const months = [
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
  ];
  if (start.getMonth() === end.getMonth()) {
    return `${start.getDate()}–${end.getDate()} ${months[start.getMonth()]}`;
  }
  return `${start.getDate()} ${months[start.getMonth()]} – ${end.getDate()} ${months[end.getMonth()]}`;
}

/**
 * Split a [startMs, endMs) interval into per-local-day slices
 * `{ dayStartMs, startMin, endMin }` (minutes from midnight, 0–1440).
 */
export function splitAcrossLocalDays(
  startMs: number,
  endMs: number,
): { dayStartMs: number; startMin: number; endMin: number }[] {
  if (endMs <= startMs) return [];
  const slices: { dayStartMs: number; startMin: number; endMin: number }[] = [];
  let cursor = startMs;
  while (cursor < endMs) {
    const dayStart = startOfLocalDay(cursor);
    const dayEnd = addDays(dayStart, 1);
    const sliceEnd = Math.min(endMs, dayEnd);
    const startMin = (cursor - dayStart) / 60_000;
    const endMin = (sliceEnd - dayStart) / 60_000;
    if (endMin > startMin) {
      slices.push({ dayStartMs: dayStart, startMin, endMin });
    }
    cursor = sliceEnd;
  }
  return slices;
}

export function formatHourLabel(hour: number): string {
  const h = ((hour % 24) + 24) % 24;
  if (h === 0) return "12am";
  if (h === 12) return "12pm";
  if (h < 12) return `${h}am`;
  return `${h - 12}pm`;
}
