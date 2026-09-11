import AsyncStorage from "@react-native-async-storage/async-storage";
import * as Notifications from "expo-notifications";
import { Platform } from "react-native";

const CHANNEL_ID = "nap-reminders";
const META_KEY = "baby-steps:nap-reminder-meta-v1";
const LEAD_MS = 10 * 60_000;

type NapMeta = Record<string, { napAt: number }>;

function notifIdFor(babyId: string): string {
  return `nap-reminder:${babyId}`;
}

async function loadMeta(): Promise<NapMeta> {
  try {
    const raw = await AsyncStorage.getItem(META_KEY);
    return raw ? (JSON.parse(raw) as NapMeta) : {};
  } catch {
    return {};
  }
}

async function ensureAndroidChannel(): Promise<void> {
  if (Platform.OS !== "android") return;
  await Notifications.setNotificationChannelAsync(CHANNEL_ID, {
    name: "Nap window",
    importance: Notifications.AndroidImportance.DEFAULT,
  });
}

function clock(ms: number): string {
  const d = new Date(ms);
  const h = d.getHours();
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return `${h12}:${String(d.getMinutes()).padStart(2, "0")} ${h < 12 ? "am" : "pm"}`;
}

export async function cancelNapReminder(babyId: string): Promise<void> {
  try {
    await Notifications.cancelScheduledNotificationAsync(notifIdFor(babyId));
  } catch {
    // ignore missing
  }
  const all = await loadMeta();
  if (all[babyId]) {
    delete all[babyId];
    await AsyncStorage.setItem(META_KEY, JSON.stringify(all));
  }
}

/**
 * Schedule a nudge 10 minutes before the predicted nap window. Never prompts for
 * permission — feed reminders own that flow. Cancels when asleep or no prediction.
 */
export async function refreshNapReminder(args: {
  babyId: string;
  babyName: string;
  napAt: number | null;
  asleep: boolean;
}): Promise<void> {
  const { babyId, babyName, napAt, asleep } = args;
  if (asleep || napAt == null || napAt - LEAD_MS <= Date.now()) {
    await cancelNapReminder(babyId);
    return;
  }
  const fireAt = napAt - LEAD_MS;

  const all = await loadMeta();
  if (all[babyId]?.napAt === napAt) return;

  const perms = await Notifications.getPermissionsAsync();
  const ok =
    perms.granted || perms.ios?.status === Notifications.IosAuthorizationStatus.PROVISIONAL;
  if (!ok) return;

  await ensureAndroidChannel();
  try {
    await Notifications.cancelScheduledNotificationAsync(notifIdFor(babyId));
  } catch {
    // ignore missing
  }
  await Notifications.scheduleNotificationAsync({
    identifier: notifIdFor(babyId),
    content: {
      title: `${babyName} · nap window soon`,
      body: `Often ready around ${clock(napAt)}. Watch for cues.`,
      data: { babyId, kind: "nap-reminder" },
      ...(Platform.OS === "android" ? { channelId: CHANNEL_ID } : {}),
    },
    trigger: {
      type: Notifications.SchedulableTriggerInputTypes.DATE,
      date: new Date(fireAt),
    },
  });

  all[babyId] = { napAt };
  await AsyncStorage.setItem(META_KEY, JSON.stringify(all));
}
