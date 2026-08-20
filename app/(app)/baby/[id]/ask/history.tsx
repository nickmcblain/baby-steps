import { useQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { Screen } from "@/components/Screen";
import { Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { formatRelative } from "@/lib/format";
import { colors, fonts, radius, shadow } from "@/lib/theme";

export default function AskHistoryScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const babyId = id as Id<"babies">;
  const threads = useQuery(api.chat.listThreads, { babyId });
  const now = Date.now();

  return (
    <Screen onBack={() => router.back()}>
      <Title>Chats</Title>
      {(threads ?? []).length === 0 ? (
        <Text style={styles.empty}>
          No chats yet — tap + on Ask to start one.
        </Text>
      ) : (
        <View style={styles.list}>
          {(threads ?? []).map((t) => (
            <Pressable
              key={t._id}
              style={styles.row}
              onPress={() =>
                router.replace(`/baby/${id}/ask?thread=${t._id}`)
              }
            >
              <Text style={styles.rowTitle} numberOfLines={2}>
                {t.title?.trim() || "New chat"}
              </Text>
              <Text style={styles.rowMeta}>
                {formatRelative(t.updatedAt, now)}
              </Text>
            </Pressable>
          ))}
        </View>
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  empty: {
    fontFamily: fonts.body,
    color: colors.muted,
    fontSize: 15,
    lineHeight: 22,
  },
  list: { gap: 10 },
  row: {
    backgroundColor: colors.card,
    borderRadius: radius.tile,
    padding: 16,
    gap: 6,
    ...shadow,
  },
  rowTitle: {
    fontFamily: fonts.bold,
    fontSize: 16,
    color: colors.ink,
  },
  rowMeta: {
    fontFamily: fonts.medium,
    fontSize: 13,
    color: colors.muted,
  },
});
