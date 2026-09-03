import { useAction, useMutation, useQuery } from "convex/react";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  ActivityIndicator,
  Alert,
  Keyboard,
  NativeScrollEvent,
  NativeSyntheticEvent,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import Markdown from "react-native-markdown-display";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Screen } from "@/components/Screen";
import { IconButton } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import type { Id } from "@/convex/_generated/dataModel";
import { useMarkInteractive } from "@/lib/useMarkInteractive";
import { colors, fonts, shadow } from "@/lib/theme";

const EMERGENCY =
  /\b(not breathing|unresponsive|blue lips|turning blue|seizure|choking badly)\b/i;

/** Near-bottom: show composer. Hysteresis stops show/hide layout thrash. */
const BOTTOM_SHOW = 64;
const BOTTOM_HIDE = 140;

function ListGlyph() {
  return (
    <View style={styles.listGlyph}>
      <View style={styles.listLine} />
      <View style={styles.listLine} />
      <View style={styles.listLine} />
    </View>
  );
}

function NewChatGlyph() {
  return (
    <View style={styles.plusGlyph}>
      <View style={styles.plusH} />
      <View style={styles.plusV} />
    </View>
  );
}

const mdStyles = StyleSheet.create({
  body: {
    fontFamily: fonts.body,
    fontSize: 15,
    color: colors.ink,
    lineHeight: 22,
    flexShrink: 1,
  },
  paragraph: {
    marginTop: 0,
    marginBottom: 8,
    flexShrink: 1,
  },
  heading1: {
    fontFamily: fonts.bold,
    fontSize: 18,
    color: colors.ink,
    marginBottom: 6,
  },
  heading2: {
    fontFamily: fonts.bold,
    fontSize: 16,
    color: colors.ink,
    marginBottom: 6,
  },
  heading3: {
    fontFamily: fonts.bold,
    fontSize: 15,
    color: colors.ink,
    marginBottom: 4,
  },
  strong: { fontFamily: fonts.bold },
  em: { fontStyle: "italic" },
  bullet_list: { marginBottom: 8 },
  ordered_list: { marginBottom: 8 },
  list_item: {
    fontFamily: fonts.body,
    fontSize: 15,
    color: colors.ink,
    lineHeight: 22,
    marginBottom: 4,
  },
  bullet_list_icon: {
    color: colors.ink,
    marginLeft: 0,
    marginRight: 8,
  },
  code_inline: {
    fontFamily: Platform.select({ ios: "Menlo", default: "monospace" }),
    fontSize: 13,
    backgroundColor: colors.tealSoft,
    color: colors.ink,
    paddingHorizontal: 4,
    borderRadius: 4,
  },
  fence: {
    fontFamily: Platform.select({ ios: "Menlo", default: "monospace" }),
    fontSize: 13,
    backgroundColor: colors.tealSoft,
    color: colors.ink,
    padding: 10,
    borderRadius: 10,
    marginBottom: 8,
  },
  link: {
    color: colors.tealDark,
    textDecorationLine: "underline",
  },
  blockquote: {
    borderLeftWidth: 3,
    borderLeftColor: colors.teal,
    paddingLeft: 10,
    marginBottom: 8,
    opacity: 0.9,
  },
});

export default function AskScreen() {
  const { id, thread: threadParam, q: questionParam } = useLocalSearchParams<{
    id: string;
    thread?: string;
    q?: string;
  }>();
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const babyId = id as Id<"babies">;
  const ensureThread = useMutation(api.chat.ensureThread);
  const createThread = useMutation(api.chat.createThread);
  const ask = useAction(api.chatAgent.ask);
  const [threadId, setThreadId] = useState<Id<"chatThreads"> | null>(
    threadParam ? (threadParam as Id<"chatThreads">) : null,
  );
  const messages = useQuery(
    api.chat.listMessages,
    threadId ? { threadId } : "skip",
  );
  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const [pendingUser, setPendingUser] = useState<string | null>(null);
  const [atBottom, setAtBottom] = useState(true);
  const [composerFocused, setComposerFocused] = useState(false);
  const [keyboardHeight, setKeyboardHeight] = useState(0);
  const scrollRef = useRef<ScrollView>(null);
  const sentQuestion = useRef<string | null>(null);
  useMarkInteractive(threadId != null);

  const showComposer =
    atBottom || composerFocused || draft.trim().length > 0 || sending;

  const showPendingUser = useMemo(() => {
    if (!pendingUser) return false;
    const alreadyIn = (messages ?? []).some(
      (m) => m.role === "user" && m.content === pendingUser,
    );
    return !alreadyIn;
  }, [pendingUser, messages]);

  function updateAtBottom(e: NativeSyntheticEvent<NativeScrollEvent>) {
    const { layoutMeasurement, contentOffset, contentSize } = e.nativeEvent;
    const distanceFromBottom =
      contentSize.height - (contentOffset.y + layoutMeasurement.height);
    setAtBottom((prev) => {
      if (prev) {
        return distanceFromBottom <= BOTTOM_HIDE;
      }
      return distanceFromBottom <= BOTTOM_SHOW;
    });
  }

  useEffect(() => {
    if (threadParam) {
      setThreadId(threadParam as Id<"chatThreads">);
      return;
    }
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
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [babyId, threadParam]);

  useEffect(() => {
    if (!atBottom) return;
    requestAnimationFrame(() => {
      scrollRef.current?.scrollToEnd({ animated: true });
    });
  }, [messages?.length, sending, showPendingUser, atBottom]);

  useEffect(() => {
    const show = Keyboard.addListener(
      Platform.OS === "ios" ? "keyboardWillShow" : "keyboardDidShow",
      (e) => setKeyboardHeight(e.endCoordinates.height),
    );
    const hide = Keyboard.addListener(
      Platform.OS === "ios" ? "keyboardWillHide" : "keyboardDidHide",
      () => setKeyboardHeight(0),
    );
    return () => {
      show.remove();
      hide.remove();
    };
  }, []);

  async function send(textArg?: string) {
    const text = (textArg ?? draft).trim();
    if (!text || !threadId || sending) return;
    if (EMERGENCY.test(text)) {
      Alert.alert(
        "Seek urgent help",
        "If your baby is not breathing normally, is unresponsive, blue/grey, or having a seizure, call 999 now.",
      );
    }
    setDraft("");
    setPendingUser(text);
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
      setPendingUser(null);
    }
  }

  useEffect(() => {
    const question =
      typeof questionParam === "string" ? questionParam.trim() : "";
    if (!question || !threadId || sending) return;
    if (sentQuestion.current === question) return;
    sentQuestion.current = question;
    void send(question);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [questionParam, threadId]);

  async function startNewChat() {
    try {
      const tid = await createThread({ babyId });
      setThreadId(tid);
      setDraft("");
      setPendingUser(null);
      router.setParams({ thread: tid });
    } catch (error) {
      Alert.alert(
        "Could not start chat",
        error instanceof Error ? error.message : "Try again",
      );
    }
  }

  return (
    <Screen
      scroll={false}
      overlayChrome
      flushBottom
      onBack={() => router.back()}
      headerRight={
        <View style={styles.headerActions}>
          <IconButton
            onPress={() => void startNewChat()}
            accessibilityLabel="New chat"
          >
            <NewChatGlyph />
          </IconButton>
          <IconButton
            onPress={() => router.push(`/baby/${id}/ask/history`)}
            accessibilityLabel="Past chats"
            style={styles.headerActionGap}
          >
            <ListGlyph />
          </IconButton>
        </View>
      }
    >
      <View style={styles.flex}>
        <ScrollView
          ref={scrollRef}
          style={styles.flex}
          contentContainerStyle={[
            styles.messages,
            styles.messagesUnderChrome,
          ]}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
          showsHorizontalScrollIndicator={false}
          onScroll={updateAtBottom}
          scrollEventThrottle={16}
          onContentSizeChange={() => {
            if (atBottom) {
              scrollRef.current?.scrollToEnd({ animated: false });
            }
          }}
        >
          {(messages ?? []).map((m) => (
            <View
              key={m._id}
              style={[
                styles.bubble,
                m.role === "user" ? styles.userBubble : styles.assistantBubble,
              ]}
            >
              {m.role === "assistant" ? (
                <Markdown style={mdStyles}>{m.content}</Markdown>
              ) : (
                <Text style={[styles.bubbleText, styles.userBubbleText]}>
                  {m.content}
                </Text>
              )}
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
          {showPendingUser ? (
            <View style={[styles.bubble, styles.userBubble]}>
              <Text style={[styles.bubbleText, styles.userBubbleText]}>
                {pendingUser}
              </Text>
            </View>
          ) : null}
          {sending ? (
            <View style={styles.pending}>
              <ActivityIndicator color={colors.teal} />
              <Text style={styles.pendingText}>Thinking…</Text>
            </View>
          ) : null}
        </ScrollView>

        <View
          style={[
            styles.composerDock,
            {
              paddingBottom:
                keyboardHeight > 0
                  ? keyboardHeight
                  : Math.max(insets.bottom, 12),
            },
            !showComposer && styles.composerDockHidden,
          ]}
          pointerEvents={showComposer ? "auto" : "none"}
        >
          <Text style={styles.disclaimer}>
            Baby Steps is not a medical or healthcare service. Guidance only —
            not diagnosis, clinical advice, or triage. Emergencies: call 999.
            Urgent advice: NHS 111 or your midwife.
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
              onFocus={() => setComposerFocused(true)}
              onBlur={() => setComposerFocused(false)}
            />
            <Pressable
              onPress={() => void send()}
              disabled={sending || draft.trim().length === 0}
              style={[
                styles.send,
                (sending || draft.trim().length === 0) && styles.sendDisabled,
              ]}
              accessibilityLabel="Send"
            >
              <Text style={styles.sendArrow}>↑</Text>
            </Pressable>
          </View>
        </View>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  headerActions: {
    flexDirection: "row",
    alignItems: "center",
  },
  headerActionGap: {
    marginLeft: 8,
  },
  listGlyph: { gap: 3.5, width: 18, justifyContent: "center" },
  listLine: {
    height: 2,
    borderRadius: 1,
    backgroundColor: colors.ink,
  },
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
  messages: { paddingVertical: 12, gap: 10, flexGrow: 1 },
  messagesUnderChrome: { paddingTop: 52 },
  composerDock: {
    backgroundColor: colors.bg,
    paddingTop: 8,
    paddingBottom: 8,
  },
  composerDockHidden: {
    opacity: 0,
  },
  bubble: {
    borderRadius: 20,
    paddingHorizontal: 14,
    paddingVertical: 12,
    maxWidth: "92%",
    gap: 6,
    overflow: "hidden",
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
    width: 48,
    height: 48,
    alignItems: "center",
    justifyContent: "center",
  },
  sendDisabled: { opacity: 0.45 },
  sendArrow: {
    fontFamily: fonts.bold,
    color: "#fff",
    fontSize: 22,
    lineHeight: 24,
    fontWeight: "700",
  },
});
