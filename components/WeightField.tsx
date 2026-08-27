import { BottomSheet } from "@/components/BottomSheet";
import { WheelPicker } from "@/components/WheelPicker";
import { Pill } from "@/components/ui";
import {
  formatWeight,
  gramsToKgParts,
  gramsToLbOz,
  kgPartsToGrams,
  lbOzToGrams,
  type WeightUnit,
} from "@/lib/format";
import { colors, fonts, shadow } from "@/lib/theme";
import { useMemo, useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

const KG_VALUES = Array.from({ length: 21 }, (_, i) => i); // 0–20 kg
const TENTHS = Array.from({ length: 10 }, (_, i) => i);
const LB_VALUES = Array.from({ length: 45 }, (_, i) => i); // 0–44 lb
const OZ_VALUES = Array.from({ length: 16 }, (_, i) => i);

export function WeightField({
  valueGrams,
  onChange,
}: {
  valueGrams: number | null;
  onChange: (grams: number) => void;
}) {
  const [open, setOpen] = useState(false);
  const [unit, setUnit] = useState<WeightUnit>("kg");
  const [kg, setKg] = useState(3);
  const [tenths, setTenths] = useState(4);
  const [lb, setLb] = useState(7);
  const [oz, setOz] = useState(8);

  function syncFromGrams(grams: number | null, nextUnit: WeightUnit) {
    const g = grams && grams > 0 ? grams : 3400;
    if (nextUnit === "kg") {
      const parts = gramsToKgParts(g);
      setKg(Math.min(20, parts.kg));
      setTenths(parts.tenths);
    } else {
      const parts = gramsToLbOz(g);
      setLb(Math.min(44, parts.lb));
      setOz(parts.oz);
    }
  }

  function openSheet() {
    syncFromGrams(valueGrams, unit);
    setOpen(true);
  }

  function switchUnit(next: WeightUnit) {
    if (next === unit) return;
    const grams =
      unit === "kg" ? kgPartsToGrams(kg, tenths) : lbOzToGrams(lb, oz);
    setUnit(next);
    syncFromGrams(grams, next);
  }

  function apply() {
    const grams =
      unit === "kg" ? kgPartsToGrams(kg, tenths) : lbOzToGrams(lb, oz);
    if (grams <= 0) return;
    onChange(grams);
    setOpen(false);
  }

  const kgLabels = useMemo(() => KG_VALUES.map((n) => String(n)), []);
  const tenthLabels = useMemo(() => TENTHS.map((n) => `.${n}`), []);
  const lbLabels = useMemo(() => LB_VALUES.map((n) => String(n)), []);
  const ozLabels = useMemo(() => OZ_VALUES.map((n) => String(n)), []);

  return (
    <>
      <View style={styles.field}>
        <Text style={styles.label}>Weight</Text>
        <Pressable onPress={openSheet} style={styles.trigger}>
          <Text style={[styles.triggerText, !valueGrams && styles.placeholder]}>
            {valueGrams ? formatWeight(valueGrams, unit) : "Pick a weight"}
          </Text>
          <Text style={styles.chevron}>⌄</Text>
        </Pressable>
      </View>

      <BottomSheet
        visible={open}
        onClose={apply}
        footer={
          <Pressable onPress={apply} style={styles.confirm}>
            <Text style={styles.confirmText}>Use this weight</Text>
          </Pressable>
        }
      >
        <View style={styles.unitRow}>
          <Pill
            label="Kilograms"
            selected={unit === "kg"}
            onPress={() => switchUnit("kg")}
          />
          <Pill
            label="Pounds & oz"
            selected={unit === "lb"}
            onPress={() => switchUnit("lb")}
            tint={colors.peachSoft}
            ink={colors.peach}
          />
        </View>

        {unit === "kg" ? (
          <View style={styles.wheels}>
            <WheelPicker
              items={kgLabels}
              value={kg}
              onChange={setKg}
              width={96}
              accessibilityLabel="Kilograms"
            />
            <Text style={styles.unitGlyph}>kg</Text>
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
              items={lbLabels}
              value={lb}
              onChange={setLb}
              width={88}
              accessibilityLabel="Pounds"
            />
            <Text style={styles.unitGlyph}>lb</Text>
            <WheelPicker
              items={ozLabels}
              value={oz}
              onChange={setOz}
              width={72}
              accessibilityLabel="Ounces"
            />
            <Text style={styles.unitGlyph}>oz</Text>
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
