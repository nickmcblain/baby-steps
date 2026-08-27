import { useMutation } from "convex/react";
import { useLocalSearchParams, useRouter, type Href } from "expo-router";
import { useState } from "react";
import { Alert, StyleSheet, Text, View } from "react-native";
import { LoggedAtField } from "@/components/LoggedAtField";
import { Screen } from "@/components/Screen";
import { Field, Pill, PrimaryButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { nowSnapped, snapToHalfHour } from "@/lib/loggedAt";
import { colors, fonts } from "@/lib/theme";

function initialLoggedAt(startedAt?: string): number {
  if (startedAt && Number.isFinite(Number(startedAt))) {
    return snapToHalfHour(Number(startedAt));
  }
  return nowSnapped();
}

export default function PumpManualScreen() {
  const {
    id,
    minutes: minutesParam,
    side: sideParam,
    startedAt,
    fromTimer,
    leftMinutes: leftMinutesParam,
    rightMinutes: rightMinutesParam,
  } = useLocalSearchParams<{
    id: string;
    minutes?: string;
    side?: string;
    startedAt?: string;
    fromTimer?: string;
    leftMinutes?: string;
    rightMinutes?: string;
  }>();
  const router = useRouter();
  const logPump = useMutation(api.events.logPump);
  const [loggedAt, setLoggedAt] = useState(() => initialLoggedAt(startedAt));
  const [side, setSide] = useState<"left" | "right" | "both">(
    sideParam === "right" || sideParam === "both" || sideParam === "left"
      ? sideParam
      : "left",
  );
  const [minutes, setMinutes] = useState(
    minutesParam && Number(minutesParam) > 0 ? String(Number(minutesParam)) : "",
  );
  const [ml, setMl] = useState("");
  const [note, setNote] = useState(() => {
    const left = Number(leftMinutesParam);
    const right = Number(rightMinutesParam);
    if (left > 0 && right > 0) return `Left ${left} min · Right ${right} min`;
    return "";
  });

  async function save() {
    const durationMinutes = Number(minutes);
    if (!Number.isFinite(durationMinutes) || durationMinutes < 1) {
      Alert.alert("Enter how long you pumped");
      return;
    }
    try {
      await logPump({
        babyId: id as Id<"babies">,
        loggedAt,
        side,
        durationMinutes,
        amountMl: ml ? Number(ml) : undefined,
        note: note.trim() || undefined,
      });
      router.dismissTo("/" as Href);
    } catch (error) {
      Alert.alert(
        "Could not log",
        error instanceof Error ? error.message : "Try again",
      );
    }
  }

  return (
    <Screen onBack={() => router.back()}>
      <Title>{fromTimer === "1" ? "Finish pump" : "Log pump"}</Title>
      {fromTimer === "1" ? (
        <Text style={styles.hint}>
          Minutes filled from your timer — add ml if you measured.
        </Text>
      ) : null}
      <LoggedAtField value={loggedAt} onChange={setLoggedAt} />
      <Text style={styles.label}>Side</Text>
      <View style={styles.row}>
        <Pill label="Left" selected={side === "left"} onPress={() => setSide("left")} />
        <Pill label="Right" selected={side === "right"} onPress={() => setSide("right")} />
        <Pill label="Both" selected={side === "both"} onPress={() => setSide("both")} />
      </View>
      <Field
        label="Minutes"
        value={minutes}
        onChangeText={setMinutes}
        keyboardType="number-pad"
        placeholder="15"
      />
      <Field
        label="Amount (ml)"
        value={ml}
        onChangeText={setMl}
        keyboardType="number-pad"
        placeholder="Optional"
      />
      <Field
        label="Note"
        value={note}
        onChangeText={setNote}
        placeholder="Let-down slow"
      />
      <PrimaryButton label="Save pump" onPress={() => void save()} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  hint: {
    fontFamily: fonts.body,
    color: colors.muted,
    fontSize: 15,
    lineHeight: 22,
    marginTop: -4,
  },
  label: {
    fontFamily: fonts.bold,
    fontSize: 13,
    color: colors.muted,
    textTransform: "uppercase",
    letterSpacing: 0.6,
  },
  row: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
});
