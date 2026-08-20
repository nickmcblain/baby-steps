import { colors, fonts } from "@/lib/theme";
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
  const scrollRef = useRef<ScrollView>(null);
  const pad = Math.floor(VISIBLE_ROWS / 2);
  const height = WHEEL_ITEM_HEIGHT * VISIBLE_ROWS;
  const lastIndex = useRef(value);

  const data = useMemo(
    () => [...Array(pad).fill(""), ...items, ...Array(pad).fill("")],
    [items, pad],
  );

  useEffect(() => {
    const y = value * WHEEL_ITEM_HEIGHT;
    requestAnimationFrame(() => {
      scrollRef.current?.scrollTo({ y, animated: false });
    });
    lastIndex.current = value;
  }, [value, items]);

  function commit(offsetY: number) {
    const index = Math.max(
      0,
      Math.min(items.length - 1, Math.round(offsetY / WHEEL_ITEM_HEIGHT)),
    );
    if (index !== lastIndex.current) {
      lastIndex.current = index;
      if (Platform.OS !== "web") {
        void Haptics.selectionAsync().catch(() => undefined);
      }
      onChange(index);
    }
    scrollRef.current?.scrollTo({
      y: index * WHEEL_ITEM_HEIGHT,
      animated: true,
    });
  }

  function onMomentumEnd(e: NativeSyntheticEvent<NativeScrollEvent>) {
    commit(e.nativeEvent.contentOffset.y);
  }

  function onScrollEndDrag(e: NativeSyntheticEvent<NativeScrollEvent>) {
    // iOS sometimes skips momentum for tiny drags.
    commit(e.nativeEvent.contentOffset.y);
  }

  return (
    <View style={[styles.wrap, { width, height }]} accessibilityLabel={accessibilityLabel}>
      <View pointerEvents="none" style={styles.highlight} />
      <ScrollView
        ref={scrollRef}
        showsVerticalScrollIndicator={false}
        snapToInterval={WHEEL_ITEM_HEIGHT}
        decelerationRate="fast"
        onMomentumScrollEnd={onMomentumEnd}
        onScrollEndDrag={onScrollEndDrag}
        nestedScrollEnabled
      >
        {data.map((label, i) => (
          <View key={`${label}-${i}`} style={styles.row}>
            <Text
              style={[
                styles.label,
                i - pad === value ? styles.labelActive : styles.labelMuted,
              ]}
            >
              {label}
            </Text>
          </View>
        ))}
      </ScrollView>
      <View pointerEvents="none" style={[styles.fade, styles.fadeTop]} />
      <View pointerEvents="none" style={[styles.fade, styles.fadeBottom]} />
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    overflow: "hidden",
    position: "relative",
  },
  highlight: {
    position: "absolute",
    left: 4,
    right: 4,
    top: WHEEL_ITEM_HEIGHT * 2,
    height: WHEEL_ITEM_HEIGHT,
    borderRadius: 14,
    backgroundColor: colors.tealSoft,
    zIndex: 0,
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
  labelActive: {
    color: colors.ink,
    fontFamily: fonts.bold,
  },
  labelMuted: {
    color: colors.muted,
  },
  fade: {
    position: "absolute",
    left: 0,
    right: 0,
    height: WHEEL_ITEM_HEIGHT * 1.4,
    zIndex: 2,
  },
  fadeTop: {
    top: 0,
    backgroundColor: "rgba(243,244,246,0.72)",
  },
  fadeBottom: {
    bottom: 0,
    backgroundColor: "rgba(243,244,246,0.72)",
  },
});
