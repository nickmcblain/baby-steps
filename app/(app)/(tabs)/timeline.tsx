import { useQuery } from "convex/react";
import { useRouter, type Href } from "expo-router";
import { Pressable, StyleSheet, Text } from "react-native";
import { TimelineView } from "../baby/[id]/log";
import { Screen } from "@/components/Screen";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { useActiveBabyId } from "@/lib/activeBaby";
import { colors, fonts } from "@/lib/theme";

export default function TimelineTab() {
  const router = useRouter();
  const babies = useQuery(api.babies.list);
  const { activeBabyId, ready } = useActiveBabyId();
  const known = babies?.some((b) => b._id === activeBabyId);
  const babyId = ready && known ? (activeBabyId as Id<"babies">) : undefined;

  if (!ready || babies === undefined) {
    return (
      <Screen clearDock>
        <Text style={styles.muted}>Loading…</Text>
      </Screen>
    );
  }

  if (!babyId) {
    return (
      <Screen clearDock>
        <Text style={styles.title}>Timeline</Text>
        <Text style={styles.muted}>Pick a kid first.</Text>
        <Pressable style={styles.cta} onPress={() => router.navigate("/kids" as Href)}>
          <Text style={styles.ctaText}>Go to Kids</Text>
        </Pressable>
      </Screen>
    );
  }

  return <TimelineView babyId={babyId} />;
}

const styles = StyleSheet.create({
  title: { fontFamily: fonts.displayBold, fontSize: 28, color: colors.ink },
  muted: { fontFamily: fonts.body, fontSize: 16, color: colors.muted, lineHeight: 22 },
  cta: {
    backgroundColor: colors.ink,
    borderRadius: 20,
    paddingVertical: 16,
    alignItems: "center",
  },
  ctaText: { fontFamily: fonts.bold, fontSize: 16, color: "#fff" },
});