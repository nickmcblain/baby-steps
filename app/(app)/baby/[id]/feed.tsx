import { useMutation } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useState } from "react";
import { Alert, StyleSheet, Text, View } from "react-native";
import { Screen } from "@/components/Screen";
import { Field, IconButton, Pill, PrimaryButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { colors, fonts } from "@/lib/theme";

export default function FeedScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const logFeed = useMutation(api.events.logFeed);
  const [kind, setKind] = useState<"breast" | "bottle">("breast");
  const [side, setSide] = useState<"left" | "right" | "both">("left");
  const [minutes, setMinutes] = useState("");
  const [ml, setMl] = useState("");
  const [milk, setMilk] = useState<"formula" | "expressed">("formula");
  const [note, setNote] = useState("");

  async function save() {
    try {
      await logFeed({
        babyId: id as Id<"babies">,
        loggedAt: Date.now(),
        feedKind: kind,
        side: kind === "breast" ? side : undefined,
        durationMinutes: minutes ? Number(minutes) : undefined,
        amountMl: kind === "bottle" ? Number(ml) : undefined,
        milk: kind === "bottle" ? milk : undefined,
        note: note.trim() || undefined,
      });
      router.back();
    } catch (error) {
      Alert.alert("Could not log", error instanceof Error ? error.message : "Try again");
    }
  }

  return (
    <Screen>
      <IconButton onPress={() => router.back()}>
        <Text style={{ fontSize: 20 }}>‹</Text>
      </IconButton>
      <Title>Feed</Title>
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
            label="Minutes (optional)"
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
});
