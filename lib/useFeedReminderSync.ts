import { useEffect } from "react";
import { AppState } from "react-native";
import {
  describeFeedWindow,
  refreshFeedReminder,
  type FeedReminderBaby,
} from "@/lib/feedReminders";

/** Keep local feed reminder aligned with last feed + sleep suppress rules. */
export function useFeedReminderSync(
  baby: FeedReminderBaby | null | undefined,
  lastFeedAt: number | null | undefined,
) {
  useEffect(() => {
    if (!baby || lastFeedAt == null) return;
    void refreshFeedReminder({ baby, lastFeedAt, quiet: true });
  }, [baby, lastFeedAt]);

  useEffect(() => {
    if (!baby || lastFeedAt == null) return;
    const sub = AppState.addEventListener("change", (state) => {
      if (state !== "active") return;
      void refreshFeedReminder({ baby, lastFeedAt, quiet: true });
    });
    return () => sub.remove();
  }, [baby, lastFeedAt]);
}

export function feedReminderHint(
  baby: FeedReminderBaby,
  lastFeedAt: number | null | undefined,
  now = Date.now(),
): string | null {
  if (lastFeedAt == null) return null;
  const window = describeFeedWindow(baby, now);
  const due = lastFeedAt + window.intervalMs;
  if (due <= now) {
    return window.shouldWakeForFeeds
      ? `Feed window open · check about every ${window.label.replace("about ", "")}`
      : `Feed window open · ${window.label} gap (sleep timer can pause this)`;
  }
  const mins = Math.max(1, Math.round((due - now) / 60_000));
  if (mins < 60) {
    return `Next feed check in ~${mins} min`;
  }
  const hours = Math.round((mins / 60) * 10) / 10;
  return `Next feed check in ~${hours}h · ${window.label}`;
}
