import { StyleSheet, type ImageStyle, type TextStyle, type ViewStyle } from "react-native";

export const lightColors = {
  bg: "#F3F4F6",
  card: "#FFFFFF",
  ink: "#12141A",
  muted: "#8A9099",
  line: "#EEF0F3",
  teal: "#14C4B2",
  tealDark: "#0B9E90",
  tealSoft: "#E6FAF7",
  purple: "#6D5EF5",
  purpleSoft: "#EEEBFF",
  sky: "#4BA3E3",
  skySoft: "#E5F3FC",
  peach: "#FF8A65",
  peachSoft: "#FFE8DF",
  amber: "#F5C84C",
  amberSoft: "#FFF6D9",
  rose: "#E86B9A",
  roseSoft: "#FCE8F1",
  danger: "#E15B4C",
  onAccent: "#FFFFFF",
  onInk: "#FFFFFF",
};

export const darkColors = {
  bg: "#12141A",
  card: "#1C1E26",
  ink: "#F3F4F6",
  muted: "#9AA0A8",
  line: "#2A2D36",
  teal: "#14C4B2",
  tealDark: "#5EE0D2",
  tealSoft: "#163330",
  purple: "#8B80FF",
  purpleSoft: "#2A2648",
  sky: "#5BB4EE",
  skySoft: "#1A3040",
  peach: "#FF8A65",
  peachSoft: "#3D2A24",
  amber: "#F5C84C",
  amberSoft: "#3A3218",
  rose: "#E86B9A",
  roseSoft: "#3A2430",
  danger: "#F07A6C",
  onAccent: "#FFFFFF",
  onInk: "#12141A",
};

export type ThemeColors = typeof lightColors;
export type ThemeScheme = "light" | "dark";
export type ThemePreference = "system" | ThemeScheme;

export type ThemeShadow = {
  shadowColor: string;
  shadowOpacity: number;
  shadowRadius: number;
  shadowOffset: { width: number; height: number };
  elevation: number;
};

/** Default light tokens — prefer `useTheme()` in components. */
export const colors = lightColors;

export function shadowFor(scheme: ThemeScheme): ThemeShadow {
  return scheme === "dark"
    ? {
        shadowColor: "#000000",
        shadowOpacity: 0.4,
        shadowRadius: 18,
        shadowOffset: { width: 0, height: 8 },
        elevation: 4,
      }
    : {
        shadowColor: "#12141A",
        shadowOpacity: 0.07,
        shadowRadius: 18,
        shadowOffset: { width: 0, height: 8 },
        elevation: 4,
      };
}

/** Space so scroll content clears the floating tab dock. */
export const tabDockInset = 88;

export const radius = {
  card: 32,
  tile: 28,
  pill: 999,
};

export const shadow = shadowFor("light");

export const fonts = {
  display: "Fredoka_600SemiBold",
  displayBold: "Fredoka_700Bold",
  body: "Nunito_400Regular",
  medium: "Nunito_600SemiBold",
  bold: "Nunito_700Bold",
};

export type ThemeValue = {
  preference: ThemePreference;
  setPreference: (next: ThemePreference) => void;
  scheme: ThemeScheme;
  colors: ThemeColors;
  shadow: ThemeShadow;
};

export type NamedStyles<T> = { [P in keyof T]: ViewStyle | TextStyle | ImageStyle };
