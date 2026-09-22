import { useQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useMemo, useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { Screen } from "@/components/Screen";
import { SleepPatternChart } from "@/components/SleepPatternChart";
import { IconButton, PlusMark, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { formatDurationMinutes } from "@/lib/eventCopy";
import { fonts, radius } from "@/lib/theme";
import { useTheme, useThemedStyles } from "@/providers/ThemeProvider";

type DayRange = 7 | 14;

export default function FeedPatternsScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const babyId = id as Id<"babies">;
  const [days, setDays] = useState<DayRange>(7);
  const rangeEndMs = useMemo(() => Date.now(), []);
  const { colors } = useTheme();
  const styles = useThemedStyles(({ colors }) => ({
    modePill: {
      paddingHorizontal: 16,
      paddingVertical: 8,
      borderRadius: 999,
      backgroundColor: colors.card,
    },
    modePillOn: {
      backgroundColor: colors.teal,
    },
    modeText: {
      fontFamily: fonts.bold,
      fontSize: 14,
      color: colors.muted,
    },
    modeTextOn: {
      color: colors.card,
    },
    loading: {
      fontFamily: fonts.body,
      color: colors.muted,
      fontSize: 15,
    },
    statLabel: {
      fontFamily: fonts.medium,
      fontSize: 12,
      textTransform: "uppercase" as const,
      letterSpacing: 0.5,
    },
    statValue: {
      fontFamily: fonts.bold,
      fontSize: 20,
      color: colors.ink,
    },
  }));

  const data = useQuery(api.events.feedPatterns, {
    babyId,
    days,
    rangeEndMs,
  });

  return (
    <Screen
      onBack={() => router.back()}
      headerRight={
        <IconButton
          onPress={() => router.push(`/baby/${id}/feed/timer`)}
          accessibilityLabel="Add feed"
        >
          <PlusMark color={colors.ink} />
        </IconButton>
      }
    >
      <Title>Feed patterns</Title>

      <View style={layout.modeRow}>
        <Pressable
          onPress={() => setDays(7)}
          style={[styles.modePill, days === 7 && styles.modePillOn]}
        >
          <Text style={[styles.modeText, days === 7 && styles.modeTextOn]}>
            7 days
          </Text>
        </Pressable>
        <Pressable
          onPress={() => setDays(14)}
          style={[styles.modePill, days === 14 && styles.modePillOn]}
        >
          <Text style={[styles.modeText, days === 14 && styles.modeTextOn]}>
            14 days
          </Text>
        </Pressable>
      </View>

      {data == null ? (
        <Text style={styles.loading}>Loading…</Text>
      ) : (
        <>
          <View style={layout.statsRow}>
            <View style={[layout.stat, { backgroundColor: colors.tealSoft }]}>
              <Text style={[styles.statLabel, { color: colors.tealDark }]}>
                Avg feed / day
              </Text>
              <Text style={styles.statValue}>
                {formatDurationMinutes(
                  Math.round(data.stats.avgFeedMinutesPerDay),
                ) || "—"}
              </Text>
            </View>
            <View style={[layout.stat, { backgroundColor: colors.tealSoft }]}>
              <Text style={[styles.statLabel, { color: colors.tealDark }]}>
                Avg sessions / day
              </Text>
              <Text style={styles.statValue}>
                {data.stats.avgSessionsPerDay > 0
                  ? data.stats.avgSessionsPerDay.toFixed(1)
                  : "—"}
              </Text>
            </View>
          </View>

          <SleepPatternChart
            sleeps={data.feeds}
            days={days}
            rangeEndMs={rangeEndMs}
            barColor={colors.teal}
            emptyText="No feeds in this range yet."
          />
        </>
      )}
    </Screen>
  );
}

const layout = StyleSheet.create({
  modeRow: {
    flexDirection: "row",
    gap: 8,
    alignSelf: "flex-start",
  },
  statsRow: {
    flexDirection: "row",
    gap: 10,
  },
  stat: {
    flex: 1,
    borderRadius: radius.tile,
    paddingHorizontal: 14,
    paddingVertical: 14,
    gap: 4,
  },
});
