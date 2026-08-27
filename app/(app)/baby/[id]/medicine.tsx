import { useMutation } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useState } from "react";
import { Alert } from "react-native";
import { LoggedAtField } from "@/components/LoggedAtField";
import { Screen } from "@/components/Screen";
import { Field, PrimaryButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { nowSnapped } from "@/lib/loggedAt";

export default function MedicineScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const logMedicine = useMutation(api.events.logMedicine);
  const [loggedAt, setLoggedAt] = useState(nowSnapped);
  const [name, setName] = useState("");
  const [dose, setDose] = useState("");

  async function save() {
    const title = name.trim();
    if (!title) {
      Alert.alert("Add a medicine name");
      return;
    }
    try {
      await logMedicine({
        babyId: id as Id<"babies">,
        loggedAt,
        title,
        note: dose.trim() || undefined,
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
      <Title>Medicine</Title>
      <LoggedAtField value={loggedAt} onChange={setLoggedAt} />
      <Field
        label="Name"
        value={name}
        onChangeText={setName}
        placeholder="Calpol"
      />
      <Field
        label="Dose"
        value={dose}
        onChangeText={setDose}
        placeholder="2.5 ml"
      />
      <PrimaryButton label="Save medicine" onPress={() => void save()} />
    </Screen>
  );
}
