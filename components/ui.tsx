import { fonts, radius } from "@/lib/theme";
import { useTheme, useThemedStyles } from "@/providers/ThemeProvider";
import { ReactNode } from "react";
import {
  Pressable,
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
  const styles = useThemedStyles(({ colors, shadow }) => ({
    card: {
      backgroundColor: colors.card,
      borderRadius: radius.card,
      padding: 20,
      gap: 12,
      ...shadow,
    },
  }));
  return <View style={[styles.card, style]}>{children}</View>;
}

export function Title({ children }: { children: ReactNode }) {
  const styles = useThemedStyles(({ colors }) => ({
    title: {
      fontFamily: fonts.displayBold,
      fontSize: 34,
      color: colors.ink,
      letterSpacing: -0.6,
    },
  }));
  return <Text style={styles.title}>{children}</Text>;
}

export function Subtitle({ children }: { children: ReactNode }) {
  const styles = useThemedStyles(({ colors }) => ({
    subtitle: {
      fontFamily: fonts.body,
      fontSize: 16,
      color: colors.muted,
      lineHeight: 22,
    },
  }));
  return <Text style={styles.subtitle}>{children}</Text>;
}

export function Pill({
  label,
  selected,
  onPress,
  tint,
  ink,
}: {
  label: string;
  selected?: boolean;
  onPress: () => void;
  tint?: string;
  ink?: string;
}) {
  const { colors } = useTheme();
  const styles = useThemedStyles(() => ({
    pill: {
      borderRadius: radius.pill,
      paddingHorizontal: 16,
      paddingVertical: 10,
    },
    pillText: { fontFamily: fonts.bold, fontSize: 15 },
  }));
  return (
    <Pressable
      onPress={onPress}
      style={[styles.pill, { backgroundColor: selected ? colors.ink : (tint ?? colors.tealSoft) }]}
    >
      <Text style={[styles.pillText, { color: selected ? colors.onInk : (ink ?? colors.tealDark) }]}>
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
  const styles = useThemedStyles(({ colors }) => ({
    primary: {
      backgroundColor: colors.teal,
      borderRadius: radius.pill,
      minHeight: 56,
      alignItems: "center",
      justifyContent: "center",
      paddingHorizontal: 22,
    },
    primaryText: { fontFamily: fonts.bold, fontSize: 17, color: colors.onAccent },
  }));
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

export function PlusMark({ color, size = 14 }: { color: string; size?: number }) {
  const thickness = 2;
  const offset = (size - thickness) / 2;
  const arm = {
    position: "absolute" as const,
    backgroundColor: color,
    borderRadius: 1,
  };
  return (
    <View style={{ width: size, height: size }}>
      <View style={[arm, { left: 0, top: offset, width: size, height: thickness }]} />
      <View style={[arm, { top: 0, left: offset, width: thickness, height: size }]} />
    </View>
  );
}

export function IconButton({
  children,
  onPress,
  style,
  ...rest
}: PressableProps & { children: ReactNode }) {
  const styles = useThemedStyles(({ colors, shadow }) => ({
    iconBtn: {
      width: 44,
      height: 44,
      borderRadius: 22,
      backgroundColor: colors.card,
      alignItems: "center",
      justifyContent: "center",
      ...shadow,
    },
  }));
  return (
    <Pressable
      onPress={onPress}
      style={(state) => [
        styles.iconBtn,
        typeof style === "function" ? style(state) : style,
      ]}
      {...rest}
    >
      {children}
    </Pressable>
  );
}

export function Field({
  label,
  ...props
}: TextInputProps & { label: string }) {
  const { colors } = useTheme();
  const styles = useThemedStyles(({ colors, shadow }) => ({
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
  }));
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
