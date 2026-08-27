import { useAuth } from "@clerk/expo";
import { UserButton } from "@clerk/expo/native";
import { useQuery } from "convex/react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { Screen } from "@/components/Screen";
import { Title } from "@/components/ui";
import { api } from "@/convex/_generated/api";
import { colors, fonts } from "@/lib/theme";
import { useMarkInteractive } from "@/lib/useMarkInteractive";

export default function ProfileTab() {
  const user = useQuery(api.users.current);
  const { signOut } = useAuth();
  useMarkInteractive(user !== undefined);

  return (
    <Screen clearDock>
      <View style={styles.header}>
        <Title>Profile</Title>
        <UserButton />
      </View>

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
  signOut: {
    alignItems: "center",
    paddingVertical: 16,
  },
  signOutText: { fontFamily: fonts.bold, fontSize: 16, color: colors.danger },
});
