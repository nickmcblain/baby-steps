import { Tabs } from "expo-router";
import { useState } from "react";
import { StyleSheet, View } from "react-native";
import { AddLogSheet } from "@/components/AddLogSheet";
import { CalTabBar } from "@/components/CalTabBar";
import { DockScrollProvider } from "@/components/DockScroll";
import { useActiveBabyId } from "@/lib/activeBaby";
import { colors } from "@/lib/theme";

export default function TabsLayout() {
  const { activeBabyId } = useActiveBabyId();
  const [logOpen, setLogOpen] = useState(false);

  return (
    <DockScrollProvider>
      <View style={styles.root}>
        <Tabs
          tabBar={(props) => (
            <CalTabBar {...props} onAdd={() => setLogOpen(true)} />
          )}
          screenOptions={{
            headerShown: false,
            animation: "none",
            tabBarStyle: {
              position: "absolute",
              backgroundColor: "transparent",
              borderTopWidth: 0,
              elevation: 0,
              shadowOpacity: 0,
            },
          }}
        >
          <Tabs.Screen name="index" options={{ title: "Home" }} />
          <Tabs.Screen name="timeline" options={{ title: "Timeline" }} />
          <Tabs.Screen name="kids" options={{ title: "Kids" }} />
          <Tabs.Screen name="profile" options={{ title: "Profile" }} />
        </Tabs>
        <AddLogSheet
          visible={logOpen}
          babyId={activeBabyId}
          onClose={() => setLogOpen(false)}
        />
      </View>
    </DockScrollProvider>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
});
