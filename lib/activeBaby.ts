import AsyncStorage from "@react-native-async-storage/async-storage";
import {
  createContext,
  createElement,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

const KEY = "baby-steps.activeBabyId";

export async function getActiveBabyId(): Promise<string | null> {
  return AsyncStorage.getItem(KEY);
}

export async function setActiveBabyId(id: string): Promise<void> {
  await AsyncStorage.setItem(KEY, id);
}

type ActiveBabyContextValue = {
  activeBabyId: string | null;
  ready: boolean;
  select: (id: string) => Promise<void>;
};

const ActiveBabyContext = createContext<ActiveBabyContextValue | null>(null);

export function ActiveBabyProvider({ children }: { children: ReactNode }) {
  const [activeBabyId, setId] = useState<string | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let cancelled = false;
    void getActiveBabyId().then((id) => {
      if (!cancelled) {
        setId(id);
        setReady(true);
      }
    });
    return () => {
      cancelled = true;
    };
  }, []);

  const select = useCallback(async (id: string) => {
    await setActiveBabyId(id);
    setId(id);
  }, []);

  const value = useMemo(
    () => ({ activeBabyId, ready, select }),
    [activeBabyId, ready, select],
  );

  return createElement(ActiveBabyContext.Provider, { value }, children);
}

export function useActiveBabyId(): ActiveBabyContextValue {
  const ctx = useContext(ActiveBabyContext);
  if (!ctx) {
    throw new Error("useActiveBabyId must be used inside ActiveBabyProvider");
  }
  return ctx;
}