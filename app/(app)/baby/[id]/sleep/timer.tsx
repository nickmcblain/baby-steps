import { useQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useEffect, useRef, useState } from "react";
import { AppState, Pressable, StyleSheet, Text, View } from "react-native";
import { Screen } from "@/components/Screen";
import { PrimaryButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import {
  onSleepTimerIdle,
  onSleepTimerRunning,
  toFeedReminderBaby,
} from "@/lib/feedReminders";
import {
  clearPersistedTimer,
  formatTimerClock,
  loadPersistedTimer,
  sleepElapsedFromPersisted,
  stopLiveTimer,
  syncLiveTimer,
  type PersistedTimer,
} from "@/lib/liveTimer";
import { snapToHalfHour } from "@/lib/loggedAt";
import { colors, fonts, radius, shadow } from "@/lib/theme";

function minutesFromMs(ms: number): number {
  if (ms < 5_000) return 0;
  return Math.max(1, Math.round(ms / 60_000));
}

export default function SleepTimerScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const babyId = id as Id<"babies">;
  const baby = useQuery(api.babies.get, { babyId });
  const dash = useQuery(api.events.dashboard, { babyId });
  const lastFeedAt = dash?.lastFeed
    ? dash.lastFeed.loggedAt + (dash.lastFeed.durationMinutes ?? 0) * 60_000
    : undefined;
  const [running, setRunning] = useState(false);
  const [elapsedMs, setElapsedMs] = useState(0);
  const [hydrated, setHydrated] = useState(false);
  const startedAtRef = useRef<number | null>(null);
  const tickOriginRef = useRef<number | null>(null);
  const baseRef = useRef(0);

  function persistSnapshot(
    runningNow: boolean,
    tickOrigin: number | null,
  ): PersistedTimer {
    return {
      kind: "sleep",
      babyId: String(babyId),
      babyName: baby?.name,
      sessionStartedAt: startedAtRef.current ?? Date.now(),
      sleepBaseMs: baseRef.current,
      sleepTickOrigin: tickOrigin,
    };
  }

  async function pushLive(
    runningNow: boolean,
    elapsed: number,
    tickOrigin: number | null,
  ) {
    await syncLiveTimer({
      kind: "sleep",
      babyId: String(babyId),
      babyName: baby?.name,
      running: runningNow,
      elapsedMs: elapsed,
      persist: persistSnapshot(runningNow, tickOrigin),
    });
  }

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      const saved = await loadPersistedTimer();
      if (cancelled) return;
      if (saved?.kind === "sleep" && saved.babyId === String(babyId)) {
        startedAtRef.current = saved.sessionStartedAt;
        baseRef.current = saved.sleepBaseMs ?? 0;
        tickOriginRef.current = saved.sleepTickOrigin ?? null;
        const elapsed = sleepElapsedFromPersisted(saved);
        setElapsedMs(elapsed);
        setRunning(saved.sleepTickOrigin != null);
        await pushLive(saved.sleepTickOrigin != null, elapsed, saved.sleepTickOrigin ?? null);
      }
      setHydrated(true);
    })();
    return () => {
      cancelled = true;
    };
    // hydrate once per baby
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [babyId]);

  // If sleep is already running (e.g. Live Activity / relaunch), suppress feed nudges when allowed.
  useEffect(() => {
    if (!hydrated || !baby || !running) return;
    void onSleepTimerRunning({
      baby: toFeedReminderBaby(baby),
      lastFeedAt,
    });
  }, [hydrated, baby, running, lastFeedAt]);

  useEffect(() => {
    if (!running) return;
    const interval = setInterval(() => {
      const origin = tickOriginRef.current;
      if (origin == null) return;
      setElapsedMs(baseRef.current + (Date.now() - origin));
    }, 200);
    return () => clearInterval(interval);
  }, [running]);

  useEffect(() => {
    const sub = AppState.addEventListener("change", (state) => {
      if (state !== "active") return;
      if (tickOriginRef.current != null) {
        setElapsedMs(baseRef.current + (Date.now() - tickOriginRef.current));
      }
    });
    return () => sub.remove();
  }, []);

  async function notifySleepRunning() {
    if (!baby) return;
    await onSleepTimerRunning({
      baby: toFeedReminderBaby(baby),
      lastFeedAt,
    });
  }

  async function notifySleepIdle() {
    if (!baby) return;
    await onSleepTimerIdle({
      baby: toFeedReminderBaby(baby),
      lastFeedAt,
    });
  }

  async function pause() {
    if (!running || tickOriginRef.current == null) return;
    baseRef.current += Date.now() - tickOriginRef.current;
    setElapsedMs(baseRef.current);
    tickOriginRef.current = null;
    setRunning(false);
    await pushLive(false, baseRef.current, null);
    await notifySleepIdle();
  }

  async function toggle() {
    if (running) {
      await pause();
      return;
    }
    const now = Date.now();
    if (startedAtRef.current == null) {
      startedAtRef.current = now;
    }
    tickOriginRef.current = now;
    setRunning(true);
    await pushLive(true, baseRef.current, now);
    await notifySleepRunning();
  }

  async function reset() {
    setRunning(false);
    setElapsedMs(0);
    startedAtRef.current = null;
    tickOriginRef.current = null;
    baseRef.current = 0;
    await stopLiveTimer();
    await notifySleepIdle();
  }

  async function finish() {
    await pause();
    const minutes = minutesFromMs(baseRef.current);
    if (minutes <= 0) return;
    const startedAt = snapToHalfHour(startedAtRef.current ?? Date.now());
    await clearPersistedTimer();
    await stopLiveTimer();
    await notifySleepIdle();
    // Replace timer so Save → baby home (not back to this screen).
    router.replace({
      pathname: "/baby/[id]/sleep/manual",
      params: {
        id: String(id),
        minutes: String(minutes),
        startedAt: String(startedAt),
      },
    });
  }

  const canFinish = minutesFromMs(elapsedMs) > 0 || elapsedMs >= 5_000;

  return (
    <Screen onBack={() => router.back()}>
      <Title>Sleep timer</Title>
      <Text style={styles.hint}>
        Start when they nod off. Keeps timing on the Lock Screen / Dynamic Island
        while the app is away.
      </Text>

      <Pressable
        onPress={() => void toggle()}
        disabled={!hydrated}
        style={[styles.clockCard, running && styles.clockCardActive]}
      >
        <Text style={[styles.clock, running && styles.clockActive]}>
          {formatTimerClock(elapsedMs)}
        </Text>
        <Text style={[styles.clockAction, running && styles.clockActionActive]}>
          {running ? "Pause" : elapsedMs > 0 ? "Resume" : "Start"}
        </Text>
      </Pressable>

      <View style={styles.controls}>
        <PrimaryButton
          label="Done — confirm details"
          onPress={() => void finish()}
          disabled={!canFinish}
        />
        {elapsedMs > 0 && !running ? (
          <Pressable onPress={() => void reset()} style={styles.reset}>
            <Text style={styles.resetText}>Reset</Text>
          </Pressable>
        ) : null}
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  hint: {
    fontFamily: fonts.body,
    color: colors.muted,
    fontSize: 15,
    lineHeight: 22,
    marginTop: -4,
  },
  clockCard: {
    backgroundColor: colors.card,
    borderRadius: radius.card,
    paddingVertical: 40,
    paddingHorizontal: 20,
    alignItems: "center",
    gap: 10,
    ...shadow,
  },
  clockCardActive: {
    backgroundColor: colors.purple,
  },
  clock: {
    fontFamily: fonts.displayBold,
    fontSize: 48,
    color: colors.ink,
    fontVariant: ["tabular-nums"],
  },
  clockActive: { color: "#fff" },
  clockAction: {
    fontFamily: fonts.medium,
    fontSize: 15,
    color: colors.purple,
  },
  clockActionActive: { color: "rgba(255,255,255,0.9)" },
  controls: { gap: 12, marginTop: 8 },
  reset: { alignItems: "center", paddingVertical: 8 },
  resetText: {
    fontFamily: fonts.medium,
    fontSize: 15,
    color: colors.muted,
  },
});
