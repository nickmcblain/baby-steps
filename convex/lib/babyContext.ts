import type { Doc } from "../_generated/dataModel";

export type BabyContextSnapshot = {
  name: string;
  dateOfBirth: number;
  ageDays: number;
  ageLabel: string;
  weightGrams: number;
  weightKg: string;
  heightCm: number | null;
  deliveryType: string | null;
  gestationWeeks: number | null;
  feedingMode: string | null;
  lastRoomTempC: number | null;
  notes: string | null;
  recentFeeds: string[];
  recentNappies: string[];
  summaryLine: string;
};

function ageLabel(days: number): string {
  if (days < 14) return `${days} day${days === 1 ? "" : "s"}`;
  const weeks = Math.floor(days / 7);
  if (weeks < 13) return `${weeks} week${weeks === 1 ? "" : "s"}`;
  const months = Math.floor(days / 30.437);
  return `${months} month${months === 1 ? "" : "s"}`;
}

function feedLine(event: Doc<"events">): string {
  const when = new Date(event.loggedAt).toISOString();
  if (event.feedKind === "bottle") {
    return `${when}: bottle ${event.amountMl ?? "?"} ml ${event.milk ?? ""}`.trim();
  }
  return `${when}: breast ${event.side ?? "?"} ${event.durationMinutes ? `${event.durationMinutes} min` : ""}`.trim();
}

function nappyLine(event: Doc<"events">): string {
  const when = new Date(event.loggedAt).toISOString();
  return `${when}: ${event.nappy ?? "nappy"} wee=${event.weeSize ?? "-"} poo=${event.pooSize ?? "-"}`;
}

export function buildBabyContext(args: {
  baby: Doc<"babies">;
  feeds: Doc<"events">[];
  nappies: Doc<"events">[];
  now?: number;
}): BabyContextSnapshot {
  const now = args.now ?? Date.now();
  const ageDays = Math.max(
    0,
    Math.floor((now - args.baby.dateOfBirth) / 86_400_000),
  );
  const label = ageLabel(ageDays);
  const weightKg = (args.baby.weightGrams / 1000).toFixed(
    args.baby.weightGrams % 1000 === 0 ? 0 : 2,
  );
  return {
    name: args.baby.name,
    dateOfBirth: args.baby.dateOfBirth,
    ageDays,
    ageLabel: label,
    weightGrams: args.baby.weightGrams,
    weightKg: `${weightKg} kg`,
    heightCm: args.baby.heightCm ?? null,
    deliveryType: args.baby.deliveryType ?? null,
    gestationWeeks: args.baby.gestationWeeks ?? null,
    feedingMode: args.baby.feedingMode ?? null,
    lastRoomTempC: args.baby.lastRoomTempC ?? null,
    notes: args.baby.notes ?? null,
    recentFeeds: args.feeds.map(feedLine),
    recentNappies: args.nappies.map(nappyLine),
    summaryLine: `${args.baby.name} · ${label} · ${weightKg} kg`,
  };
}
