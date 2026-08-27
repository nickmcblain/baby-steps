import { useAction } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useState } from "react";
import { Alert } from "react-native";
import { Screen } from "@/components/Screen";
import { Field, PrimaryButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";

export default function QuickLogScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const logFromText = useAction(api.voiceLog.logFromText);
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);

  async function save() {
    const text = note.trim();
    if (text.length < 2) {
      Alert.alert("Write what happened");
      return;
    }
    setBusy(true);
    try {
      const result = await logFromText({
        babyId: id as Id<"babies">,
        note: text,
      });
      Alert.alert("Logged", result.confirmation, [
        { text: "OK", onPress: () => router.back() },
      ]);
    } catch (error) {
      Alert.alert(
        "Could not log",
        error instanceof Error ? error.message : "Try again",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <Screen onBack={() => router.back()}>
      <Title>Type a log</Title>
      <Field
        label="What happened"
        value={note}
        onChangeText={setNote}
        placeholder="Bottle 90 ml, or 45 min nap"
        multiline
      />
      <PrimaryButton
        label={busy ? "Logging…" : "Log it"}
        onPress={() => void save()}
        disabled={busy}
      />
    </Screen>
  );
}
