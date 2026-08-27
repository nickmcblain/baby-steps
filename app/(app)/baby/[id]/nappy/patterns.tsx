import { useQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useMemo, useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { Screen } from "@/components/Screen";
import { SleepPatternChart } from "@/components/SleepPatternChart";
import { Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { colors, fonts, radius } from "@/lib/theme";

type DayRange = 7 | 14;

export default function NappyPatternsScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const babyId = id as Id<"babies">;
  const [days, setDays] = useState<DayRange>(7);
  const rangeEndMs = useMemo(() => Date.now(), []);

  const data = useQuery(api.events.nappyPatterns, {
    babyId,
    days,
    rangeEndMs,
  });

  return (
    <Screen onBack={() => router.back()}>
      <Title>Nappy patterns</Title>

      <View style={styles.modeRow}>
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
          <View style={styles.statsRow}>
            <View style={[styles.stat, { backgroundColor: colors.peachSoft }]}>
              <Text style={[styles.statLabel, { color: colors.peach }]}>
                Avg / day
              </Text>
              <Text style={styles.statValue}>
                {data.stats.avgSessionsPerDay > 0
                  ? data.stats.avgSessionsPerDay.toFixed(1)
                  : "—"}
              </Text>
            </View>
            <View style={[styles.stat, { backgroundColor: colors.peachSoft }]}>
              <Text style={[styles.statLabel, { color: colors.peach }]}>
                Wee · poo
              </Text>
              <Text style={styles.statValue}>
                {data.stats.weeCount} · {data.stats.pooCount}
              </Text>
            </View>
          </View>

          <SleepPatternChart
            sleeps={data.nappies}
            days={days}
            rangeEndMs={rangeEndMs}
            barColor={colors.peach}
            emptyText="No nappies in this range yet."
          />
        </>
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
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
    backgroundColor: colors.peach,
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
  statLabel: {
    fontFamily: fonts.medium,
    fontSize: 12,
    textTransform: "uppercase",
    letterSpacing: 0.5,
  },
  statValue: {
    fontFamily: fonts.bold,
    fontSize: 20,
    color: colors.ink,
  },
});
