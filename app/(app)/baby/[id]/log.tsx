import { usePaginatedQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { Screen } from "@/components/Screen";
import { IconButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { eventTitle } from "@/lib/eventCopy";
import { formatRelative } from "@/lib/format";
import { colors, fonts, radius, shadow } from "@/lib/theme";

export default function LogScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const now = Date.now();
  const { results, status, loadMore } = usePaginatedQuery(
    api.events.list,
    { babyId: id as Id<"babies"> },
    { initialNumItems: 30 },
  );

  return (
    <Screen>
      <IconButton onPress={() => router.back()}>
        <Text style={{ fontSize: 20 }}>‹</Text>
      </IconButton>
      <Title>Log</Title>
      {results.map((event) => (
        <View key={event._id} style={styles.row}>
          <View
            style={[
              styles.badge,
              {
                backgroundColor:
                  event.kind === "feed" ? colors.tealSoft : colors.peachSoft,
              },
            ]}
          >
            <Text style={{ fontSize: 18 }}>{event.kind === "feed" ? "🍼" : "🧷"}</Text>
          </View>
          <View style={{ flex: 1 }}>
            <Text style={styles.title}>{eventTitle(event)}</Text>
            <Text style={styles.meta}>{formatRelative(event.loggedAt, now)}</Text>
            {event.note ? <Text style={styles.note}>{event.note}</Text> : null}
          </View>
        </View>
      ))}
      {status === "CanLoadMore" ? (
        <Pressable onPress={() => loadMore(20)} style={styles.more}>
          <Text style={styles.moreText}>Load older</Text>
        </Pressable>
      ) : null}
      {results.length === 0 ? (
        <Text style={styles.meta}>Nothing logged yet. The 3am entries start here.</Text>
      ) : null}
    </Screen>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: "row",
    gap: 12,
    backgroundColor: colors.card,
    borderRadius: radius.tile,
    padding: 14,
    ...shadow,
    alignItems: "center",
  },
  badge: {
    width: 46,
    height: 46,
    borderRadius: 23,
    alignItems: "center",
    justifyContent: "center",
  },
  title: { fontFamily: fonts.bold, fontSize: 16, color: colors.ink },
  meta: { fontFamily: fonts.body, color: colors.muted },
  note: { fontFamily: fonts.body, color: colors.ink, marginTop: 4 },
  more: {
    alignItems: "center",
    padding: 14,
    backgroundColor: colors.card,
    borderRadius: radius.pill,
  },
  moreText: { fontFamily: fonts.bold, color: colors.tealDark },
});
