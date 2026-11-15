import assert from "node:assert/strict";
import { test } from "node:test";
import { claimedEnvironment, isSubscribed, mayClaim, stateFromTransaction, type TransactionInfo } from "./appStore.ts";

const NOW = 1_800_000_000_000;
const DAY = 86_400_000;

const monthly: TransactionInfo = {
  productId: "com.nickmcblain.babysteps.monthly",
  originalTransactionId: "2000000123",
  expiresDate: NOW + 30 * DAY,
  inAppOwnershipType: "PURCHASED",
  environment: "Sandbox",
  signedDate: NOW - 1000,
};

test("a new subscription is active and keeps its renewal flag", () => {
  const state = stateFromTransaction(monthly, { autoRenewStatus: 1 }, 1, NOW);
  assert.ok(state);
  assert.equal(state.status, "active");
  assert.equal(state.willAutoRenew, true);
  assert.equal(state.familyShared, false);
  assert.equal(state.signedAt, NOW - 1000);
  assert.ok(isSubscribed(state, NOW));
});

test("cancelling keeps access until the period ends", () => {
  const state = stateFromTransaction(monthly, { autoRenewStatus: 0 }, 1, NOW);
  assert.equal(state?.willAutoRenew, false);
  assert.ok(state && isSubscribed(state, NOW));
});

test("an app transaction without renewal info leaves willAutoRenew unknown", () => {
  assert.equal(stateFromTransaction(monthly, undefined, undefined, NOW)?.willAutoRenew, undefined);
});

test("expiry is read from Apple's status, or from the expiry date when there is none", () => {
  assert.equal(stateFromTransaction(monthly, undefined, 2, NOW)?.status, "expired");
  const state = stateFromTransaction({ ...monthly, expiresDate: NOW - 1 }, undefined, undefined, NOW);
  assert.equal(state?.status, "expired");
  assert.ok(state && !isSubscribed(state, NOW));
});

test("an active row whose expiry passed without a notification stops counting after a day", () => {
  assert.ok(isSubscribed({ status: "active", expiresAt: NOW - DAY / 2 }, NOW));
  assert.ok(!isSubscribed({ status: "active", expiresAt: NOW - 2 * DAY }, NOW));
  assert.ok(!isSubscribed({ status: "none" }, NOW));
});

test("a refund revokes access", () => {
  const state = stateFromTransaction({ ...monthly, revocationDate: NOW - 5 }, undefined, 1, NOW);
  assert.equal(state?.status, "revoked");
  assert.ok(state && !isSubscribed(state, NOW));
});

test("billing grace period keeps access, billing retry does not", () => {
  assert.ok(isSubscribed(stateFromTransaction(monthly, undefined, 4, NOW)!, NOW));
  assert.ok(!isSubscribed(stateFromTransaction(monthly, undefined, 3, NOW)!, NOW));
});

test("family sharing is recorded", () => {
  const state = stateFromTransaction({ ...monthly, inAppOwnershipType: "FAMILY_SHARED" }, undefined, 1, NOW);
  assert.equal(state?.familyShared, true);
});

test("other products are ignored", () => {
  assert.equal(stateFromTransaction({ ...monthly, productId: "com.example.other" }, undefined, 1, NOW), null);
  assert.equal(stateFromTransaction({ ...monthly, originalTransactionId: undefined }, undefined, 1, NOW), null);
});

function fakeJws(payload: object): string {
  const part = (o: object) => Buffer.from(JSON.stringify(o)).toString("base64url");
  return `${part({ alg: "ES256" })}.${part(payload)}.sig`;
}

test("claimedEnvironment reads transactions and notifications", () => {
  assert.equal(claimedEnvironment(fakeJws({ environment: "Sandbox" })), "Sandbox");
  assert.equal(claimedEnvironment(fakeJws({ data: { environment: "Production" } })), "Production");
  assert.equal(claimedEnvironment(fakeJws({ summary: { environment: "Sandbox" } })), "Sandbox");
  assert.equal(claimedEnvironment(fakeJws({})), undefined);
  assert.equal(claimedEnvironment("not-a-jws"), undefined);
});

test("a transaction unlocks only the carer it was bought for", () => {
  const base = { familyShared: false, transactionToken: "ABC", myToken: "abc", claimedBy: null, userId: "users:mum" };
  assert.equal(mayClaim(base), true);
  assert.equal(mayClaim({ ...base, claimedBy: "users:mum" }), true);
  assert.equal(mayClaim({ ...base, claimedBy: "users:dad" }), false, "already another carer's");
  assert.equal(mayClaim({ ...base, myToken: "other" }), false, "bought for another account");
  assert.equal(mayClaim({ ...base, familyShared: true }), false, "Family Sharing is off");
  assert.equal(mayClaim({ ...base, transactionToken: undefined }), true);
});
