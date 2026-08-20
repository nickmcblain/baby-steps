import { useMutation, useQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useEffect, useState } from "react";
import { Alert, Pressable, StyleSheet, Text } from "react-native";
import { GrowthChart } from "@/components/GrowthChart";
import { HeightField } from "@/components/HeightField";
import { LoggedAtField } from "@/components/LoggedAtField";
import { Screen } from "@/components/Screen";
import { Field, PrimaryButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { nowSnapped } from "@/lib/loggedAt";
import { colors, fonts } from "@/lib/theme";

export default function HeightScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const babyId = id as Id<"babies">;
  const series = useQuery(api.events.growthSeries, {
    babyId,
    kind: "height",
  });
  const logHeight = useMutation(api.events.logHeight);
  const [loggedAt, setLoggedAt] = useState(nowSnapped);
  const [heightCm, setHeightCm] = useState<number | null>(null);
  const [note, setNote] = useState("");

  const baby = series?.baby;

  useEffect(() => {
    if (baby && heightCm == null && baby.heightCm != null) {
      setHeightCm(baby.heightCm);
    }
  }, [baby, heightCm]);

  async function save() {
    if (!heightCm) {
      Alert.alert("Pick a height");
      return;
    }
    try {
      await logHeight({
        babyId,
        loggedAt,
        heightCm,
        note: note.trim() || undefined,
      });
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
      <Title>Height</Title>

      {series ? (
        <GrowthChart
          metric="length"
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
      <HeightField valueCm={heightCm} onChange={setHeightCm} />
      <Field
        label="Note"
        value={note}
        onChangeText={setNote}
        placeholder="Clinic visit"
      />
      <PrimaryButton label="Save height" onPress={() => void save()} />
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
