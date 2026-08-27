import * as Haptics from "expo-haptics";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { startOfLocalDay, startOfWeekMonday, weekDayLabels } from "@/lib/weekGrid";
import { colors, fonts } from "@/lib/theme";

export function WeekStrip({
  selectedDayStart,
  onSelect,
}: {
  selectedDayStart: number;
  onSelect: (dayStart: number) => void;
}) {
  const weekStart = startOfWeekMonday(selectedDayStart);
  const days = weekDayLabels(weekStart);
  const todayStart = startOfLocalDay(Date.now());

  return (
    <View style={styles.row}>
      {days.map((day) => {
        const selected = day.dayStartMs === selectedDayStart;
        const isToday = day.dayStartMs === todayStart;
        return (
          <Pressable
            key={day.dayStartMs}
            onPress={() => {
              void Haptics.selectionAsync().catch(() => undefined);
              onSelect(day.dayStartMs);
            }}
            style={[styles.day, selected && styles.dayOn]}
          >
            <Text style={[styles.dow, selected && styles.dowOn, isToday && !selected && styles.today]}>
              {day.label}
            </Text>
            <Text style={[styles.num, selected && styles.numOn, isToday && !selected && styles.today]}>
              {day.dateNum}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: "row",
    justifyContent: "space-between",
    gap: 4,
  },
  day: {
    flex: 1,
    alignItems: "center",
    paddingVertical: 10,
    borderRadius: 16,
    gap: 4,
  },
  dayOn: {
    backgroundColor: colors.card,
    borderWidth: 1,
    borderColor: "#E4E6EA",
  },
  dow: {
    fontFamily: fonts.medium,
    fontSize: 12,
    color: colors.muted,
  },
  dowOn: {
    color: colors.ink,
  },
  num: {
    fontFamily: fonts.bold,
    fontSize: 16,
    color: colors.muted,
  },
  numOn: {
    color: colors.ink,
  },
  today: {
    color: colors.tealDark,
  },
});