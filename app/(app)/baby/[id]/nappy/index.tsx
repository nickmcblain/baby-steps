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

type Kind = "wee" | "poo" | "both";
type Size = "small" | "medium" | "large";

export default function NappyScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const logNappy = useMutation(api.events.logNappy);
  const [loggedAt, setLoggedAt] = useState(nowSnapped);
  const [kind, setKind] = useState<Kind>("wee");
  const [wee, setWee] = useState<Size>("medium");
  const [poo, setPoo] = useState<Size>("medium");
  const [note, setNote] = useState("");

  async function save() {
    try {
      await logNappy({
        babyId: id as Id<"babies">,
        loggedAt,
        nappy: kind,
        weeSize: kind === "wee" || kind === "both" ? wee : undefined,
        pooSize: kind === "poo" || kind === "both" ? poo : undefined,
        note: note.trim() || undefined,
      });
      router.back();
    } catch (error) {
      Alert.alert("Could not log", error instanceof Error ? error.message : "Try again");
    }
  }

  return (
    <Screen onBack={() => router.back()}>
      <Title>Nappy</Title>
      <LoggedAtField value={loggedAt} onChange={setLoggedAt} />
      <View style={styles.row}>
        <Pill label="Wee" selected={kind === "wee"} onPress={() => setKind("wee")} tint={colors.amberSoft} ink={colors.ink} />
        <Pill label="Poo" selected={kind === "poo"} onPress={() => setKind("poo")} tint={colors.peachSoft} ink={colors.peach} />
        <Pill label="Both" selected={kind === "both"} onPress={() => setKind("both")} />
      </View>
      {(kind === "wee" || kind === "both") && (
        <>
          <Text style={styles.label}>Wee size</Text>
          <SizeRow value={wee} onChange={setWee} />
        </>
      )}
      {(kind === "poo" || kind === "both") && (
        <>
          <Text style={styles.label}>Poo size</Text>
          <SizeRow value={poo} onChange={setPoo} />
        </>
      )}
      <Field label="Note" value={note} onChangeText={setNote} placeholder="Seedy mustard" />
      <PrimaryButton label="Save nappy" onPress={() => void save()} />
    </Screen>
  );
}

function SizeRow({ value, onChange }: { value: Size; onChange: (s: Size) => void }) {
  return (
    <View style={styles.row}>
      <Pill label="Small" selected={value === "small"} onPress={() => onChange("small")} />
      <Pill label="Medium" selected={value === "medium"} onPress={() => onChange("medium")} />
      <Pill label="Large" selected={value === "large"} onPress={() => onChange("large")} />
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  label: { fontFamily: fonts.medium, color: colors.muted, marginLeft: 4 },
});
