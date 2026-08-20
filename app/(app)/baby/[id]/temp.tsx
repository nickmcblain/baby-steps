import { useMutation, useQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useEffect, useMemo, useState } from "react";
import { Alert, Pressable, StyleSheet, Text, View } from "react-native";
import { Screen } from "@/components/Screen";
import { Card, IconButton, Pill, PrimaryButton, Subtitle, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { clothingAdvice } from "@/lib/clothingAdvice";
import { colors, fonts, radius, shadow } from "@/lib/theme";

type TempUnit = "C" | "F";

const MIN_C = 5;
const MAX_C = 40;
const STEP_C = 0.5;
const DEFAULT_C = 18;

function cToF(c: number): number {
  return (c * 9) / 5 + 32;
}

function formatTemp(c: number, unit: TempUnit): string {
  if (unit === "F") {
    const f = cToF(c);
    return Number.isInteger(f) ? String(f) : f.toFixed(1);
  }
  return Number.isInteger(c) ? String(c) : c.toFixed(1);
}

export default function TempScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const babyId = id as Id<"babies">;
  const baby = useQuery(api.babies.get, { babyId });
  const saveRoomTemp = useMutation(api.babies.saveRoomTemp);
  const [unit, setUnit] = useState<TempUnit>("C");
  const [tempC, setTempC] = useState(DEFAULT_C);
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    if (!baby || hydrated) return;
    setTempC(baby.lastRoomTempC ?? DEFAULT_C);
    setHydrated(true);
  }, [baby, hydrated]);

  const advice = useMemo(() => {
    if (!baby) return null;
    return clothingAdvice({
      tempC,
      dateOfBirth: baby.dateOfBirth,
      weightGrams: baby.weightGrams,
    });
  }, [baby, tempC]);

  function nudge(deltaC: number) {
    setTempC((current) =>
      Math.min(MAX_C, Math.max(MIN_C, Math.round((current + deltaC) * 2) / 2)),
    );
  }

  async function save() {
    try {
      await saveRoomTemp({ babyId, tempC });
    } catch (error) {
      Alert.alert("Could not save", error instanceof Error ? error.message : "Try again");
    }
  }

  return (
    <Screen>
      <IconButton onPress={() => router.back()}>
        <Text style={{ fontSize: 20 }}>‹</Text>
      </IconButton>
      <Title>Clothing</Title>
      <Subtitle>
        What is the room now? We map it to Lullaby Trust-style TOG layers for
        {baby ? ` ${baby.name}` : " baby"}.
      </Subtitle>

      <View style={styles.unitRow}>
        <Pill label="°C" selected={unit === "C"} onPress={() => setUnit("C")} />
        <Pill
          label="°F"
          selected={unit === "F"}
          onPress={() => setUnit("F")}
          tint={colors.peachSoft}
          ink={colors.peach}
        />
      </View>

      <View style={styles.tempCard}>
        <Text style={styles.tempValue}>
          {formatTemp(tempC, unit)}
          <Text style={styles.tempUnit}> {unit === "C" ? "°C" : "°F"}</Text>
        </Text>
        <View style={styles.arrows}>
          <Pressable
            onPress={() => nudge(-STEP_C)}
            style={styles.arrowBtn}
            accessibilityLabel="Decrease temperature"
          >
            <Text style={styles.arrowGlyph}>‹</Text>
          </Pressable>
          <Text style={styles.stepHint}>±0.5°C</Text>
          <Pressable
            onPress={() => nudge(STEP_C)}
            style={styles.arrowBtn}
            accessibilityLabel="Increase temperature"
          >
            <Text style={styles.arrowGlyph}>›</Text>
          </Pressable>
        </View>
      </View>

      <PrimaryButton label="Check layers" onPress={() => void save()} />
      {advice ? (
        <Card>
          <Text style={styles.tog}>{advice.tog}</Text>
          {advice.layers.map((layer) => (
            <View key={layer} style={styles.layer}>
              <View style={styles.dot} />
              <Text style={styles.layerText}>{layer}</Text>
            </View>
          ))}
          <Text style={styles.why}>{advice.why}</Text>
          {advice.overheat ? (
            <Text style={styles.warn}>
              Feel the chest or back of the neck. Warm is good; sweaty means strip a layer.
            </Text>
          ) : null}
        </Card>
      ) : null}
      <Text style={styles.fine}>
        Guidance, not medical advice. No hats or hoods indoors for sleep.
      </Text>
    </Screen>
  );
}

const styles = StyleSheet.create({
  unitRow: {
    flexDirection: "row",
    gap: 8,
    justifyContent: "center",
  },
  tempCard: {
    backgroundColor: colors.card,
    borderRadius: radius.card,
    paddingVertical: 28,
    paddingHorizontal: 20,
    alignItems: "center",
    gap: 18,
    ...shadow,
  },
  tempValue: {
    fontFamily: fonts.displayBold,
    fontSize: 56,
    color: colors.ink,
    textAlign: "center",
    letterSpacing: -1,
  },
  tempUnit: {
    fontFamily: fonts.bold,
    fontSize: 22,
    color: colors.muted,
  },
  arrows: {
    flexDirection: "row",
    alignItems: "center",
    gap: 20,
  },
  arrowBtn: {
    width: 52,
    height: 52,
    borderRadius: 26,
    backgroundColor: colors.tealSoft,
    alignItems: "center",
    justifyContent: "center",
  },
  arrowGlyph: {
    fontFamily: fonts.bold,
    fontSize: 28,
    lineHeight: 30,
    color: colors.tealDark,
    textAlign: "center",
  },
  stepHint: {
    fontFamily: fonts.medium,
    fontSize: 13,
    color: colors.muted,
    minWidth: 56,
    textAlign: "center",
  },
  tog: { fontFamily: fonts.displayBold, fontSize: 28, color: colors.tealDark },
  layer: { flexDirection: "row", alignItems: "center", gap: 10 },
  dot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: colors.teal,
  },
  layerText: { fontFamily: fonts.medium, fontSize: 16, color: colors.ink },
  why: { fontFamily: fonts.body, color: colors.muted, marginTop: 8 },
  warn: {
    fontFamily: fonts.bold,
    color: colors.peach,
    backgroundColor: colors.peachSoft,
    padding: 12,
    borderRadius: radius.tile,
    overflow: "hidden",
  },
  fine: { fontFamily: fonts.body, color: colors.muted, fontSize: 13 },
});
