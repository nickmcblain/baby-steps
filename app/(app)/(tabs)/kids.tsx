import { useConvexAuth, useMutation, useQuery } from "convex/react";
import { useRouter } from "expo-router";
import { useEffect, useState } from "react";
import {
  ActivityIndicator,
  Keyboard,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { BottomSheet } from "@/components/BottomSheet";
import {
  InviteCodeBoxes,
  INVITE_CODE_LEN,
  sanitizeInviteCode,
} from "@/components/InviteCodeBoxes";
import { Screen } from "@/components/Screen";
import { KidsTabIcon } from "@/components/TabIcons";
import { IconButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { useActiveBabyId } from "@/lib/activeBaby";
import { formatAge, formatKg } from "@/lib/format";
import { useMarkInteractive } from "@/lib/useMarkInteractive";
import { colors, fonts, radius, shadow } from "@/lib/theme";

export default function KidsTab() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { isAuthenticated, isLoading: authLoading } = useConvexAuth();
  const babies = useQuery(api.babies.list, isAuthenticated ? {} : "skip");
  const joinByCode = useMutation(api.babies.joinByCode);
  const { activeBabyId, select } = useActiveBabyId();
  const [joinOpen, setJoinOpen] = useState(false);
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [keyboardPad, setKeyboardPad] = useState(0);
  const now = Date.now();
  useMarkInteractive(isAuthenticated && babies !== undefined);

  useEffect(() => {
    const show = Keyboard.addListener(
      Platform.OS === "ios" ? "keyboardWillShow" : "keyboardDidShow",
      (e) => setKeyboardPad(e.endCoordinates.height),
    );
    const hide = Keyboard.addListener(
      Platform.OS === "ios" ? "keyboardWillHide" : "keyboardDidHide",
      () => setKeyboardPad(0),
    );
    return () => {
      show.remove();
      hide.remove();
    };
  }, []);

  async function openBaby(id: Id<"babies">) {
    await select(id);
    router.navigate("/");
  }

  function closeJoin() {
    setJoinOpen(false);
    setCode("");
    setError(null);
    setBusy(false);
  }

  async function join(nextCode: string) {
    if (busy || nextCode.length < INVITE_CODE_LEN) return;
    setBusy(true);
    setError(null);
    try {
      const id = await joinByCode({ code: nextCode });
      closeJoin();
      await openBaby(id);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Check the code.");
      setBusy(false);
    }
  }

  function onCodeChange(next: string) {
    const cleaned = sanitizeInviteCode(next);
    setCode(cleaned);
    setError(null);
    if (cleaned.length === INVITE_CODE_LEN) void join(cleaned);
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
    <>
      <Screen
        clearDock
        headerRight={
          <View style={styles.headerActions}>
            <IconButton
              onPress={() => setJoinOpen(true)}
              accessibilityLabel="Join a partner"
            >
              <KidsTabIcon color={colors.ink} />
            </IconButton>
            <IconButton
              onPress={() => router.push("/babies/new")}
              accessibilityLabel="Add baby"
              style={styles.headerGap}
            >
              <View style={styles.plusGlyph}>
                <View style={styles.plusH} />
                <View style={styles.plusV} />
              </View>
            </IconButton>
          </View>
        }
      >
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
        </View>
      </Screen>

      <BottomSheet
        visible={joinOpen}
        onClose={closeJoin}
        contentStyle={{
          paddingBottom:
            keyboardPad > 0 ? Math.max(keyboardPad - insets.bottom, 12) : 8,
        }}
      >
        <Text style={styles.sheetTitle}>Join a partner</Text>
        <Text style={styles.sheetHint}>Enter their 6-character invite code.</Text>
        <InviteCodeBoxes
          value={code}
          onChange={onCodeChange}
          autoFocus={joinOpen}
          editable={!busy}
        />
        {busy ? (
          <ActivityIndicator color={colors.teal} style={styles.sheetBusy} />
        ) : error ? (
          <Text style={styles.sheetError}>{error}</Text>
        ) : null}
      </BottomSheet>
    </>
  );
}

const styles = StyleSheet.create({
  loading: { flex: 1, alignItems: "center", justifyContent: "center", gap: 12, minHeight: 240 },
  loadingText: { fontFamily: fonts.body, color: colors.muted },
  headerActions: { flexDirection: "row", alignItems: "center" },
  headerGap: { marginLeft: 8 },
  plusGlyph: {
    width: 18,
    height: 18,
    alignItems: "center",
    justifyContent: "center",
  },
  plusH: {
    position: "absolute",
    width: 14,
    height: 2.5,
    borderRadius: 2,
    backgroundColor: colors.ink,
  },
  plusV: {
    position: "absolute",
    width: 2.5,
    height: 14,
    borderRadius: 2,
    backgroundColor: colors.ink,
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
  tileOn: {
    borderWidth: 2,
    borderColor: colors.teal,
  },
  avatar: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: colors.purpleSoft,
    alignItems: "center",
    justifyContent: "center",
  },
  avatarText: { fontFamily: fonts.displayBold, fontSize: 20, color: colors.purple },
  tileName: { fontFamily: fonts.bold, fontSize: 18, color: colors.ink },
  tileMeta: { fontFamily: fonts.body, color: colors.muted, fontSize: 13 },
  invite: {
    fontFamily: fonts.medium,
    fontSize: 12,
    color: colors.purple,
    marginTop: 2,
  },
  sheetTitle: { fontFamily: fonts.bold, fontSize: 22, color: colors.ink },
  sheetHint: {
    fontFamily: fonts.body,
    fontSize: 15,
    color: colors.muted,
    marginBottom: 8,
  },
  sheetBusy: { marginTop: 12 },
  sheetError: {
    fontFamily: fonts.medium,
    fontSize: 14,
    color: colors.danger,
    marginTop: 12,
  },
});
