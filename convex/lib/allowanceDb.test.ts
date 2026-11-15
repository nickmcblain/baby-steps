import assert from "node:assert/strict";
import { test } from "node:test";
import { ConvexError } from "convex/values";
import type { Id } from "../_generated/dataModel";
import type { MutationCtx } from "../_generated/server";
import { logTypeFor, type LogType } from "./allowance.ts";
import { chargeAllowance, usedFor, userSubscribed } from "./allowanceDb.ts";
import { createInvite, redeemInvite, visibleBaby } from "./sharing.ts";

type Row = Record<string, unknown> & { _id: string };

/** Just enough of ctx.db for the allowance and sharing helpers: get, equality index lookups, insert and patch. */
function fakeCtx() {
  const tables: Record<string, Row[]> = {};
  let next = 0;
  const db = {
    query(table: string) {
      const filters: [string, unknown][] = [];
      const rows = () => (tables[table] ?? []).filter((row) => filters.every(([k, v]) => row[k] === v));
      const chain = {
        withIndex(_name: string, build: (q: { eq: (k: string, v: unknown) => unknown }) => unknown) {
          const q = { eq: (k: string, v: unknown) => (filters.push([k, v]), q) };
          build(q);
          return chain;
        },
        unique: async () => rows()[0] ?? null,
        take: async (n: number) => rows().slice(0, n),
      };
      return chain;
    },
    async get(id: string) {
      return Object.values(tables).flat().find((r) => r._id === id) ?? null;
    },
    async insert(table: string, doc: Record<string, unknown>) {
      const _id = `${table}:${next++}`;
      (tables[table] ??= []).push({ ...doc, _id });
      return _id;
    },
    async patch(id: string, fields: Record<string, unknown>) {
      const row = Object.values(tables).flat().find((r) => r._id === id);
      if (row) Object.assign(row, fields);
    },
  };
  return { ctx: { db } as unknown as MutationCtx, db };
}

type Db = ReturnType<typeof fakeCtx>["db"];
const mum = "users:mum" as Id<"users">;
const dad = "users:dad" as Id<"users">;

async function newBaby(db: Db, owner: Id<"users">): Promise<Id<"babies">> {
  const babyId = (await db.insert("babies", { name: "Ada", createdBy: owner })) as Id<"babies">;
  await db.insert("babyMembers", { babyId, userId: owner });
  return babyId;
}

async function subscribe(db: Db, userId: Id<"users">) {
  return await db.insert("subscriptions", { userId, status: "active", expiresAt: Date.now() + 30 * 86_400_000 });
}

async function members(db: Db, babyId: Id<"babies">) {
  return (await db.query("babyMembers").withIndex("by_baby", (q) => q.eq("babyId", babyId)).take(10)).map((m) => m.userId);
}

function log(ctx: MutationCtx, babyId: Id<"babies">, userId: Id<"users">, type: LogType | null) {
  return chargeAllowance(ctx, babyId, userId, type);
}

function isFreeLimitFor(type: LogType) {
  return (error: unknown) =>
    error instanceof ConvexError && error.data.code === "FREE_LIMIT_REACHED" && error.data.type === type;
}

function isSubscriptionRequired(error: unknown) {
  return error instanceof ConvexError && error.data.code === "SUBSCRIPTION_REQUIRED" && error.data.feature === "sharing";
}

// MARK: Free allowance

test("five free entries per type, then the sixth is refused", async () => {
  const { ctx, db } = fakeCtx();
  const baby = await newBaby(db, mum);
  for (let i = 0; i < 5; i++) await log(ctx, baby, mum, "nappy");
  await assert.rejects(log(ctx, baby, mum, "nappy"), isFreeLimitFor("nappy"));
  await log(ctx, baby, mum, "feed");
  assert.deepEqual(await usedFor(ctx, baby, mum), { nappy: 5, feed: 1 });
});

test("sleep is never counted or refused", async () => {
  const { ctx, db } = fakeCtx();
  const baby = await newBaby(db, mum);
  for (let i = 0; i < 50; i++) await log(ctx, baby, mum, logTypeFor("sleep"));
  assert.deepEqual(await usedFor(ctx, baby, mum), {});
});

test("each carer gets their own five of each type on a shared baby, and each baby has its own", async () => {
  const { ctx, db } = fakeCtx();
  const baby = await newBaby(db, mum);
  const otherBaby = await newBaby(db, mum);
  await db.insert("babyMembers", { babyId: baby, userId: dad });
  for (let i = 0; i < 5; i++) await log(ctx, baby, mum, "feed");
  await assert.rejects(log(ctx, baby, mum, "feed"), isFreeLimitFor("feed"));
  for (let i = 0; i < 5; i++) await log(ctx, baby, dad, "feed");
  await assert.rejects(log(ctx, baby, dad, "feed"), isFreeLimitFor("feed"));
  await log(ctx, otherBaby, mum, "feed");
  assert.deepEqual(await usedFor(ctx, baby, mum), { feed: 5 });
  assert.deepEqual(await usedFor(ctx, baby, dad), { feed: 5 });
});

test("a subscription unlocks only the carer who has it, and expiry locks it again", async () => {
  const { ctx, db } = fakeCtx();
  const baby = await newBaby(db, mum);
  await db.insert("babyMembers", { babyId: baby, userId: dad });
  for (let i = 0; i < 5; i++) {
    await log(ctx, baby, mum, "pump");
    await log(ctx, baby, dad, "pump");
  }
  const sub = await subscribe(db, mum);
  assert.equal(await userSubscribed(ctx, mum), true);
  assert.equal(await userSubscribed(ctx, dad), false);
  await log(ctx, baby, mum, "pump");
  await assert.rejects(log(ctx, baby, dad, "pump"), isFreeLimitFor("pump"), "a partner's subscription doesn't cover you");

  await db.patch(sub, { status: "expired" });
  await assert.rejects(log(ctx, baby, mum, "pump"), isFreeLimitFor("pump"));
});

// MARK: Sharing

test("an unsubscribed carer can't create a share code", async () => {
  const { ctx, db } = fakeCtx();
  const baby = await newBaby(db, mum);
  await assert.rejects(createInvite(ctx, mum, baby), isSubscriptionRequired);
  assert.equal((await db.get(baby))?.inviteCode, undefined);
});

test("a subscribed carer gets one stable code, and only subscribers can see it", async () => {
  const { ctx, db } = fakeCtx();
  const baby = await newBaby(db, mum);
  await db.insert("babyMembers", { babyId: baby, userId: dad });
  await subscribe(db, mum);
  const code = await createInvite(ctx, mum, baby);
  assert.match(code, /^[2-9A-HJ-NP-Z]{6}$/);
  assert.equal(await createInvite(ctx, mum, baby), code);
  const row = await ctx.db.get(baby);
  assert.equal((await visibleBaby(ctx, row!, mum)).inviteCode, code);
  assert.equal((await visibleBaby(ctx, row!, dad)).inviteCode, undefined);
});

test("only members can create a code", async () => {
  const { ctx, db } = fakeCtx();
  const baby = await newBaby(db, mum);
  await subscribe(db, dad);
  await assert.rejects(createInvite(ctx, dad, baby), /Not a member/);
});

test("an unsubscribed carer can't redeem a code, and isn't told whether it exists", async () => {
  const { ctx, db } = fakeCtx();
  const baby = await newBaby(db, mum);
  await subscribe(db, mum);
  const code = await createInvite(ctx, mum, baby);
  await assert.rejects(redeemInvite(ctx, dad, code), isSubscriptionRequired);
  await assert.rejects(redeemInvite(ctx, dad, "ZZZZZZ"), isSubscriptionRequired);
  assert.deepEqual(await members(db, baby), [mum]);
});

test("a subscribed carer redeems a code and joins", async () => {
  const { ctx, db } = fakeCtx();
  const baby = await newBaby(db, mum);
  await subscribe(db, mum);
  const code = await createInvite(ctx, mum, baby);
  await subscribe(db, dad);
  assert.equal(await redeemInvite(ctx, dad, ` ${code.toLowerCase()} `), baby);
  assert.equal(await redeemInvite(ctx, dad, code), baby);
  assert.deepEqual(await members(db, baby), [mum, dad]);
  await assert.rejects(redeemInvite(ctx, dad, "ZZZZZZ"), /No baby matches/);
});

test("a lapsed carer stays on the baby, keeps sleep, and hits the paywall for everything else", async () => {
  const { ctx, db } = fakeCtx();
  const baby = await newBaby(db, mum);
  await subscribe(db, mum);
  const code = await createInvite(ctx, mum, baby);
  const dadSub = await subscribe(db, dad);
  await redeemInvite(ctx, dad, code);
  for (let i = 0; i < 8; i++) await log(ctx, baby, dad, "nappy");

  await db.patch(dadSub, { status: "expired" });
  assert.deepEqual(await members(db, baby), [mum, dad]);
  assert.equal(await redeemInvite(ctx, dad, code), baby, "rejoining an existing baby isn't blocked");
  await log(ctx, baby, dad, logTypeFor("sleep"));
  await assert.rejects(log(ctx, baby, dad, "nappy"), isFreeLimitFor("nappy"));
  assert.equal((await visibleBaby(ctx, (await ctx.db.get(baby))!, dad)).inviteCode, undefined);
  await assert.rejects(createInvite(ctx, dad, baby), isSubscriptionRequired);
  await log(ctx, baby, mum, "nappy");
});
