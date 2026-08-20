import AsyncStorage from "@react-native-async-storage/async-storage";
import * as Notifications from "expo-notifications";
import { Platform } from "react-native";
import { loadPersistedTimer } from "@/lib/liveTimer";
import {
  feedWindow,
  nextFeedDueAt,
  type FeedingMode,
  type FeedWindow,
} from "@/lib/feedWindows";

const CHANNEL_ID = "feed-reminders";
const META_KEY = "baby-steps:feed-reminder-meta-v1";

export type FeedReminderBaby = {
  babyId: string;
  babyName: string;
  dateOfBirth: number;
  weightGrams: number;
  feedingMode?: FeedingMode | null;
};

export function toFeedReminderBaby(baby: {
  _id: string;
  name: string;
  dateOfBirth: number;
  weightGrams: number;
  feedingMode?: FeedingMode | null;
}): FeedReminderBaby {
  return {
    babyId: String(baby._id),
    babyName: baby.name,
    dateOfBirth: baby.dateOfBirth,
    weightGrams: baby.weightGrams,
    feedingMode: baby.feedingMode,
  };
}

type ReminderMeta = {
  babyId: string;
  notificationId: string | null;
  dueAt: number;
  lastFeedAt: number;
  suppressedForSleep: boolean;
};

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldPlaySound: true,
    shouldSetBadge: false,
    shouldShowBanner: true,
    shouldShowList: true,
  }),
});

function notifIdFor(babyId: string): string {
  return `feed-reminder:${babyId}`;
}

async function loadMeta(): Promise<Record<string, ReminderMeta>> {
  try {
    const raw = await AsyncStorage.getItem(META_KEY);
    if (!raw) return {};
    return JSON.parse(raw) as Record<string, ReminderMeta>;
  } catch {
    return {};
  }
}

async function saveMeta(all: Record<string, ReminderMeta>): Promise<void> {
  await AsyncStorage.setItem(META_KEY, JSON.stringify(all));
}

async function ensureAndroidChannel(): Promise<void> {
  if (Platform.OS !== "android") return;
  await Notifications.setNotificationChannelAsync(CHANNEL_ID, {
    name: "Feed reminders",
    importance: Notifications.AndroidImportance.DEFAULT,
    vibrationPattern: [0, 250, 150, 250],
  });
}

export async function ensureFeedReminderPermission(): Promise<boolean> {
  await ensureAndroidChannel();
  const current = await Notifications.getPermissionsAsync();
  if (
    current.granted ||
    current.ios?.status === Notifications.IosAuthorizationStatus.PROVISIONAL
  ) {
    return true;
  }
  const asked = await Notifications.requestPermissionsAsync();
  return (
    asked.granted ||
    asked.ios?.status === Notifications.IosAuthorizationStatus.PROVISIONAL
  );
}

export function describeFeedWindow(
  baby: FeedReminderBaby,
  now = Date.now(),
): FeedWindow {
  return feedWindow({
    dateOfBirth: baby.dateOfBirth,
    weightGrams: baby.weightGrams,
    feedingMode: baby.feedingMode,
    now,
  });
}

async function activeSleepBlocksFeeds(
  babyId: string,
  window: FeedWindow,
): Promise<boolean> {
  if (window.shouldWakeForFeeds) return false;
  const timer = await loadPersistedTimer();
  if (!timer || timer.babyId !== babyId || timer.kind !== "sleep") return false;
  return timer.sleepTickOrigin != null;
}

async function cancelScheduled(babyId: string): Promise<void> {
  try {
    await Notifications.cancelScheduledNotificationAsync(notifIdFor(babyId));
  } catch {
    // ignore missing
  }
}

/**
 * Schedule (or refresh) the next feed check-in from lastFeedAt.
 * Suppresses while an active sleep timer is running if guidance says leave them.
 */
export async function refreshFeedReminder(args: {
  baby: FeedReminderBaby;
  lastFeedAt: number | null | undefined;
  /** When true, skip the OS permission prompt (e.g. background sync). */
  quiet?: boolean;
}): Promise<{ scheduled: boolean; dueAt: number | null; suppressed: boolean }> {
  const { baby, lastFeedAt, quiet } = args;
  if (lastFeedAt == null || !Number.isFinite(lastFeedAt)) {
    await cancelFeedReminder(baby.babyId);
    return { scheduled: false, dueAt: null, suppressed: false };
  }

  const ok = quiet
    ? (await Notifications.getPermissionsAsync()).granted
    : await ensureFeedReminderPermission();
  if (!ok) {
    return { scheduled: false, dueAt: null, suppressed: false };
  }

  const window = describeFeedWindow(baby);
  const dueAt = nextFeedDueAt(lastFeedAt, window);
  const suppress = await activeSleepBlocksFeeds(baby.babyId, window);

  await cancelScheduled(baby.babyId);

  const all = await loadMeta();
  if (suppress) {
    all[baby.babyId] = {
      babyId: baby.babyId,
      notificationId: null,
      dueAt,
      lastFeedAt,
      suppressedForSleep: true,
    };
    await saveMeta(all);
    return { scheduled: false, dueAt, suppressed: true };
  }

  const now = Date.now();
  // If already due, nudge in 60s so we don't fire mid-save UX.
  const fireAt = Math.max(dueAt, now + 60_000);
  const id = notifIdFor(baby.babyId);

  await ensureAndroidChannel();
  await Notifications.scheduleNotificationAsync({
    identifier: id,
    content: {
      title: `${baby.babyName} · feed check`,
      body: window.shouldWakeForFeeds
        ? `Around ${window.label} since the last feed — time for a gentle check.`
        : `Around ${window.label} since the last feed — offer if they're stirring.`,
      data: { babyId: baby.babyId, kind: "feed-reminder" },
      ...(Platform.OS === "android" ? { channelId: CHANNEL_ID } : {}),
    },
    trigger: {
      type: Notifications.SchedulableTriggerInputTypes.DATE,
      date: new Date(fireAt),
    },
  });

  all[baby.babyId] = {
    babyId: baby.babyId,
    notificationId: id,
    dueAt: fireAt,
    lastFeedAt,
    suppressedForSleep: false,
  };
  await saveMeta(all);
  return { scheduled: true, dueAt: fireAt, suppressed: false };
}

export async function cancelFeedReminder(babyId: string): Promise<void> {
  await cancelScheduled(babyId);
  const all = await loadMeta();
  delete all[babyId];
  await saveMeta(all);
}

/** Call when sleep timer starts/resumes — may cancel pending feed nudge. */
export async function onSleepTimerRunning(args: {
  baby: FeedReminderBaby;
  lastFeedAt: number | null | undefined;
}): Promise<void> {
  const window = describeFeedWindow(args.baby);
  if (window.shouldWakeForFeeds) {
    // Keep reminders — newborns often need waking.
    await refreshFeedReminder({
      baby: args.baby,
      lastFeedAt: args.lastFeedAt,
      quiet: true,
    });
    return;
  }
  await cancelScheduled(args.baby.babyId);
  if (args.lastFeedAt == null) return;
  const all = await loadMeta();
  all[args.baby.babyId] = {
    babyId: args.baby.babyId,
    notificationId: null,
    dueAt: nextFeedDueAt(args.lastFeedAt, window),
    lastFeedAt: args.lastFeedAt,
    suppressedForSleep: true,
  };
  await saveMeta(all);
}

/** Call when sleep pauses, resets, or finishes — restore reminder if still due. */
export async function onSleepTimerIdle(args: {
  baby: FeedReminderBaby;
  lastFeedAt: number | null | undefined;
}): Promise<void> {
  await refreshFeedReminder({
    baby: args.baby,
    lastFeedAt: args.lastFeedAt,
    quiet: true,
  });
}
