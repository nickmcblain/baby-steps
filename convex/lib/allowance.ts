import { ConvexError, v, type Infer, type Value } from "convex/values";
import config from "../../ios-native/Packages/ScrunchCore/Sources/ScrunchCore/Resources/free-allowance.json" with { type: "json" };

/**
 * The usage-based trial. Each carer gets FREE_LIMIT entries of every log type except sleep on
 * each baby. Mirrors `FreeAllowance` in ScrunchCore, and reads the limit from the same file.
 */
export const FREE_LIMIT: number = config.freeLimit;

export const FREE_LIMIT_REACHED = "FREE_LIMIT_REACHED";
export const SUBSCRIPTION_REQUIRED = "SUBSCRIPTION_REQUIRED";

export const logTypeValidator = v.union(
  v.literal("feed"),
  v.literal("nappy"),
  v.literal("pump"),
  v.literal("growth"),
  v.literal("tummy"),
  v.literal("potty"),
  v.literal("medicine"),
  v.literal("activity"),
  v.literal("note"),
);

export type LogType = Infer<typeof logTypeValidator>;

/** Which allowance an event counts against; null for sleep, which is always free. */
export function logTypeFor(kind: string): LogType | null {
  switch (kind) {
    case "weight":
    case "height":
      return "growth";
    case "custom":
      return "note";
    case "feed":
    case "nappy":
    case "pump":
    case "tummy":
    case "potty":
    case "medicine":
    case "activity":
      return kind;
    default:
      return null;
  }
}

export function canLog(type: LogType | null, used: number, unlocked: boolean): boolean {
  return type === null || unlocked || used < FREE_LIMIT;
}

/** Ask and patterns stay open until the first free allowance runs out. */
export function trialUsed(used: Partial<Record<LogType, number>>): boolean {
  return Object.values(used).some((n) => (n ?? 0) >= FREE_LIMIT);
}

export function isFreeLimit(error: unknown): error is ConvexError<Value> {
  if (!(error instanceof ConvexError)) return false;
  const data: unknown = error.data;
  return typeof data === "object" && data !== null && (data as { code?: unknown }).code === FREE_LIMIT_REACHED;
}
