import { useEffect, useRef } from "react";
import {
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
  type TextInput as TextInputType,
} from "react-native";
import { colors, fonts, radius } from "@/lib/theme";

export const INVITE_CODE_LEN = 6;
const ALLOWED = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";

export function sanitizeInviteCode(raw: string) {
  let out = "";
  for (const ch of raw.toUpperCase()) {
    if (!ALLOWED.includes(ch)) continue;
    out += ch;
    if (out.length === INVITE_CODE_LEN) break;
  }
  return out;
}

export function InviteCodeBoxes({
  value,
  onChange,
  autoFocus,
  editable = true,
}: {
  value: string;
  onChange: (code: string) => void;
  autoFocus?: boolean;
  editable?: boolean;
}) {
  const inputRef = useRef<TextInputType>(null);

  useEffect(() => {
    if (!autoFocus) return;
    const t = setTimeout(() => inputRef.current?.focus(), 360);
    return () => clearTimeout(t);
  }, [autoFocus]);

  return (
    <Pressable
      onPress={() => inputRef.current?.focus()}
      style={styles.row}
      accessibilityLabel="Invite code"
    >
      {Array.from({ length: INVITE_CODE_LEN }, (_, i) => {
        const active = value.length === i;
        return (
          <View key={i} style={[styles.box, active && editable && styles.boxOn]}>
            <Text style={styles.char}>{value[i] ?? ""}</Text>
          </View>
        );
      })}
      <TextInput
        ref={inputRef}
        value={value}
        onChangeText={(text) => onChange(sanitizeInviteCode(text))}
        maxLength={INVITE_CODE_LEN}
        autoCapitalize="characters"
        autoCorrect={false}
        autoComplete="off"
        spellCheck={false}
        caretHidden
        editable={editable}
        keyboardType="ascii-capable"
        textContentType="none"
        importantForAutofill="no"
        accessibilityLabel="Invite code"
        style={styles.hidden}
      />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: "row",
    justifyContent: "space-between",
    gap: 8,
  },
  box: {
    flex: 1,
    aspectRatio: 0.85,
    maxWidth: 48,
    borderRadius: radius.tile - 8,
    backgroundColor: colors.card,
    borderWidth: 2,
    borderColor: colors.line,
    alignItems: "center",
    justifyContent: "center",
  },
  boxOn: {
    borderColor: colors.teal,
  },
  char: {
    fontFamily: fonts.displayBold,
    fontSize: 22,
    color: colors.ink,
  },
  hidden: {
    ...StyleSheet.absoluteFillObject,
    opacity: 0,
  },
});
