import { Pressable, Text, View } from "react-native";
import { dayBarOffset, type DayRhythm, type RhythmKind } from "@/lib/dayRhythm";
import { fonts, radius } from "@/lib/theme";
import { useTheme, useThemedStyles } from "@/providers/ThemeProvider";

const TICKS = ["7am", "1pm", "7pm", "1am"] as const;

export function DayRhythmBar({
  rhythm,
  now,
  onPress,
  embedded = false,
}: {
  rhythm: DayRhythm;
  now: number;
  onPress: () => void;
  embedded?: boolean;
}) {
  const { scheme, colors } = useTheme();
  const nap = scheme === "dark" ? "#4A4580" : "#C4BEF8";
  const styles = useThemedStyles(({ colors, shadow }) => ({
    card: {
      backgroundColor: colors.card,
      borderRadius: radius.tile,
      paddingHorizontal: 16,
      paddingVertical: 14,
      gap: 10,
      ...shadow,
    },
    label: { fontFamily: fonts.medium, fontSize: 12, color: colors.purple },
    track: {
      height: 28,
      borderRadius: 8,
      overflow: "hidden" as const,
      flexDirection: "row" as const,
      backgroundColor: colors.line,
    },
    now: {
      position: "absolute" as const,
      top: 0,
      bottom: 0,
      width: 2,
      marginLeft: -1,
      backgroundColor: colors.ink,
    },
    ticks: { flexDirection: "row" as const, justifyContent: "space-between" as const },
    tick: { fontFamily: fonts.medium, fontSize: 11, color: colors.muted },
    embedded: { gap: 8 },
  }));

  const fill: Record<RhythmKind, string> = {
    night: colors.purple,
    nap,
    awake: colors.line,
  };
  const label = rhythm.source === "logs" ? "Usual day" : "Typical day";

  return (
    <View style={embedded ? styles.embedded : styles.card}>
      {embedded ? null : <Text style={styles.label}>{label}</Text>}
      <Pressable onPress={onPress} accessibilityRole="button" accessibilityLabel={rhythm.caption}>
        <View style={styles.track}>
          {rhythm.segments.map((segment) => (
            <View
              key={`${segment.kind}-${segment.start}`}
              style={{ flex: segment.end - segment.start, backgroundColor: fill[segment.kind] }}
            />
          ))}
          <View pointerEvents="none" style={[styles.now, { left: `${(dayBarOffset(now) / 1440) * 100}%` }]} />
        </View>
      </Pressable>
      <View style={styles.ticks}>
        {TICKS.map((tick) => (
          <Text key={tick} style={styles.tick}>
            {tick}
          </Text>
        ))}
      </View>
    </View>
  );
}
