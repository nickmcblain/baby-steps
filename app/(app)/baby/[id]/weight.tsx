import { useMutation, useQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useEffect, useState } from "react";
import { Alert, Pressable, StyleSheet, Text } from "react-native";
import { GrowthChart } from "@/components/GrowthChart";
import { LoggedAtField } from "@/components/LoggedAtField";
import { Screen } from "@/components/Screen";
import { WeightField } from "@/components/WeightField";
import { Field, PrimaryButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import {
  refreshFeedReminder,
  toFeedReminderBaby,
} from "@/lib/feedReminders";
import { nowSnapped } from "@/lib/loggedAt";
import { colors, fonts } from "@/lib/theme";

export default function WeightScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const babyId = id as Id<"babies">;
  const series = useQuery(api.events.growthSeries, {
    babyId,
    kind: "weight",
  });
  const logWeight = useMutation(api.events.logWeight);
  const dash = useQuery(api.events.dashboard, { babyId });
  const [loggedAt, setLoggedAt] = useState(nowSnapped);
  const [weightGrams, setWeightGrams] = useState<number | null>(null);
  const [note, setNote] = useState("");

  const baby = series?.baby;

  useEffect(() => {
    if (baby && weightGrams == null) {
      setWeightGrams(baby.weightGrams);
    }
  }, [baby, weightGrams]);

  async function save() {
    if (!weightGrams) {
      Alert.alert("Pick a weight");
      return;
    }
    try {
      await logWeight({
        babyId,
        loggedAt,
        weightGrams,
        note: note.trim() || undefined,
      });
      if (baby) {
        await refreshFeedReminder({
          baby: toFeedReminderBaby({ ...baby, weightGrams }),
          lastFeedAt: dash?.lastFeed
            ? dash.lastFeed.loggedAt +
              (dash.lastFeed.durationMinutes ?? 0) * 60_000
            : undefined,
          quiet: true,
        });
      }
      router.back();
    } catch (error) {
      Alert.alert(
        "Could not save",
        error instanceof Error ? error.message : "Try again",
      );
    }
  }

  return (
    <Screen onBack={() => router.back()}>
      <Title>Weigh-in</Title>

      {series ? (
        <GrowthChart
          metric="weight"
          sex={baby?.sex}
          dateOfBirth={series.baby.dateOfBirth}
          points={series.points}
        />
      ) : (
        <Text style={styles.loading}>Loading chart…</Text>
      )}

      {!baby?.sex && (
        <Pressable onPress={() => router.push(`/baby/${id}/edit`)}>
          <Text style={styles.linkish}>Add boy / girl on Edit →</Text>
        </Pressable>
      )}

      <LoggedAtField value={loggedAt} onChange={setLoggedAt} />
      <WeightField valueGrams={weightGrams} onChange={setWeightGrams} />
      <Field
        label="Note"
        value={note}
        onChangeText={setNote}
        placeholder="After bath"
      />
      <PrimaryButton label="Save weigh-in" onPress={() => void save()} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  loading: {
    fontFamily: fonts.body,
    color: colors.muted,
  },
  linkish: {
    fontFamily: fonts.medium,
    color: colors.tealDark,
    fontSize: 14,
  },
});
