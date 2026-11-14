"use node";

import { Environment, SignedDataVerifier } from "@apple/app-store-server-library";
import { ConvexError, v } from "convex/values";
import { internal } from "./_generated/api";
import { action, internalAction } from "./_generated/server";
import { APPLE_ROOT_CA_G3_BASE64 } from "./lib/appleRootCa";
import { BUNDLE_ID, claimedEnvironment, stateFromTransaction } from "./lib/appStore";

/**
 * Production payloads also need the app's numeric Apple ID (App Store Connect > App Information),
 * set as the APPLE_APP_APPLE_ID Convex environment variable. Local StoreKit (Xcode) payloads are
 * not signed by Apple, so they are only accepted when APPSTORE_ACCEPT_XCODE=true, which must
 * never be set on the production deployment.
 */
function verifierFor(jws: string): SignedDataVerifier | null {
  const roots = [Buffer.from(APPLE_ROOT_CA_G3_BASE64, "base64")];
  const environment = claimedEnvironment(jws);
  if (environment === Environment.SANDBOX) {
    return new SignedDataVerifier(roots, true, Environment.SANDBOX, BUNDLE_ID);
  }
  if (environment === Environment.PRODUCTION) {
    const appAppleId = Number(process.env.APPLE_APP_APPLE_ID);
    if (!Number.isInteger(appAppleId) || appAppleId <= 0) {
      console.error("APPLE_APP_APPLE_ID is not set; cannot verify production App Store data");
      return null;
    }
    return new SignedDataVerifier(roots, true, Environment.PRODUCTION, BUNDLE_ID, appAppleId);
  }
  if (environment === Environment.XCODE && process.env.APPSTORE_ACCEPT_XCODE === "true") {
    return new SignedDataVerifier(roots, false, Environment.XCODE, BUNDLE_ID);
  }
  return null;
}

/** The app sends each verified StoreKit transaction so Convex unlocks logging straight away. */
export const syncTransaction = action({
  args: { signedTransaction: v.string() },
  returns: v.boolean(),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("Not authenticated");
    const verifier = verifierFor(args.signedTransaction);
    if (!verifier) return false;
    let tx;
    try {
      tx = await verifier.verifyAndDecodeTransaction(args.signedTransaction);
    } catch (error) {
      console.warn("Rejected app transaction", error);
      return false;
    }
    const state = stateFromTransaction(tx, undefined, undefined, Date.now());
    if (!state) return false;
    if (tx.appAccountToken && !state.familyShared) {
      const mine = await ctx.runQuery(internal.subscriptions.tokenForUser, {
        tokenIdentifier: identity.tokenIdentifier,
      });
      if (mine !== null && mine.toLowerCase() !== tx.appAccountToken.toLowerCase()) {
        console.warn("Transaction belongs to a different Scrunch account");
        return false;
      }
    }
    await ctx.runMutation(internal.subscriptions.applyForUser, {
      tokenIdentifier: identity.tokenIdentifier,
      state,
    });
    return true;
  },
});

/** App Store Server Notifications V2, called from the HTTP route in http.ts. */
export const processNotification = internalAction({
  args: { signedPayload: v.string() },
  returns: v.union(v.literal("applied"), v.literal("ignored"), v.literal("invalid")),
  handler: async (ctx, args) => {
    const verifier = verifierFor(args.signedPayload);
    if (!verifier) return "invalid";
    let notification;
    try {
      notification = await verifier.verifyAndDecodeNotification(args.signedPayload);
    } catch (error) {
      console.warn("Rejected App Store notification", error);
      return "invalid";
    }
    const data = notification.data;
    if (!data?.signedTransactionInfo) return "ignored";
    const tx = await verifier.verifyAndDecodeTransaction(data.signedTransactionInfo);
    const renewal = data.signedRenewalInfo
      ? await verifier.verifyAndDecodeRenewalInfo(data.signedRenewalInfo)
      : undefined;
    const state = stateFromTransaction(tx, renewal, data.status, Date.now());
    if (!state) return "ignored";
    await ctx.runMutation(internal.subscriptions.applyFromNotification, {
      appAccountToken: tx.appAccountToken,
      state,
    });
    return "applied";
  },
});
