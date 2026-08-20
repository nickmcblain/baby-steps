import { colors, fonts, radius, shadow } from "@/lib/theme";
import { ReactNode } from "react";
import {
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
  type PressableProps,
  type TextInputProps,
} from "react-native";

export function Card({
  children,
  style,
}: {
  children: ReactNode;
  style?: object;
}) {
  return <View style={[styles.card, style]}>{children}</View>;
}

export function Title({ children }: { children: ReactNode }) {
  return <Text style={styles.title}>{children}</Text>;
}

export function Subtitle({ children }: { children: ReactNode }) {
  return <Text style={styles.subtitle}>{children}</Text>;
}

export function Pill({
  label,
  selected,
  onPress,
  tint = colors.tealSoft,
  ink = colors.tealDark,
}: {
  label: string;
  selected?: boolean;
  onPress: () => void;
  tint?: string;
  ink?: string;
}) {
  return (
    <Pressable
      onPress={onPress}
      style={[styles.pill, { backgroundColor: selected ? colors.ink : tint }]}
    >
      <Text style={[styles.pillText, { color: selected ? "#fff" : ink }]}>
        {label}
      </Text>
    </Pressable>
  );
}

export function PrimaryButton({
  label,
  onPress,
  disabled,
}: {
  label: string;
  onPress: () => void;
  disabled?: boolean;
}) {
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      style={[styles.primary, disabled && { opacity: 0.45 }]}
    >
      <Text style={styles.primaryText}>{label}</Text>
    </Pressable>
  );
}

export function IconButton({
  children,
  onPress,
}: PressableProps & { children: ReactNode }) {
  return (
    <Pressable onPress={onPress} style={styles.iconBtn}>
      {children}
    </Pressable>
  );
}

export function Field({
  label,
  ...props
}: TextInputProps & { label: string }) {
  return (
    <View style={{ gap: 8 }}>
      <Text style={styles.fieldLabel}>{label}</Text>
      <TextInput
        placeholderTextColor={colors.muted}
        style={styles.input}
        {...props}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.card,
    borderRadius: radius.card,
    padding: 20,
    gap: 12,
    ...shadow,
  },
  title: {
    fontFamily: fonts.displayBold,
    fontSize: 34,
    color: colors.ink,
    letterSpacing: -0.6,
  },
  subtitle: {
    fontFamily: fonts.body,
    fontSize: 16,
    color: colors.muted,
    lineHeight: 22,
  },
  pill: {
    borderRadius: radius.pill,
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  pillText: { fontFamily: fonts.bold, fontSize: 15 },
  primary: {
    backgroundColor: colors.teal,
    borderRadius: radius.pill,
    minHeight: 56,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 22,
  },
  primaryText: { fontFamily: fonts.bold, fontSize: 17, color: "#fff" },
  iconBtn: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: colors.card,
    alignItems: "center",
    justifyContent: "center",
    ...shadow,
  },
  fieldLabel: {
    fontFamily: fonts.medium,
    color: colors.muted,
    fontSize: 13,
    marginLeft: 8,
  },
  input: {
    backgroundColor: colors.card,
    borderRadius: 22,
    paddingHorizontal: 18,
    paddingVertical: 14,
    fontFamily: fonts.medium,
    fontSize: 16,
    color: colors.ink,
    ...shadow,
  },
});
