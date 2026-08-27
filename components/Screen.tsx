import { colors, tabDockInset } from "@/lib/theme";
import { ReactNode } from "react";
import { ScrollView, StyleSheet, Text, View } from "react-native";
import { SafeAreaView, useSafeAreaInsets } from "react-native-safe-area-context";
import { IconButton } from "@/components/ui";

export function Screen({
  children,
  scroll = true,
  stickyHeader,
  onBack,
  headerRight,
  /** When true, content can run under floating controls (no reserved top bar). */
  overlayChrome = false,
  /** Extra bottom pad so content clears the floating tab dock. */
  clearDock = false,
}: {
  children: ReactNode;
  scroll?: boolean;
  /** Full custom sticky content (overrides onBack / headerRight). */
  stickyHeader?: ReactNode;
  /** Floating back chevron — same position on every screen. */
  onBack?: () => void;
  /** Floating right-side control(s). */
  headerRight?: ReactNode;
  overlayChrome?: boolean;
  clearDock?: boolean;
}) {
  const insets = useSafeAreaInsets();
  const hasChrome = stickyHeader != null || onBack != null || headerRight != null;
  const reserveChrome = hasChrome && !overlayChrome;
  const dockPad = clearDock
    ? { paddingBottom: tabDockInset + Math.max(insets.bottom, 10) }
    : null;

  const body = scroll ? (
    <ScrollView
      style={styles.flex}
      contentContainerStyle={[
        styles.pad,
        reserveChrome ? styles.padWithSticky : null,
        dockPad,
      ]}
      keyboardShouldPersistTaps="handled"
      showsVerticalScrollIndicator={false}
      showsHorizontalScrollIndicator={false}
    >
      {children}
    </ScrollView>
  ) : (
    <View
      style={[
        styles.pad,
        styles.padFill,
        reserveChrome ? styles.padWithSticky : null,
        overlayChrome ? styles.padOverlay : null,
        dockPad,
      ]}
    >
      {children}
    </View>
  );

  return (
    <SafeAreaView style={styles.safe} edges={["top", "left", "right"]}>
      <View style={styles.flex}>
        {body}
        {hasChrome ? (
          <View style={styles.sticky} pointerEvents="box-none">
            {stickyHeader ?? (
              <>
                {onBack != null ? (
                  <View style={styles.floatLeft}>
                    <IconButton onPress={onBack} accessibilityLabel="Back">
                      <Text style={styles.chev}>‹</Text>
                    </IconButton>
                  </View>
                ) : null}
                {headerRight != null ? (
                  <View style={styles.floatRight}>{headerRight}</View>
                ) : null}
              </>
            )}
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
    zIndex: 30,
    elevation: 30,
    paddingTop: 4,
    minHeight: 52,
  },
  floatLeft: {
    position: "absolute",
    left: 16,
    top: 4,
    zIndex: 31,
  },
  floatRight: {
    position: "absolute",
    right: 16,
    top: 4,
    zIndex: 31,
    flexDirection: "row",
    alignItems: "center",
  },
  chev: {
    fontSize: 22,
    lineHeight: 22,
    color: colors.ink,
    textAlign: "center",
  },
  pad: { padding: 20, paddingBottom: 40, gap: 16, flexGrow: 1 },
  padWithSticky: { paddingTop: 60 },
  /** Content under floating chips — only horizontal/bottom pad from Screen. */
  padOverlay: { paddingTop: 8 },
  padFill: { flex: 1 },
});
