import { useMutation } from "convex/react";
import { useRouter } from "expo-router";
import { useState } from "react";
import { Alert, Text } from "react-native";
import { DateOfBirthField } from "@/components/DateOfBirthField";
import { HeightField } from "@/components/HeightField";
import { Screen } from "@/components/Screen";
import { WeightField } from "@/components/WeightField";
import { Field, IconButton, PrimaryButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import { setActiveBabyId } from "@/lib/activeBaby";

export default function NewBabyScreen() {
  const router = useRouter();
  const create = useMutation(api.babies.create);
  const [name, setName] = useState("");
  const [dateOfBirth, setDateOfBirth] = useState<number | null>(null);
  const [weightGrams, setWeightGrams] = useState<number | null>(null);
  const [heightCm, setHeightCm] = useState<number | null>(null);
  const [notes, setNotes] = useState("");

  async function save() {
    if (!name.trim()) return Alert.alert("Name needed");
    if (!dateOfBirth) return Alert.alert("Pick a date of birth");
    if (!weightGrams) return Alert.alert("Pick a weight");
    try {
      const id = await create({
        name,
        dateOfBirth,
        weightGrams,
        heightCm: heightCm ?? undefined,
        notes: notes.trim() || undefined,
      });
      await setActiveBabyId(id);
      router.replace(`/baby/${id}`);
    } catch (error) {
      Alert.alert("Could not save", error instanceof Error ? error.message : "Try again");
    }
  }

  return (
    <Screen>
      <IconButton onPress={() => router.back()}>
        <Text style={{ fontSize: 20 }}>‹</Text>
      </IconButton>
      <Title>New baby</Title>
      <Field label="Name" value={name} onChangeText={setName} placeholder="Nico" />
      <DateOfBirthField value={dateOfBirth} onChange={setDateOfBirth} />
      <WeightField valueGrams={weightGrams} onChange={setWeightGrams} />
      <HeightField valueCm={heightCm} onChange={setHeightCm} />
      <Field
        label="Notes (optional)"
        value={notes}
        onChangeText={setNotes}
        placeholder="Prefers left side first"
      />
      <PrimaryButton label="Save baby" onPress={() => void save()} />
    </Screen>
  );
}
