import { colors } from "@/lib/theme";
import { ReactNode } from "react";
import { ScrollView, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { IconButton } from "@/components/ui";

export function Screen({
  children,
  scroll = true,
  stickyHeader,
  onBack,
  headerRight,
}: {
  children: ReactNode;
  scroll?: boolean;
  /** Full custom sticky bar (overrides onBack / headerRight). */
  stickyHeader?: ReactNode;
  /** Sticky back chevron — same position on every screen. */
  onBack?: () => void;
  /** Optional right-side control next to back (e.g. Edit). */
  headerRight?: ReactNode;
}) {
  const header =
    stickyHeader ??
    (onBack != null ? (
      <View style={[styles.topBar, headerRight ? styles.topBarSpread : null]}>
        <IconButton onPress={onBack}>
          <Text style={styles.chev}>‹</Text>
        </IconButton>
        {headerRight}
      </View>
    ) : null);

  const body = scroll ? (
    <ScrollView
      style={styles.flex}
      contentContainerStyle={[styles.pad, header ? styles.padWithSticky : null]}
      keyboardShouldPersistTaps="handled"
    >
      {children}
    </ScrollView>
  ) : (
    <View
      style={[
        styles.pad,
        styles.padFill,
        header ? styles.padWithSticky : null,
      ]}
    >
      {children}
    </View>
  );

  return (
    <SafeAreaView style={styles.safe} edges={["top", "left", "right"]}>
      <View style={styles.flex}>
        {body}
        {header ? (
          <View style={styles.sticky} pointerEvents="box-none">
            {header}
          </View>
        ) : null}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.bg },
  flex: { flex: 1 },
  sticky: {
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    zIndex: 20,
    paddingHorizontal: 20,
    paddingTop: 4,
    paddingBottom: 8,
  },
  topBar: {
    flexDirection: "row",
    alignItems: "center",
  },
  topBarSpread: {
    justifyContent: "space-between",
  },
  chev: {
    fontSize: 22,
    lineHeight: 22,
    color: colors.ink,
    textAlign: "center",
  },
  pad: { padding: 20, paddingBottom: 40, gap: 16, flexGrow: 1 },
  padWithSticky: { paddingTop: 60 },
  padFill: { flex: 1 },
});
