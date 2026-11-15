import assert from "node:assert/strict";
import { test } from "node:test";
import { FREE_LIMIT, canLog, logTypeFor, trialUsed } from "./allowance.ts";

test("the free limit is ten, read from the file ScrunchCore uses", () => {
  assert.equal(FREE_LIMIT, 10);
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

test("the entry after the free limit needs a subscription", () => {
  for (let used = 0; used < FREE_LIMIT; used++) assert.equal(canLog("nappy", used, false), true);
  assert.equal(canLog("nappy", FREE_LIMIT, false), false);
  assert.equal(canLog("nappy", FREE_LIMIT, true), true);
  assert.equal(canLog("nappy", 40, true), true);
});

test("trial is used once any allowance runs out", () => {
  assert.equal(trialUsed({}), false);
  assert.equal(trialUsed({ feed: FREE_LIMIT - 1, nappy: FREE_LIMIT - 1 }), false);
  assert.equal(trialUsed({ feed: FREE_LIMIT - 1, nappy: FREE_LIMIT }), true);
});
