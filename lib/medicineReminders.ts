import * as Notifications from "expo-notifications";
import { Platform } from "react-native";
import { ensureFeedReminderPermission } from "@/lib/feedReminders";

const CHANNEL_ID = "medicine-reminders";

function slug(name: string): string {
  return name.trim().toLowerCase().replace(/\s+/g, "-").slice(0, 40);
}

function notifIdFor(babyId: string, name: string): string {
  return `medicine-reminder:${babyId}:${slug(name)}`;
}

async function ensureAndroidChannel(): Promise<void> {
  if (Platform.OS !== "android") return;
  await Notifications.setNotificationChannelAsync(CHANNEL_ID, {
    name: "Medicine reminders",
    importance: Notifications.AndroidImportance.HIGH,
    vibrationPattern: [0, 250, 150, 250],
  });
}

export async function scheduleMedicineReminder(args: {
  babyId: string;
  babyName: string;
  name: string;
  dose?: string;
  hours: number;
}): Promise<number | null> {
  if (!Number.isFinite(args.hours) || args.hours <= 0) return null;
  const ok = await ensureFeedReminderPermission();
  if (!ok) return null;

  await ensureAndroidChannel();
  const id = notifIdFor(args.babyId, args.name);
  try {
    await Notifications.cancelScheduledNotificationAsync(id);
  } catch {
    // ignore
  }

  const dueAt = Date.now() + args.hours * 60 * 60_000;
  const doseBit = args.dose ? ` · ${args.dose}` : "";
  await Notifications.scheduleNotificationAsync({
    identifier: id,
    content: {
      title: `${args.babyName} · ${args.name}`,
      body: `Next dose due${doseBit}.`,
      data: { babyId: args.babyId, kind: "medicine-reminder" },
      ...(Platform.OS === "android" ? { channelId: CHANNEL_ID } : {}),
    },
    trigger: {
      type: Notifications.SchedulableTriggerInputTypes.DATE,
      date: new Date(dueAt),
    },
  });
  return dueAt;
}

export async function cancelMedicineReminder(
  babyId: string,
  name: string,
): Promise<void> {
  try {
    await Notifications.cancelScheduledNotificationAsync(
      notifIdFor(babyId, name),
    );
  } catch {
    // ignore
  }
}
