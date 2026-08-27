import { useAuth, useUser } from "@clerk/expo";
import { UserButton } from "@clerk/expo/native";
import { useQuery } from "convex/react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { Screen } from "@/components/Screen";
import { Card, Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import { colors, fonts } from "@/lib/theme";
import { useMarkInteractive } from "@/lib/useMarkInteractive";

export default function ProfileTab() {
  const user = useQuery(api.users.current);
  const { user: clerkUser } = useUser();
  const { signOut } = useAuth();
  useMarkInteractive(user !== undefined);

  const email =
    user?.email ?? clerkUser?.primaryEmailAddress?.emailAddress ?? "—";

  return (
    <Screen clearDock>
      <View style={styles.header}>
        <Title>Profile</Title>
        <UserButton />
      </View>

      <Card>
        <View style={styles.row}>
          <Text style={styles.label}>Email</Text>
          <Text style={styles.value}>{email}</Text>
        </View>
        <View style={styles.rule} />
        <View style={styles.row}>
          <Text style={styles.label}>Subscription</Text>
          <Text style={styles.value}>Not subscribed</Text>
        </View>
      </Card>

      <Pressable
        style={styles.signOut}
        onPress={() => void signOut()}
      >
        <Text style={styles.signOutText}>Sign out</Text>
      </Pressable>
    </Screen>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  row: { gap: 4 },
  label: { fontFamily: fonts.medium, fontSize: 13, color: colors.muted },
  value: { fontFamily: fonts.bold, fontSize: 17, color: colors.ink },
  rule: { height: 1, backgroundColor: colors.line },
  signOut: {
    alignItems: "center",
    paddingVertical: 16,
  },
  signOutText: { fontFamily: fonts.bold, fontSize: 16, color: colors.danger },
});
