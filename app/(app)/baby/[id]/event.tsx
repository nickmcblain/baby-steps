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

const PRESETS = [
  "Midwife visit",
  "GP visit",
  "Immunisation",
  "Health visitor",
  "Other",
] as const;

export default function CustomEventScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const logCustom = useMutation(api.events.logCustom);
  const [loggedAt, setLoggedAt] = useState(nowSnapped);
  const [preset, setPreset] = useState<(typeof PRESETS)[number]>("Midwife visit");
  const [customTitle, setCustomTitle] = useState("");
  const [note, setNote] = useState("");

  const title =
    preset === "Other" ? customTitle.trim() : preset;

  async function save() {
    if (!title) {
      Alert.alert("Add a title");
      return;
    }
    try {
      await logCustom({
        babyId: id as Id<"babies">,
        loggedAt,
        title,
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
      <Title>Add event</Title>
      <Text style={styles.hint}>
        Midwife, GP, jabs, and other appointments — past or upcoming.
      </Text>
      <Text style={styles.label}>Type</Text>
      <View style={styles.row}>
        {PRESETS.map((item) => (
          <Pill
            key={item}
            label={item}
            selected={preset === item}
            onPress={() => setPreset(item)}
            tint={colors.roseSoft}
            ink={colors.rose}
          />
        ))}
      </View>
      {preset === "Other" ? (
        <Field
          label="Title"
          value={customTitle}
          onChangeText={setCustomTitle}
          placeholder="Hearing test"
        />
      ) : null}
      <LoggedAtField
        label="When"
        value={loggedAt}
        onChange={setLoggedAt}
        allowFuture
      />
      <Field
        label="Note"
        value={note}
        onChangeText={setNote}
        placeholder="Bring red book"
      />
      <PrimaryButton label="Save event" onPress={() => void save()} />
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
    fontFamily: fonts.medium,
    color: colors.muted,
    marginLeft: 4,
  },
  row: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
});
