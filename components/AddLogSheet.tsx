import { useRouter, type Href } from "expo-router";
import type { ReactNode } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import {
  ActivityIcon,
  AskIcon,
  FeedIcon,
  LogIcon,
  MedicineIcon,
  NappyIcon,
  PottyIcon,
  PumpIcon,
  SleepIcon,
  TummyIcon,
} from "@/components/ActionIcons";
import { BottomSheet } from "@/components/BottomSheet";
import { colors, fonts, shadow } from "@/lib/theme";

const TILES = [
  { path: "feed/timer", label: "Feed", tint: colors.teal, ink: "#fff", icon: "feed" },
  { path: "sleep/timer", label: "Sleep", tint: colors.purple, ink: "#fff", icon: "sleep" },
  { path: "nappy", label: "Nappy", tint: colors.peach, ink: "#fff", icon: "nappy" },
  { path: "tummy/timer", label: "Tummy", tint: colors.sky, ink: "#fff", icon: "tummy" },
  { path: "pump/timer", label: "Pump", tint: colors.tealDark, ink: "#fff", icon: "pump" },
  { path: "medicine", label: "Medicine", tint: colors.amber, ink: colors.ink, icon: "medicine" },
  { path: "potty", label: "Potty", tint: colors.peach, ink: "#fff", icon: "potty" },
  { path: "activity", label: "Activity", tint: colors.purple, ink: "#fff", icon: "activity" },
  { path: "event", label: "Note", tint: colors.rose, ink: "#fff", icon: "event" },
  { path: "ask", label: "Ask", tint: colors.teal, ink: "#fff", icon: "ask" },
] as const;

function TileIcon({
  name,
  color,
  cut,
}: {
  name: (typeof TILES)[number]["icon"];
  color: string;
  cut: string;
}): ReactNode {
  switch (name) {
    case "feed":
      return <FeedIcon color={color} />;
    case "sleep":
      return <SleepIcon color={color} cutColor={cut} />;
    case "nappy":
      return <NappyIcon color={color} />;
    case "tummy":
      return <TummyIcon color={color} />;
    case "pump":
      return <PumpIcon color={color} />;
    case "medicine":
      return <MedicineIcon color={color} />;
    case "potty":
      return <PottyIcon color={color} />;
    case "activity":
      return <ActivityIcon color={color} />;
    case "event":
      return <LogIcon color={color} />;
    case "ask":
      return <AskIcon color={color} />;
  }
}

export function AddLogSheet({
  visible,
  babyId,
  onClose,
}: {
  visible: boolean;
  babyId: string | null;
  onClose: () => void;
}) {
  const router = useRouter();

  function go(path: string) {
    onClose();
    if (!babyId) {
      router.navigate("/kids" as Href);
      return;
    }
    router.push(`/baby/${babyId}/${path}`);
  }

  return (
    <BottomSheet visible={visible} onClose={onClose}>
      <View style={styles.grid}>
        {TILES.map((tile) => (
          <Pressable
            key={tile.path}
            onPress={() => go(tile.path)}
            style={({ pressed }) => [styles.tile, pressed && styles.pressed]}
          >
            <View style={[styles.iconWell, { backgroundColor: tile.tint }]}>
              <TileIcon name={tile.icon} color={tile.ink} cut={tile.tint} />
            </View>
            <Text style={styles.label}>{tile.label}</Text>
          </Pressable>
        ))}
      </View>
    </BottomSheet>
  );
}

const styles = StyleSheet.create({
  grid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 10,
  },
  tile: {
    width: "47.5%",
    backgroundColor: colors.card,
    borderRadius: 20,
    paddingVertical: 14,
    paddingHorizontal: 10,
    alignItems: "center",
    gap: 8,
    ...shadow,
  },
  pressed: {
    transform: [{ scale: 0.97 }],
  },
  iconWell: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: "center",
    justifyContent: "center",
  },
  label: {
    fontFamily: fonts.bold,
    fontSize: 14,
    color: colors.ink,
  },
});
