import { UserButton } from "@clerk/expo/native";
import { useConvexAuth, useMutation, useQuery } from "convex/react";
import { useRouter } from "expo-router";
import { useState } from "react";
import { ActivityIndicator, Alert, Pressable, StyleSheet, Text, View } from "react-native";
import { Screen } from "@/components/Screen";
import { Card, Field, PrimaryButton, Subtitle, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { setActiveBabyId } from "@/lib/activeBaby";
import { formatAge, formatKg } from "@/lib/format";
import { useMarkInteractive } from "@/lib/useMarkInteractive";
import { colors, fonts, radius, shadow } from "@/lib/theme";

export default function BabiesScreen() {
  const router = useRouter();
  const { isAuthenticated, isLoading: authLoading } = useConvexAuth();
  const babies = useQuery(api.babies.list, isAuthenticated ? {} : "skip");
  const joinByCode = useMutation(api.babies.joinByCode);
  const [code, setCode] = useState("");
  const now = Date.now();
  useMarkInteractive(isAuthenticated && babies !== undefined);

  async function openBaby(id: Id<"babies">) {
    await setActiveBabyId(id);
    router.push(`/baby/${id}`);
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
      <Screen>
        <View style={styles.loading}>
          <ActivityIndicator color={colors.teal} />
          <Text style={styles.loadingText}>Connecting…</Text>
        </View>
      </Screen>
    );
  }

  return (
    <Screen>
      <View style={styles.header}>
        <View style={{ flex: 1 }}>
          <Text style={styles.hello}>Today</Text>
          <Title>Your little crew</Title>
        </View>
        <UserButton />
      </View>
      <Subtitle>Tap a baby to log feeds, nappies, and room kit.</Subtitle>

      <View style={styles.grid}>
        {(babies ?? []).map((baby) => (
          <Pressable key={baby._id} onPress={() => void openBaby(baby._id)} style={styles.tile}>
            <View style={styles.avatar}>
              <Text style={styles.avatarText}>{baby.name.slice(0, 1).toUpperCase()}</Text>
            </View>
            <Text style={styles.tileName}>{baby.name}</Text>
            <Text style={styles.tileMeta}>
              {formatAge(baby.dateOfBirth, now)} · {formatKg(baby.weightGrams)}
            </Text>
            <Text style={styles.invite}>Code {baby.inviteCode}</Text>
          </Pressable>
        ))}
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
  header: { flexDirection: "row", alignItems: "flex-start", gap: 12 },
  loading: { flex: 1, alignItems: "center", justifyContent: "center", gap: 12, minHeight: 240 },
  loadingText: { fontFamily: fonts.body, color: colors.muted },
  hello: {
    fontFamily: fonts.bold,
    color: colors.tealDark,
    textTransform: "uppercase",
    letterSpacing: 0.8,
    marginBottom: 4,
  },
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
