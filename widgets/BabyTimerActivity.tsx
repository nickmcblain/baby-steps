import { HStack, Image, Text, VStack } from "@expo/ui/swift-ui";
import {
  font,
  foregroundStyle,
  frame,
  monospacedDigit,
  padding,
} from "@expo/ui/swift-ui/modifiers";
import { createLiveActivity, type LiveActivityEnvironment } from "expo-widgets";

/** Props must be JSON-serializable — use epoch ms, not Date objects. */
export type BabyTimerProps = {
  kind: "sleep" | "feed";
  /** e.g. "Sleep" or "Feed · Left" */
  title: string;
  /** Optional baby name */
  subtitle: string;
  running: boolean;
  /**
   * Effective start for the native count-up clock when `running` is true.
   * (Date.now() - alreadyElapsed) so the Island keeps ticking without JS.
   */
  startEpochMs: number;
  /** Upper bound for timerInterval (start + 24h). Required for count-up. */
  endEpochMs: number;
  /** Static clock when paused, e.g. "12:34" */
  pausedLabel: string;
};

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Live Activity for sleep / feed timers.
 * All helpers must live inside this function — `'widget'` serializes the body only.
 */
const BabyTimerActivity = (
  props: BabyTimerProps,
  _env: LiveActivityEnvironment,
) => {
  "widget";

  const TEAL = "#14C4B2";
  const PURPLE = "#6D5EF5";
  const accent = props.kind === "sleep" ? PURPLE : TEAL;
  const symbol = props.kind === "sleep" ? "moon.fill" : "drop.fill";
  const start = new Date(props.startEpochMs);
  const end = new Date(props.endEpochMs);

  const Clock = ({ size, width }: { size: number; width: number }) =>
    props.running ? (
      <Text
        timerInterval={{ lower: start, upper: end }}
        countsDown={false}
        modifiers={[
          font({ weight: "bold", size }),
          monospacedDigit(),
          foregroundStyle("#FFFFFF"),
          frame({ width, alignment: "trailing" }),
        ]}
      />
    ) : (
      <Text
        modifiers={[
          font({ weight: "bold", size }),
          monospacedDigit(),
          foregroundStyle("#FFFFFF"),
          frame({ width, alignment: "trailing" }),
        ]}
      >
        {props.pausedLabel}
      </Text>
    );

  return {
    banner: (
      <HStack modifiers={[padding({ all: 14 })]}>
        <Image systemName={symbol} color={accent} />
        <VStack>
          <Text
            modifiers={[
              font({ weight: "bold", size: 16 }),
              foregroundStyle("#FFFFFF"),
            ]}
          >
            {props.title}
          </Text>
          {props.subtitle ? (
            <Text
              modifiers={[font({ size: 13 }), foregroundStyle("#FFFFFF99")]}
            >
              {props.subtitle}
            </Text>
          ) : null}
          <Text
            modifiers={[font({ size: 12 }), foregroundStyle("#FFFFFF66")]}
          >
            {props.running ? "Timing…" : "Paused"}
          </Text>
        </VStack>
        <Clock size={28} width={100} />
      </HStack>
    ),
    compactLeading: <Image systemName={symbol} color={accent} />,
    compactTrailing: <Clock size={16} width={72} />,
    minimal: <Clock size={12} width={44} />,
    expandedLeading: (
      <VStack modifiers={[padding({ all: 10 })]}>
        <Image systemName={symbol} color={accent} />
        <Text
          modifiers={[font({ size: 12 }), foregroundStyle("#FFFFFF")]}
        >
          {props.kind === "sleep" ? "Sleep" : "Feed"}
        </Text>
      </VStack>
    ),
    expandedTrailing: (
      <VStack modifiers={[padding({ all: 10 })]}>
        <Clock size={24} width={96} />
        <Text
          modifiers={[font({ size: 11 }), foregroundStyle("#FFFFFF99")]}
        >
          {props.running ? "Running" : "Paused"}
        </Text>
      </VStack>
    ),
    expandedBottom: (
      <VStack modifiers={[padding({ horizontal: 12, bottom: 10 })]}>
        <Text
          modifiers={[
            font({ weight: "semibold", size: 15 }),
            foregroundStyle("#FFFFFF"),
          ]}
        >
          {props.title}
        </Text>
        {props.subtitle ? (
          <Text
            modifiers={[font({ size: 13 }), foregroundStyle("#FFFFFF99")]}
          >
            {props.subtitle}
          </Text>
        ) : null}
      </VStack>
    ),
  };
};

export { DAY_MS };
export default createLiveActivity<BabyTimerProps>(
  "BabyTimerActivity",
  BabyTimerActivity,
);
