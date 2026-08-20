import { useQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import type { ReactNode } from "react";
import { useMemo, useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import {
  AskIcon,
  FeedIcon,
  LogIcon,
  NappyIcon,
  SleepIcon,
  TempIcon,
} from "@/components/ActionIcons";
import { BottomSheet } from "@/components/BottomSheet";
import { Screen } from "@/components/Screen";
import { IconButton, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { eventTitle } from "@/lib/eventCopy";
import { toFeedReminderBaby } from "@/lib/feedReminders";
import { formatAge, formatHeight, formatRelative, formatWeight } from "@/lib/format";
import { useMarkInteractive } from "@/lib/useMarkInteractive";
import {
  feedReminderHint,
  useFeedReminderSync,
} from "@/lib/useFeedReminderSync";
import { colors, fonts, radius, shadow } from "@/lib/theme";

export default function BabyHome() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const babyId = id as Id<"babies">;
  const data = useQuery(api.events.dashboard, { babyId });
  const now = Date.now();
  const [feedSheetOpen, setFeedSheetOpen] = useState(false);
  const [sleepSheetOpen, setSleepSheetOpen] = useState(false);
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

  const { baby, lastFeed, lastSleep } = data;
  const feedHint =
    reminderBaby != null
      ? feedReminderHint(
          reminderBaby,
          lastFeed
            ? lastFeed.loggedAt + (lastFeed.durationMinutes ?? 0) * 60_000
            : null,
          now,
        )
      : null;

  function openFeed(path: "timer" | "manual") {
    setFeedSheetOpen(false);
    router.push(`/baby/${id}/feed/${path}`);
  }

  function openSleep(path: "timer" | "manual") {
    setSleepSheetOpen(false);
    router.push(`/baby/${id}/sleep/${path}`);
  }

  return (
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
          <Text style={styles.statusDetail}>Tap to log weigh-in</Text>
        </Pressable>
        <Pressable
          style={[styles.status, { backgroundColor: colors.skySoft }]}
          onPress={() => router.push(`/baby/${id}/height`)}
        >
          <Text style={styles.statusLabel}>Height</Text>
          <Text style={styles.statusValue}>
            {baby.heightCm != null ? formatHeight(baby.heightCm) : "—"}
          </Text>
          <Text style={styles.statusDetail}>
            {baby.heightCm != null ? "Tap to log height" : "Add a height"}
          </Text>
        </Pressable>
      </View>

      <View style={styles.statusRow}>
        <StatusCard
          label="Last feed"
          value={lastFeed ? formatRelative(lastFeed.loggedAt, now) : "Not yet"}
          detail={lastFeed ? eventTitle(lastFeed) : "Log the first one"}
          tint={colors.amberSoft}
        />
        <StatusCard
          label="Last sleep"
          value={lastSleep ? formatRelative(lastSleep.loggedAt, now) : "Not yet"}
          detail={lastSleep ? eventTitle(lastSleep) : "Log a nap"}
          tint={colors.purpleSoft}
        />
      </View>
      {feedHint ? <Text style={styles.feedHint}>{feedHint}</Text> : null}

      <View style={styles.actions}>
        <ActionTile
          icon={<FeedIcon />}
          label="Feed"
          color={colors.teal}
          onPress={() => setFeedSheetOpen(true)}
        />
        <ActionTile
          icon={<SleepIcon cutColor={colors.purple} />}
          label="Sleep"
          color={colors.purple}
          onPress={() => setSleepSheetOpen(true)}
        />
        <ActionTile
          icon={<NappyIcon />}
          label="Nappy"
          color={colors.peach}
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
        <ActionTile
          icon={<AskIcon />}
          label="Ask"
          color={colors.ink}
          onPress={() => router.push(`/baby/${id}/ask`)}
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
        </View>
      </BottomSheet>
    </Screen>
  );
}

function StatusCard({
  label,
  value,
  detail,
  tint,
}: {
  label: string;
  value: string;
  detail: string;
  tint: string;
}) {
  return (
    <View style={[styles.status, { backgroundColor: tint }]}>
      <Text style={styles.statusLabel}>{label}</Text>
      <Text style={styles.statusValue}>{value}</Text>
      <Text style={styles.statusDetail}>{detail}</Text>
    </View>
  );
}

function ActionTile({
  icon,
  label,
  color,
  onPress,
}: {
  icon: ReactNode;
  label: string;
  color: string;
  onPress: () => void;
}) {
  return (
    <Pressable onPress={onPress} style={styles.action}>
      <View style={[styles.actionIcon, { backgroundColor: color }]}>{icon}</View>
      <Text style={styles.actionLabel}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
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
  feedHint: {
    fontFamily: fonts.body,
    fontSize: 13,
    color: colors.muted,
    marginTop: -8,
    lineHeight: 18,
  },
  status: {
    flex: 1,
    borderRadius: radius.tile,
    padding: 16,
    gap: 4,
  },
  statusLabel: { fontFamily: fonts.medium, color: colors.muted, fontSize: 13 },
  statusValue: { fontFamily: fonts.displayBold, fontSize: 22, color: colors.ink },
  statusDetail: { fontFamily: fonts.body, color: colors.ink, opacity: 0.7 },
  actions: { flexDirection: "row", flexWrap: "wrap", gap: 12 },
  action: {
    width: "47.5%",
    backgroundColor: colors.card,
    borderRadius: radius.tile,
    padding: 18,
    minHeight: 130,
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
