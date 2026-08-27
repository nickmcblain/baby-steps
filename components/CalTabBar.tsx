import { useUser } from "@clerk/expo";
import { Image, Pressable, StyleSheet, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { HomeTabIcon, KidsTabIcon, TimelineTabIcon } from "@/components/TabIcons";
import { colors, fonts, shadow } from "@/lib/theme";

const TABS = [
  { name: "index", label: "Home" },
  { name: "timeline", label: "Timeline" },
  { name: "kids", label: "Kids" },
  { name: "profile", label: "Profile" },
] as const;

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

  return (
    <View
      pointerEvents="box-none"
      style={[styles.dock, { paddingBottom: Math.max(insets.bottom, 10) }]}
    >
      <View style={styles.row}>
        <View style={styles.pill}>
          {TABS.map((tab) => {
            const routeIndex = state.routes.findIndex((r) => r.name === tab.name);
            const active = routeIndex === state.index;
            const color = active ? colors.ink : colors.muted;
            return (
              <Pressable
                key={tab.name}
                onPress={() => navigation.navigate(tab.name)}
                style={({ pressed }) => [styles.item, pressed && styles.pressed]}
                accessibilityRole="tab"
                accessibilityState={{ selected: active }}
                accessibilityLabel={tab.label}
              >
                {tab.name === "index" ? (
                  <HomeTabIcon color={color} />
                ) : tab.name === "timeline" ? (
                  <TimelineTabIcon color={color} />
                ) : tab.name === "kids" ? (
                  <KidsTabIcon color={color} />
                ) : (
                  avatarUrl ? (
                    <Image
                      source={{ uri: avatarUrl }}
                      style={[styles.avatar, active && styles.avatarOn]}
                    />
                  ) : (
                    <View style={[styles.avatar, active && styles.avatarOn]} />
                  )
                )}
                <Text style={[styles.label, { color }]}>{tab.label}</Text>
              </Pressable>
            );
          })}
        </View>
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
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
  },
  pill: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: colors.card,
    borderRadius: 32,
    paddingVertical: 8,
    paddingHorizontal: 4,
    minHeight: 56,
    ...shadow,
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
    width: 56,
    height: 56,
    borderRadius: 28,
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