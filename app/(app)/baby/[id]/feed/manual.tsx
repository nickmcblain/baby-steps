import { useMutation, useQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useState } from "react";
import { Alert, StyleSheet, Text, View } from "react-native";
import { LoggedAtField } from "@/components/LoggedAtField";
import { Screen } from "@/components/Screen";
import { Field, Pill, PrimaryButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import {
  refreshFeedReminder,
  toFeedReminderBaby,
} from "@/lib/feedReminders";
import { nowSnapped, snapToHalfHour } from "@/lib/loggedAt";
import { colors, fonts } from "@/lib/theme";

function initialLoggedAt(startedAt?: string): number {
  if (startedAt && Number.isFinite(Number(startedAt))) {
    return snapToHalfHour(Number(startedAt));
  }
  return nowSnapped();
}

export default function FeedManualScreen() {
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
  const babyId = id as Id<"babies">;
  const baby = useQuery(api.babies.get, { babyId });
  const logFeed = useMutation(api.events.logFeed);
  const [loggedAt, setLoggedAt] = useState(() => initialLoggedAt(startedAt));
  const [kind, setKind] = useState<"breast" | "bottle">("breast");
  const [side, setSide] = useState<"left" | "right" | "both">(
    sideParam === "right" || sideParam === "both" || sideParam === "left"
      ? sideParam
      : "left",
  );
  const [minutes, setMinutes] = useState(
    minutesParam && Number(minutesParam) > 0 ? String(Number(minutesParam)) : "",
  );
  const [ml, setMl] = useState("");
  const [milk, setMilk] = useState<"formula" | "expressed">("formula");
  const [note, setNote] = useState(() => {
    const left = Number(leftMinutesParam);
    const right = Number(rightMinutesParam);
    if (left > 0 && right > 0) return `Left ${left} min · Right ${right} min`;
    return "";
  });

  async function save() {
    try {
      await logFeed({
        babyId,
        loggedAt,
        feedKind: kind,
        side: kind === "breast" ? side : undefined,
        durationMinutes: minutes ? Number(minutes) : undefined,
        amountMl: kind === "bottle" ? Number(ml) : undefined,
        milk: kind === "bottle" ? milk : undefined,
        note: note.trim() || undefined,
      });
      if (baby) {
        const durationMs =
          minutes && Number.isFinite(Number(minutes))
            ? Number(minutes) * 60_000
            : 0;
        await refreshFeedReminder({
          baby: toFeedReminderBaby(baby),
          lastFeedAt: loggedAt + durationMs,
        });
      }
      // Pop past timer/manual to baby home.
      router.dismissTo(`/baby/${id}`);
    } catch (error) {
      Alert.alert("Could not log", error instanceof Error ? error.message : "Try again");
    }
  }

  return (
    <Screen onBack={() => router.back()}>
      <Title>{fromTimer === "1" ? "Finish feed" : "Log feed"}</Title>
      {fromTimer === "1" ? (
        <Text style={styles.hint}>Minutes filled from your timer — tweak anything before saving.</Text>
      ) : null}
      <LoggedAtField value={loggedAt} onChange={setLoggedAt} />
      <View style={styles.row}>
        <Pill label="Breast" selected={kind === "breast"} onPress={() => setKind("breast")} />
        <Pill label="Bottle" selected={kind === "bottle"} onPress={() => setKind("bottle")} />
      </View>
      {kind === "breast" ? (
        <>
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
            placeholder="12"
          />
        </>
      ) : (
        <>
          <Field
            label="Amount (ml)"
            value={ml}
            onChangeText={setMl}
            keyboardType="number-pad"
            placeholder="90"
          />
          <View style={styles.row}>
            <Pill
              label="Formula"
              selected={milk === "formula"}
              onPress={() => setMilk("formula")}
            />
            <Pill
              label="Expressed"
              selected={milk === "expressed"}
              onPress={() => setMilk("expressed")}
            />
          </View>
        </>
      )}
      <Field label="Note" value={note} onChangeText={setNote} placeholder="Dream feed" />
      <PrimaryButton label="Save feed" onPress={() => void save()} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  label: { fontFamily: fonts.medium, color: colors.muted, marginLeft: 4 },
  hint: {
    fontFamily: fonts.body,
    color: colors.muted,
    fontSize: 15,
    lineHeight: 22,
    marginTop: -4,
  },
});
