import { useQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import type { ReactNode } from "react";
import { useMemo, useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import {
  AskIcon,
  FeedIcon,
  LogIcon,
  NappyIcon,
  SleepIcon,
  TempIcon,
  TummyIcon,
} from "@/components/ActionIcons";
import { BottomSheet } from "@/components/BottomSheet";
import { Screen } from "@/components/Screen";
import { IconButton, Title } from "@/components/ui";
import { VoiceLogFab } from "@/components/VoiceLogFab";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { eventTitle } from "@/lib/eventCopy";
import { toFeedReminderBaby } from "@/lib/feedReminders";
import { formatAge, formatHeight, formatRelative, formatWeight } from "@/lib/format";
import { useMarkInteractive } from "@/lib/useMarkInteractive";
import { useFeedReminderSync } from "@/lib/useFeedReminderSync";
import { colors, fonts, radius, shadow } from "@/lib/theme";

export default function BabyHome() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const babyId = id as Id<"babies">;
  const data = useQuery(api.events.dashboard, { babyId });
  const now = Date.now();
  const [feedSheetOpen, setFeedSheetOpen] = useState(false);
  const [sleepSheetOpen, setSleepSheetOpen] = useState(false);
  const [tummySheetOpen, setTummySheetOpen] = useState(false);
  const [voiceStatus, setVoiceStatus] = useState<string | null>(null);
  useMarkInteractive(data != null);

  const reminderBaby = useMemo(
    () => (data ? toFeedReminderBaby(data.baby) : null),
    [data],
  );
  useFeedReminderSync(
    reminderBaby,
    data?.lastFeed
      ? data.lastFeed.loggedAt + (data.lastFeed.durationMinutes ?? 0) * 60_000
      : null,
  );

  if (!data) {
    return (
      <Screen>
        <Title>Loading…</Title>
      </Screen>
    );
  }

  const { baby, lastFeed, lastSleep, lastNappy, lastTummy } = data;

  function openFeed(path: "timer" | "manual") {
    setFeedSheetOpen(false);
    router.push(`/baby/${id}/feed/${path}`);
  }

  function openSleep(path: "timer" | "manual") {
    setSleepSheetOpen(false);
    router.push(`/baby/${id}/sleep/${path}`);
  }

  function openTummy(path: "timer" | "manual") {
    setTummySheetOpen(false);
    router.push(`/baby/${id}/tummy/${path}`);
  }

  return (
    <View style={styles.root}>
    <Screen
      onBack={() => {
        if (router.canGoBack()) router.back();
        else router.replace("/(app)");
      }}
      headerRight={
        <IconButton onPress={() => router.push(`/baby/${id}/edit`)}>
          <Text style={styles.editMark}>Edit</Text>
        </IconButton>
      }
    >
      <View style={styles.heading}>
        <View style={styles.headingName}>
          <Title>{baby.name}</Title>
        </View>
        <Text style={styles.kicker}>{formatAge(baby.dateOfBirth, now)}</Text>
      </View>

      <View style={styles.statusRow}>
        <Pressable
          style={[styles.status, { backgroundColor: colors.tealSoft }]}
          onPress={() => router.push(`/baby/${id}/weight`)}
        >
          <Text style={styles.statusLabel}>Weight</Text>
          <Text style={styles.statusValue}>{formatWeight(baby.weightGrams)}</Text>
        </Pressable>
        <Pressable
          style={[styles.status, { backgroundColor: colors.skySoft }]}
          onPress={() => router.push(`/baby/${id}/height`)}
        >
          <Text style={styles.statusLabel}>Height</Text>
          <Text style={styles.statusValue}>
            {baby.heightCm != null ? formatHeight(baby.heightCm) : "—"}
          </Text>
        </Pressable>
      </View>

      <View style={styles.actions}>
        <ActionTile
          icon={<FeedIcon />}
          label="Feed"
          color={colors.teal}
          last={
            lastFeed
              ? `${formatRelative(lastFeed.loggedAt, now)} · ${eventTitle(lastFeed)}`
              : undefined
          }
          onPress={() => setFeedSheetOpen(true)}
        />
        <ActionTile
          icon={<SleepIcon cutColor={colors.purple} />}
          label="Sleep"
          color={colors.purple}
          last={
            lastSleep
              ? `${formatRelative(lastSleep.loggedAt, now)} · ${eventTitle(lastSleep)}`
              : undefined
          }
          onPress={() => setSleepSheetOpen(true)}
        />
        <ActionTile
          icon={<TummyIcon />}
          label="Tummy"
          color={colors.sky}
          last={
            lastTummy
              ? `${formatRelative(lastTummy.loggedAt, now)} · ${eventTitle(lastTummy)}`
              : undefined
          }
          onPress={() => setTummySheetOpen(true)}
        />
        <ActionTile
          icon={<NappyIcon />}
          label="Nappy"
          color={colors.peach}
          last={
            lastNappy
              ? `${formatRelative(lastNappy.loggedAt, now)} · ${eventTitle(lastNappy)}`
              : undefined
          }
          onPress={() => router.push(`/baby/${id}/nappy`)}
        />
        <ActionTile
          icon={<TempIcon />}
          label="Clothing"
          color={colors.tealDark}
          onPress={() => router.push(`/baby/${id}/temp`)}
        />
        <ActionTile
          icon={<LogIcon />}
          label="Timeline"
          color={colors.amber}
          onPress={() => router.push(`/baby/${id}/log`)}
        />
      </View>

      <BottomSheet
        visible={feedSheetOpen}
        onClose={() => setFeedSheetOpen(false)}
      >
        <View style={styles.sheetStack}>
          <Pressable style={styles.sheetPrimary} onPress={() => openFeed("timer")}>
            <Text style={styles.sheetPrimaryText}>Start timer</Text>
          </Pressable>
          <Pressable style={styles.sheetSecondary} onPress={() => openFeed("manual")}>
            <Text style={styles.sheetSecondaryText}>Log manually</Text>
          </Pressable>
          <Pressable
            style={styles.sheetSecondary}
            onPress={() => {
              setFeedSheetOpen(false);
              router.push(`/baby/${id}/feed/patterns`);
            }}
          >
            <Text style={styles.sheetSecondaryText}>Feed patterns</Text>
          </Pressable>
        </View>
      </BottomSheet>

      <BottomSheet
        visible={sleepSheetOpen}
        onClose={() => setSleepSheetOpen(false)}
      >
        <View style={styles.sheetStack}>
          <Pressable
            style={[styles.sheetPrimary, { backgroundColor: colors.purple }]}
            onPress={() => openSleep("timer")}
          >
            <Text style={styles.sheetPrimaryText}>Start timer</Text>
          </Pressable>
          <Pressable
            style={[styles.sheetSecondary, { backgroundColor: colors.purpleSoft }]}
            onPress={() => openSleep("manual")}
          >
            <Text style={styles.sheetSecondaryText}>Log manually</Text>
          </Pressable>
          <Pressable
            style={[styles.sheetSecondary, { backgroundColor: colors.purpleSoft }]}
            onPress={() => {
              setSleepSheetOpen(false);
              router.push(`/baby/${id}/sleep/patterns`);
            }}
          >
            <Text style={styles.sheetSecondaryText}>Sleep patterns</Text>
          </Pressable>
        </View>
      </BottomSheet>

      <BottomSheet
        visible={tummySheetOpen}
        onClose={() => setTummySheetOpen(false)}
      >
        <View style={styles.sheetStack}>
          <Pressable
            style={[styles.sheetPrimary, { backgroundColor: colors.sky }]}
            onPress={() => openTummy("timer")}
          >
            <Text style={styles.sheetPrimaryText}>Start timer</Text>
          </Pressable>
          <Pressable
            style={[styles.sheetSecondary, { backgroundColor: colors.skySoft }]}
            onPress={() => openTummy("manual")}
          >
            <Text style={styles.sheetSecondaryText}>Log manually</Text>
          </Pressable>
        </View>
      </BottomSheet>
    </Screen>
      {voiceStatus ? (
        <View style={styles.voiceBanner} pointerEvents="none">
          <Text style={styles.voiceBannerText}>{voiceStatus}</Text>
        </View>
      ) : null}
      <VoiceLogFab babyId={babyId} onStatus={setVoiceStatus} />
      <View
        style={[styles.fab, { bottom: Math.max(insets.bottom, 12) + 8 }]}
        pointerEvents="box-none"
      >
        <IconButton
          onPress={() => router.push(`/baby/${id}/ask`)}
          accessibilityLabel="Ask"
        >
          <AskIcon color={colors.ink} />
        </IconButton>
      </View>
    </View>
  );
}

function ActionTile({
  icon,
  label,
  color,
  last,
  onPress,
}: {
  icon: ReactNode;
  label: string;
  color: string;
  last?: string;
  onPress: () => void;
}) {
  return (
    <Pressable onPress={onPress} style={styles.action}>
      <View style={[styles.actionIcon, { backgroundColor: color }]}>{icon}</View>
      <Text style={styles.actionLabel}>{label}</Text>
      <Text style={styles.actionLast} numberOfLines={2}>
        {last ?? " "}
      </Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  fab: {
    position: "absolute",
    right: 16,
    zIndex: 40,
    elevation: 40,
  },
  voiceBanner: {
    position: "absolute",
    left: 20,
    right: 20,
    bottom: 72,
    zIndex: 45,
    backgroundColor: colors.ink,
    borderRadius: 16,
    paddingHorizontal: 16,
    paddingVertical: 12,
    ...shadow,
  },
  voiceBannerText: {
    fontFamily: fonts.medium,
    fontSize: 14,
    color: "#fff",
    textAlign: "center",
    lineHeight: 20,
  },
  editMark: {
    fontFamily: fonts.bold,
    fontSize: 13,
    color: colors.ink,
  },
  heading: {
    flexDirection: "row",
    alignItems: "baseline",
    justifyContent: "space-between",
    gap: 12,
  },
  headingName: { flex: 1, minWidth: 0 },
  kicker: {
    fontFamily: fonts.bold,
    color: colors.tealDark,
    textTransform: "uppercase",
    letterSpacing: 0.7,
    flexShrink: 0,
  },
  statusRow: { flexDirection: "row", gap: 12 },
  status: {
    flex: 1,
    borderRadius: radius.tile,
    padding: 16,
    gap: 4,
  },
  statusLabel: { fontFamily: fonts.medium, color: colors.muted, fontSize: 13 },
  statusValue: { fontFamily: fonts.displayBold, fontSize: 22, color: colors.ink },
  actions: { flexDirection: "row", flexWrap: "wrap", gap: 12 },
  action: {
    width: "47.5%",
    backgroundColor: colors.card,
    borderRadius: radius.tile,
    padding: 18,
    minHeight: 168,
    ...shadow,
    gap: 12,
  },
  actionIcon: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: "center",
    justifyContent: "center",
  },
  actionLabel: { fontFamily: fonts.bold, fontSize: 18, color: colors.ink },
  actionLast: {
    fontFamily: fonts.body,
    fontSize: 13,
    color: colors.muted,
    lineHeight: 18,
    minHeight: 36,
  },
  sheetStack: { gap: 10 },
  sheetPrimary: {
    backgroundColor: colors.teal,
    borderRadius: 20,
    paddingVertical: 16,
    paddingHorizontal: 18,
    alignItems: "center",
  },
  sheetPrimaryText: {
    fontFamily: fonts.bold,
    fontSize: 16,
    color: "#fff",
    textAlign: "center",
  },
  sheetSecondary: {
    backgroundColor: colors.tealSoft,
    borderRadius: 20,
    paddingVertical: 16,
    paddingHorizontal: 18,
    alignItems: "center",
  },
  sheetSecondaryText: {
    fontFamily: fonts.bold,
    fontSize: 16,
    color: colors.ink,
    textAlign: "center",
  },
});
