import "@/widgets/BabyTimerActivity";
import { ClerkProvider } from "@clerk/expo";
import { tokenCache } from "@clerk/expo/token-cache";
import "react-native-gesture-handler";
import { Fredoka_600SemiBold, Fredoka_700Bold } from "@expo-google-fonts/fredoka";
import {
  Nunito_400Regular,
  Nunito_600SemiBold,
  Nunito_700Bold,
  useFonts,
} from "@expo-google-fonts/nunito";
import { Stack } from "expo-router";
import { Observe, ObserveRoot } from "expo-observe";
import * as SplashScreen from "expo-splash-screen";
import { StatusBar } from "expo-status-bar";
import { useEffect } from "react";
import { Text, View } from "react-native";
import { colors, fonts } from "@/lib/theme";
import { AppProviders, LoadingScreen } from "@/providers/AppProviders";

Observe.configure({
  integrations: { "expo-router": true },
});

const publishableKey = process.env.EXPO_PUBLIC_CLERK_PUBLISHABLE_KEY ?? "";

SplashScreen.preventAutoHideAsync().catch(() => undefined);

function MissingClerkKeyScreen() {
  return (
    <View
      style={{
        flex: 1,
        backgroundColor: colors.bg,
        justifyContent: "center",
        padding: 28,
        gap: 12,
      }}
    >
      <Text style={{ fontFamily: fonts.displayBold, fontSize: 28, color: colors.ink }}>
        Missing Clerk key
      </Text>
      <Text style={{ fontFamily: fonts.body, color: colors.muted, fontSize: 16, lineHeight: 24 }}>
        EXPO_PUBLIC_CLERK_PUBLISHABLE_KEY was not set for this build. Add it to the EAS
        production environment and create a new build.
      </Text>
    </View>
  );
}

function RootLayout() {
  const [loaded] = useFonts({
    Fredoka_600SemiBold,
    Fredoka_700Bold,
    Nunito_400Regular,
    Nunito_600SemiBold,
    Nunito_700Bold,
  });

  useEffect(() => {
    if (loaded) {
      SplashScreen.hideAsync().catch(() => undefined);
    }
  }, [loaded]);

  if (!loaded) {
    return <LoadingScreen />;
  }

  if (!publishableKey) {
    return <MissingClerkKeyScreen />;
  }

  return (
    <ClerkProvider publishableKey={publishableKey} tokenCache={tokenCache}>
      <AppProviders>
        <StatusBar style="dark" />
        <Stack
          screenOptions={{
            headerShown: false,
            contentStyle: { backgroundColor: colors.bg },
            animation: "slide_from_right",
            animationTypeForReplace: "pop",
            gestureEnabled: true,
            fullScreenGestureEnabled: true,
          }}
        />
      </AppProviders>
    </ClerkProvider>
  );
}

export default ObserveRoot.wrap(RootLayout);
