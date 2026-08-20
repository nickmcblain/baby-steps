import { Stack } from "expo-router";
import { colors } from "@/lib/theme";

export default function AuthLayout() {
  // Do not redirect on isSignedIn here — AuthView must stay mounted through
  // native→JS session sync / pending tasks. sign-in.tsx navigates when ready.
  return (
    <Stack
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: colors.bg },
      }}
    />
  );
}
