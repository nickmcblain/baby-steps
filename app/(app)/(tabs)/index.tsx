import { useQuery } from "convex/react";
import { useRouter, type Href } from "expo-router";
import { useEffect, useRef, useState } from "react";
import { Image, Pressable, StyleSheet, Text, View } from "react-native";
import { ProgressRing } from "@/components/ProgressRing";
import { Screen } from "@/components/Screen";
import { WeekStrip } from "@/components/WeekStrip";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { useActiveBabyId } from "@/lib/activeBaby";
import { formatAge, formatHeight, formatWeight } from "@/lib/format";
import { typicalFeedCount, typicalNappyCount, typicalSleepHours } from "@/lib/sleepGoals";
import { colors, fonts, radius, shadow } from "@/lib/theme";
import { addDays, startOfLocalDay } from "@/lib/weekGrid";
import { useMarkInteractive } from "@/lib/useMarkInteractive";

export default function HomeTab() {
  const router = useRouter();
  const babies = useQuery(api.babies.list);
  const { activeBabyId, ready, select } = useActiveBabyId();
  const [dayStart, setDayStart] = useState(() => startOfLocalDay(Date.now()));
  const now = Date.now();

  useEffect(() => {
    if (!ready || !babies?.length) return;
    const known = babies.some((b) => b._id === activeBabyId);
    if (!known) void select(babies[0]._id);
  }, [ready, babies, activeBabyId, select]);

  const babyId = (activeBabyId ?? undefined) as Id<"babies"> | undefined;
  const summary = useQuery(
    api.events.daySummary,
    babyId ? { babyId, dayStart, dayEnd: addDays(dayStart, 1) } : "skip",
  );
  const lastSummary = useRef(summary);
  if (summary) lastSummary.current = summary;
  const shown = summary ?? lastSummary.current;
  useMarkInteractive(babies !== undefined);

  if (babies !== undefined && babies.length === 0) {
    return (
      <Screen clearDock>
        <Text style={styles.brand}>Baby Steps</Text>
        <Text style={styles.emptyTitle}>Add a kid to start</Text>
        <Text style={styles.emptyBody}>Feeds, sleep, and nappies live here once you add a baby.</Text>
        <Pressable style={styles.cta} onPress={() => router.navigate("/kids" as Href)}>
          <Text style={styles.ctaText}>Go to Kids</Text>
        </Pressable>
      </Screen>
    );
  }

  const baby =
    (babyId ? babies?.find((item) => item._id === babyId) : undefined) ?? shown?.baby;
  const sleepGoalH = baby ? typicalSleepHours(baby.dateOfBirth, now) : 14;
  const sleepH = (shown?.sleepMinutes ?? 0) / 60;
  const feedGoal = baby ? typicalFeedCount(baby.dateOfBirth, now) : 6;
  const nappyGoal = baby ? typicalNappyCount(baby.dateOfBirth, now) : 6;
  const tummyGoalMin = 30;

  return (
    <Screen clearDock>
      <View style={styles.header}>
        <View style={styles.brandRow}>
          <Image source={require("../../../assets/icon.png")} style={styles.mark} />
          <Text style={styles.brand} numberOfLines={1}>
            {baby?.name ?? " "}
          </Text>
        </View>
      </View>

      {baby ? (
        <View style={styles.vitals}>
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
              {formatWeight(baby.weightGrams)}
            </Text>
          </Pressable>
        </View>
      ) : null}

      <WeekStrip selectedDayStart={dayStart} onSelect={setDayStart} />

      <Pressable
        style={styles.hero}
        onPress={() => {
          if (baby) router.push(`/baby/${baby._id}/sleep/patterns`);
        }}
      >
        <View style={styles.heroCopy}>
          <Text style={styles.heroValue}>
            {formatHours(sleepH)}
            <Text style={styles.heroGoal}> / {formatHours(sleepGoalH)}</Text>
          </Text>
          <Text style={styles.heroLabel}>Sleep today</Text>
        </View>
        <ProgressRing
          progress={sleepGoalH > 0 ? sleepH / sleepGoalH : 0}
          size={72}
          color={colors.purple}
          track={colors.purpleSoft}
        >
          <View style={[styles.ringGlyph, { backgroundColor: colors.purple }]} />
        </ProgressRing>
      </Pressable>

      <View style={styles.macros}>
        <MacroCard
          value={shown?.feedCount ?? 0}
          goal={feedGoal}
          label="Feeds"
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
          color={colors.peach}
          track={colors.peachSoft}
          onPress={() => {
            if (baby) router.push(`/baby/${baby._id}/nappy/patterns`);
          }}
        />
        <MacroCard
          value={Math.round(shown?.tummyMinutes ?? 0)}
          goal={tummyGoalMin}
          label="Tummy"
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

function formatHours(hours: number): string {
  const rounded = Math.round(hours * 10) / 10;
  return Number.isInteger(rounded) ? `${rounded}h` : `${rounded}h`;
}

function MacroCard({
  value,
  goal,
  label,
  color,
  track,
  onPress,
}: {
  value: number;
  goal: number;
  label: string;
  color: string;
  track: string;
  onPress: () => void;
}) {
  return (
    <Pressable style={styles.macro} onPress={onPress}>
      <ProgressRing progress={goal > 0 ? value / goal : 0} size={36} stroke={4} color={color} track={track} />
      <Text style={styles.macroValue}>
        {value}
        <Text style={styles.macroGoal}> / {goal}</Text>
      </Text>
      <Text style={styles.macroLabel}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: "row",
    alignItems: "center",
  },
  brandRow: { flexDirection: "row", alignItems: "center", gap: 10, flex: 1, minWidth: 0 },
  mark: { width: 28, height: 28, borderRadius: 8 },
  brand: {
    fontFamily: fonts.displayBold,
    fontSize: 26,
    color: colors.ink,
    flexShrink: 1,
  },
  vitals: { flexDirection: "row", gap: 8 },
  vital: {
    flex: 1,
    backgroundColor: colors.card,
    borderRadius: 16,
    paddingHorizontal: 10,
    paddingVertical: 10,
    alignItems: "center",
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
    alignItems: "center",
  },
  ctaText: { fontFamily: fonts.bold, fontSize: 16, color: "#fff" },
  hero: {
    backgroundColor: colors.card,
    borderRadius: radius.tile,
    padding: 20,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    ...shadow,
  },
  heroCopy: { flex: 1, gap: 4 },
  heroValue: { fontFamily: fonts.displayBold, fontSize: 28, color: colors.ink },
  heroGoal: { fontFamily: fonts.bold, fontSize: 20, color: colors.muted },
  heroLabel: { fontFamily: fonts.medium, fontSize: 15, color: colors.muted },
  ringGlyph: { width: 10, height: 10, borderRadius: 5 },
  macros: { flexDirection: "row", gap: 10 },
  macro: {
    flex: 1,
    backgroundColor: colors.card,
    borderRadius: 22,
    padding: 12,
    gap: 8,
    ...shadow,
  },
  macroValue: { fontFamily: fonts.bold, fontSize: 16, color: colors.ink },
  macroGoal: { fontFamily: fonts.medium, fontSize: 13, color: colors.muted },
  macroLabel: { fontFamily: fonts.body, fontSize: 12, color: colors.muted },
});