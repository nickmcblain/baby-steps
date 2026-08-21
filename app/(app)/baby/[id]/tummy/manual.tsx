import { useMutation } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useState } from "react";
import { Alert, StyleSheet, Text, View } from "react-native";
import { LoggedAtField } from "@/components/LoggedAtField";
import { Screen } from "@/components/Screen";
import { Field, Pill, PrimaryButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { nowSnapped, snapToHalfHour } from "@/lib/loggedAt";
import { colors, fonts } from "@/lib/theme";

const QUICK = [3, 5, 10, 15, 20, 30] as const;

function initialLoggedAt(startedAt?: string): number {
  if (startedAt && Number.isFinite(Number(startedAt))) {
    return snapToHalfHour(Number(startedAt));
  }
  return nowSnapped();
}

export default function TummyManualScreen() {
  const {
    id,
    minutes: minutesParam,
    startedAt,
  } = useLocalSearchParams<{
    id: string;
    minutes?: string;
    startedAt?: string;
  }>();
  const router = useRouter();
  const logTummy = useMutation(api.events.logTummy);
  const [loggedAt, setLoggedAt] = useState(() => initialLoggedAt(startedAt));
  const [minutes, setMinutes] = useState(
    minutesParam && Number(minutesParam) > 0 ? String(Number(minutesParam)) : "",
  );
  const [note, setNote] = useState("");

  async function save() {
    const durationMinutes = Number(minutes);
    if (!Number.isFinite(durationMinutes) || durationMinutes < 1) {
      Alert.alert("Enter how long tummy time lasted");
      return;
    }
    try {
      await logTummy({
        babyId: id as Id<"babies">,
        loggedAt,
        durationMinutes,
        note: note.trim() || undefined,
      });
      router.dismissTo(`/baby/${id}`);
    } catch (error) {
      Alert.alert(
        "Could not log",
        error instanceof Error ? error.message : "Try again",
      );
    }
  }

  return (
    <Screen onBack={() => router.back()}>
      <Title>Tummy time</Title>
      <LoggedAtField
        label="Started"
        value={loggedAt}
        onChange={setLoggedAt}
      />
      <Text style={styles.label}>Duration</Text>
      <View style={styles.row}>
        {QUICK.map((m) => (
          <Pill
            key={m}
            label={`${m}m`}
            selected={Number(minutes) === m}
            onPress={() => setMinutes(String(m))}
            tint={colors.skySoft}
            ink={colors.sky}
          />
        ))}
      </View>
      <Field
        label="Minutes"
        value={minutes}
        onChangeText={setMinutes}
        keyboardType="number-pad"
        placeholder="10"
      />
      <Field
        label="Note"
        value={note}
        onChangeText={setNote}
        placeholder="On the play mat"
      />
      <PrimaryButton label="Save tummy time" onPress={() => void save()} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  label: {
    fontFamily: fonts.bold,
    fontSize: 13,
    color: colors.muted,
    textTransform: "uppercase",
    letterSpacing: 0.6,
  },
  row: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
});
