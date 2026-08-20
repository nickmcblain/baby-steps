import { usePaginatedQuery, useQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useMemo, useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { Screen } from "@/components/Screen";
import { WeekRhythmChart } from "@/components/WeekRhythmChart";
import { IconButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Doc, Id } from "@/convex/_generated/dataModel";
import { eventKindLabel, eventTitle } from "@/lib/eventCopy";
import {
  formatLoggedAt,
  formatTimelineDay,
  timelineDayKey,
} from "@/lib/loggedAt";
import { addDays, startOfWeekMonday } from "@/lib/weekGrid";
import { colors, fonts } from "@/lib/theme";

type Event = Doc<"events">;
type Mode = "list" | "week";

function tintFor(kind: Event["kind"]): string {
  switch (kind) {
    case "feed":
      return colors.tealSoft;
    case "nappy":
      return colors.peachSoft;
    case "weight":
      return colors.amberSoft;
    case "height":
      return colors.skySoft;
    case "sleep":
      return colors.purpleSoft;
    case "custom":
      return colors.roseSoft;
  }
}

function inkFor(kind: Event["kind"]): string {
  switch (kind) {
    case "feed":
      return colors.tealDark;
    case "nappy":
      return colors.peach;
    case "weight":
      return colors.amber;
    case "height":
      return colors.sky;
    case "sleep":
      return colors.purple;
    case "custom":
      return colors.rose;
  }
}

function PlusGlyph() {
  return (
    <View style={styles.plusGlyph} accessibilityLabel="Add event">
      <View style={styles.plusH} />
      <View style={styles.plusV} />
    </View>
  );
}

export default function TimelineScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const babyId = id as Id<"babies">;
  const now = Date.now();
  const [mode, setMode] = useState<Mode>("list");
  const [weekStartMs, setWeekStartMs] = useState(() => startOfWeekMonday(now));

  const { results, status, loadMore } = usePaginatedQuery(
    api.events.list,
    { babyId },
    { initialNumItems: 40 },
  );

  const weekGrid = useQuery(
    api.events.weekGrid,
    mode === "week" ? { babyId, weekStartMs } : "skip",
  );

  const sections = useMemo(() => {
    const groups: { key: string; label: string; items: Event[]; dayStart: number }[] =
      [];
    for (const event of results) {
      const key = timelineDayKey(event.loggedAt);
      const last = groups[groups.length - 1];
      if (last && last.key === key) {
        last.items.push(event);
      } else {
        const d = new Date(event.loggedAt);
        const dayStart = new Date(
          d.getFullYear(),
          d.getMonth(),
          d.getDate(),
        ).getTime();
        groups.push({
          key,
          label: formatTimelineDay(event.loggedAt, now),
          items: [event],
          dayStart,
        });
      }
    }

    const todayStart = new Date(
      new Date(now).getFullYear(),
      new Date(now).getMonth(),
      new Date(now).getDate(),
    ).getTime();

    const upcoming = groups
      .filter((g) => g.dayStart > todayStart)
      .sort((a, b) => a.dayStart - b.dayStart);
    const rest = groups.filter((g) => g.dayStart <= todayStart);
    return [...upcoming, ...rest];
  }, [results, now]);

  return (
    <Screen
      scroll={mode === "list"}
      onBack={() => router.back()}
      headerRight={
        <IconButton
          onPress={() => router.push(`/baby/${id}/event`)}
          accessibilityLabel="Add event"
        >
          <PlusGlyph />
        </IconButton>
      }
    >
      <Title>Timeline</Title>
      <Text style={styles.subtitle}>
        {mode === "list"
          ? "Care logs and appointments — upcoming first, then recent."
          : "Sleep blocks and care markers for the week."}
      </Text>

      <View style={styles.modeRow}>
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

      {mode === "week" ? (
        weekGrid == null ? (
          <Text style={styles.empty}>Loading week…</Text>
        ) : (
          <WeekRhythmChart
            weekStartMs={weekGrid.weekStartMs}
            sleeps={weekGrid.sleeps}
            markers={weekGrid.markers}
            onPrevWeek={() => setWeekStartMs((w) => addDays(w, -7))}
            onNextWeek={() => setWeekStartMs((w) => addDays(w, 7))}
          />
        )
      ) : (
        <>
          {sections.map((section) => (
            <View key={section.key} style={styles.section}>
              <Text style={styles.day}>{section.label}</Text>
              <View style={styles.rail}>
                {section.items.map((event, index) => (
                  <View key={event._id} style={styles.row}>
                    <View style={styles.railCol}>
                      <View
                        style={[
                          styles.dot,
                          { backgroundColor: inkFor(event.kind) },
                        ]}
                      />
                      {index < section.items.length - 1 ? (
                        <View style={styles.line} />
                      ) : null}
                    </View>
                    <View
                      style={[
                        styles.card,
                        { backgroundColor: tintFor(event.kind) },
                      ]}
                    >
                      <View style={styles.cardTop}>
                        <Text
                          style={[styles.kind, { color: inkFor(event.kind) }]}
                        >
                          {eventKindLabel(event)}
                        </Text>
                        <Text style={styles.time}>
                          {formatLoggedAt(event.loggedAt).split(" · ")[1]}
                        </Text>
                      </View>
                      <Text style={styles.title}>{eventTitle(event)}</Text>
                      {event.note ? (
                        <Text style={styles.note}>{event.note}</Text>
                      ) : null}
                    </View>
                  </View>
                ))}
              </View>
            </View>
          ))}

          {status === "CanLoadMore" ? (
            <Pressable onPress={() => loadMore(20)} style={styles.more}>
              <Text style={styles.moreText}>Load older</Text>
            </Pressable>
          ) : null}
          {results.length === 0 ? (
            <Text style={styles.empty}>
              Nothing yet. Log care, or tap + to add a midwife visit or jab date.
            </Text>
          ) : null}
        </>
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  plusGlyph: {
    width: 18,
    height: 18,
    alignItems: "center",
    justifyContent: "center",
  },
  plusH: {
    position: "absolute",
    width: 14,
    height: 2.5,
    borderRadius: 2,
    backgroundColor: colors.ink,
  },
  plusV: {
    position: "absolute",
    width: 2.5,
    height: 14,
    borderRadius: 2,
    backgroundColor: colors.ink,
  },
  subtitle: {
    fontFamily: fonts.body,
    color: colors.muted,
    fontSize: 15,
    marginTop: -8,
  },
  modeRow: {
    flexDirection: "row",
    gap: 8,
    alignSelf: "flex-start",
  },
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
  section: { gap: 12 },
  day: {
    fontFamily: fonts.bold,
    fontSize: 13,
    color: colors.tealDark,
    textTransform: "uppercase",
    letterSpacing: 0.7,
  },
  rail: { gap: 0 },
  row: {
    flexDirection: "row",
    gap: 12,
    minHeight: 72,
  },
  railCol: {
    width: 18,
    alignItems: "center",
  },
  dot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginTop: 18,
    zIndex: 1,
  },
  line: {
    flex: 1,
    width: 2,
    backgroundColor: colors.line,
    marginTop: 4,
    marginBottom: -4,
  },
  card: {
    flex: 1,
    borderRadius: 20,
    paddingHorizontal: 16,
    paddingVertical: 14,
    marginBottom: 12,
    gap: 4,
  },
  cardTop: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  kind: {
    fontFamily: fonts.bold,
    fontSize: 12,
    textTransform: "uppercase",
    letterSpacing: 0.6,
  },
  time: {
    fontFamily: fonts.medium,
    fontSize: 13,
    color: colors.muted,
  },
  title: {
    fontFamily: fonts.bold,
    fontSize: 17,
    color: colors.ink,
  },
  note: {
    fontFamily: fonts.body,
    color: colors.ink,
    opacity: 0.75,
    marginTop: 2,
  },
  more: {
    alignItems: "center",
    padding: 14,
    backgroundColor: colors.card,
    borderRadius: 999,
  },
  moreText: { fontFamily: fonts.bold, color: colors.tealDark },
  empty: {
    fontFamily: fonts.body,
    color: colors.muted,
    fontSize: 15,
    lineHeight: 22,
  },
});
