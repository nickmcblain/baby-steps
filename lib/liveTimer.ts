import AsyncStorage from "@react-native-async-storage/async-storage";
import Constants, { ExecutionEnvironment } from "expo-constants";
import { Platform } from "react-native";
import type { LiveActivity } from "expo-widgets";
import BabyTimerActivity, {
  DAY_MS,
  type BabyTimerProps,
} from "@/widgets/BabyTimerActivity";

export type TimerKind = "sleep" | "feed";
export type FeedSide = "left" | "right";

const STORAGE_KEY = "baby-steps:live-timer-v1";

export type PersistedTimer = {
  kind: TimerKind;
  babyId: string;
  babyName?: string;
  /** Wall-clock when the overall session first started */
  sessionStartedAt: number;
  /** Sleep: accumulated ms while paused */
  sleepBaseMs?: number;
  /** Sleep: Date.now() when current run segment started; null if paused */
  sleepTickOrigin?: number | null;
  /** Feed */
  leftBaseMs?: number;
  rightBaseMs?: number;
  activeSide?: FeedSide | null;
  feedTickOrigin?: number | null;
};

type ActivityHandle = LiveActivity<BabyTimerProps>;

let activity: ActivityHandle | null = null;

function canUseLiveActivity(): boolean {
  if (Platform.OS !== "ios") return false;
  // Expo Go has no widget extension — Live Activities will never show.
  if (Constants.executionEnvironment === ExecutionEnvironment.StoreClient) {
    return false;
  }
  return true;
}

export function liveActivityUnavailableReason(): string | null {
  if (Platform.OS !== "ios") return "Live Activities are iOS-only.";
  if (Constants.executionEnvironment === ExecutionEnvironment.StoreClient) {
    return "Live Activities need a native build (Baby Steps app), not Expo Go.";
  }
  return null;
}

export function formatTimerClock(ms: number): string {
  const totalSec = Math.max(0, Math.floor(ms / 1000));
  const hours = Math.floor(totalSec / 3600);
  const minutes = Math.floor((totalSec % 3600) / 60);
  const seconds = totalSec % 60;
  if (hours > 0) {
    return `${hours}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
  }
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
}

function deepLink(kind: TimerKind, babyId: string): string {
  return `babysteps://baby/${babyId}/${kind}/timer`;
}

function buildProps(args: {
  kind: TimerKind;
  babyName?: string;
  running: boolean;
  elapsedMs: number;
  side?: FeedSide | null;
}): BabyTimerProps {
  const { kind, babyName, running, elapsedMs, side } = args;
  const title =
    kind === "sleep"
      ? "Sleep"
      : side === "right"
        ? "Feed · Right"
        : side === "left"
          ? "Feed · Left"
          : "Feed";
  const startEpochMs = running ? Date.now() - elapsedMs : Date.now() - elapsedMs;
  return {
    kind,
    title,
    subtitle: babyName?.trim() || "",
    running,
    startEpochMs,
    endEpochMs: startEpochMs + DAY_MS,
    pausedLabel: formatTimerClock(elapsedMs),
  };
}

async function savePersisted(data: PersistedTimer | null): Promise<void> {
  if (!data) {
    await AsyncStorage.removeItem(STORAGE_KEY);
    return;
  }
  await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(data));
}

export async function loadPersistedTimer(): Promise<PersistedTimer | null> {
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    return JSON.parse(raw) as PersistedTimer;
  } catch {
    return null;
  }
}

export async function clearPersistedTimer(): Promise<void> {
  await savePersisted(null);
}

async function endExisting(): Promise<void> {
  if (!activity) {
    if (canUseLiveActivity()) {
      try {
        for (const inst of BabyTimerActivity.getInstances()) {
          await inst.end("immediate");
        }
      } catch {
        // ignore
      }
    }
    activity = null;
    return;
  }
  try {
    await activity.end("immediate");
  } catch {
    // ignore
  }
  activity = null;
}

/**
 * Push / refresh Live Activity to match current timer state.
 * Safe no-op on Android or when Live Activities unavailable.
 */
export async function syncLiveTimer(args: {
  kind: TimerKind;
  babyId: string;
  babyName?: string;
  running: boolean;
  elapsedMs: number;
  side?: FeedSide | null;
  persist: PersistedTimer;
}): Promise<{ ok: boolean; error?: string }> {
  await savePersisted(args.persist);

  if (!canUseLiveActivity()) {
    return {
      ok: false,
      error:
        liveActivityUnavailableReason() ?? "Live Activities need iOS",
    };
  }

  const props = buildProps({
    kind: args.kind,
    babyName: args.babyName,
    running: args.running,
    elapsedMs: Math.max(0, args.elapsedMs),
    side: args.side,
  });
  const url = deepLink(args.kind, args.babyId);

  try {
    if (!activity) {
      const existing = BabyTimerActivity.getInstances();
      activity = existing[0] ?? null;
    }
    if (activity) {
      try {
        await activity.update(props);
        return { ok: true };
      } catch {
        // Stale handle — end and recreate below.
        try {
          await activity.end("immediate");
        } catch {
          // ignore
        }
        activity = null;
      }
    }
    activity = BabyTimerActivity.start(props, url);
    return { ok: true };
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Could not start Live Activity";
    console.warn("Live Activity unavailable", error);
    activity = null;
    return { ok: false, error: message };
  }
}

export async function stopLiveTimer(): Promise<void> {
  await clearPersistedTimer();
  await endExisting();
}

/** Elapsed ms for a sleep session from persisted fields. */
export function sleepElapsedFromPersisted(
  p: PersistedTimer,
  now = Date.now(),
): number {
  const base = p.sleepBaseMs ?? 0;
  if (p.sleepTickOrigin != null) {
    return base + (now - p.sleepTickOrigin);
  }
  return base;
}

/** Elapsed ms for one feed side from persisted fields. */
export function feedSideElapsed(
  p: PersistedTimer,
  side: FeedSide,
  now = Date.now(),
): number {
  const base = side === "left" ? (p.leftBaseMs ?? 0) : (p.rightBaseMs ?? 0);
  if (p.activeSide === side && p.feedTickOrigin != null) {
    return base + (now - p.feedTickOrigin);
  }
  return base;
}
