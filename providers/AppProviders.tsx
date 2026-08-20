import { useAuth } from "@clerk/expo";
import { ConvexReactClient } from "convex/react";
import { ConvexProviderWithClerk } from "convex/react-clerk";
import { ReactNode } from "react";
import { ActivityIndicator, Text, View } from "react-native";
import { StoreUser } from "@/components/StoreUser";
import { colors, fonts } from "@/lib/theme";

const convexUrl = process.env.EXPO_PUBLIC_CONVEX_URL ?? "";
const convex = convexUrl ? new ConvexReactClient(convexUrl) : null;

export function AppProviders({ children }: { children: ReactNode }) {
  if (!convex) {
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
        <Text style={{ fontFamily: fonts.displayBold, fontSize: 28 }}>
          Almost there
        </Text>
        <Text style={{ fontFamily: fonts.body, color: colors.muted, fontSize: 16 }}>
          Add EXPO_PUBLIC_CONVEX_URL to .env.local. In Clerk, create a JWT
          template named convex. In Convex, set CLERK_JWT_ISSUER_DOMAIN.
        </Text>
      </View>
    );
  }

  return (
    <ConvexProviderWithClerk client={convex} useAuth={useAuth}>
      <StoreUser />
      {children}
    </ConvexProviderWithClerk>
  );
}

export function LoadingScreen() {
  return (
    <View
      style={{
        flex: 1,
        backgroundColor: colors.bg,
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <ActivityIndicator color={colors.teal} />
    </View>
  );
}
