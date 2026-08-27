import { BottomSheet } from "@/components/BottomSheet";
import { WheelPicker } from "@/components/WheelPicker";
import {
  HOUR_SLOTS,
  MINUTE_SLOTS,
  formatLoggedAt,
  loggedAtFromParts,
  nowSnapped,
  partsFromLoggedAt,
  snapToMinute,
  type LoggedAtParts,
} from "@/lib/loggedAt";
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
  return new Date(year, monthIndex + 1, 0).getDate();
}

export function LoggedAtField({
  value,
  onChange,
  label = "When",
  allowFuture = false,
}: {
  value: number;
  onChange: (ms: number) => void;
  label?: string;
  /** Allow dates ahead of now (appointments). */
  allowFuture?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const today = new Date();
  const maxYear = today.getFullYear() + (allowFuture ? 2 : 0);
  const minYear = today.getFullYear() - 3;
  const years = useMemo(() => {
    const list: number[] = [];
    for (let y = maxYear; y >= minYear; y -= 1) list.push(y);
    return list;
  }, [maxYear, minYear]);

  const [parts, setParts] = useState<LoggedAtParts>(() =>
    partsFromLoggedAt(value || nowSnapped()),
  );

  function openSheet() {
    setParts(partsFromLoggedAt(value || nowSnapped()));
    setOpen(true);
  }

  function apply() {
    const maxDay = daysInMonth(parts.year, parts.month);
    const safe: LoggedAtParts = {
      ...parts,
      day: Math.min(parts.day, maxDay),
    };
    const snapped = snapToMinute(loggedAtFromParts(safe));
    const ms = allowFuture ? snapped : Math.min(snapped, nowSnapped());
    onChange(ms);
    setOpen(false);
  }

  const dayCount = daysInMonth(parts.year, parts.month);
  const dayItems = useMemo(
    () => Array.from({ length: dayCount }, (_, i) => String(i + 1)),
    [dayCount],
  );
  const safeDay = Math.min(parts.day, dayCount);

  useEffect(() => {
    if (parts.day > dayCount) {
      setParts((p) => ({ ...p, day: dayCount }));
    }
  }, [parts.day, dayCount]);

  return (
    <>
      <View style={styles.field}>
        <Text style={styles.label}>{label}</Text>
        <Pressable onPress={openSheet} style={styles.trigger}>
          <Text style={styles.triggerText}>{formatLoggedAt(value)}</Text>
          <Text style={styles.chevron}>⌄</Text>
        </Pressable>
      </View>

      <BottomSheet
        visible={open}
        onClose={apply}
        footer={
          <Pressable onPress={apply} style={styles.confirm}>
            <Text style={styles.confirmText}>Use this time</Text>
          </Pressable>
        }
      >
        <View style={styles.wheels}>
          <WheelPicker
            items={dayItems}
            value={safeDay - 1}
            onChange={(i) => setParts((p) => ({ ...p, day: i + 1 }))}
            width={64}
            accessibilityLabel="Day"
          />
          <WheelPicker
            items={MONTHS}
            value={parts.month}
            onChange={(month) => setParts((p) => ({ ...p, month }))}
            width={128}
            accessibilityLabel="Month"
          />
          <WheelPicker
            items={years.map(String)}
            value={Math.max(0, years.indexOf(parts.year))}
            onChange={(i) =>
              setParts((p) => ({ ...p, year: years[i] ?? maxYear }))
            }
            width={80}
            accessibilityLabel="Year"
          />
        </View>
        <View style={styles.timeRow}>
          <WheelPicker
            items={HOUR_SLOTS}
            value={parts.hour}
            onChange={(hour) => setParts((p) => ({ ...p, hour }))}
            width={72}
            accessibilityLabel="Hour"
          />
          <Text style={styles.timeSep}>:</Text>
          <WheelPicker
            items={MINUTE_SLOTS}
            value={parts.minute}
            onChange={(minute) => setParts((p) => ({ ...p, minute }))}
            width={72}
            accessibilityLabel="Minute"
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
  chevron: {
    fontFamily: fonts.bold,
    fontSize: 16,
    color: colors.tealDark,
  },
  wheels: {
    flexDirection: "row",
    justifyContent: "center",
    alignItems: "center",
    gap: 6,
  },
  timeRow: {
    marginTop: 8,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
  },
  timeSep: {
    fontFamily: fonts.bold,
    fontSize: 22,
    color: colors.ink,
    marginBottom: 2,
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
