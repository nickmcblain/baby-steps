import { useUser } from "@clerk/expo";
import { useEffect, useState } from "react";
import { Image, Pressable, StyleSheet, View } from "react-native";
import Animated, {
  Extrapolation,
  interpolate,
  useAnimatedStyle,
  useSharedValue,
} from "react-native-reanimated";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { expandDock, useDockCollapsed } from "@/components/DockScroll";
import { HomeTabIcon, KidsTabIcon, TimelineTabIcon } from "@/components/TabIcons";
import { colors, fonts, shadow } from "@/lib/theme";

const TABS = [
  { name: "index", label: "Home" },
  { name: "timeline", label: "Timeline" },
  { name: "kids", label: "Kids" },
  { name: "profile", label: "Profile" },
] as const;

const COLLAPSED = 56;

type TabNav = {
  navigate: (name: string) => void;
};

type TabState = {
  index: number;
  routes: { key: string; name: string }[];
};

export function CalTabBar({
  state,
  navigation,
  onAdd,
}: {
  state: TabState;
  navigation: TabNav;
  onAdd: () => void;
}) {
  const insets = useSafeAreaInsets();
  const { user } = useUser();
  const avatarUrl = user?.imageUrl;
  const collapsed = useDockCollapsed();
  const expandedW = useSharedValue(0);
  const [measured, setMeasured] = useState(false);

  useEffect(() => {
    if (collapsed) expandDock(collapsed);
  }, [state.index, collapsed]);

  const pillStyle = useAnimatedStyle(() => {
    const full = expandedW.get();
    if (full <= 0 || collapsed == null) return {};
    return {
      width: interpolate(collapsed.get(), [0, 1], [full, COLLAPSED]),
    };
  });

  const innerStyle = useAnimatedStyle(() => {
    const full = expandedW.get();
    if (full <= 0 || collapsed == null) return {};
    const shift = COLLAPSED / 2 - full / 8;
    return {
      width: full,
      transform: [
        {
          translateX: interpolate(
            collapsed.get(),
            [0, 1],
            [0, shift],
            Extrapolation.CLAMP,
          ),
        },
      ],
    };
  });

  const extrasStyle = useAnimatedStyle(() => ({
    opacity: interpolate(
      collapsed?.get() ?? 0,
      [0, 0.4],
      [1, 0],
      Extrapolation.CLAMP,
    ),
  }));

  const homeIconStyle = useAnimatedStyle(() => ({
    transform: [
      {
        translateY: interpolate(
          collapsed?.get() ?? 0,
          [0, 1],
          [0, 7],
          Extrapolation.CLAMP,
        ),
      },
    ],
  }));

  return (
    <View
      pointerEvents="box-none"
      style={[styles.dock, { paddingBottom: Math.max(insets.bottom, 10) }]}
    >
      <View style={styles.row}>
        <Animated.View
          style={[styles.pill, measured ? pillStyle : styles.pillGrow]}
          onLayout={(e) => {
            const w = e.nativeEvent.layout.width;
            if (w > 0 && expandedW.get() === 0) {
              expandedW.set(w);
              setMeasured(true);
            }
          }}
        >
          <Animated.View style={[styles.inner, measured ? innerStyle : styles.innerFill]}>
            {TABS.map((tab) => {
              const routeIndex = state.routes.findIndex((r) => r.name === tab.name);
              const active = routeIndex === state.index;
              const color = active ? colors.ink : colors.muted;
              const home = tab.name === "index";
              return (
                <Pressable
                  key={tab.name}
                  onPress={() => navigation.navigate(tab.name)}
                  style={({ pressed }) => [styles.item, pressed && styles.pressed]}
                  accessibilityRole="tab"
                  accessibilityState={{ selected: active }}
                  accessibilityLabel={tab.label}
                >
                  {home ? (
                    <Animated.View style={homeIconStyle}>
                      <HomeTabIcon color={color} />
                    </Animated.View>
                  ) : tab.name === "timeline" ? (
                    <Animated.View style={extrasStyle}>
                      <TimelineTabIcon color={color} />
                    </Animated.View>
                  ) : tab.name === "kids" ? (
                    <Animated.View style={extrasStyle}>
                      <KidsTabIcon color={color} />
                    </Animated.View>
                  ) : avatarUrl ? (
                    <Animated.View style={extrasStyle}>
                      <Image
                        source={{ uri: avatarUrl }}
                        style={[styles.avatar, active && styles.avatarOn]}
                      />
                    </Animated.View>
                  ) : (
                    <Animated.View style={[styles.avatar, extrasStyle, active && styles.avatarOn]} />
                  )}
                  <Animated.Text style={[styles.label, { color }, extrasStyle]}>
                    {tab.label}
                  </Animated.Text>
                </Pressable>
              );
            })}
          </Animated.View>
        </Animated.View>
        <Pressable
          onPress={onAdd}
          style={({ pressed }) => [styles.fab, pressed && styles.pressed]}
          accessibilityLabel="Log"
        >
          <View style={styles.plusH} />
          <View style={styles.plusV} />
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  dock: {
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: "transparent",
    paddingHorizontal: 16,
    paddingTop: 8,
  },
  row: {
    width: "100%",
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  pill: {
    height: COLLAPSED,
    borderRadius: COLLAPSED / 2,
    backgroundColor: colors.card,
    overflow: "hidden",
    ...shadow,
  },
  pillGrow: {
    flex: 1,
    marginRight: 10,
  },
  inner: {
    flexDirection: "row",
    alignItems: "center",
    height: COLLAPSED,
  },
  innerFill: {
    flex: 1,
  },
  item: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    gap: 3,
    minHeight: 44,
  },
  pressed: {
    transform: [{ scale: 0.97 }],
  },
  label: {
    fontFamily: fonts.medium,
    fontSize: 11,
  },
  avatar: {
    width: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: colors.line,
  },
  avatarOn: {
    borderWidth: 1.5,
    borderColor: colors.ink,
  },
  fab: {
    width: COLLAPSED,
    height: COLLAPSED,
    borderRadius: COLLAPSED / 2,
    backgroundColor: colors.teal,
    alignItems: "center",
    justifyContent: "center",
    ...shadow,
    shadowOpacity: 0.2,
  },
  plusH: {
    position: "absolute",
    width: 18,
    height: 2.5,
    borderRadius: 2,
    backgroundColor: "#fff",
  },
  plusV: {
    position: "absolute",
    width: 2.5,
    height: 18,
    borderRadius: 2,
    backgroundColor: "#fff",
  },
});
