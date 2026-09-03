import { useRouter, type Href } from "expo-router";
import { type ReactNode, useEffect } from "react";
import {
  ActivityIndicator,
  Alert,
  Pressable,
  StyleSheet,
  Text,
  View,
} from "react-native";
import {
  ActivityIcon,
  AskIcon,
  FeedIcon,
  LogIcon,
  MedicineIcon,
  MicIcon,
  NappyIcon,
  PottyIcon,
  PumpIcon,
  SleepIcon,
  TempIcon,
  TummyIcon,
} from "@/components/ActionIcons";
import { BottomSheet } from "@/components/BottomSheet";
import type { Id } from "@/convex/_generated/dataModel";
import { colors, fonts, shadow } from "@/lib/theme";
import { useVoiceLog } from "@/lib/useVoiceLog";

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
  { path: "temp", label: "Clothing", tint: colors.amber, ink: colors.ink, icon: "temp" },
  { path: "ask", label: "Ask", tint: colors.teal, ink: "#fff", icon: "ask" },
] as const;

function TileIcon({
  name,
  color,
  cut,
}: {
  name: (typeof TILES)[number]["icon"] | "mic";
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
    case "temp":
      return <TempIcon color={color} />;
    case "ask":
      return <AskIcon color={color} />;
    case "mic":
      return <MicIcon color={color} />;
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
  const voice = useVoiceLog(babyId as Id<"babies"> | null);
  useEffect(() => {
    if (!visible) void voice.cancel();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible]);

  function go(path: string) {
    if (voice.recording || voice.busy) return;
    onClose();
    if (!babyId) {
      router.navigate("/kids" as Href);
      return;
    }
    router.push(`/baby/${babyId}/${path}`);
  }

  async function onSpeak() {
    if (!babyId) {
      onClose();
      router.navigate("/kids" as Href);
      return;
    }
    const result = await voice.toggle();
    if (!result) return;
    onClose();
    if (result.handoff === "ask") {
      router.push(
        `/baby/${babyId}/ask?q=${encodeURIComponent(result.transcript)}` as Href,
      );
      return;
    }
    Alert.alert("Logged", result.confirmation);
  }

  const speakTint = voice.recording ? colors.danger : colors.ink;

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
        <Pressable
          onPress={() => void onSpeak()}
          disabled={voice.busy}
          accessibilityLabel={
            voice.recording ? "Stop and send" : "Speak a log or question"
          }
          style={({ pressed }) => [styles.tile, pressed && styles.pressed]}
        >
          <View style={[styles.iconWell, { backgroundColor: speakTint }]}>
            {voice.busy ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <TileIcon name="mic" color="#fff" cut={speakTint} />
            )}
          </View>
          <Text style={styles.label}>
            {voice.recording ? "Listening" : "Speak"}
          </Text>
        </Pressable>
      </View>
      {voice.status ? <Text style={styles.status}>{voice.status}</Text> : null}
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
    flexGrow: 1,
    flexBasis: "40%",
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
  status: {
    fontFamily: fonts.medium,
    fontSize: 14,
    color: colors.muted,
    textAlign: "center",
  },
});
