import { useMutation, useQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useEffect, useState } from "react";
import { Alert, Text } from "react-native";
import { DateOfBirthField } from "@/components/DateOfBirthField";
import { HeightField } from "@/components/HeightField";
import { Screen } from "@/components/Screen";
import { WeightField } from "@/components/WeightField";
import { Field, IconButton, PrimaryButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";

export default function EditBabyScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const babyId = id as Id<"babies">;
  const baby = useQuery(api.babies.get, { babyId });
  const update = useMutation(api.babies.update);
  const [name, setName] = useState("");
  const [dateOfBirth, setDateOfBirth] = useState<number | null>(null);
  const [weightGrams, setWeightGrams] = useState<number | null>(null);
  const [heightCm, setHeightCm] = useState<number | null>(null);
  const [notes, setNotes] = useState("");

  useEffect(() => {
    if (!baby) return;
    setName(baby.name);
    setDateOfBirth(baby.dateOfBirth);
    setWeightGrams(baby.weightGrams);
    setHeightCm(baby.heightCm ?? null);
    setNotes(baby.notes ?? "");
  }, [baby]);

  async function save() {
    if (!name.trim() || !dateOfBirth || !weightGrams) {
      Alert.alert("Check name, date, and weight");
      return;
    }
    try {
      await update({
        babyId,
        name,
        dateOfBirth,
        weightGrams,
        heightCm: heightCm ?? undefined,
        notes: notes.trim() || undefined,
      });
      router.back();
    } catch (error) {
      Alert.alert("Could not save", error instanceof Error ? error.message : "Try again");
    }
  }

  return (
    <Screen>
      <IconButton onPress={() => router.back()}>
        <Text style={{ fontSize: 20 }}>‹</Text>
      </IconButton>
      <Title>Edit</Title>
      <Field label="Name" value={name} onChangeText={setName} />
      <DateOfBirthField value={dateOfBirth} onChange={setDateOfBirth} />
      <WeightField valueGrams={weightGrams} onChange={setWeightGrams} />
      <HeightField valueCm={heightCm} onChange={setHeightCm} />
      <Field label="Notes" value={notes} onChangeText={setNotes} />
      <PrimaryButton label="Save changes" onPress={() => void save()} />
    </Screen>
  );
}
