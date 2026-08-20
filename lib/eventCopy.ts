import type { Doc } from "../convex/_generated/dataModel";

export function feedSummary(event: Doc<"events">): string {
  if (event.feedKind === "bottle") {
    const milk = event.milk === "expressed" ? "expressed" : "formula";
    return `${event.amountMl ?? "?"} ml ${milk}`;
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
    bits.push(`wee ${event.weeSize ?? ""}`.trim());
  }
  if (event.nappy === "poo" || event.nappy === "both") {
    bits.push(`poo ${event.pooSize ?? ""}`.trim());
  }
  return bits.join(" · ") || "Nappy";
}

export function eventTitle(event: Doc<"events">): string {
  return event.kind === "feed" ? feedSummary(event) : nappySummary(event);
}
