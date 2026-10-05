import { useMutation, usePaginatedQuery, useQuery } from "convex/react";
import * as Haptics from "expo-haptics";
import { useMemo, useState, type ReactNode } from "react";
import { Alert, Pressable, StyleSheet, Text, View } from "react-native";
import { BottomSheet } from "@/components/BottomSheet";
import { api } from "@/convex/_generated/api";
import type { Doc, Id } from "@/convex/_generated/dataModel";
import { eventKindLabel, eventTitle } from "@/lib/eventCopy";
import {
  formatLoggedAt,
  formatTimelineDay,
  timelineDayKey,
} from "@/lib/loggedAt";
import { fonts, type ThemeColors } from "@/lib/theme";
import { addDays, startOfLocalDay } from "@/lib/weekGrid";
import { useTheme, useThemedStyles } from "@/providers/ThemeProvider";

type Event = Doc<"events">;

function tintFor(kind: Event["kind"], colors: ThemeColors): string {
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
    case "tummy":
      return colors.skySoft;
    case "custom":
      return colors.roseSoft;
    case "pump":
      return colors.tealSoft;
    case "medicine":
      return colors.amberSoft;
    case "potty":
      return colors.peachSoft;
    case "activity":
      return colors.purpleSoft;
  }
}

function inkFor(kind: Event["kind"], colors: ThemeColors): string {
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
    case "tummy":
      return colors.sky;
    case "custom":
      return colors.rose;
    case "pump":
      return colors.tealDark;
    case "medicine":
      return colors.amber;
    case "potty":
      return colors.peach;
    case "activity":
      return colors.purple;
  }
}

function patternWindow(days: number, rangeEndMs: number) {
  const endDay = startOfLocalDay(rangeEndMs - 1);
  return {
    startMs: addDays(endDay, 1 - days),
    endMs: addDays(endDay, 1),
  };
}

export function EventList({
  babyId,
  kind,
  days,
  rangeEndMs,
  emptyText,
}: {
  babyId: Id<"babies">;
  kind?: Event["kind"];
  days?: 7 | 14 | 30;
  rangeEndMs?: number;
  emptyText?: string;
}) {
  const now = Date.now();
  const ranged = kind != null && days != null && rangeEndMs != null;
  const window = ranged ? patternWindow(days, rangeEndMs) : null;
  const rangedEvents = useQuery(
    api.events.listByKindInRange,
    window && kind
      ? { babyId, kind, startMs: window.startMs, endMs: window.endMs }
      : "skip",
  );
  const paginated = usePaginatedQuery(
    api.events.list,
    ranged ? "skip" : kind ? { babyId, kind } : { babyId },
    { initialNumItems: 40 },
  );
  if (ranged) {
    if (rangedEvents === undefined) return null;
    return (
      <EventTimeline events={rangedEvents} now={now} emptyText={emptyText} />
    );
  }

  return (
    <EventTimeline
      events={paginated.results}
      now={now}
      emptyText={emptyText}
      footer={
        paginated.status === "CanLoadMore" ? (
          <LoadMore onPress={() => paginated.loadMore(20)} />
        ) : null
      }
    />
  );
}

function EventTimeline({
  events,
  now,
  emptyText,
  footer,
}: {
  events: Event[];
  now: number;
  emptyText?: string;
  footer?: ReactNode;
}) {
  const [pendingDelete, setPendingDelete] = useState<Event | null>(null);
  const [deleting, setDeleting] = useState(false);
  const { colors } = useTheme();
  const removeEvent = useMutation(api.events.remove);
  const styles = useThemedStyles(({ colors }) => ({
    day: {
      fontFamily: fonts.bold,
      fontSize: 13,
      color: colors.tealDark,
      textTransform: "uppercase" as const,
      letterSpacing: 0.7,
    },
    line: {
      flex: 1,
      width: 2,
      backgroundColor: colors.line,
      marginTop: 4,
      marginBottom: -4,
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
    empty: {
      fontFamily: fonts.body,
      color: colors.muted,
      fontSize: 15,
      lineHeight: 22,
    },
    deleteKind: {
      fontFamily: fonts.bold,
      fontSize: 12,
      color: colors.muted,
      textTransform: "uppercase" as const,
      letterSpacing: 0.6,
    },
    deleteTitle: {
      fontFamily: fonts.bold,
      fontSize: 20,
      color: colors.ink,
    },
    deleteWhen: {
      fontFamily: fonts.body,
      fontSize: 15,
      color: colors.muted,
    },
    deleteHint: {
      fontFamily: fonts.body,
      fontSize: 14,
      color: colors.muted,
      marginTop: 4,
      marginBottom: 8,
    },
    deleteBtn: {
      backgroundColor: colors.danger,
      borderRadius: 999,
      paddingVertical: 16,
      alignItems: "center" as const,
    },
    deleteBtnText: {
      fontFamily: fonts.bold,
      fontSize: 17,
      color: colors.onAccent,
    },
    cancelText: {
      fontFamily: fonts.bold,
      fontSize: 16,
      color: colors.muted,
    },
  }));

  const sections = useMemo(() => {
    const groups: { key: string; label: string; items: Event[]; dayStart: number }[] =
      [];
    for (const event of events) {
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
  }, [events, now]);

  async function confirmDelete() {
    if (!pendingDelete || deleting) return;
    setDeleting(true);
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium).catch(
      () => undefined,
    );
    try {
      await removeEvent({ eventId: pendingDelete._id });
      setPendingDelete(null);
    } catch (error) {
      Alert.alert(
        "Couldn’t delete",
        error instanceof Error ? error.message : "Try again",
      );
    } finally {
      setDeleting(false);
    }
  }

  function onLongPressEvent(event: Event) {
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(
      () => undefined,
    );
    setPendingDelete(event);
  }

  return (
    <>
      {sections.map((section) => (
        <View key={section.key} style={layout.section}>
          <Text style={styles.day}>{section.label}</Text>
          <View style={layout.rail}>
            {section.items.map((event, index) => (
              <View key={event._id} style={layout.row}>
                <View style={layout.railCol}>
                  <View
                    style={[
                      layout.dot,
                      { backgroundColor: inkFor(event.kind, colors) },
                    ]}
                  />
                  {index < section.items.length - 1 ? (
                    <View style={styles.line} />
                  ) : null}
                </View>
                <Pressable
                  onLongPress={() => onLongPressEvent(event)}
                  delayLongPress={380}
                  style={[
                    layout.card,
                    { backgroundColor: tintFor(event.kind, colors) },
                  ]}
                  accessibilityHint="Press and hold to delete"
                >
                  <View style={layout.cardTop}>
                    <Text
                      style={[layout.kind, { color: inkFor(event.kind, colors) }]}
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
                </Pressable>
              </View>
            ))}
          </View>
        </View>
      ))}

      {footer}
      {events.length === 0 && emptyText ? (
        <Text style={styles.empty}>{emptyText}</Text>
      ) : null}

      <BottomSheet
        visible={pendingDelete != null}
        onClose={() => {
          if (!deleting) setPendingDelete(null);
        }}
      >
        {pendingDelete ? (
          <View style={layout.deleteBody}>
            <Text style={styles.deleteKind}>
              {eventKindLabel(pendingDelete)}
            </Text>
            <Text style={styles.deleteTitle}>{eventTitle(pendingDelete)}</Text>
            <Text style={styles.deleteWhen}>
              {formatLoggedAt(pendingDelete.loggedAt)}
            </Text>
            <Text style={styles.deleteHint}>This can’t be undone.</Text>
            <Pressable
              onPress={() => void confirmDelete()}
              disabled={deleting}
              style={[styles.deleteBtn, deleting && layout.deleteBtnDisabled]}
            >
              <Text style={styles.deleteBtnText}>
                {deleting ? "Deleting…" : "Delete"}
              </Text>
            </Pressable>
            <Pressable
              onPress={() => setPendingDelete(null)}
              disabled={deleting}
              style={layout.cancelBtn}
            >
              <Text style={styles.cancelText}>Cancel</Text>
            </Pressable>
          </View>
        ) : null}
      </BottomSheet>
    </>
  );
}

function LoadMore({ onPress }: { onPress: () => void }) {
  const styles = useThemedStyles(({ colors }) => ({
    more: {
      alignItems: "center" as const,
      padding: 14,
      backgroundColor: colors.card,
      borderRadius: 999,
    },
    moreText: { fontFamily: fonts.bold, color: colors.tealDark },
  }));
  return (
    <Pressable onPress={onPress} style={styles.more}>
      <Text style={styles.moreText}>Load older</Text>
    </Pressable>
  );
}

const layout = StyleSheet.create({
  section: { gap: 12 },
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
  deleteBody: { gap: 8 },
  deleteBtnDisabled: { opacity: 0.45 },
  cancelBtn: {
    alignItems: "center",
    paddingVertical: 12,
  },
});
