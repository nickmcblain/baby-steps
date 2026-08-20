import { useMutation, useQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useEffect, useState } from "react";
import { Alert, StyleSheet, Text, View } from "react-native";
import { DateOfBirthField } from "@/components/DateOfBirthField";
import { Screen } from "@/components/Screen";
import { Field, Pill, PrimaryButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import {
  refreshFeedReminder,
  toFeedReminderBaby,
} from "@/lib/feedReminders";
import type { Sex } from "@/lib/growth/lms";
import { colors, fonts } from "@/lib/theme";

type Delivery = "vaginal" | "c_section";
type Feeding = "breast" | "bottle" | "mixed";

export default function EditBabyScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const babyId = id as Id<"babies">;
  const baby = useQuery(api.babies.get, { babyId });
  const update = useMutation(api.babies.update);
  const dash = useQuery(api.events.dashboard, { babyId });
  const [name, setName] = useState("");
  const [dateOfBirth, setDateOfBirth] = useState<number | null>(null);
  const [sex, setSex] = useState<Sex | null>(null);
  const [notes, setNotes] = useState("");
  const [deliveryType, setDeliveryType] = useState<Delivery | null>(null);
  const [gestation, setGestation] = useState("");
  const [feedingMode, setFeedingMode] = useState<Feeding | null>(null);

  useEffect(() => {
    if (!baby) return;
    setName(baby.name);
    setDateOfBirth(baby.dateOfBirth);
    setSex(baby.sex ?? null);
    setNotes(baby.notes ?? "");
    setDeliveryType(baby.deliveryType ?? null);
    setGestation(
      baby.gestationWeeks != null ? String(baby.gestationWeeks) : "",
    );
    setFeedingMode(baby.feedingMode ?? null);
  }, [baby]);

  async function save() {
    if (!name.trim() || !dateOfBirth) {
      Alert.alert("Check name and date of birth");
      return;
    }
    const gestationWeeks = gestation.trim()
      ? Number(gestation.trim())
      : undefined;
    if (
      gestationWeeks !== undefined &&
      (!Number.isFinite(gestationWeeks) ||
        gestationWeeks < 22 ||
        gestationWeeks > 44)
    ) {
      Alert.alert("Gestation weeks should be between 22 and 44");
      return;
    }
    try {
      await update({
        babyId,
        name,
        dateOfBirth,
        sex: sex ?? undefined,
        notes: notes.trim() || undefined,
        deliveryType: deliveryType ?? undefined,
        gestationWeeks,
        feedingMode: feedingMode ?? undefined,
      });
      await refreshFeedReminder({
        baby: toFeedReminderBaby({
          _id: babyId,
          name: name.trim(),
          dateOfBirth,
          weightGrams: baby?.weightGrams ?? 0,
          feedingMode: feedingMode ?? undefined,
        }),
        lastFeedAt: dash?.lastFeed
          ? dash.lastFeed.loggedAt + (dash.lastFeed.durationMinutes ?? 0) * 60_000
          : undefined,
        quiet: true,
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
      <Title>Edit</Title>
      <Field label="Name" value={name} onChangeText={setName} />
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

      <Text style={styles.label}>Delivery (optional)</Text>
      <View style={styles.row}>
        <Pill
          label="Vaginal"
          selected={deliveryType === "vaginal"}
          onPress={() =>
            setDeliveryType((d) => (d === "vaginal" ? null : "vaginal"))
          }
        />
        <Pill
          label="C-section"
          selected={deliveryType === "c_section"}
          onPress={() =>
            setDeliveryType((d) => (d === "c_section" ? null : "c_section"))
          }
        />
      </View>

      <Field
        label="Gestation weeks (optional)"
        value={gestation}
        onChangeText={setGestation}
        keyboardType="number-pad"
        placeholder="40"
      />

      <Text style={styles.label}>Feeding (optional)</Text>
      <View style={styles.row}>
        <Pill
          label="Breast"
          selected={feedingMode === "breast"}
          onPress={() =>
            setFeedingMode((f) => (f === "breast" ? null : "breast"))
          }
        />
        <Pill
          label="Bottle"
          selected={feedingMode === "bottle"}
          onPress={() =>
            setFeedingMode((f) => (f === "bottle" ? null : "bottle"))
          }
        />
        <Pill
          label="Mixed"
          selected={feedingMode === "mixed"}
          onPress={() =>
            setFeedingMode((f) => (f === "mixed" ? null : "mixed"))
          }
        />
      </View>

      <Field label="Notes" value={notes} onChangeText={setNotes} />
      <PrimaryButton label="Save changes" onPress={() => void save()} />
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
});
