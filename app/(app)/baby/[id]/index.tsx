import { useQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import type { ReactNode } from "react";
import { Pressable, Share, StyleSheet, Text, View } from "react-native";
import { FeedIcon, LogIcon, NappyIcon, TempIcon } from "@/components/ActionIcons";
import { Screen } from "@/components/Screen";
import { IconButton, Subtitle, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { eventTitle } from "@/lib/eventCopy";
import { formatAge, formatHeight, formatRelative, formatWeight } from "@/lib/format";
import { colors, fonts, radius, shadow } from "@/lib/theme";

export default function BabyHome() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const babyId = id as Id<"babies">;
  const data = useQuery(api.events.dashboard, { babyId });
  const now = Date.now();

  if (!data) {
    return (
      <Screen>
        <Title>Loading…</Title>
      </Screen>
    );
  }

  const { baby, lastFeed, lastNappy } = data;

  return (
    <Screen>
      <View style={styles.top}>
        <IconButton
          onPress={() => {
            if (router.canGoBack()) router.back();
            else router.replace("/(app)");
          }}
        >
          <Text style={styles.chev}>‹</Text>
        </IconButton>
        <IconButton onPress={() => router.push(`/baby/${id}/edit`)}>
          <Text style={styles.editMark}>Edit</Text>
        </IconButton>
      </View>
      <Text style={styles.kicker}>{formatAge(baby.dateOfBirth, now)}</Text>
      <Title>{baby.name}</Title>
      <Subtitle>Invite code {baby.inviteCode}</Subtitle>

      <View style={styles.statusRow}>
        <Pressable
          style={[styles.status, { backgroundColor: colors.tealSoft }]}
          onPress={() => router.push(`/baby/${id}/edit`)}
        >
          <Text style={styles.statusLabel}>Weight</Text>
          <Text style={styles.statusValue}>{formatWeight(baby.weightGrams)}</Text>
          <Text style={styles.statusDetail}>Tap to update</Text>
        </Pressable>
        <Pressable
          style={[styles.status, { backgroundColor: colors.purpleSoft }]}
          onPress={() => router.push(`/baby/${id}/edit`)}
        >
          <Text style={styles.statusLabel}>Height</Text>
          <Text style={styles.statusValue}>
            {baby.heightCm != null ? formatHeight(baby.heightCm) : "—"}
          </Text>
          <Text style={styles.statusDetail}>
            {baby.heightCm != null ? "Tap to update" : "Add on edit"}
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
          label="Last nappy"
          value={lastNappy ? formatRelative(lastNappy.loggedAt, now) : "Not yet"}
          detail={lastNappy ? eventTitle(lastNappy) : "Waiting…"}
          tint={colors.peachSoft}
        />
      </View>

      <View style={styles.actions}>
        <ActionTile
          icon={<FeedIcon />}
          label="Feed"
          color={colors.teal}
          onPress={() => router.push(`/baby/${id}/feed`)}
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
          color={colors.purple}
          onPress={() => router.push(`/baby/${id}/temp`)}
        />
        <ActionTile
          icon={<LogIcon />}
          label="Log"
          color={colors.amber}
          onPress={() => router.push(`/baby/${id}/log`)}
        />
      </View>

      <Pressable
        style={styles.share}
        onPress={() =>
          void Share.share({
            message: `Join ${baby.name} on Baby Steps with code ${baby.inviteCode}`,
          })
        }
      >
        <Text style={styles.shareText}>Share invite with the other parent</Text>
      </Pressable>
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
  top: { flexDirection: "row", justifyContent: "space-between" },
  chev: { fontSize: 22, lineHeight: 22, color: colors.ink, textAlign: "center" },
  editMark: {
    fontFamily: fonts.bold,
    fontSize: 13,
    color: colors.ink,
  },
  kicker: {
    fontFamily: fonts.bold,
    color: colors.tealDark,
    textTransform: "uppercase",
    letterSpacing: 0.7,
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
  share: {
    backgroundColor: colors.card,
    borderRadius: radius.pill,
    paddingVertical: 16,
    alignItems: "center",
    ...shadow,
  },
  shareText: { fontFamily: fonts.bold, color: colors.purple },
});
