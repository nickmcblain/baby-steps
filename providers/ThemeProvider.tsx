import AsyncStorage from "@react-native-async-storage/async-storage";
import * as SystemUI from "expo-system-ui";
import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { StyleSheet, useColorScheme } from "react-native";
import {
  darkColors,
  lightColors,
  shadowFor,
  type NamedStyles,
  type ThemePreference,
  type ThemeScheme,
  type ThemeValue,
} from "@/lib/theme";

const STORAGE_KEY = "theme-preference";
const ThemeContext = createContext<ThemeValue | null>(null);

function readPreference(raw: string | null): ThemePreference {
  if (raw === "light" || raw === "dark" || raw === "system") return raw;
  return "system";
}

export function ThemeProvider({ children }: { children: ReactNode }) {
  const system = useColorScheme();
  const [preference, setPreferenceState] = useState<ThemePreference>("system");

  useEffect(() => {
    void AsyncStorage.getItem(STORAGE_KEY).then((raw) => {
      setPreferenceState(readPreference(raw));
    });
  }, []);

  function setPreference(next: ThemePreference) {
    setPreferenceState(next);
    void AsyncStorage.setItem(STORAGE_KEY, next);
  }

  const scheme: ThemeScheme =
    preference === "system" ? (system === "dark" ? "dark" : "light") : preference;
  const colors = scheme === "dark" ? darkColors : lightColors;
  const shadow = useMemo(() => shadowFor(scheme), [scheme]);

  useEffect(() => {
    void SystemUI.setBackgroundColorAsync(colors.bg);
  }, [colors.bg]);

  const value = useMemo<ThemeValue>(
    () => ({ preference, setPreference, scheme, colors, shadow }),
    [preference, scheme, colors, shadow],
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

const fallbackTheme: ThemeValue = {
  preference: "light",
  setPreference: () => undefined,
  scheme: "light",
  colors: lightColors,
  shadow: shadowFor("light"),
};

export function useTheme(): ThemeValue {
  return useContext(ThemeContext) ?? fallbackTheme;
}

export function useThemedStyles<T extends NamedStyles<T>>(
  factory: (theme: { colors: ThemeValue["colors"]; shadow: ThemeValue["shadow"] }) => T,
): T {
  const theme = useTheme();
  return useMemo(() => StyleSheet.create(factory(theme)), [theme]);
}
