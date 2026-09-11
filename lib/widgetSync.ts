import Constants, { ExecutionEnvironment } from "expo-constants";
import { Platform } from "react-native";
import BabyGlanceWidget, { type BabyGlanceProps } from "@/widgets/BabyGlanceWidget";

let lastJson: string | null = null;

function canUseWidgets(): boolean {
  if (Platform.OS !== "ios") return false;
  // Expo Go has no widget extension.
  return Constants.executionEnvironment !== ExecutionEnvironment.StoreClient;
}

/** Push the home-screen glance widget. Skips identical payloads. */
export function syncGlanceWidget(props: BabyGlanceProps): void {
  if (!canUseWidgets()) return;
  const json = JSON.stringify(props);
  if (json === lastJson) return;
  lastJson = json;
  try {
    BabyGlanceWidget.updateSnapshot(props);
  } catch {
    // Widget extension missing (e.g. dev build predating the widget) — ignore.
  }
}
