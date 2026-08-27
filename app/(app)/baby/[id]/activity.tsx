import { useMutation } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useState } from "react";
import { Alert, StyleSheet, Text, View } from "react-native";
import { LoggedAtField } from "@/components/LoggedAtField";
import { Screen } from "@/components/Screen";
import { Field, Pill, PrimaryButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { nowSnapped } from "@/lib/loggedAt";
import { colors, fonts } from "@/lib/theme";

const PRESETS = ["Bath", "Play", "Walk", "Other"] as const;
const QUICK = [5, 10, 15, 20, 30, 45] as const;

export default function ActivityScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const logActivity = useMutation(api.events.logActivity);
  const [loggedAt, setLoggedAt] = useState(nowSnapped);
  const [preset, setPreset] = useState<(typeof PRESETS)[number]>("Play");
  const [customTitle, setCustomTitle] = useState("");
  const [minutes, setMinutes] = useState("");
  const [note, setNote] = useState("");

  const title = preset === "Other" ? customTitle.trim() : preset;

  async function save() {
    if (!title) {
      Alert.alert("Pick an activity");
      return;
    }
    try {
      await logActivity({
        babyId: id as Id<"babies">,
        loggedAt,
        title,
        durationMinutes: minutes ? Number(minutes) : undefined,
        note: note.trim() || undefined,
      });
      router.back();
    } catch (error) {
      Alert.alert(
        "Could not log",
        error instanceof Error ? error.message : "Try again",
      );
    }
  }

  return (
    <Screen onBack={() => router.back()}>
      <Title>Activity</Title>
      <LoggedAtField value={loggedAt} onChange={setLoggedAt} />
      <Text style={styles.label}>Type</Text>
      <View style={styles.row}>
        {PRESETS.map((item) => (
          <Pill
            key={item}
            label={item}
            selected={preset === item}
            onPress={() => setPreset(item)}
            tint={colors.purpleSoft}
            ink={colors.purple}
          />
        ))}
      </View>
      {preset === "Other" ? (
        <Field
          label="Title"
          value={customTitle}
          onChangeText={setCustomTitle}
          placeholder="Swimming"
        />
      ) : null}
      <Text style={styles.label}>Duration</Text>
      <View style={styles.row}>
        {QUICK.map((m) => (
          <Pill
            key={m}
            label={`${m}m`}
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
        placeholder="Optional"
      />
      <Field
        label="Note"
        value={note}
        onChangeText={setNote}
        placeholder="Loved the water"
      />
      <PrimaryButton label="Save activity" onPress={() => void save()} />
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
