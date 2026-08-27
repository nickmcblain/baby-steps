import { BottomSheet } from "@/components/BottomSheet";
import { WheelPicker } from "@/components/WheelPicker";
import { formatDob } from "@/lib/format";
import { colors, fonts, shadow } from "@/lib/theme";
import { useEffect, useMemo, useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

const MONTHS = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
] as const;

function daysInMonth(year: number, monthIndex: number): number {
  return new Date(Date.UTC(year, monthIndex + 1, 0)).getUTCDate();
}

function clampDate(year: number, monthIndex: number, day: number): number {
  const maxDay = daysInMonth(year, monthIndex);
  const safeDay = Math.min(day, maxDay);
  return Date.UTC(year, monthIndex, safeDay);
}

function partsFromMs(ms: number | null): { year: number; month: number; day: number } {
  if (ms == null) {
    const now = new Date();
    return {
      year: now.getUTCFullYear(),
      month: now.getUTCMonth(),
      day: Math.min(now.getUTCDate(), 28),
    };
  }
  const date = new Date(ms);
  return {
    year: date.getUTCFullYear(),
    month: date.getUTCMonth(),
    day: date.getUTCDate(),
  };
}

export function DateOfBirthField({
  value,
  onChange,
}: {
  value: number | null;
  onChange: (ms: number) => void;
}) {
  const [open, setOpen] = useState(false);
  const today = new Date();
  const maxYear = today.getUTCFullYear();
  const years = useMemo(() => {
    const list: number[] = [];
    for (let y = maxYear; y >= maxYear - 6; y -= 1) list.push(y);
    return list;
  }, [maxYear]);

  const initial = partsFromMs(value);
  const [year, setYear] = useState(initial.year);
  const [month, setMonth] = useState(initial.month);
  const [day, setDay] = useState(initial.day);

  function openSheet() {
    const next = partsFromMs(value);
    setYear(next.year);
    setMonth(next.month);
    setDay(next.day);
    setOpen(true);
  }

  function apply() {
    const ms = clampDate(year, month, day);
    const now = Date.now();
    onChange(Math.min(ms, now));
    setOpen(false);
  }

  const dayCount = daysInMonth(year, month);
  const dayItems = useMemo(
    () => Array.from({ length: dayCount }, (_, i) => String(i + 1)),
    [dayCount],
  );
  const safeDay = Math.min(day, dayCount);

  useEffect(() => {
    if (day > dayCount) setDay(dayCount);
  }, [day, dayCount]);

  return (
    <>
      <View style={styles.field}>
        <Text style={styles.label}>Date of birth</Text>
        <Pressable onPress={openSheet} style={styles.trigger}>
          <Text style={[styles.triggerText, !value && styles.placeholder]}>
            {value ? formatDob(value) : "Pick a date"}
          </Text>
          <Text style={styles.chevron}>⌄</Text>
        </Pressable>
      </View>

      <BottomSheet
        visible={open}
        onClose={apply}
        footer={
          <Pressable onPress={apply} style={styles.confirm}>
            <Text style={styles.confirmText}>Use this date</Text>
          </Pressable>
        }
      >
        <View style={styles.wheels}>
          <WheelPicker
            items={dayItems}
            value={safeDay - 1}
            onChange={(i) => setDay(i + 1)}
            width={72}
            accessibilityLabel="Day"
          />
          <WheelPicker
            items={MONTHS}
            value={month}
            onChange={setMonth}
            width={140}
            accessibilityLabel="Month"
          />
          <WheelPicker
            items={years.map(String)}
            value={Math.max(0, years.indexOf(year))}
            onChange={(i) => setYear(years[i] ?? maxYear)}
            width={88}
            accessibilityLabel="Year"
          />
        </View>
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
  wheels: {
    flexDirection: "row",
    justifyContent: "center",
    alignItems: "center",
    gap: 8,
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
