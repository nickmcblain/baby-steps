import { AuthView } from "@clerk/expo/native";
import { useAuth } from "@clerk/expo";
import { useRouter } from "expo-router";
import { useEffect, useState } from "react";
import { Platform, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useMarkInteractive } from "@/lib/useMarkInteractive";
import { colors, fonts } from "@/lib/theme";
import { LoadingScreen } from "@/providers/AppProviders";

export default function SignIn() {
  // Pending native→JS session sync must not look signed-out or AuthView remounts.
  const { isLoaded, isSignedIn } = useAuth({ treatPendingAsSignedOut: false });
  const router = useRouter();
  const [showAuthView, setShowAuthView] = useState(false);
  const ready = isLoaded && !isSignedIn && showAuthView;
  useMarkInteractive(ready);

  useEffect(() => {
    if (!isSignedIn) return;
    router.replace("/(app)");
  }, [isSignedIn, router]);

  // Mount AuthView once after Clerk is ready. Clearing only the timer (not
  // showAuthView) avoids React Strict Mode remount races — clerk-ios allows
  // only one AuthView registration per instance.
  useEffect(() => {
    if (!isLoaded || isSignedIn) return;
    const id = setTimeout(() => setShowAuthView(true), 0);
    return () => clearTimeout(id);
  }, [isLoaded, isSignedIn]);

  if (!isLoaded || isSignedIn || !showAuthView) {
    return <LoadingScreen />;
  }

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.hero}>
        <View style={styles.blob} />
        <Text style={styles.kicker}>Baby Steps</Text>
        <Text style={styles.title}>Keep the little hours in one place.</Text>
      </View>
      <View style={styles.sheet}>
        {Platform.OS === "web" ? (
          <Text style={styles.webNote}>
            Native Clerk AuthView needs an iOS or Android build. Open this
            project on a device.
          </Text>
        ) : (
          <AuthView isDismissible={false} />
        )}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.bg },
  hero: { paddingHorizontal: 24, paddingTop: 28, paddingBottom: 12, gap: 8 },
  blob: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: colors.teal,
    marginBottom: 8,
  },
  kicker: {
    fontFamily: fonts.bold,
    color: colors.tealDark,
    fontSize: 14,
    letterSpacing: 0.6,
    textTransform: "uppercase",
  },
  title: {
    fontFamily: fonts.displayBold,
    fontSize: 32,
    color: colors.ink,
    lineHeight: 38,
  },
  sheet: {
    flex: 1,
    backgroundColor: colors.card,
    borderTopLeftRadius: 36,
    borderTopRightRadius: 36,
    overflow: "hidden",
    marginTop: 8,
  },
  webNote: {
    padding: 24,
    fontFamily: fonts.body,
    color: colors.muted,
  },
});
