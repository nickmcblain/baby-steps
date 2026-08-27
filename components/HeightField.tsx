import { BottomSheet } from "@/components/BottomSheet";
import { WheelPicker } from "@/components/WheelPicker";
import { Pill } from "@/components/ui";
import {
  cmPartsToCm,
  cmToFtIn,
  cmToParts,
  formatHeight,
  ftInToCm,
  type HeightUnit,
} from "@/lib/format";
import { colors, fonts, shadow } from "@/lib/theme";
import { useMemo, useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

const CM_WHOLE = Array.from({ length: 91 }, (_, i) => i + 40); // 40–130
const TENTHS = Array.from({ length: 10 }, (_, i) => i);
const FT_VALUES = Array.from({ length: 5 }, (_, i) => i + 1); // 1–5 ft
const IN_VALUES = Array.from({ length: 12 }, (_, i) => i);

export function HeightField({
  valueCm,
  onChange,
}: {
  valueCm: number | null;
  onChange: (cm: number) => void;
}) {
  const [open, setOpen] = useState(false);
  const [unit, setUnit] = useState<HeightUnit>("cm");
  const [whole, setWhole] = useState(50);
  const [tenths, setTenths] = useState(0);
  const [ft, setFt] = useState(1);
  const [inch, setInch] = useState(8);

  function syncFromCm(cm: number | null, nextUnit: HeightUnit) {
    const value = cm && cm > 0 ? cm : 50;
    if (nextUnit === "cm") {
      const parts = cmToParts(value);
      setWhole(Math.min(130, Math.max(40, parts.whole)));
      setTenths(parts.tenths);
    } else {
      const parts = cmToFtIn(value);
      setFt(Math.min(5, Math.max(1, parts.ft || 1)));
      setInch(parts.inch);
    }
  }

  function openSheet() {
    syncFromCm(valueCm, unit);
    setOpen(true);
  }

  function switchUnit(next: HeightUnit) {
    if (next === unit) return;
    const cm = unit === "cm" ? cmPartsToCm(whole, tenths) : ftInToCm(ft, inch);
    setUnit(next);
    syncFromCm(cm, next);
  }

  function apply() {
    const cm = unit === "cm" ? cmPartsToCm(whole, tenths) : ftInToCm(ft, inch);
    if (cm <= 0) return;
    onChange(cm);
    setOpen(false);
  }

  const wholeLabels = useMemo(() => CM_WHOLE.map(String), []);
  const tenthLabels = useMemo(() => TENTHS.map((n) => `.${n}`), []);
  const ftLabels = useMemo(() => FT_VALUES.map(String), []);
  const inLabels = useMemo(() => IN_VALUES.map(String), []);

  return (
    <>
      <View style={styles.field}>
        <Text style={styles.label}>Height (optional)</Text>
        <Pressable onPress={openSheet} style={styles.trigger}>
          <Text style={[styles.triggerText, !valueCm && styles.placeholder]}>
            {valueCm ? formatHeight(valueCm, unit) : "Pick a height"}
          </Text>
          <Text style={styles.chevron}>⌄</Text>
        </Pressable>
      </View>

      <BottomSheet
        visible={open}
        onClose={apply}
        footer={
          <Pressable onPress={apply} style={styles.confirm}>
            <Text style={styles.confirmText}>Use this height</Text>
          </Pressable>
        }
      >
        <View style={styles.unitRow}>
          <Pill
            label="Centimetres"
            selected={unit === "cm"}
            onPress={() => switchUnit("cm")}
          />
          <Pill
            label="Feet & in"
            selected={unit === "in"}
            onPress={() => switchUnit("in")}
            tint={colors.peachSoft}
            ink={colors.peach}
          />
        </View>

        {unit === "cm" ? (
          <View style={styles.wheels}>
            <WheelPicker
              items={wholeLabels}
              value={Math.max(0, CM_WHOLE.indexOf(whole))}
              onChange={(i) => setWhole(CM_WHOLE[i] ?? 50)}
              width={88}
              accessibilityLabel="Centimetres"
            />
            <Text style={styles.unitGlyph}>cm</Text>
            <WheelPicker
              items={tenthLabels}
              value={tenths}
              onChange={setTenths}
              width={72}
              accessibilityLabel="Tenths"
            />
          </View>
        ) : (
          <View style={styles.wheels}>
            <WheelPicker
              items={ftLabels}
              value={Math.max(0, FT_VALUES.indexOf(ft))}
              onChange={(i) => setFt(FT_VALUES[i] ?? 1)}
              width={72}
              accessibilityLabel="Feet"
            />
            <Text style={styles.unitGlyph}>ft</Text>
            <WheelPicker
              items={inLabels}
              value={inch}
              onChange={setInch}
              width={72}
              accessibilityLabel="Inches"
            />
            <Text style={styles.unitGlyph}>in</Text>
          </View>
        )}
      </BottomSheet>
    </>
  );
}

const styles = StyleSheet.create({
  field: { gap: 8 },
  label: {
    fontFamily: fonts.medium,
    color: colors.muted,
    fontSize: 13,
    marginLeft: 8,
  },
  trigger: {
    backgroundColor: colors.card,
    borderRadius: 22,
    paddingHorizontal: 18,
    paddingVertical: 14,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    ...shadow,
  },
  triggerText: {
    fontFamily: fonts.medium,
    fontSize: 16,
    color: colors.ink,
  },
  placeholder: { color: colors.muted },
  chevron: {
    fontFamily: fonts.bold,
    fontSize: 16,
    color: colors.tealDark,
  },
  unitRow: {
    flexDirection: "row",
    gap: 8,
    justifyContent: "center",
    marginBottom: 8,
  },
  wheels: {
    flexDirection: "row",
    justifyContent: "center",
    alignItems: "center",
    gap: 6,
  },
  unitGlyph: {
    fontFamily: fonts.bold,
    fontSize: 16,
    color: colors.tealDark,
    marginHorizontal: 2,
  },
  confirm: {
    backgroundColor: colors.teal,
    borderRadius: 999,
    minHeight: 52,
    alignItems: "center",
    justifyContent: "center",
  },
  confirmText: {
    fontFamily: fonts.bold,
    fontSize: 16,
    color: "#fff",
  },
});
