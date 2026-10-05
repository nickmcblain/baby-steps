import { fonts } from "@/lib/theme";
import {
  shouldCommitOnEndDrag,
  wheelIndexFromOffset,
} from "@/lib/wheelPicker";
import { useTheme, useThemedStyles } from "@/providers/ThemeProvider";
import * as Haptics from "expo-haptics";
import { useEffect, useMemo, useRef } from "react";
import {
  NativeScrollEvent,
  NativeSyntheticEvent,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";

export const WHEEL_ITEM_HEIGHT = 44;
const VISIBLE_ROWS = 5;

export function WheelPicker({
  items,
  value,
  onChange,
  width = 88,
  accessibilityLabel,
}: {
  items: readonly string[];
  value: number;
  onChange: (index: number) => void;
  width?: number;
  accessibilityLabel?: string;
}) {
  const { scheme } = useTheme();
  const fadeColor =
    scheme === "dark" ? "rgba(18,20,26,0.72)" : "rgba(243,244,246,0.72)";
  const styles = useThemedStyles(({ colors }) => ({
    highlight: {
      position: "absolute" as const,
      left: 4,
      right: 4,
      top: WHEEL_ITEM_HEIGHT * 2,
      height: WHEEL_ITEM_HEIGHT,
      borderRadius: 14,
      backgroundColor: colors.tealSoft,
      zIndex: 0,
    },
    labelActive: {
      color: colors.ink,
      fontFamily: fonts.bold,
    },
    labelMuted: {
      color: colors.muted,
    },
    fadeTop: {
      top: 0,
      backgroundColor: fadeColor,
    },
    fadeBottom: {
      bottom: 0,
      backgroundColor: fadeColor,
    },
  }));
  const scrollRef = useRef<ScrollView>(null);
  const pad = Math.floor(VISIBLE_ROWS / 2);
  const height = WHEEL_ITEM_HEIGHT * VISIBLE_ROWS;
  const lastIndex = useRef(value);
  const interacting = useRef(false);

  const data = useMemo(
    () => [...Array(pad).fill(""), ...items, ...Array(pad).fill("")],
    [items, pad],
  );

  useEffect(() => {
    lastIndex.current = value;
    if (interacting.current) return;
    const y = value * WHEEL_ITEM_HEIGHT;
    requestAnimationFrame(() => {
      if (interacting.current) return;
      scrollRef.current?.scrollTo({ y, animated: false });
    });
  }, [value, items]);

  function commit(offsetY: number) {
    const index = wheelIndexFromOffset(
      offsetY,
      items.length,
      WHEEL_ITEM_HEIGHT,
    );
    const y = index * WHEEL_ITEM_HEIGHT;
    if (index !== lastIndex.current) {
      lastIndex.current = index;
      if (Platform.OS !== "web") {
        void Haptics.selectionAsync().catch(() => undefined);
      }
      onChange(index);
    }
    if (Math.abs(offsetY - y) < 1) return;
    scrollRef.current?.scrollTo({ y, animated: true });
  }

  function onMomentumEnd(e: NativeSyntheticEvent<NativeScrollEvent>) {
    interacting.current = false;
    commit(e.nativeEvent.contentOffset.y);
  }

  function onScrollEndDrag(e: NativeSyntheticEvent<NativeScrollEvent>) {
    if (!shouldCommitOnEndDrag(e.nativeEvent.velocity?.y)) return;
    interacting.current = false;
    commit(e.nativeEvent.contentOffset.y);
  }

  return (
    <View style={[layout.wrap, { width, height }]} accessibilityLabel={accessibilityLabel}>
      <View pointerEvents="none" style={styles.highlight} />
      <ScrollView
        ref={scrollRef}
        showsVerticalScrollIndicator={false}
        snapToInterval={WHEEL_ITEM_HEIGHT}
        decelerationRate="fast"
        onScrollBeginDrag={() => {
          interacting.current = true;
        }}
        onMomentumScrollEnd={onMomentumEnd}
        onScrollEndDrag={onScrollEndDrag}
        nestedScrollEnabled
      >
        {data.map((label, i) => (
          <View key={`${label}-${i}`} style={layout.row}>
            <Text
              style={[
                layout.label,
                i - pad === value ? styles.labelActive : styles.labelMuted,
              ]}
            >
              {label}
            </Text>
          </View>
        ))}
      </ScrollView>
      <View pointerEvents="none" style={[layout.fade, styles.fadeTop]} />
      <View pointerEvents="none" style={[layout.fade, styles.fadeBottom]} />
    </View>
  );
}

const layout = StyleSheet.create({
  wrap: {
    overflow: "hidden",
    position: "relative",
  },
  row: {
    height: WHEEL_ITEM_HEIGHT,
    alignItems: "center",
    justifyContent: "center",
  },
  label: {
    fontFamily: fonts.medium,
    fontSize: 20,
  },
  fade: {
    position: "absolute",
    left: 0,
    right: 0,
    height: WHEEL_ITEM_HEIGHT * 1.4,
    zIndex: 2,
  },
});
