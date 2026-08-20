import { useAuth } from "@clerk/expo";
import { Redirect, Stack } from "expo-router";
import { colors } from "@/lib/theme";
import { LoadingScreen } from "@/providers/AppProviders";

export default function AppGroupLayout() {
  const { isLoaded, isSignedIn } = useAuth();
  if (!isLoaded) return <LoadingScreen />;
  if (!isSignedIn) return <Redirect href="/(auth)/sign-in" />;

  return (
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
  );
}
