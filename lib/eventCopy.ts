import type { Doc } from "../convex/_generated/dataModel";
import { formatHeight, formatWeight } from "@/lib/format";

export type EventCopySource = Pick<
  Doc<"events">,
  | "kind"
  | "loggedAt"
  | "feedKind"
  | "side"
  | "durationMinutes"
  | "amountMl"
  | "milk"
  | "nappy"
  | "weeSize"
  | "pooSize"
  | "weightGrams"
  | "heightCm"
  | "title"
  | "note"
>;

function capitalize(value: string): string {
  if (!value) return value;
  return value.charAt(0).toUpperCase() + value.slice(1);
}

export function formatDurationMinutes(minutes: number): string {
  if (!Number.isFinite(minutes) || minutes <= 0) return "";
  const total = Math.round(minutes);
  if (total < 60) return `${total} min`;
  const h = Math.floor(total / 60);
  const m = total % 60;
  if (m === 0) return `${h}h`;
  return `${h}h ${m}m`;
}

export function feedSummary(event: EventCopySource): string {
  if (event.feedKind === "bottle") {
    const milk = event.milk === "expressed" ? "expressed" : "formula";
    return `${event.amountMl ?? "?"} ml ${capitalize(milk)}`;
  }
  const side =
    event.side === "left"
      ? "left"
      : event.side === "right"
        ? "right"
        : "both sides";
  const duration = event.durationMinutes
    ? ` · ${event.durationMinutes} min`
    : "";
  return `Breast ${side}${duration}`;
}

export function nappySummary(event: EventCopySource): string {
  const bits: string[] = [];
  if (event.nappy === "wee" || event.nappy === "both") {
    bits.push(`Wee ${capitalize(event.weeSize ?? "")}`.trim());
  }
  if (event.nappy === "poo" || event.nappy === "both") {
    bits.push(`Poo ${capitalize(event.pooSize ?? "")}`.trim());
  }
  return bits.join(" · ") || "Nappy";
}

export function sleepSummary(event: EventCopySource): string {
  if (event.durationMinutes == null) return "Sleep";
  return formatDurationMinutes(event.durationMinutes);
}

export function tummySummary(event: EventCopySource): string {
  if (event.durationMinutes == null) return "Tummy time";
  return formatDurationMinutes(event.durationMinutes);
}

export function eventKindLabel(event: EventCopySource): string {
  switch (event.kind) {
    case "feed":
      return "Feed";
    case "nappy":
      return "Nappy";
    case "weight":
      return "Weight";
    case "height":
      return "Height";
    case "sleep":
      return "Sleep";
    case "tummy":
      return "Tummy time";
    case "custom":
      return event.loggedAt > Date.now() ? "Upcoming" : "Event";
    case "pump":
      return "Pump";
    case "medicine":
      return "Medicine";
    case "potty":
      return "Potty";
    case "activity":
      return "Activity";
  }
}

export function eventTitle(event: EventCopySource): string {
  switch (event.kind) {
    case "feed":
      return feedSummary(event);
    case "nappy":
      return nappySummary(event);
    case "weight":
      return event.weightGrams != null
        ? formatWeight(event.weightGrams)
        : "Weight";
    case "height":
      return event.heightCm != null ? formatHeight(event.heightCm) : "Height";
    case "sleep":
      return sleepSummary(event);
    case "tummy":
      return tummySummary(event);
    case "custom":
      return event.title?.trim() || "Event";
    case "pump":
      return pumpSummary(event);
    case "medicine":
      return event.title?.trim() || "Medicine";
    case "potty":
      return nappySummary(event);
    case "activity":
      return activitySummary(event);
  }
}

export function pumpSummary(event: EventCopySource): string {
  const side =
    event.side === "left"
      ? "left"
      : event.side === "right"
        ? "right"
        : "both sides";
  const duration = event.durationMinutes
    ? ` · ${event.durationMinutes} min`
    : "";
  const amount = event.amountMl != null ? ` · ${event.amountMl} ml` : "";
  return `${capitalize(side)}${duration}${amount}`;
}

export function activitySummary(event: EventCopySource): string {
  const title = event.title?.trim() || "Activity";
  const duration = event.durationMinutes
    ? ` · ${formatDurationMinutes(event.durationMinutes)}`
    : "";
  return `${title}${duration}`;
}
