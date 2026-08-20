import { useAuth } from "@clerk/expo";
import { Redirect } from "expo-router";
import { LoadingScreen } from "@/providers/AppProviders";

export default function Index() {
  const { isLoaded, isSignedIn } = useAuth({ treatPendingAsSignedOut: false });
  if (!isLoaded) return <LoadingScreen />;
  return <Redirect href={isSignedIn ? "/(app)" : "/(auth)/sign-in"} />;
}
