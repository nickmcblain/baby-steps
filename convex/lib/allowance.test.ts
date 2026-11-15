import assert from "node:assert/strict";
import { test } from "node:test";
import { FREE_LIMIT, canLog, logTypeFor, trialUsed } from "./allowance.ts";

test("free limit is five", () => {
  assert.equal(FREE_LIMIT, 5);
});

test("sleep never counts", () => {
  assert.equal(logTypeFor("sleep"), null);
  assert.equal(canLog(null, 500, false), true);
});

test("breast and bottle feeds share one feeds allowance", () => {
  assert.equal(logTypeFor("feed"), "feed");
});

test("weight and height share the growth allowance", () => {
  assert.equal(logTypeFor("weight"), "growth");
  assert.equal(logTypeFor("height"), "growth");
  assert.equal(logTypeFor("custom"), "note");
  for (const kind of ["feed", "nappy", "pump", "tummy", "potty", "medicine", "activity"]) {
    assert.equal(logTypeFor(kind), kind);
  }
});

test("the sixth entry needs a subscription", () => {
  for (let used = 0; used < FREE_LIMIT; used++) assert.equal(canLog("nappy", used, false), true);
  assert.equal(canLog("nappy", 5, false), false);
  assert.equal(canLog("nappy", 5, true), true);
  assert.equal(canLog("nappy", 40, true), true);
});

test("trial is used once any allowance runs out", () => {
  assert.equal(trialUsed({}), false);
  assert.equal(trialUsed({ feed: 4, nappy: 4 }), false);
  assert.equal(trialUsed({ feed: 4, nappy: 5 }), true);
});
