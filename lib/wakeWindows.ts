/** Typical wake-window start by age. Cues still matter; not medical advice. */

const DAY = 86_400_000;

function ageDays(dateOfBirth: number, now: number): number {
  return Math.max(0, Math.floor((now - dateOfBirth) / DAY));
}

/** Minutes after last wake before a nap is typically offered. */
export function wakeMinutes(dateOfBirth: number, now: number): number {
  const days = ageDays(dateOfBirth, now);
  if (days < 28) return 45;
  if (days < 56) return 60;
  if (days < 90) return 75;
  if (days < 120) return 90;
  if (days < 180) return 120;
  if (days < 270) return 150;
  if (days < 365) return 180;
  return 240;
}

function clock(ms: number): string {
  const d = new Date(ms);
  const hours = d.getHours();
  const minutes = String(d.getMinutes()).padStart(2, "0");
  const h12 = hours % 12 === 0 ? 12 : hours % 12;
  const suffix = hours < 12 ? "am" : "pm";
  return `${h12}:${minutes} ${suffix}`;
}

export function predictedNapLabel(args: {
  dateOfBirth: number;
  lastSleepEndMs: number | null | undefined;
  asleep: boolean;
  now: number;
}): string | null {
  if (args.asleep) return "Asleep";
  if (args.lastSleepEndMs == null) return null;
  if (args.lastSleepEndMs > args.now) return "Asleep";
  const dueAt = args.lastSleepEndMs + wakeMinutes(args.dateOfBirth, args.now) * 60_000;
  if (dueAt <= args.now) return "Now";
  return clock(dueAt);
}

export function formatAwake(ms: number): string {
  const totalMin = Math.max(0, Math.round(ms / 60_000));
  const hours = Math.floor(totalMin / 60);
  const minutes = totalMin % 60;
  if (hours <= 0) return `${minutes}m`;
  if (minutes === 0) return `${hours}h`;
  return `${hours}h ${minutes}m`;
}

export function describeNextNap(): {
  title: string;
  body: string;
  scheduleLine: string;
  status: string;
} {
  return { title: "Next nap", body: "", scheduleLine: "", status: "open" };
}
