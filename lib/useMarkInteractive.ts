import { useObserve } from "expo-observe";
import { useEffect, useRef } from "react";

/** Record TTI once this screen is ready for input. Safe to call on every entry screen. */
export function useMarkInteractive(ready: boolean) {
  const { markInteractive } = useObserve();
  const doneRef = useRef(false);

  useEffect(() => {
    if (!ready || doneRef.current) return;
    doneRef.current = true;
    markInteractive();
  }, [ready, markInteractive]);
}
