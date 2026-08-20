import { useAction, useMutation, useQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useEffect, useRef, useState } from "react";
import {
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { Screen } from "@/components/Screen";
import { Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { useMarkInteractive } from "@/lib/useMarkInteractive";
import { colors, fonts, radius, shadow } from "@/lib/theme";

const EMERGENCY =
  /\b(not breathing|unresponsive|blue lips|turning blue|seizure|choking badly)\b/i;

export default function AskScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const babyId = id as Id<"babies">;
  const [now] = useState(() => Date.now());
  const chip = useQuery(api.chat.contextChip, { babyId, now });
  const ensureThread = useMutation(api.chat.ensureThread);
  const ask = useAction(api.chatAgent.ask);
  const [threadId, setThreadId] = useState<Id<"chatThreads"> | null>(null);
  const messages = useQuery(
    api.chat.listMessages,
    threadId ? { threadId } : "skip",
  );
  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const scrollRef = useRef<ScrollView>(null);
  useMarkInteractive(chip != null && threadId != null);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const tid = await ensureThread({ babyId });
        if (!cancelled) setThreadId(tid);
      } catch (error) {
        Alert.alert(
          "Could not open chat",
          error instanceof Error ? error.message : "Try again",
        );
      }
    })();
    return () => {
      cancelled = true;
    };
    // ensureThread is a stable Convex mutation handle
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [babyId]);

  useEffect(() => {
    if (!messages?.length) return;
    requestAnimationFrame(() => {
      scrollRef.current?.scrollToEnd({ animated: true });
    });
  }, [messages?.length, sending]);

  async function send() {
    const text = draft.trim();
    if (!text || !threadId || sending) return;
    if (EMERGENCY.test(text)) {
      Alert.alert(
        "Seek urgent help",
        "If your baby is not breathing normally, is unresponsive, blue/grey, or having a seizure, call 999 now.",
      );
    }
    setDraft("");
    setSending(true);
    try {
      await ask({ babyId, threadId, message: text });
    } catch (error) {
      Alert.alert(
        "Ask failed",
        error instanceof Error ? error.message : "Try again",
      );
      setDraft(text);
    } finally {
      setSending(false);
    }
  }

  return (
    <Screen scroll={false} onBack={() => router.back()}>
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === "ios" ? "padding" : undefined}
        keyboardVerticalOffset={8}
      >
        <View>
          <Title>Ask</Title>
          {chip ? (
            <View style={styles.chip}>
              <Text style={styles.chipText}>{chip.summaryLine}</Text>
            </View>
          ) : null}
        </View>

        <ScrollView
          ref={scrollRef}
          style={styles.flex}
          contentContainerStyle={styles.messages}
          keyboardShouldPersistTaps="handled"
        >
          {(messages ?? []).length === 0 && !sending ? (
            <Text style={styles.empty}>
              Ask about sleep, feeds, nappies, clothing, or settling. Answers use
              {chip ? ` ${chip.name}'s` : " this baby's"} details automatically.
            </Text>
          ) : null}
          {(messages ?? []).map((m) => (
            <View
              key={m._id}
              style={[
                styles.bubble,
                m.role === "user" ? styles.userBubble : styles.assistantBubble,
              ]}
            >
              <Text
                style={[
                  styles.bubbleText,
                  m.role === "user" && styles.userBubbleText,
                ]}
              >
                {m.content}
              </Text>
              {m.role === "assistant" && m.citations && m.citations.length > 0 ? (
                <View style={styles.cites}>
                  {m.citations.map((c) => (
                    <Text key={`${c.title}-${c.url ?? ""}`} style={styles.cite}>
                      · {c.title}
                    </Text>
                  ))}
                </View>
              ) : null}
            </View>
          ))}
          {sending ? (
            <View style={styles.pending}>
              <ActivityIndicator color={colors.teal} />
              <Text style={styles.pendingText}>Thinking with baby context…</Text>
            </View>
          ) : null}
        </ScrollView>

        <Text style={styles.disclaimer}>
          Guidance, not medical advice. For emergencies call 999; for urgent
          advice use NHS 111 or your midwife.
        </Text>
        <View style={styles.composer}>
          <TextInput
            style={styles.input}
            value={draft}
            onChangeText={setDraft}
            placeholder="Ask about newborn care…"
            placeholderTextColor={colors.muted}
            multiline
            editable={!sending}
          />
          <Pressable
            onPress={() => void send()}
            disabled={sending || draft.trim().length === 0}
            style={[
              styles.send,
              (sending || draft.trim().length === 0) && styles.sendDisabled,
            ]}
          >
            <Text style={styles.sendText}>Send</Text>
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  chip: {
    alignSelf: "flex-start",
    backgroundColor: colors.tealSoft,
    borderRadius: radius.pill,
    paddingHorizontal: 12,
    paddingVertical: 6,
    marginTop: 4,
  },
  chipText: {
    fontFamily: fonts.medium,
    fontSize: 13,
    color: colors.tealDark,
  },
  messages: { paddingVertical: 12, gap: 10, flexGrow: 1 },
  empty: {
    fontFamily: fonts.body,
    color: colors.muted,
    fontSize: 15,
    lineHeight: 22,
    paddingHorizontal: 4,
  },
  bubble: {
    borderRadius: 20,
    paddingHorizontal: 14,
    paddingVertical: 12,
    maxWidth: "92%",
    gap: 6,
  },
  userBubble: {
    alignSelf: "flex-end",
    backgroundColor: colors.teal,
  },
  assistantBubble: {
    alignSelf: "flex-start",
    backgroundColor: colors.card,
    ...shadow,
  },
  bubbleText: {
    fontFamily: fonts.body,
    fontSize: 15,
    color: colors.ink,
    lineHeight: 22,
  },
  userBubbleText: { color: "#fff" },
  cites: { gap: 2, marginTop: 4 },
  cite: {
    fontFamily: fonts.medium,
    fontSize: 12,
    color: colors.muted,
  },
  pending: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    paddingVertical: 8,
  },
  pendingText: { fontFamily: fonts.body, color: colors.muted },
  disclaimer: {
    fontFamily: fonts.body,
    fontSize: 12,
    color: colors.muted,
    lineHeight: 16,
    marginBottom: 8,
  },
  composer: {
    flexDirection: "row",
    alignItems: "flex-end",
    gap: 8,
    paddingBottom: 8,
  },
  input: {
    flex: 1,
    minHeight: 48,
    maxHeight: 120,
    backgroundColor: colors.card,
    borderRadius: 22,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontFamily: fonts.body,
    fontSize: 16,
    color: colors.ink,
    ...shadow,
  },
  send: {
    backgroundColor: colors.teal,
    borderRadius: 999,
    paddingHorizontal: 18,
    minHeight: 48,
    justifyContent: "center",
  },
  sendDisabled: { opacity: 0.45 },
  sendText: { fontFamily: fonts.bold, color: "#fff", fontSize: 15 },
});
