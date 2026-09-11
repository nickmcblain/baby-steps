import { HStack, Image, Spacer, Text, VStack } from "@expo/ui/swift-ui";
import type { SFSymbols7_0 } from "sf-symbols-typescript";
import { font, foregroundStyle, padding } from "@expo/ui/swift-ui/modifiers";
import { createWidget, type WidgetEnvironment } from "expo-widgets";

/** All strings preformatted by the app — the widget just lays them out. */
export type BabyGlanceProps = {
  babyName: string;
  /** e.g. "Often ready ~12:40 pm" or "Asleep" */
  nextNap: string;
  /** e.g. "Fed 2:10 pm · Left 12m" */
  lastFeed: string;
  /** e.g. "Wet 1:45 pm" */
  lastNappy: string;
  /** e.g. "13.4h today" */
  sleepToday: string;
};

/**
 * Home-screen glance: next nap, last feed, last nappy.
 * All helpers must live inside this function — `'widget'` serializes the body only.
 */
const BabyGlanceWidget = (props: BabyGlanceProps, env: WidgetEnvironment) => {
  "widget";

  const dark = env.colorScheme === "dark";
  const INK = dark ? "#F3F4F6" : "#12141A";
  const MUTED = dark ? "#9AA0A8" : "#8A9099";
  const PURPLE = dark ? "#8B80FF" : "#6D5EF5";
  const TEAL = dark ? "#5EE0D2" : "#0B9E90";
  const PEACH = "#FF8A65";

  const Row = ({
    symbol,
    color,
    label,
    value,
  }: {
    symbol: SFSymbols7_0;
    color: string;
    label: string;
    value: string;
  }) => (
    <HStack spacing={8}>
      <Image systemName={symbol} color={color} />
      <VStack alignment="leading" spacing={0}>
        <Text modifiers={[font({ size: 11, weight: "semibold" }), foregroundStyle(color)]}>
          {label}
        </Text>
        <Text modifiers={[font({ size: 13, weight: "bold" }), foregroundStyle(INK)]}>
          {value}
        </Text>
      </VStack>
      <Spacer />
    </HStack>
  );

  const Header = () => (
    <Text modifiers={[font({ size: 15, weight: "bold" }), foregroundStyle(INK)]}>
      {props.babyName}
    </Text>
  );

  if (env.widgetFamily === "systemMedium") {
    return (
      <VStack alignment="leading" spacing={8} modifiers={[padding({ all: 12 })]}>
        <HStack>
          <Header />
          <Spacer />
          <Text modifiers={[font({ size: 12, weight: "semibold" }), foregroundStyle(MUTED)]}>
            {props.sleepToday}
          </Text>
        </HStack>
        <HStack spacing={12}>
          <Row symbol="moon.fill" color={PURPLE} label="Next nap" value={props.nextNap} />
          <Row symbol="drop.fill" color={TEAL} label="Last feed" value={props.lastFeed} />
        </HStack>
        <Row symbol="circle.grid.2x2.fill" color={PEACH} label="Last nappy" value={props.lastNappy} />
      </VStack>
    );
  }

  return (
    <VStack alignment="leading" spacing={8} modifiers={[padding({ all: 12 })]}>
      <Header />
      <Row symbol="moon.fill" color={PURPLE} label="Next nap" value={props.nextNap} />
      <Row symbol="drop.fill" color={TEAL} label="Last feed" value={props.lastFeed} />
    </VStack>
  );
};

export default createWidget<BabyGlanceProps>("BabyGlanceWidget", BabyGlanceWidget);
