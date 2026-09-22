import { useQuery } from "convex/react";
import { useRouter, type Href } from "expo-router";
import { useEffect, useMemo, useRef, useState } from "react";
import { Image, Pressable, StyleSheet, Text, View } from "react-native";
import { ProgressRing } from "@/components/ProgressRing";
import { Screen } from "@/components/Screen";
import { DayRhythmBar } from "@/components/DayRhythmBar";
import { WeekStrip } from "@/components/WeekStrip";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { useActiveBabyId } from "@/lib/activeBaby";
import { formatAge, formatHeight, formatRelative, formatWeight } from "@/lib/format";
import { loadPersistedTimer } from "@/lib/liveTimer";
import { sleepDurationRange, typicalFeedCount, typicalNappyCount } from "@/lib/sleepGoals";
import { ensureWeeklyDigestReminder } from "@/lib/digestReminder";
import { refreshNapReminder } from "@/lib/napReminders";
import { nextSleepCountdown, recommendedDay } from "@/lib/dayRhythm";
import { predictedNapAt } from "@/lib/sleepOffer";
import { fonts, radius } from "@/lib/theme";
import { useTheme, useThemedStyles } from "@/providers/ThemeProvider";
import { addDays, startOfLocalDay } from "@/lib/weekGrid";
import { syncGlanceWidget } from "@/lib/widgetSync";
import { useMarkInteractive } from "@/lib/useMarkInteractive";

function useHomeStyles() {
  return useThemedStyles(({ colors, shadow }) => ({
    brand: {
      fontFamily: fonts.displayBold,
      fontSize: 26,
      color: colors.ink,
      flexShrink: 1,
    },
    vital: {
      flex: 1,
      backgroundColor: colors.card,
      borderRadius: 16,
      paddingHorizontal: 10,
      paddingVertical: 10,
      alignItems: "center" as const,
      ...shadow,
    },
    vitalLabel: {
      fontFamily: fonts.medium,
      fontSize: 11,
      color: colors.muted,
    },
    vitalValue: {
      fontFamily: fonts.bold,
      fontSize: 14,
      color: colors.ink,
    },
    emptyTitle: { fontFamily: fonts.displayBold, fontSize: 28, color: colors.ink },
    emptyBody: { fontFamily: fonts.body, fontSize: 16, color: colors.muted, lineHeight: 22 },
    cta: {
      backgroundColor: colors.ink,
      borderRadius: 20,
      paddingVertical: 16,
      alignItems: "center" as const,
    },
    ctaText: { fontFamily: fonts.bold, fontSize: 16, color: colors.onAccent },
    sleepBlock: {
      backgroundColor: colors.purpleSoft,
      borderRadius: radius.tile,
      padding: 6,
      paddingTop: 0,
    },
    napLabel: {
      fontFamily: fonts.medium,
      fontSize: 13,
      color: colors.purple,
    },
    napValue: { fontFamily: fonts.bold, fontSize: 16, color: colors.ink },
    hero: {
      backgroundColor: colors.card,
      borderRadius: radius.tile,
      overflow: "hidden" as const,
      ...shadow,
    },
    heroBody: {
      padding: 20,
      gap: 4,
    },
    heroValue: { fontFamily: fonts.displayBold, fontSize: 28, color: colors.ink },
    heroLabel: { fontFamily: fonts.medium, fontSize: 15, color: colors.muted },
    heroTypical: { fontFamily: fonts.body, fontSize: 13, color: colors.muted },
    macro: {
      flex: 1,
      backgroundColor: colors.card,
      borderRadius: 22,
      overflow: "hidden" as const,
      ...shadow,
    },
    macroBody: {
      padding: 12,
      gap: 8,
    },
    macroValue: { fontFamily: fonts.bold, fontSize: 16, color: colors.ink },
    macroGoal: { fontFamily: fonts.medium, fontSize: 13, color: colors.muted },
    macroLabel: { fontFamily: fonts.body, fontSize: 12, color: colors.muted },
    strip: {
      backgroundColor: colors.card,
      borderTopWidth: StyleSheet.hairlineWidth,
      borderTopColor: colors.line,
      paddingHorizontal: 12,
      paddingVertical: 8,
    },
    stripText: {
      fontFamily: fonts.medium,
      fontSize: 11,
      color: colors.muted,
      lineHeight: 14,
    },
  }));
}

export default function HomeScreen() {
  const router = useRouter();
  const { colors } = useTheme();
  const styles = useHomeStyles();
  const babies = useQuery(api.babies.list);
  const { activeBabyId, ready, select } = useActiveBabyId();
  const [dayStart, setDayStart] = useState(() => startOfLocalDay(Date.now()));
  const [now, setNow] = useState(() => Date.now());
  const [asleep, setAsleep] = useState(false);

  useEffect(() => {
    const tick = setInterval(() => setNow(Date.now()), 30_000);
    return () => clearInterval(tick);
  }, []);

  useEffect(() => {
    if (!ready || !babies?.length) return;
    const known = babies.some((b) => b._id === activeBabyId);
    if (!known) void select(babies[0]._id);
  }, [ready, babies, activeBabyId, select]);

  const babyId = (activeBabyId ?? undefined) as Id<"babies"> | undefined;
  const rangeEndMs = useMemo(() => Date.now(), []);
  const summary = useQuery(
    api.events.daySummary,
    babyId ? { babyId, dayStart, dayEnd: addDays(dayStart, 1) } : "skip",
  );
  const dash = useQuery(api.events.dashboard, babyId ? { babyId } : "skip");
  const patterns = useQuery(
    api.events.sleepPatterns,
    babyId ? { babyId, days: 14, rangeEndMs } : "skip",
  );
  const lastSummary = useRef(summary);
  if (summary) lastSummary.current = summary;
  const shown = summary ?? lastSummary.current;
  const lastDash = useRef(dash);
  if (dash) lastDash.current = dash;
  const last = dash ?? lastDash.current;
  const lastPatterns = useRef(patterns);
  if (patterns) lastPatterns.current = patterns;
  const sleeps = (patterns ?? lastPatterns.current)?.sleeps ?? [];
  useMarkInteractive(babies !== undefined);

  useEffect(() => {
    let cancelled = false;
    void loadPersistedTimer().then((timer) => {
      if (cancelled) return;
      setAsleep(
        timer != null &&
          timer.babyId === String(activeBabyId) &&
          timer.kind === "sleep" &&
          timer.sleepTickOrigin != null,
      );
    });
    return () => {
      cancelled = true;
    };
  }, [activeBabyId, shown?.sleepMinutes]);

  const napAt = predictedNapAt({ sleeps, lastSleepEndMs: shown?.lastSleepEndMs });
  const activeBaby = babyId ? babies?.find((item) => item._id === babyId) : undefined;
  useEffect(() => {
    if (!activeBaby) return;
    void refreshNapReminder({
      babyId: String(activeBaby._id),
      babyName: activeBaby.name,
      napAt,
      asleep,
    });
  }, [activeBaby?._id, activeBaby?.name, napAt, asleep]);

  useEffect(() => {
    if (!activeBaby) return;
    const nowMs = Date.now();
    const lastFeed = last?.lastFeed;
    const lastNappy = last?.lastNappy;
    syncGlanceWidget({
      babyName: activeBaby.name,
      nextNap: asleep
        ? "Asleep"
        : napAt == null
          ? "Watch cues"
          : napAt > nowMs
            ? `Often ready ~${clockTime(napAt)}`
            : "Offer a nap",
      lastFeed: lastFeed
        ? `${lastFeedStrip(lastFeed, nowMs).split(" · ")[0]} · ${clockTime(lastFeed.loggedAt)}`
        : "No feeds yet",
      lastNappy: lastNappy
        ? `${lastNappyStrip(lastNappy, nowMs).split(" · ")[0]} · ${clockTime(lastNappy.loggedAt)}`
        : "No nappies yet",
      sleepToday: `${formatHours((shown?.sleepMinutes ?? 0) / 60)} today`,
    });
  }, [activeBaby?._id, activeBaby?.name, napAt, asleep, last?.lastFeed, last?.lastNappy, shown?.sleepMinutes]);

  useEffect(() => {
    if (!activeBaby) return;
    void ensureWeeklyDigestReminder(String(activeBaby._id), activeBaby.name);
  }, [activeBaby?._id, activeBaby?.name]);

  if (babies !== undefined && babies.length === 0) {
    return (
      <Screen clearDock>
        <Text style={styles.brand}>Scrunch</Text>
        <Text style={styles.emptyTitle}>Add a kid to start</Text>
        <Text style={styles.emptyBody}>Feeds, sleep, and nappies live here once you add a baby.</Text>
        <Pressable style={styles.cta} onPress={() => router.navigate("/kids" as Href)}>
          <Text style={styles.ctaText}>Go to Kids</Text>
        </Pressable>
      </Screen>
    );
  }

  const baby = activeBaby ?? shown?.baby;
  const sleepRange = baby ? sleepDurationRange(baby.dateOfBirth, now) : null;
  const sleepH = (shown?.sleepMinutes ?? 0) / 60;
  const feedGoal = baby ? typicalFeedCount(baby.dateOfBirth, now) : 6;
  const nappyGoal = baby ? typicalNappyCount(baby.dateOfBirth, now) : 6;
  const tummyGoalMin = 30;
  const night =
    baby && baby.nightBedMin != null && baby.nightWakeMin != null
      ? { bedMin: baby.nightBedMin, wakeMin: baby.nightWakeMin }
      : null;
  const rhythm = baby
    ? recommendedDay({ dateOfBirth: baby.dateOfBirth, now, sleeps, night })
    : null;
  const nextWindow = rhythm ? nextSleepCountdown(rhythm.segments, now) : null;

  return (
    <Screen clearDock>
      <View style={layout.header}>
        <View style={layout.brandRow}>
          <Image source={require("../../../assets/icon.png")} style={layout.mark} />
          <Text style={styles.brand} numberOfLines={1}>
            {baby?.name ?? " "}
          </Text>
        </View>
      </View>

      {baby ? (
        <View style={layout.vitals}>
          <Pressable
            style={styles.vital}
            onPress={() => router.push(`/baby/${baby._id}/edit`)}
          >
            <Text style={styles.vitalLabel}>Age</Text>
            <Text style={styles.vitalValue} numberOfLines={1}>
              {formatAge(baby.dateOfBirth, now)}
            </Text>
          </Pressable>
          <Pressable
            style={styles.vital}
            onPress={() => router.push(`/baby/${baby._id}/height`)}
          >
            <Text style={styles.vitalLabel}>Height</Text>
            <Text style={styles.vitalValue} numberOfLines={1}>
              {baby.heightCm != null ? formatHeight(baby.heightCm) : "—"}
            </Text>
          </Pressable>
          <Pressable
            style={styles.vital}
            onPress={() => router.push(`/baby/${baby._id}/weight`)}
          >
            <Text style={styles.vitalLabel}>Weight</Text>
            <Text style={styles.vitalValue} numberOfLines={1}>
              {formatWeight(baby.weightGrams, "lb")}
            </Text>
          </Pressable>
        </View>
      ) : null}

      <WeekStrip selectedDayStart={dayStart} onSelect={setDayStart} />

      <View style={[styles.sleepBlock, !nextWindow && layout.sleepBlockSolo]}>
        {nextWindow && baby ? (
          <Pressable
            style={layout.nap}
            onPress={() => router.push(`/baby/${baby._id}/sleep/timer`)}
          >
            <View style={layout.napTop}>
              <Text style={styles.napLabel}>
                {nextWindow.kind === "night" && nextWindow.inMs > 0 ? "Bedtime" : "Next nap"}
              </Text>
              <Text style={styles.napValue}>{formatCountdown(nextWindow.inMs)}</Text>
            </View>
          </Pressable>
        ) : null}

        <View style={styles.hero}>
          <Pressable
            onPress={() => {
              if (baby) router.push(`/baby/${baby._id}/sleep/patterns`);
            }}
          >
            <View style={styles.heroBody}>
              <Text style={styles.heroValue}>{formatHours(sleepH)}</Text>
              <Text style={styles.heroLabel}>Sleep today</Text>
              {sleepRange ? (
                <Text style={styles.heroTypical}>
                  Typical at this age: {sleepRange.lowHours}–{sleepRange.highHours}h
                </Text>
              ) : null}
            </View>
          </Pressable>
          {rhythm && baby ? (
            <View style={layout.rhythm}>
              <DayRhythmBar
                embedded
                rhythm={rhythm}
                now={now}
                onPress={() => router.push(`/baby/${baby._id}/sleep/patterns`)}
              />
            </View>
          ) : null}
          <LastStrip text={lastSleepStrip(last?.lastSleep, now)} inset={20} />
        </View>
      </View>

      <View style={layout.macros}>
        <MacroCard
          value={shown?.feedCount ?? 0}
          goal={feedGoal}
          label="Feeds"
          last={lastFeedStrip(last?.lastFeed, now)}
          color={colors.teal}
          track={colors.tealSoft}
          onPress={() => {
            if (baby) router.push(`/baby/${baby._id}/feed/patterns`);
          }}
        />
        <MacroCard
          value={shown?.nappyCount ?? 0}
          goal={nappyGoal}
          label="Nappies"
          last={lastNappyStrip(last?.lastNappy, now)}
          color={colors.peach}
          track={colors.peachSoft}
          onPress={() => {
            if (baby) router.push(`/baby/${baby._id}/nappy/patterns`);
          }}
        />
        <MacroCard
          value={Math.round(shown?.tummyMinutes ?? 0)}
          goal={tummyGoalMin}
          unit="min"
          label="Tummy"
          last={lastTummyStrip(last?.lastTummy, now)}
          color={colors.sky}
          track={colors.skySoft}
          onPress={() => {
            if (baby) router.push(`/baby/${baby._id}/tummy/patterns`);
          }}
        />
      </View>

    </Screen>
  );
}

function formatCountdown(ms: number): string {
  if (ms <= 0) return "Now";
  const total = Math.ceil(ms / 60_000);
  const hours = Math.floor(total / 60);
  const minutes = total % 60;
  if (hours === 0) return `${minutes}m`;
  if (minutes === 0) return `${hours}h`;
  return `${hours}h ${minutes}m`;
}

function formatHours(hours: number): string {
  const rounded = Math.round(hours * 10) / 10;
  return Number.isInteger(rounded) ? `${rounded}h` : `${rounded}h`;
}

function clockTime(ms: number): string {
  const d = new Date(ms);
  const h = d.getHours();
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return `${h12}:${String(d.getMinutes()).padStart(2, "0")} ${h < 12 ? "am" : "pm"}`;
}

type LastEvent = {
  loggedAt: number;
  feedKind?: "breast" | "bottle";
  side?: "left" | "right" | "both";
  nappy?: "wee" | "poo" | "both";
  durationMinutes?: number;
} | null | undefined;

function lastFeedStrip(event: LastEvent, now: number): string {
  if (!event) return "No feeds yet";
  const kind =
    event.feedKind === "bottle"
      ? "Bottle"
      : event.side === "left"
        ? "Left"
        : event.side === "right"
          ? "Right"
          : event.side === "both"
            ? "Both"
            : "Feed";
  return `${kind} · ${formatRelative(event.loggedAt, now)}`;
}

function lastNappyStrip(event: LastEvent, now: number): string {
  if (!event) return "No nappies yet";
  const kind =
    event.nappy === "both"
      ? "Wee + poo"
      : event.nappy === "poo"
        ? "Poo"
        : event.nappy === "wee"
          ? "Wee"
          : "Nappy";
  return `${kind} · ${formatRelative(event.loggedAt, now)}`;
}

function lastSleepStrip(event: LastEvent, now: number): string {
  if (!event) return "No sleep yet";
  const dur =
    event.durationMinutes != null && event.durationMinutes > 0
      ? `${event.durationMinutes} min · `
      : "";
  return `${dur}${formatRelative(event.loggedAt, now)}`;
}

function lastTummyStrip(event: LastEvent, now: number): string {
  if (!event) return "No tummy yet";
  const dur =
    event.durationMinutes != null && event.durationMinutes > 0
      ? `${event.durationMinutes} min · `
      : "";
  return `${dur}${formatRelative(event.loggedAt, now)}`;
}

function LastStrip({ text, inset }: { text: string; inset?: number }) {
  const styles = useHomeStyles();
  return (
    <View style={[styles.strip, inset != null && { paddingHorizontal: inset }]}>
      <Text style={styles.stripText} numberOfLines={1}>
        {text}
      </Text>
    </View>
  );
}

function MacroCard({
  value,
  goal,
  unit,
  label,
  last,
  color,
  track,
  onPress,
}: {
  value: number;
  goal: number;
  unit?: string;
  label: string;
  last?: string;
  color: string;
  track: string;
  onPress: () => void;
}) {
  const styles = useHomeStyles();
  return (
    <Pressable style={styles.macro} onPress={onPress}>
      <View style={styles.macroBody}>
        <ProgressRing progress={goal > 0 ? value / goal : 0} size={36} stroke={4} color={color} track={track} />
        <Text style={styles.macroValue}>
          {value}
          <Text style={styles.macroGoal}>
            {" "}
            / {goal}
            {unit ? ` ${unit}` : ""}
          </Text>
        </Text>
        <Text style={styles.macroLabel}>{label}</Text>
      </View>
      {last ? <LastStrip text={last} /> : null}
    </Pressable>
  );
}

const layout = StyleSheet.create({
  header: {
    flexDirection: "row",
    alignItems: "center",
  },
  brandRow: { flexDirection: "row", alignItems: "center", gap: 10, flex: 1, minWidth: 0 },
  mark: { width: 28, height: 28, borderRadius: 8 },
  vitals: { flexDirection: "row", gap: 8 },
  sleepBlockSolo: {
    paddingTop: 6,
  },
  nap: {
    paddingHorizontal: 10,
    paddingVertical: 12,
  },
  napTop: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    gap: 8,
  },
  macros: { flexDirection: "row", gap: 10 },
  rhythm: { paddingHorizontal: 20, paddingBottom: 14 },
});