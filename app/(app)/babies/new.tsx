import { useMutation } from "convex/react";
import { useRouter } from "expo-router";
import { useState } from "react";
import { Alert, Pressable, StyleSheet, Text, View } from "react-native";
import { DateOfBirthField } from "@/components/DateOfBirthField";
import { HeightField } from "@/components/HeightField";
import { Screen } from "@/components/Screen";
import { WeightField } from "@/components/WeightField";
import { Field, Pill, PrimaryButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import { setActiveBabyId } from "@/lib/activeBaby";
import type { Sex } from "@/lib/growth/lms";
import { colors, fonts } from "@/lib/theme";

export default function NewBabyScreen() {
  const router = useRouter();
  const create = useMutation(api.babies.create);
  const [name, setName] = useState("");
  const [dateOfBirth, setDateOfBirth] = useState<number | null>(null);
  const [sex, setSex] = useState<Sex | null>(null);
  const [weightGrams, setWeightGrams] = useState<number | null>(null);
  const [heightCm, setHeightCm] = useState<number | null>(null);
  const [notes, setNotes] = useState("");
  const [careConsent, setCareConsent] = useState(false);

  async function save() {
    if (!name.trim()) return Alert.alert("Name needed");
    if (!dateOfBirth) return Alert.alert("Pick a date of birth");
    if (!weightGrams) return Alert.alert("Pick a weight");
    if (!careConsent) {
      return Alert.alert(
        "Consent needed",
        "Please confirm you agree to save this baby's details before continuing.",
      );
    }
    try {
      const id = await create({
        name,
        dateOfBirth,
        weightGrams,
        heightCm: heightCm ?? undefined,
        sex: sex ?? undefined,
        notes: notes.trim() || undefined,
        careDataConsent: true,
      });
      await setActiveBabyId(id);
      router.replace(`/baby/${id}`);
    } catch (error) {
      Alert.alert("Could not save", error instanceof Error ? error.message : "Try again");
    }
  }

  return (
    <Screen onBack={() => router.back()}>
      <Title>New baby</Title>
      <Field label="Name" value={name} onChangeText={setName} placeholder="Nico" />
      <DateOfBirthField value={dateOfBirth} onChange={setDateOfBirth} />
      <Text style={styles.label}>Sex (for UK growth charts)</Text>
      <View style={styles.row}>
        <Pill
          label="Boy"
          selected={sex === "boy"}
          onPress={() => setSex((s) => (s === "boy" ? null : "boy"))}
        />
        <Pill
          label="Girl"
          selected={sex === "girl"}
          onPress={() => setSex((s) => (s === "girl" ? null : "girl"))}
        />
      </View>
      <WeightField valueGrams={weightGrams} onChange={setWeightGrams} />
      <HeightField valueCm={heightCm} onChange={setHeightCm} />
      <Field
        label="Notes (optional)"
        value={notes}
        onChangeText={setNotes}
        placeholder="Prefers left side first"
      />
      <Pressable
        onPress={() => setCareConsent((v) => !v)}
        style={styles.consentRow}
        accessibilityRole="checkbox"
        accessibilityState={{ checked: careConsent }}
      >
        <View style={[styles.checkbox, careConsent && styles.checkboxOn]}>
          {careConsent ? <Text style={styles.tick}>✓</Text> : null}
        </View>
        <Text style={styles.consentText}>
          I am a parent or guardian and I consent to Baby Steps storing this
          baby's care details (such as name, date of birth, growth, and logs) so
          the app can work. Baby Steps is not a medical or healthcare service.
        </Text>
      </Pressable>
      <PrimaryButton
        label="Save baby"
        onPress={() => void save()}
        disabled={!careConsent}
      />
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
  consentRow: {
    flexDirection: "row",
    alignItems: "flex-start",
    gap: 12,
    paddingVertical: 4,
  },
  checkbox: {
    width: 24,
    height: 24,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: colors.tealDark,
    backgroundColor: colors.card,
    alignItems: "center",
    justifyContent: "center",
    marginTop: 2,
  },
  checkboxOn: {
    backgroundColor: colors.teal,
    borderColor: colors.teal,
  },
  tick: {
    color: "#fff",
    fontFamily: fonts.bold,
    fontSize: 14,
    lineHeight: 16,
  },
  consentText: {
    flex: 1,
    fontFamily: fonts.body,
    fontSize: 14,
    lineHeight: 20,
    color: colors.ink,
  },
});
