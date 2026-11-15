import { v, type Infer } from "convex/values";

export const BUNDLE_ID = "com.nickmcblain.babysteps";

/** One subscription group. Keep in sync with `Subscription.productIDs` in ScrunchCore. */
export const SUBSCRIPTION_PRODUCT_IDS: readonly string[] = [
  "com.nickmcblain.babysteps.monthly",
  "com.nickmcblain.babysteps.yearly",
];

export const subscriptionStatusValidator = v.union(
  v.literal("none"),
  v.literal("active"),
  v.literal("gracePeriod"),
  v.literal("billingRetry"),
  v.literal("expired"),
  v.literal("revoked"),
);

export type SubscriptionStatus = Infer<typeof subscriptionStatusValidator>;

export const subscriptionStateValidator = v.object({
  productId: v.string(),
  originalTransactionId: v.string(),
  status: subscriptionStatusValidator,
  expiresAt: v.optional(v.number()),
  willAutoRenew: v.optional(v.boolean()),
  familyShared: v.boolean(),
  environment: v.string(),
  /** Apple's signedDate, used to drop notifications that arrive out of order. */
  signedAt: v.number(),
});

export type SubscriptionState = Infer<typeof subscriptionStateValidator>;

/** The fields we read from Apple's decoded transaction, so this file stays free of the Node-only library. */
export type TransactionInfo = {
  productId?: string;
  originalTransactionId?: string;
  expiresDate?: number;
  revocationDate?: number;
  inAppOwnershipType?: string;
  environment?: string;
  appAccountToken?: string;
  signedDate?: number;
};

export type RenewalInfo = { autoRenewStatus?: number };

const AUTO_RENEW_ON = 1;

/** Apple's notification `data.status` values. */
const APPLE_STATUS: Record<number, SubscriptionStatus> = {
  1: "active",
  2: "expired",
  3: "billingRetry",
  4: "gracePeriod",
  5: "revoked",
};

export function stateFromTransaction(
  tx: TransactionInfo,
  renewal: RenewalInfo | undefined,
  appleStatus: number | undefined,
  now: number,
): SubscriptionState | null {
  if (!tx.productId || !SUBSCRIPTION_PRODUCT_IDS.includes(tx.productId) || !tx.originalTransactionId) {
    return null;
  }
  const status = statusFor(tx, appleStatus, now);
  return {
    productId: tx.productId,
    originalTransactionId: tx.originalTransactionId,
    status,
    expiresAt: tx.expiresDate,
    willAutoRenew: renewal?.autoRenewStatus === undefined ? undefined : renewal.autoRenewStatus === AUTO_RENEW_ON,
    familyShared: tx.inAppOwnershipType === "FAMILY_SHARED",
    environment: tx.environment ?? "unknown",
    signedAt: tx.signedDate ?? now,
  };
}

function statusFor(tx: TransactionInfo, appleStatus: number | undefined, now: number): SubscriptionStatus {
  if (tx.revocationDate !== undefined) return "revoked";
  const fromApple = appleStatus === undefined ? undefined : APPLE_STATUS[appleStatus];
  if (fromApple) return fromApple;
  return tx.expiresDate !== undefined && tx.expiresDate <= now ? "expired" : "active";
}

/** A day of slack covers a renewal that Apple has taken but not yet told us about. */
const RENEWAL_LEEWAY_MS = 86_400_000;

export function isSubscribed(
  row: { status: SubscriptionStatus; expiresAt?: number },
  now: number,
): boolean {
  if (row.status === "gracePeriod") return true;
  if (row.status !== "active") return false;
  return row.expiresAt === undefined || row.expiresAt + RENEWAL_LEEWAY_MS > now;
}

/**
 * The environment a JWS claims, read without verifying, so we can pick the matching verifier.
 * The verifier then rejects the payload if the claim was false.
 */
export function claimedEnvironment(jws: string): string | undefined {
  const payload = jws.split(".")[1];
  if (!payload) return undefined;
  try {
    const json: unknown = JSON.parse(atob(payload.replace(/-/g, "+").replace(/_/g, "/")));
    if (typeof json !== "object" || json === null) return undefined;
    const record = json as Record<string, unknown>;
    if (typeof record.environment === "string") return record.environment;
    for (const key of ["data", "summary"]) {
      const nested = record[key];
      if (typeof nested === "object" && nested !== null) {
        const env = (nested as Record<string, unknown>).environment;
        if (typeof env === "string") return env;
      }
    }
    return undefined;
  } catch {
    return undefined;
  }
}
