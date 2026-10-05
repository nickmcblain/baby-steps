import { useQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { EventList } from "@/components/EventList";
import { Screen } from "@/components/Screen";
import { WeekRhythmChart } from "@/components/WeekRhythmChart";
import { Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { addDays, startOfWeekMonday } from "@/lib/weekGrid";
import { fonts } from "@/lib/theme";
import { useThemedStyles } from "@/providers/ThemeProvider";

type Mode = "list" | "week";

export function TimelineView({
  babyId,
  showBack = false,
}: {
  babyId: Id<"babies">;
  showBack?: boolean;
}) {
  const router = useRouter();
  const now = Date.now();
  const [mode, setMode] = useState<Mode>("list");
  const [weekStartMs, setWeekStartMs] = useState(() => startOfWeekMonday(now));
  const styles = useThemedStyles(({ colors }) => ({
    modePill: {
      paddingHorizontal: 16,
      paddingVertical: 8,
      borderRadius: 999,
      backgroundColor: colors.card,
    },
    modePillOn: {
      backgroundColor: colors.ink,
    },
    modeText: {
      fontFamily: fonts.bold,
      fontSize: 14,
      color: colors.muted,
    },
    modeTextOn: {
      color: colors.card,
    },
    empty: {
      fontFamily: fonts.body,
      color: colors.muted,
      fontSize: 15,
      lineHeight: 22,
    },
  }));

  const weekGrid = useQuery(
    api.events.weekGrid,
    mode === "week" ? { babyId, weekStartMs } : "skip",
  );

  return (
    <Screen
      scroll={mode === "list"}
      onBack={showBack ? () => router.back() : undefined}
      clearDock={!showBack}
    >
      <View style={layout.headingRow}>
        <Title>Timeline</Title>
        <View style={layout.modeRow}>
          <Pressable
            onPress={() => setMode("list")}
            style={[styles.modePill, mode === "list" && styles.modePillOn]}
          >
            <Text style={[styles.modeText, mode === "list" && styles.modeTextOn]}>
              List
            </Text>
          </Pressable>
          <Pressable
            onPress={() => setMode("week")}
            style={[styles.modePill, mode === "week" && styles.modePillOn]}
          >
            <Text style={[styles.modeText, mode === "week" && styles.modeTextOn]}>
              Week
            </Text>
          </Pressable>
        </View>
      </View>

      {mode === "week" ? (
        weekGrid == null ? (
          <Text style={styles.empty}>Loading week…</Text>
        ) : (
          <WeekRhythmChart
            weekStartMs={weekGrid.weekStartMs}
            sleeps={weekGrid.sleeps}
            tummies={weekGrid.tummies}
            markers={weekGrid.markers}
            onPrevWeek={() => setWeekStartMs((w) => addDays(w, -7))}
            onNextWeek={() => setWeekStartMs((w) => addDays(w, 7))}
          />
        )
      ) : (
        <EventList
          babyId={babyId}
          emptyText="Nothing yet. Log care, or tap + to add a midwife visit or jab date."
        />
      )}
    </Screen>
  );
}

export default function TimelineScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  return <TimelineView babyId={id as Id<"babies">} showBack />;
}

const layout = StyleSheet.create({
  headingRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    gap: 12,
  },
  modeRow: {
    flexDirection: "row",
    gap: 8,
  },
});
