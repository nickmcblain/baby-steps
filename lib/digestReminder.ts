import * as Notifications from "expo-notifications";
import { Platform } from "react-native";

const CHANNEL_ID = "weekly-digest";
const scheduledFor = new Set<string>();

function notifIdFor(babyId: string): string {
  return `digest:${babyId}`;
}

/**
 * Sunday 6pm local: "Your week with {name} is ready". Idempotent per app session;
 * cancel-then-reschedule so a renamed baby gets the new title. Never prompts.
 */
export async function ensureWeeklyDigestReminder(babyId: string, babyName: string): Promise<void> {
  const key = `${babyId}:${babyName}`;
  if (scheduledFor.has(key)) return;

  const perms = await Notifications.getPermissionsAsync();
  const ok =
    perms.granted || perms.ios?.status === Notifications.IosAuthorizationStatus.PROVISIONAL;
  if (!ok) return;

  if (Platform.OS === "android") {
    await Notifications.setNotificationChannelAsync(CHANNEL_ID, {
      name: "Weekly digest",
      importance: Notifications.AndroidImportance.LOW,
    });
  }
  try {
    await Notifications.cancelScheduledNotificationAsync(notifIdFor(babyId));
  } catch {
    // ignore missing
  }
  await Notifications.scheduleNotificationAsync({
    identifier: notifIdFor(babyId),
    content: {
      title: `Your week with ${babyName} is ready`,
      body: "Open Baby Steps to see how sleep and feeds changed.",
      data: { babyId, kind: "weekly-digest" },
      ...(Platform.OS === "android" ? { channelId: CHANNEL_ID } : {}),
    },
    trigger: {
      type: Notifications.SchedulableTriggerInputTypes.WEEKLY,
      weekday: 1, // Sunday
      hour: 18,
      minute: 0,
    },
  });
  scheduledFor.add(key);
}
