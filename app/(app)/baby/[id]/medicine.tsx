import { useMutation, useQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useState } from "react";
import { Alert, StyleSheet, Text, View } from "react-native";
import { LoggedAtField } from "@/components/LoggedAtField";
import { Screen } from "@/components/Screen";
import { Field, Pill, PrimaryButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { nowSnapped } from "@/lib/loggedAt";
import { scheduleMedicineReminder } from "@/lib/medicineReminders";
import { colors, fonts } from "@/lib/theme";

const REMIND = [4, 6, 8] as const;

export default function MedicineScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const baby = useQuery(api.babies.get, { babyId: id as Id<"babies"> });
  const logMedicine = useMutation(api.events.logMedicine);
  const [loggedAt, setLoggedAt] = useState(nowSnapped);
  const [name, setName] = useState("");
  const [dose, setDose] = useState("");
  const [remindHours, setRemindHours] = useState<number | null>(4);

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
      if (remindHours != null && baby) {
        const dueAt = await scheduleMedicineReminder({
          babyId: String(baby._id),
          babyName: baby.name,
          name: title,
          dose: dose.trim() || undefined,
          hours: remindHours,
        });
        if (dueAt == null) {
          Alert.alert(
            "Logged, no reminder",
            "Allow notifications to get the next-dose nudge.",
          );
        }
      }
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
      <Text style={styles.label}>Remind me</Text>
      <View style={styles.row}>
        {REMIND.map((hours) => (
          <Pill
            key={hours}
            label={`${hours}h`}
            selected={remindHours === hours}
            onPress={() => setRemindHours(hours)}
            tint={colors.amberSoft}
            ink={colors.ink}
          />
        ))}
        <Pill
          label="Off"
          selected={remindHours == null}
          onPress={() => setRemindHours(null)}
          tint={colors.amberSoft}
          ink={colors.ink}
        />
      </View>
      <PrimaryButton label="Save medicine" onPress={() => void save()} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  label: {
    fontFamily: fonts.medium,
    fontSize: 13,
    color: colors.muted,
    marginLeft: 8,
  },
  row: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
});
