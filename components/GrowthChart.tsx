import { useMemo, useState } from "react";
import { StyleSheet, Text, View, type LayoutChangeEvent } from "react-native";
import Svg, { Circle, Line, Path, Text as SvgText } from "react-native-svg";
import {
  ageMonths,
  bandLabel,
  centileFromZ,
  formatCentile,
  growthBand,
  maxChartMonths,
  type GrowthMetric,
  type Sex,
  UK_CENTILES,
  valueFromZ,
  zScore,
} from "@/lib/growth/lms";
import { colors, fonts, radius, shadow } from "@/lib/theme";

export type GrowthPoint = {
  at: number;
  value: number; // kg or cm
};

/** Plot insets inside the SVG — keep left tight for y labels */
const PAD = { top: 12, right: 18, bottom: 26, left: 28 };
const CHART_H = 220;

/** Draw 0.4, 9, 50, 91, 99.6 — keep chart readable on phone */
const DRAW_CENTILES = UK_CENTILES.filter((c) =>
  ["0.4th", "9th", "50th", "91st", "99.6th"].includes(c.label),
);

function pathForCentile(
  metric: GrowthMetric,
  sex: Sex,
  z: number,
  maxMonth: number,
  toX: (m: number) => number,
  toY: (v: number) => number,
): string {
  const steps = Math.max(24, Math.round(maxMonth * 4));
  const parts: string[] = [];
  for (let i = 0; i <= steps; i++) {
    const month = (i / steps) * maxMonth;
    const v = valueFromZ(metric, sex, month, z);
    if (v == null) continue;
    const cmd = parts.length === 0 ? "M" : "L";
    parts.push(`${cmd}${toX(month).toFixed(1)} ${toY(v).toFixed(1)}`);
  }
  return parts.join(" ");
}

export function GrowthChart({
  metric,
  sex,
  dateOfBirth,
  points,
}: {
  metric: GrowthMetric;
  sex: Sex | null | undefined;
  dateOfBirth: number;
  points: GrowthPoint[];
}) {
  const [chartW, setChartW] = useState(0);

  function onPlotLayout(e: LayoutChangeEvent) {
    const w = Math.floor(e.nativeEvent.layout.width);
    if (w > 0 && w !== chartW) setChartW(w);
  }

  const now = Date.now();
  const maxMonth = maxChartMonths(dateOfBirth, now);

  const latest = points.length
    ? [...points].sort((a, b) => b.at - a.at)[0]
    : null;
  const latestMonth = latest ? ageMonths(dateOfBirth, latest.at) : null;
  const latestZ =
    sex && latest && latestMonth != null
      ? zScore(metric, sex, latestMonth, latest.value)
      : null;
  const latestCentile =
    latestZ != null ? centileFromZ(latestZ) : null;
  const band = growthBand(latestZ);

  const { yMin, yMax, plotPoints } = useMemo(() => {
    const unitPoints = points.map((p) => ({
      month: ageMonths(dateOfBirth, p.at),
      value: p.value,
    }));
    let min = Infinity;
    let max = -Infinity;
    if (sex) {
      for (const c of DRAW_CENTILES) {
        for (let m = 0; m <= maxMonth; m += 1) {
          const v = valueFromZ(metric, sex, m, c.z);
          if (v == null) continue;
          min = Math.min(min, v);
          max = Math.max(max, v);
        }
      }
    }
    for (const p of unitPoints) {
      min = Math.min(min, p.value);
      max = Math.max(max, p.value);
    }
    if (!Number.isFinite(min) || !Number.isFinite(max)) {
      min = metric === "weight" ? 2 : 45;
      max = metric === "weight" ? 12 : 90;
    }
    const pad = (max - min) * 0.08 || 1;
    return {
      yMin: min - pad,
      yMax: max + pad,
      plotPoints: unitPoints.filter((p) => p.month <= maxMonth + 0.05),
    };
  }, [points, dateOfBirth, sex, metric, maxMonth]);

  const innerW = chartW - PAD.left - PAD.right;
  const innerH = CHART_H - PAD.top - PAD.bottom;
  const toX = (m: number) => PAD.left + (m / maxMonth) * innerW;
  const toY = (v: number) =>
    PAD.top + ((yMax - v) / (yMax - yMin || 1)) * innerH;

  const unit = metric === "weight" ? "kg" : "cm";
  const title =
    metric === "weight" ? "Weight for age" : "Length / height for age";

  return (
    <View style={styles.wrap}>
      <Text style={styles.title}>{title}</Text>
      <Text style={styles.sub}>
        UK Red Book centiles (WHO / UK-WHO standards)
      </Text>

      {!sex ? (
        <Text style={styles.hint}>
          Set boy or girl on Edit profile to plot against UK charts.
        </Text>
      ) : (
        <>
          {latestCentile != null && (
            <Text style={styles.status}>
              Latest ≈ {formatCentile(latestCentile)} centile · {bandLabel(band)}
            </Text>
          )}
          <View style={styles.plot} onLayout={onPlotLayout}>
            {chartW > 0 ? (
              <Svg width={chartW} height={CHART_H}>
                {[0, 0.25, 0.5, 0.75, 1].map((t) => {
                  const y = PAD.top + t * innerH;
                  const v = yMax - t * (yMax - yMin);
                  return (
                    <SvgText
                      key={`y-${t}`}
                      x={PAD.left - 4}
                      y={y + 3}
                      fontSize={10}
                      fill={colors.muted}
                      textAnchor="end"
                      fontFamily={fonts.body}
                    >
                      {metric === "weight" ? v.toFixed(1) : Math.round(v)}
                    </SvgText>
                  );
                })}
                {[0, 6, 12, 18, 24]
                  .filter((m) => m <= maxMonth)
                  .map((m) => (
                    <SvgText
                      key={`x-${m}`}
                      x={toX(m)}
                      y={CHART_H - 6}
                      fontSize={10}
                      fill={colors.muted}
                      textAnchor={m === 0 ? "start" : m === maxMonth ? "end" : "middle"}
                      fontFamily={fonts.body}
                    >
                      {m}m
                    </SvgText>
                  ))}
                {DRAW_CENTILES.map((c) => {
                  const d = pathForCentile(
                    metric,
                    sex,
                    c.z,
                    maxMonth,
                    toX,
                    toY,
                  );
                  const isMedian = c.label === "50th";
                  return (
                    <Path
                      key={c.label}
                      d={d}
                      stroke={isMedian ? colors.ink : colors.line}
                      strokeWidth={isMedian ? 2 : 1}
                      fill="none"
                      opacity={isMedian ? 1 : 0.9}
                    />
                  );
                })}
                {(() => {
                  const v = valueFromZ(metric, sex, maxMonth, 0);
                  if (v == null) return null;
                  return (
                    <SvgText
                      x={toX(maxMonth) - 2}
                      y={toY(v) - 4}
                      fontSize={9}
                      fill={colors.muted}
                      textAnchor="end"
                    >
                      50th
                    </SvgText>
                  );
                })()}
                {plotPoints.map((p, i) => (
                  <Circle
                    key={`${p.month}-${i}`}
                    cx={toX(Math.min(p.month, maxMonth))}
                    cy={toY(p.value)}
                    r={5}
                    fill={colors.teal}
                    stroke="#fff"
                    strokeWidth={2}
                  />
                ))}
                {plotPoints.length > 1 && (
                  <Path
                    d={plotPoints
                      .slice()
                      .sort((a, b) => a.month - b.month)
                      .map((p, i) => {
                        const x = toX(Math.min(p.month, maxMonth));
                        const y = toY(p.value);
                        return `${i === 0 ? "M" : "L"}${x} ${y}`;
                      })
                      .join(" ")}
                    stroke={colors.teal}
                    strokeWidth={2}
                    fill="none"
                    opacity={0.55}
                  />
                )}
                <Line
                  x1={PAD.left}
                  y1={PAD.top + innerH}
                  x2={PAD.left + innerW}
                  y2={PAD.top + innerH}
                  stroke={colors.line}
                />
                <Line
                  x1={PAD.left}
                  y1={PAD.top}
                  x2={PAD.left}
                  y2={PAD.top + innerH}
                  stroke={colors.line}
                />
              </Svg>
            ) : null}
          </View>
          <View style={styles.legend}>
            <Text style={styles.legendText}>Lines: 0.4 · 9 · 50 · 91 · 99.6</Text>
            <Text style={styles.legendText}>Dots: your logs ({unit})</Text>
          </View>
          {(band === "very_low" || band === "very_high") && (
            <Text style={styles.caution}>
              Outside usual UK chart range — check with your health visitor or GP.
              This is not medical advice.
            </Text>
          )}
        </>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    backgroundColor: colors.card,
    borderRadius: radius.card,
    padding: 16,
    gap: 6,
    overflow: "hidden",
    ...shadow,
  },
  plot: {
    width: "100%",
    alignSelf: "stretch",
  },
  title: {
    fontFamily: fonts.display,
    fontSize: 18,
    color: colors.ink,
  },
  sub: {
    fontFamily: fonts.body,
    fontSize: 12,
    color: colors.muted,
    marginBottom: 4,
  },
  status: {
    fontFamily: fonts.medium,
    fontSize: 14,
    color: colors.tealDark,
    marginBottom: 4,
  },
  hint: {
    fontFamily: fonts.body,
    fontSize: 14,
    color: colors.muted,
    paddingVertical: 12,
  },
  legend: { gap: 2, marginTop: 4 },
  legendText: {
    fontFamily: fonts.body,
    fontSize: 11,
    color: colors.muted,
  },
  caution: {
    fontFamily: fonts.medium,
    fontSize: 12,
    color: colors.danger,
    marginTop: 6,
  },
});
