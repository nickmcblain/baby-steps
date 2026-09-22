import { useMemo, useState } from "react";
import { Pressable, Text, View, type LayoutChangeEvent } from "react-native";
import Svg, { Rect, Text as SvgText } from "react-native-svg";
import {
  addDays,
  formatHourLabel,
  splitAcrossLocalDays,
  startOfLocalDay,
} from "@/lib/weekGrid";
import { fonts, radius } from "@/lib/theme";
import { useTheme, useThemedStyles } from "@/providers/ThemeProvider";

const PAD = { top: 8, right: 8, bottom: 28, left: 38 };
const CHART_H = 320;
const HOUR_TICKS = [0, 3, 6, 9, 12, 15, 18, 21, 24];
const DAY_SHORT = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const LABEL_W = 58;
const TICKS = [
  { label: "12am", at: 0 },
  { label: "6am", at: 0.25 },
  { label: "12pm", at: 0.5 },
  { label: "6pm", at: 0.75 },
] as const;

export type SleepPatternItem = {
  startMs: number;
  endMs: number;
  durationMinutes: number;
};

export function SleepPatternChart({
  sleeps,
  days,
  rangeEndMs,
  barColor,
  emptyText = "No sleeps in this range yet.",
}: {
  sleeps: SleepPatternItem[];
  days: 7 | 14 | 30;
  rangeEndMs: number;
  barColor?: string;
  emptyText?: string;
}) {
  const [chartW, setChartW] = useState(0);
  const [view, setView] = useState<"bars" | "chart">("bars");
  const { colors } = useTheme();
  const resolvedBar = barColor ?? colors.purple;
  const styles = useThemedStyles(({ colors }) => ({
    plot: {
      backgroundColor: colors.card,
      borderRadius: radius.tile,
      overflow: "hidden" as const,
      minHeight: CHART_H,
    },
    emptyBox: {
      backgroundColor: colors.card,
      borderRadius: radius.tile,
      padding: 28,
      alignItems: "center" as const,
    },
    emptyText: {
      fontFamily: fonts.body,
      fontSize: 15,
      color: colors.muted,
      textAlign: "center" as const,
    },
    switchRow: { flexDirection: "row" as const, gap: 8 },
    pill: {
      paddingHorizontal: 14,
      paddingVertical: 8,
      borderRadius: 999,
      backgroundColor: colors.card,
    },
    pillOn: { backgroundColor: colors.ink },
    pillText: { fontFamily: fonts.bold, fontSize: 14, color: colors.muted },
    pillTextOn: { color: colors.card },
    stack: {
      backgroundColor: colors.card,
      borderRadius: radius.tile,
      paddingHorizontal: 14,
      paddingVertical: 12,
      gap: 8,
    },
    row: { flexDirection: "row" as const, alignItems: "center" as const, gap: 8 },
    dayLabel: {
      width: LABEL_W,
      fontFamily: fonts.bold,
      fontSize: 12,
      color: colors.ink,
    },
    track: {
      flex: 1,
      height: 22,
      borderRadius: 6,
      overflow: "hidden" as const,
      backgroundColor: colors.line,
    },
    tickRow: { flexDirection: "row" as const, marginLeft: LABEL_W + 8 },
    tickLane: { flex: 1, height: 16 },
    tick: {
      position: "absolute" as const,
      fontFamily: fonts.medium,
      fontSize: 10,
      color: colors.muted,
    },
  }));

  const dayColumns = useMemo(() => {
    const endDay = startOfLocalDay(rangeEndMs - 1);
    const cols: { dayStartMs: number; label: string }[] = [];
    for (let i = days - 1; i >= 0; i--) {
      const dayStartMs = addDays(endDay, -i);
      const d = new Date(dayStartMs);
      cols.push({
        dayStartMs,
        label: `${DAY_SHORT[d.getDay()]} ${d.getDate()}`,
      });
    }
    return cols;
  }, [days, rangeEndMs]);

  function onLayout(e: LayoutChangeEvent) {
    const w = Math.floor(e.nativeEvent.layout.width);
    if (w > 0 && w !== chartW) setChartW(w);
  }

  const plotW = Math.max(0, chartW - PAD.left - PAD.right);
  const plotH = CHART_H - PAD.top - PAD.bottom;
  const colW = dayColumns.length > 0 ? plotW / dayColumns.length : 0;

  function yForMin(min: number): number {
    return PAD.top + (min / 1440) * plotH;
  }

  const sleepRects = useMemo(() => {
    const out: {
      key: string;
      x: number;
      y: number;
      w: number;
      h: number;
    }[] = [];
    if (colW <= 0) return out;
    for (let si = 0; si < sleeps.length; si++) {
      const sleep = sleeps[si];
      for (const slice of splitAcrossLocalDays(sleep.startMs, sleep.endMs)) {
        const dayIndex = dayColumns.findIndex(
          (d) => d.dayStartMs === slice.dayStartMs,
        );
        if (dayIndex < 0) continue;
        const y = yForMin(slice.startMin);
        const h = Math.max(3, yForMin(slice.endMin) - y);
        const inset = Math.max(1.5, colW * 0.1);
        out.push({
          key: `${si}-${slice.dayStartMs}`,
          x: PAD.left + dayIndex * colW + inset,
          y,
          w: Math.max(3, colW - inset * 2),
          h,
        });
      }
    }
    return out;
  }, [sleeps, dayColumns, colW, plotH]);

  const slicesByDay = useMemo(() => {
    const map = new Map<number, { key: string; startMin: number; endMin: number }[]>();
    for (const day of dayColumns) map.set(day.dayStartMs, []);
    sleeps.forEach((sleep, index) => {
      for (const slice of splitAcrossLocalDays(sleep.startMs, sleep.endMs)) {
        const list = map.get(slice.dayStartMs);
        if (!list) continue;
        list.push({
          key: `${index}-${slice.dayStartMs}-${slice.startMin}`,
          startMin: slice.startMin,
          endMin: slice.endMin,
        });
      }
    });
    return map;
  }, [sleeps, dayColumns]);

  if (sleeps.length === 0) {
    return (
      <View style={styles.emptyBox}>
        <Text style={styles.emptyText}>{emptyText}</Text>
      </View>
    );
  }

  const showEveryNthLabel = days > 7 ? 2 : 1;

  const switcher = (
    <View style={styles.switchRow}>
      <Pressable
        onPress={() => setView("bars")}
        style={[styles.pill, view === "bars" && styles.pillOn]}
        accessibilityRole="button"
      >
        <Text style={[styles.pillText, view === "bars" && styles.pillTextOn]}>Bars</Text>
      </Pressable>
      <Pressable
        onPress={() => setView("chart")}
        style={[styles.pill, view === "chart" && styles.pillOn]}
        accessibilityRole="button"
      >
        <Text style={[styles.pillText, view === "chart" && styles.pillTextOn]}>Chart</Text>
      </Pressable>
    </View>
  );

  if (view === "bars") {
    return (
      <View style={{ gap: 10 }}>
        {switcher}
        <View style={styles.stack}>
          {dayColumns.map((day) => (
            <View key={day.dayStartMs} style={styles.row}>
              <Text style={styles.dayLabel}>{day.label}</Text>
              <View style={styles.track}>
                {(slicesByDay.get(day.dayStartMs) ?? []).map((slice) => {
                  const start = slice.startMin / 1440;
                  const width = Math.min(Math.max(slice.endMin - slice.startMin, 12) / 1440, 1 - start);
                  return (
                    <View
                      key={slice.key}
                      style={{
                        position: "absolute",
                        top: 0,
                        bottom: 0,
                        left: `${start * 100}%`,
                        width: `${width * 100}%`,
                        backgroundColor: resolvedBar,
                        borderRadius: 4,
                      }}
                    />
                  );
                })}
              </View>
            </View>
          ))}
          <View style={styles.tickRow}>
            <View style={styles.tickLane}>
              {TICKS.map((tick) => (
                <Text key={tick.label} style={[styles.tick, { left: `${tick.at * 100}%` }]}>
                  {tick.label}
                </Text>
              ))}
            </View>
          </View>
        </View>
      </View>
    );
  }

  return (
    <View style={{ gap: 10 }}>
      {switcher}
    <View onLayout={onLayout} style={styles.plot}>
      {chartW > 0 ? (
        <Svg width={chartW} height={CHART_H}>
          {HOUR_TICKS.map((h) => {
            const y = yForMin(h * 60);
            return (
              <SvgText
                key={`yl-${h}`}
                x={PAD.left - 6}
                y={y + 3}
                fontSize={10}
                fill={colors.muted}
                textAnchor="end"
                fontFamily={fonts.medium}
              >
                {formatHourLabel(h)}
              </SvgText>
            );
          })}
          {HOUR_TICKS.map((h) => {
            const y = yForMin(h * 60);
            return (
              <Rect
                key={`gl-${h}`}
                x={PAD.left}
                y={y}
                width={plotW}
                height={1}
                fill={colors.line}
              />
            );
          })}
          {dayColumns.map((d, i) =>
            i % showEveryNthLabel === 0 ? (
              <SvgText
                key={`dx-${d.dayStartMs}`}
                x={PAD.left + i * colW + colW / 2}
                y={CHART_H - 8}
                fontSize={days > 7 ? 9 : 11}
                fill={colors.ink}
                textAnchor="middle"
                fontFamily={fonts.bold}
              >
                {d.label}
              </SvgText>
            ) : null,
          )}
          {sleepRects.map((r) => (
            <Rect
              key={r.key}
              x={r.x}
              y={r.y}
              width={r.w}
              height={r.h}
              rx={Math.min(5, r.w / 2)}
              fill={resolvedBar}
              opacity={0.85}
            />
          ))}
        </Svg>
      ) : null}
    </View>
    </View>
  );
}

