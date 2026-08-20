import type { Doc } from "../convex/_generated/dataModel";
import { formatHeight, formatWeight } from "@/lib/format";

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

export function feedSummary(event: Doc<"events">): string {
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

export function nappySummary(event: Doc<"events">): string {
  const bits: string[] = [];
  if (event.nappy === "wee" || event.nappy === "both") {
    bits.push(`Wee ${capitalize(event.weeSize ?? "")}`.trim());
  }
  if (event.nappy === "poo" || event.nappy === "both") {
    bits.push(`Poo ${capitalize(event.pooSize ?? "")}`.trim());
  }
  return bits.join(" · ") || "Nappy";
}

export function sleepSummary(event: Doc<"events">): string {
  if (event.durationMinutes == null) return "Sleep";
  return formatDurationMinutes(event.durationMinutes);
}

export function eventKindLabel(event: Doc<"events">): string {
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
  }
}

export function eventTitle(event: Doc<"events">): string {
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
  }
}
