import { useMemo, useState } from "react";
import {
  Pressable,
  StyleSheet,
  Text,
  View,
  type LayoutChangeEvent,
} from "react-native";
import Svg, { Circle, Rect, Text as SvgText } from "react-native-svg";
import {
  formatHourLabel,
  formatWeekRange,
  splitAcrossLocalDays,
  startOfWeekMonday,
  weekDayLabels,
} from "@/lib/weekGrid";
import { colors, fonts } from "@/lib/theme";

const PAD = { top: 22, right: 10, bottom: 12, left: 28 };
const HOUR_TICKS = [0, 3, 6, 9, 12, 15, 18, 21, 24];
const DOT_R = 6.5;

export type WeekSleep = {
  kind: "sleep";
  eventId: string;
  startMs: number;
  endMs: number;
};

export type WeekMarkerKind = "feed" | "nappy" | "weight" | "height" | "custom";

export type WeekMarker = {
  kind: WeekMarkerKind;
  eventId: string;
  atMs: number;
};

const MARKER_COLOR: Record<WeekMarkerKind, string> = {
  feed: colors.teal,
  nappy: colors.peach,
  weight: colors.amber,
  height: colors.sky,
  custom: colors.rose,
};

const LEGEND: { label: string; color: string; shape: "bar" | "dot" }[] = [
  { label: "Sleep", color: colors.purple, shape: "bar" },
  { label: "Feed", color: colors.teal, shape: "dot" },
  { label: "Nappy", color: colors.peach, shape: "dot" },
  { label: "Weight", color: colors.amber, shape: "dot" },
  { label: "Height", color: colors.sky, shape: "dot" },
  { label: "Event", color: colors.rose, shape: "dot" },
];

/** Small x-offsets so same-minute markers of different kinds stay readable. */
const KIND_OFFSET: Record<WeekMarkerKind, number> = {
  feed: -3,
  nappy: 3,
  weight: -6,
  height: 6,
  custom: 0,
};

export function WeekRhythmChart({
  weekStartMs,
  sleeps,
  markers,
  onPrevWeek,
  onNextWeek,
}: {
  weekStartMs: number;
  sleeps: WeekSleep[];
  markers: WeekMarker[];
  onPrevWeek: () => void;
  onNextWeek: () => void;
}) {
  const [plotSize, setPlotSize] = useState({ w: 0, h: 0 });
  const days = useMemo(() => weekDayLabels(weekStartMs), [weekStartMs]);
  const thisWeek = startOfWeekMonday(Date.now()) === weekStartMs;

  function onPlotLayout(e: LayoutChangeEvent) {
    const { width, height } = e.nativeEvent.layout;
    const w = Math.floor(width);
    const h = Math.floor(height);
    if (w > 0 && h > 0 && (w !== plotSize.w || h !== plotSize.h)) {
      setPlotSize({ w, h });
    }
  }

  const plotW = Math.max(0, plotSize.w - PAD.left - PAD.right);
  const plotH = Math.max(0, plotSize.h - PAD.top - PAD.bottom);
  const colW = days.length > 0 ? plotW / days.length : 0;

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
    if (colW <= 0 || plotH <= 0) return out;
    for (const sleep of sleeps) {
      for (const slice of splitAcrossLocalDays(sleep.startMs, sleep.endMs)) {
        const dayIndex = days.findIndex((d) => d.dayStartMs === slice.dayStartMs);
        if (dayIndex < 0) continue;
        const y = yForMin(slice.startMin);
        const h = Math.max(4, yForMin(slice.endMin) - y);
        const inset = Math.max(2, colW * 0.12);
        out.push({
          key: `${sleep.eventId}-${slice.dayStartMs}`,
          x: PAD.left + dayIndex * colW + inset,
          y,
          w: Math.max(4, colW - inset * 2),
          h,
        });
      }
    }
    return out;
  }, [sleeps, days, colW, plotH]);

  const markerDots = useMemo(() => {
    const out: { key: string; cx: number; cy: number; color: string }[] = [];
    if (colW <= 0 || plotH <= 0) return out;
    for (const marker of markers) {
      const at = new Date(marker.atMs);
      const localDay = new Date(
        at.getFullYear(),
        at.getMonth(),
        at.getDate(),
      ).getTime();
      const dayIndex = days.findIndex((d) => d.dayStartMs === localDay);
      if (dayIndex < 0) continue;
      const min = at.getHours() * 60 + at.getMinutes() + at.getSeconds() / 60;
      out.push({
        key: marker.eventId,
        cx: PAD.left + dayIndex * colW + colW / 2 + KIND_OFFSET[marker.kind],
        cy: yForMin(min),
        color: MARKER_COLOR[marker.kind],
      });
    }
    return out;
  }, [markers, days, colW, plotH]);

  return (
    <View style={styles.wrap}>
      <View style={styles.nav}>
        <Pressable onPress={onPrevWeek} hitSlop={12} accessibilityLabel="Previous week">
          <Text style={styles.chev}>‹</Text>
        </Pressable>
        <View style={styles.navCenter}>
          <Text style={styles.navTitle}>{thisWeek ? "This week" : "Week"}</Text>
          <Text style={styles.navRange}>{formatWeekRange(weekStartMs)}</Text>
        </View>
        <Pressable onPress={onNextWeek} hitSlop={12} accessibilityLabel="Next week">
          <Text style={styles.chev}>›</Text>
        </Pressable>
      </View>

      <View style={styles.legend}>
        {LEGEND.map((item) => (
          <View key={item.label} style={styles.legendItem}>
            {item.shape === "bar" ? (
              <View style={[styles.legendSwatch, { backgroundColor: item.color }]} />
            ) : (
              <View style={[styles.legendDot, { backgroundColor: item.color }]} />
            )}
            <Text style={styles.legendText}>{item.label}</Text>
          </View>
        ))}
      </View>

      <View onLayout={onPlotLayout} style={styles.plot}>
        {plotSize.w > 0 && plotSize.h > 0 ? (
          <Svg width={plotSize.w} height={plotSize.h}>
            {days.map((d, i) => (
              <SvgText
                key={`dx-${d.dayStartMs}`}
                x={PAD.left + i * colW + colW / 2}
                y={14}
                fontSize={11}
                fill={colors.ink}
                textAnchor="middle"
                fontFamily={fonts.bold}
              >
                {`${d.label} ${d.dateNum}`}
              </SvgText>
            ))}
            {HOUR_TICKS.map((h) => {
              const y = yForMin(h * 60);
              return (
                <SvgText
                  key={`yl-${h}`}
                  x={PAD.left - 4}
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
            {sleepRects.map((r) => (
              <Rect
                key={r.key}
                x={r.x}
                y={r.y}
                width={r.w}
                height={r.h}
                rx={Math.min(6, r.w / 2)}
                fill={colors.purple}
                opacity={0.85}
              />
            ))}
            {markerDots.map((d) => (
              <Circle
                key={d.key}
                cx={d.cx}
                cy={d.cy}
                r={DOT_R}
                fill={d.color}
              />
            ))}
          </Svg>
        ) : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { flex: 1, gap: 12, minHeight: 0 },
  nav: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  navCenter: { alignItems: "center", gap: 2 },
  navTitle: {
    fontFamily: fonts.bold,
    fontSize: 17,
    color: colors.ink,
  },
  navRange: {
    fontFamily: fonts.body,
    fontSize: 13,
    color: colors.muted,
  },
  chev: {
    fontFamily: fonts.bold,
    fontSize: 28,
    color: colors.ink,
    paddingHorizontal: 8,
  },
  legend: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 10,
    justifyContent: "center",
    rowGap: 6,
  },
  legendItem: { flexDirection: "row", alignItems: "center", gap: 5 },
  legendSwatch: {
    width: 12,
    height: 12,
    borderRadius: 4,
  },
  legendDot: {
    width: 11,
    height: 11,
    borderRadius: 6,
  },
  legendText: {
    fontFamily: fonts.medium,
    fontSize: 12,
    color: colors.muted,
  },
  plot: {
    flex: 1,
    minHeight: 0,
    backgroundColor: colors.card,
    // Cancel Screen pad so white fills edge-to-edge remaining space.
    marginHorizontal: -20,
    marginBottom: -40,
  },
});
