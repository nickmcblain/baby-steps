import { useConvexAuth, useMutation, useQuery } from "convex/react";
import { useRouter } from "expo-router";
import { useState } from "react";
import { ActivityIndicator, Alert, Pressable, StyleSheet, Text, View } from "react-native";
import { Screen } from "@/components/Screen";
import { Card, Field, PrimaryButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { useActiveBabyId } from "@/lib/activeBaby";
import { formatAge, formatKg } from "@/lib/format";
import { useMarkInteractive } from "@/lib/useMarkInteractive";
import { colors, fonts, radius, shadow } from "@/lib/theme";

export default function KidsTab() {
  const router = useRouter();
  const { isAuthenticated, isLoading: authLoading } = useConvexAuth();
  const babies = useQuery(api.babies.list, isAuthenticated ? {} : "skip");
  const joinByCode = useMutation(api.babies.joinByCode);
  const { activeBabyId, select } = useActiveBabyId();
  const [code, setCode] = useState("");
  const now = Date.now();
  useMarkInteractive(isAuthenticated && babies !== undefined);

  async function openBaby(id: Id<"babies">) {
    await select(id);
    router.navigate("/");
  }

  async function join() {
    try {
      const id = await joinByCode({ code });
      setCode("");
      await openBaby(id);
    } catch (error) {
      Alert.alert("Could not join", error instanceof Error ? error.message : "Check the code.");
    }
  }

  if (authLoading || !isAuthenticated) {
    return (
      <Screen clearDock>
        <View style={styles.loading}>
          <ActivityIndicator color={colors.teal} />
          <Text style={styles.loadingText}>Connecting…</Text>
        </View>
      </Screen>
    );
  }

  return (
    <Screen clearDock>
      <Title>Kids</Title>

      <View style={styles.grid}>
        {(babies ?? []).map((baby) => {
          const active = baby._id === activeBabyId;
          return (
            <Pressable
              key={baby._id}
              onPress={() => void openBaby(baby._id)}
              style={[styles.tile, active && styles.tileOn]}
            >
              <View style={styles.avatar}>
                <Text style={styles.avatarText}>{baby.name.slice(0, 1).toUpperCase()}</Text>
              </View>
              <Text style={styles.tileName}>{baby.name}</Text>
              <Text style={styles.tileMeta}>
                {formatAge(baby.dateOfBirth, now)} · {formatKg(baby.weightGrams)}
              </Text>
              <Text style={styles.invite}>Code {baby.inviteCode}</Text>
            </Pressable>
          );
        })}
        <Pressable onPress={() => router.push("/babies/new")} style={[styles.tile, styles.addTile]}>
          <View style={[styles.avatar, styles.addAvatar]}>
            <View style={styles.plusMark} pointerEvents="none">
              <View style={styles.plusBarH} />
              <View style={styles.plusBarV} />
            </View>
          </View>
          <Text style={styles.tileName}>Add baby</Text>
          <Text style={styles.tileMeta}>Name, age, weight</Text>
        </Pressable>
      </View>

      <Card>
        <Text style={styles.cardLabel}>Join a partner</Text>
        <Field
          label="Invite code"
          value={code}
          onChangeText={setCode}
          autoCapitalize="characters"
          placeholder="ABC123"
        />
        <PrimaryButton label="Join with code" onPress={() => void join()} disabled={code.trim().length < 4} />
      </Card>
    </Screen>
  );
}

const styles = StyleSheet.create({
  loading: { flex: 1, alignItems: "center", justifyContent: "center", gap: 12, minHeight: 240 },
  loadingText: { fontFamily: fonts.body, color: colors.muted },
  grid: { flexDirection: "row", flexWrap: "wrap", gap: 12 },
  tile: {
    width: "47.5%",
    backgroundColor: colors.card,
    borderRadius: radius.tile,
    padding: 16,
    minHeight: 150,
    ...shadow,
    gap: 8,
  },
  tileOn: {
    borderWidth: 2,
    borderColor: colors.teal,
  },
  addTile: { borderWidth: 2, borderColor: colors.line, shadowOpacity: 0 },
  avatar: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: colors.purpleSoft,
    alignItems: "center",
    justifyContent: "center",
  },
  addAvatar: { backgroundColor: colors.tealSoft },
  avatarText: { fontFamily: fonts.displayBold, fontSize: 20, color: colors.purple },
  plusMark: {
    width: 18,
    height: 18,
    alignItems: "center",
    justifyContent: "center",
  },
  plusBarH: {
    position: "absolute",
    width: 18,
    height: 3,
    borderRadius: 2,
    backgroundColor: colors.tealDark,
  },
  plusBarV: {
    position: "absolute",
    width: 3,
    height: 18,
    borderRadius: 2,
    backgroundColor: colors.tealDark,
  },
  tileName: { fontFamily: fonts.bold, fontSize: 18, color: colors.ink },
  tileMeta: { fontFamily: fonts.body, color: colors.muted, fontSize: 13 },
  invite: {
    fontFamily: fonts.medium,
    fontSize: 12,
    color: colors.purple,
    marginTop: 2,
  },
  cardLabel: { fontFamily: fonts.bold, fontSize: 16, color: colors.ink, marginBottom: 8 },
});