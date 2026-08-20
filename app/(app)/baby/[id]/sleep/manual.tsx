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

const QUICK = [30, 45, 60, 90, 120, 180] as const;

function initialLoggedAt(startedAt?: string): number {
  if (startedAt && Number.isFinite(Number(startedAt))) {
    return snapToHalfHour(Number(startedAt));
  }
  return nowSnapped();
}

export default function SleepManualScreen() {
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
  const logSleep = useMutation(api.events.logSleep);
  const [loggedAt, setLoggedAt] = useState(() => initialLoggedAt(startedAt));
  const [minutes, setMinutes] = useState(
    minutesParam && Number(minutesParam) > 0 ? String(Number(minutesParam)) : "",
  );
  const [note, setNote] = useState("");

  async function save() {
    const durationMinutes = Number(minutes);
    if (!Number.isFinite(durationMinutes) || durationMinutes < 1) {
      Alert.alert("Enter how long they slept");
      return;
    }
    try {
      await logSleep({
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
      <Title>Sleep</Title>
      <LoggedAtField
        label="Fell asleep"
        value={loggedAt}
        onChange={setLoggedAt}
      />
      <Text style={styles.label}>Duration</Text>
      <View style={styles.row}>
        {QUICK.map((m) => (
          <Pill
            key={m}
            label={m < 60 ? `${m}m` : m % 60 === 0 ? `${m / 60}h` : `${Math.floor(m / 60)}h ${m % 60}m`}
            selected={Number(minutes) === m}
            onPress={() => setMinutes(String(m))}
            tint={colors.purpleSoft}
            ink={colors.purple}
          />
        ))}
      </View>
      <Field
        label="Minutes"
        value={minutes}
        onChangeText={setMinutes}
        keyboardType="number-pad"
        placeholder="45"
      />
      <Field
        label="Note"
        value={note}
        onChangeText={setNote}
        placeholder="Pram nap"
      />
      <PrimaryButton label="Save sleep" onPress={() => void save()} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  label: {
    fontFamily: fonts.medium,
    color: colors.muted,
    fontSize: 13,
    marginLeft: 8,
  },
});
