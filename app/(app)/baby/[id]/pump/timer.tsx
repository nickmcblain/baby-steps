import { useQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useEffect, useRef, useState } from "react";
import { Alert, AppState, Pressable, StyleSheet, Text, View } from "react-native";
import { Screen } from "@/components/Screen";
import { PrimaryButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import {
  clearPersistedTimer,
  feedSideElapsed,
  formatTimerClock,
  liveActivityUnavailableReason,
  loadPersistedTimer,
  stopLiveTimer,
  syncLiveTimer,
  type FeedSide,
  type PersistedTimer,
} from "@/lib/liveTimer";
import { snapToHalfHour } from "@/lib/loggedAt";
import { colors, fonts, radius, shadow } from "@/lib/theme";

type Side = FeedSide;

function minutesFromMs(ms: number): number {
  if (ms < 5_000) return 0;
  return Math.max(1, Math.round(ms / 60_000));
}

export default function PumpTimerScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const babyId = id as Id<"babies">;
  const baby = useQuery(api.babies.get, { babyId });
  const [active, setActive] = useState<Side | null>(null);
  const [leftMs, setLeftMs] = useState(0);
  const [rightMs, setRightMs] = useState(0);
  const [hydrated, setHydrated] = useState(false);
  const startedAtRef = useRef<number | null>(null);
  const tickOriginRef = useRef<number | null>(null);
  const leftBaseRef = useRef(0);
  const rightBaseRef = useRef(0);
  const activeRef = useRef<Side | null>(null);

  useEffect(() => {
    activeRef.current = active;
  }, [active]);

  function persistSnapshot(
    activeSide: Side | null,
    tickOrigin: number | null,
  ): PersistedTimer {
    return {
      kind: "pump",
      babyId: String(babyId),
      babyName: baby?.name,
      sessionStartedAt: startedAtRef.current ?? Date.now(),
      leftBaseMs: leftBaseRef.current,
      rightBaseMs: rightBaseRef.current,
      activeSide,
      feedTickOrigin: tickOrigin,
    };
  }

  async function pushLive(
    activeSide: Side | null,
    tickOrigin: number | null,
  ) {
    const running = activeSide != null && tickOrigin != null;
    const sideBase =
      activeSide === "right" ? rightBaseRef.current : leftBaseRef.current;
    const displayElapsed = running
      ? sideBase + (Date.now() - (tickOrigin as number))
      : leftBaseRef.current + rightBaseRef.current;

    const result = await syncLiveTimer({
      kind: "pump",
      babyId: String(babyId),
      babyName: baby?.name,
      running,
      elapsedMs: displayElapsed,
      side:
        activeSide ??
        (rightBaseRef.current > leftBaseRef.current ? "right" : "left"),
      persist: persistSnapshot(activeSide, tickOrigin),
    });
    if (running && !result.ok) {
      Alert.alert(
        "Lock Screen timer unavailable",
        result.error ??
          liveActivityUnavailableReason() ??
          "Could not start Dynamic Island / Lock Screen timer.",
      );
    }
  }

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      const saved = await loadPersistedTimer();
      if (cancelled) return;
      if (saved?.kind === "pump" && saved.babyId === String(babyId)) {
        startedAtRef.current = saved.sessionStartedAt;
        leftBaseRef.current = saved.leftBaseMs ?? 0;
        rightBaseRef.current = saved.rightBaseMs ?? 0;
        tickOriginRef.current = saved.feedTickOrigin ?? null;
        const left = feedSideElapsed(saved, "left");
        const right = feedSideElapsed(saved, "right");
        if (saved.activeSide && saved.feedTickOrigin != null) {
          setLeftMs(left);
          setRightMs(right);
          setActive(saved.activeSide);
        } else {
          setLeftMs(leftBaseRef.current);
          setRightMs(rightBaseRef.current);
          setActive(null);
        }
        await pushLive(saved.activeSide ?? null, saved.feedTickOrigin ?? null);
      }
      setHydrated(true);
    })();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [babyId]);

  useEffect(() => {
    if (!active) return;
    const interval = setInterval(() => {
      const origin = tickOriginRef.current;
      if (origin == null) return;
      const delta = Date.now() - origin;
      if (active === "left") {
        setLeftMs(leftBaseRef.current + delta);
      } else {
        setRightMs(rightBaseRef.current + delta);
      }
    }, 200);
    return () => clearInterval(interval);
  }, [active]);

  useEffect(() => {
    const sub = AppState.addEventListener("change", (state) => {
      if (state !== "active") return;
      const side = activeRef.current;
      const origin = tickOriginRef.current;
      if (side == null || origin == null) return;
      const delta = Date.now() - origin;
      if (side === "left") setLeftMs(leftBaseRef.current + delta);
      else setRightMs(rightBaseRef.current + delta);
    });
    return () => sub.remove();
  }, []);

  async function pauseActive() {
    if (active == null || tickOriginRef.current == null) return;
    const delta = Date.now() - tickOriginRef.current;
    if (active === "left") {
      leftBaseRef.current += delta;
      setLeftMs(leftBaseRef.current);
    } else {
      rightBaseRef.current += delta;
      setRightMs(rightBaseRef.current);
    }
    tickOriginRef.current = null;
    setActive(null);
    await pushLive(null, null);
  }

  async function startSide(side: Side) {
    const now = Date.now();
    if (startedAtRef.current == null) {
      startedAtRef.current = now;
    }
    if (active != null && active !== side) {
      await pauseActive();
    }
    if (active === side) {
      await pauseActive();
      return;
    }
    tickOriginRef.current = now;
    setActive(side);
    await pushLive(side, now);
  }

  async function reset() {
    setActive(null);
    setLeftMs(0);
    setRightMs(0);
    startedAtRef.current = null;
    tickOriginRef.current = null;
    leftBaseRef.current = 0;
    rightBaseRef.current = 0;
    await stopLiveTimer();
  }

  async function finish() {
    await pauseActive();
    const leftMinutes = minutesFromMs(leftBaseRef.current);
    const rightMinutes = minutesFromMs(rightBaseRef.current);
    const totalMinutes = leftMinutes + rightMinutes;
    if (totalMinutes <= 0) return;

    let side: "left" | "right" | "both" = "left";
    if (leftMinutes > 0 && rightMinutes > 0) side = "both";
    else if (rightMinutes > 0) side = "right";

    const startedAt = snapToHalfHour(startedAtRef.current ?? Date.now());
    await clearPersistedTimer();
    await stopLiveTimer();
    router.replace({
      pathname: "/baby/[id]/pump/manual",
      params: {
        id: String(id),
        minutes: String(totalMinutes),
        side,
        startedAt: String(startedAt),
        fromTimer: "1",
        ...(leftMinutes > 0 ? { leftMinutes: String(leftMinutes) } : {}),
        ...(rightMinutes > 0 ? { rightMinutes: String(rightMinutes) } : {}),
      },
    });
  }

  const canFinish =
    minutesFromMs(leftMs) > 0 ||
    minutesFromMs(rightMs) > 0 ||
    leftMs >= 5_000 ||
    rightMs >= 5_000;

  return (
    <Screen onBack={() => router.back()}>
      <Title>Pump</Title>
      <Text style={styles.hint}>
        Time one side at a time. Island keeps the active side running if you leave
        the app.
      </Text>

      <View style={styles.sides}>
        <SideTimer
          label="Left"
          ms={leftMs}
          running={active === "left"}
          disabled={!hydrated}
          onPress={() => void startSide("left")}
        />
        <SideTimer
          label="Right"
          ms={rightMs}
          running={active === "right"}
          disabled={!hydrated}
          onPress={() => void startSide("right")}
        />
      </View>

      <View style={styles.controls}>
        <PrimaryButton
          label="Done — add amount"
          onPress={() => void finish()}
          disabled={!canFinish}
        />
        {(leftMs > 0 || rightMs > 0) && active == null ? (
          <Pressable onPress={() => void reset()} style={styles.reset}>
            <Text style={styles.resetText}>Reset</Text>
          </Pressable>
        ) : null}
      </View>
    </Screen>
  );
}

function SideTimer({
  label,
  ms,
  running,
  disabled,
  onPress,
}: {
  label: string;
  ms: number;
  running: boolean;
  disabled?: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      style={[styles.sideCard, running && styles.sideCardActive]}
    >
      <Text style={[styles.sideLabel, running && styles.sideLabelActive]}>
        {label}
      </Text>
      <Text style={[styles.sideClock, running && styles.sideClockActive]}>
        {formatTimerClock(ms)}
      </Text>
      <Text style={[styles.sideAction, running && styles.sideActionActive]}>
        {running ? "Pause" : ms > 0 ? "Resume" : "Start"}
      </Text>
    </Pressable>
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
  sides: { flexDirection: "row", gap: 12 },
  sideCard: {
    flex: 1,
    backgroundColor: colors.card,
    borderRadius: radius.card,
    paddingVertical: 28,
    paddingHorizontal: 12,
    alignItems: "center",
    gap: 8,
    ...shadow,
  },
  sideCardActive: {
    backgroundColor: colors.teal,
  },
  sideLabel: {
    fontFamily: fonts.bold,
    fontSize: 13,
    color: colors.muted,
    textTransform: "uppercase",
    letterSpacing: 0.6,
  },
  sideLabelActive: { color: "rgba(255,255,255,0.85)" },
  sideClock: {
    fontFamily: fonts.displayBold,
    fontSize: 36,
    color: colors.ink,
    fontVariant: ["tabular-nums"],
  },
  sideClockActive: { color: "#fff" },
  sideAction: {
    fontFamily: fonts.medium,
    fontSize: 14,
    color: colors.tealDark,
  },
  sideActionActive: { color: "rgba(255,255,255,0.9)" },
  controls: { gap: 12, marginTop: 8 },
  reset: { alignItems: "center", paddingVertical: 8 },
  resetText: {
    fontFamily: fonts.medium,
    fontSize: 15,
    color: colors.muted,
  },
});
