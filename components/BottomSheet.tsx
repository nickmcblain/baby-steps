import { colors, fonts, radius, shadow } from "@/lib/theme";
import * as Haptics from "expo-haptics";
import { ReactNode, useEffect, useMemo, useRef, useState } from "react";
import {
  Modal,
  Pressable,
  StyleSheet,
  View,
  type StyleProp,
  type ViewStyle,
} from "react-native";
import { Gesture, GestureDetector, GestureHandlerRootView } from "react-native-gesture-handler";
import Animated, {
  Extrapolation,
  interpolate,
  useAnimatedStyle,
  useReducedMotion,
  useSharedValue,
  withSpring,
} from "react-native-reanimated";
import { scheduleOnRN } from "react-native-worklets";
import { useSafeAreaInsets } from "react-native-safe-area-context";

const FALLBACK_H = 420;

function project(velocity: number, decelerationRate = 0.998) {
  "worklet";
  return ((velocity / 1000) * decelerationRate) / (1 - decelerationRate);
}

function rubberband(overshoot: number, dimension: number, constant = 0.55) {
  "worklet";
  return (overshoot * dimension * constant) / (dimension + constant * Math.abs(overshoot));
}

export function BottomSheet({
  visible,
  onClose,
  children,
  footer,
  contentStyle,
}: {
  visible: boolean;
  onClose: () => void;
  children: ReactNode;
  footer?: ReactNode;
  contentStyle?: StyleProp<ViewStyle>;
}) {
  const insets = useSafeAreaInsets();
  const reduced = useReducedMotion();
  const [mounted, setMounted] = useState(visible);
  const translateY = useSharedValue(FALLBACK_H);
  const dragStart = useSharedValue(0);
  const sheetH = useSharedValue(FALLBACK_H);
  const onCloseRef = useRef(onClose);
  onCloseRef.current = onClose;

  function closeFromJS() {
    onCloseRef.current();
  }

  function unmount() {
    setMounted(false);
  }

  const pan = useMemo(
    () =>
      Gesture.Pan()
        .activeOffsetY([-10, 10])
        .onStart(() => {
          dragStart.set(translateY.get());
        })
        .onUpdate((e) => {
          const next = dragStart.get() + e.translationY;
          const height = sheetH.get();
          translateY.set(next >= 0 ? next : rubberband(next, height));
        })
        .onEnd((e) => {
          const height = sheetH.get();
          const projected = translateY.get() + project(e.velocityY);
          if (projected > height * 0.4) {
            translateY.set(
              withSpring(
                height,
                {
                  duration: 300,
                  dampingRatio: 1,
                  velocity: e.velocityY,
                  overshootClamping: true,
                },
                (finished) => {
                  if (finished) scheduleOnRN(closeFromJS);
                },
              ),
            );
          } else {
            translateY.set(
              withSpring(0, {
                duration: 300,
                dampingRatio: 0.8,
                velocity: e.velocityY,
              }),
            );
            scheduleOnRN(Haptics.impactAsync, Haptics.ImpactFeedbackStyle.Light);
          }
        }),
    [],
  );

  useEffect(() => {
    if (visible) {
      setMounted(true);
      const height = sheetH.get() || FALLBACK_H;
      if (reduced) {
        translateY.set(0);
        return;
      }
      translateY.set(height);
      translateY.set(withSpring(0, { duration: 300, dampingRatio: 0.8 }));
      return;
    }

    const height = sheetH.get() || FALLBACK_H;
    if (reduced || translateY.get() >= height * 0.85) {
      setMounted(false);
      translateY.set(height);
      return;
    }
    translateY.set(
      withSpring(
        height,
        { duration: 300, dampingRatio: 1, overshootClamping: true },
        (finished) => {
          if (finished) scheduleOnRN(unmount);
        },
      ),
    );
  }, [visible, reduced, translateY, sheetH]);

  const backdropStyle = useAnimatedStyle(() => ({
    opacity: interpolate(
      translateY.get(),
      [0, sheetH.get() || FALLBACK_H],
      [1, 0],
      Extrapolation.CLAMP,
    ),
  }));

  const sheetStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: translateY.get() }],
  }));

  return (
    <Modal
      visible={mounted}
      transparent
      animationType="none"
      onRequestClose={onClose}
      statusBarTranslucent
    >
      <GestureHandlerRootView style={styles.root}>
        <View style={styles.root} pointerEvents="box-none">
          <Animated.View style={[styles.backdrop, backdropStyle]}>
            <Pressable
              style={StyleSheet.absoluteFill}
              onPress={onClose}
              accessibilityLabel="Dismiss"
            />
          </Animated.View>
          <Animated.View
            style={[
              styles.sheet,
              { paddingBottom: Math.max(insets.bottom, 16) },
              sheetStyle,
            ]}
            onLayout={(e) => {
              const height = e.nativeEvent.layout.height;
              if (height > 0) sheetH.set(height);
            }}
          >
            <GestureDetector gesture={pan}>
              <View
                style={styles.handleHit}
                accessibilityRole="adjustable"
                accessibilityLabel="Drag down to close"
              >
                <View style={styles.handle} />
              </View>
            </GestureDetector>
            <View style={styles.content}>
              <View style={[styles.body, contentStyle]}>
                {children}
              </View>
              {footer}
            </View>
          </Animated.View>
        </View>
      </GestureHandlerRootView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, justifyContent: "flex-end" },
  backdrop: {
    ...StyleSheet.absoluteFill,
    backgroundColor: "rgba(18, 20, 26, 0.35)",
  },
  sheet: {
    backgroundColor: colors.bg,
    borderTopLeftRadius: radius.card,
    borderTopRightRadius: radius.card,
    paddingTop: 4,
    ...shadow,
  },
  handleHit: {
    width: "100%",
    alignItems: "center",
    justifyContent: "center",
    minHeight: 28,
    paddingVertical: 10,
  },
  handle: {
    width: 42,
    height: 5,
    borderRadius: 999,
    backgroundColor: colors.muted,
  },
  // fonts kept imported — stale Fast Refresh still reads styles.title.fontFamily
  _fonts: { fontFamily: fonts.bold },
  content: {
    paddingHorizontal: 20,
    gap: 16,
  },
  body: { minHeight: 0 },
});
