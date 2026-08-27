import { createContext, useContext, type ReactNode } from "react";
import {
  ReduceMotion,
  useAnimatedScrollHandler,
  useSharedValue,
  withSpring,
  type SharedValue,
} from "react-native-reanimated";

const SPRING = {
  duration: 400,
  dampingRatio: 1,
  reduceMotion: ReduceMotion.System,
} as const;

type DockScroll = {
  collapsed: SharedValue<number>;
};

const DockScrollContext = createContext<DockScroll | null>(null);

export function DockScrollProvider({ children }: { children: ReactNode }) {
  const collapsed = useSharedValue(0);
  return (
    <DockScrollContext.Provider value={{ collapsed }}>
      {children}
    </DockScrollContext.Provider>
  );
}

export function useDockCollapsed() {
  return useContext(DockScrollContext)?.collapsed ?? null;
}

export function expandDock(collapsed: SharedValue<number>) {
  collapsed.set(withSpring(0, SPRING));
}

export function useDockScrollHandler(enabled: boolean) {
  const collapsed = useDockCollapsed();
  const lastY = useSharedValue(0);
  const target = useSharedValue(0);

  return useAnimatedScrollHandler({
    onScroll(e) {
      if (!enabled || collapsed == null) return;
      const y = e.contentOffset.y;
      const dy = y - lastY.get();
      lastY.set(y);

      let next = target.get();
      if (y <= 24) next = 0;
      else if (dy > 8) next = 1;
      else if (dy < -8) next = 0;

      if (next === target.get()) return;
      target.set(next);
      collapsed.set(withSpring(next, SPRING));
    },
  });
}
