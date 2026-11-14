import assert from "node:assert/strict";
import { test } from "node:test";
import { ConvexError } from "convex/values";
import type { Id } from "../_generated/dataModel";
import type { MutationCtx } from "../_generated/server";
import { logTypeFor, type LogType } from "./allowance.ts";
import { babyUnlocked, chargeAllowance, usedForBaby } from "./allowanceDb.ts";

type Row = Record<string, unknown> & { _id: string };

/** Just enough of ctx.db for the allowance helpers: equality index lookups, insert and patch. */
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

const baby = "babies:1" as Id<"babies">;
const otherBaby = "babies:2" as Id<"babies">;

async function share(db: ReturnType<typeof fakeCtx>["db"], babyId: string, userId: string) {
  await db.insert("babyMembers", { babyId, userId });
}

async function log(ctx: MutationCtx, babyId: Id<"babies">, type: LogType | null) {
  await chargeAllowance(ctx, babyId, type);
}

function isFreeLimitFor(type: LogType) {
  return (error: unknown) =>
    error instanceof ConvexError && error.data.code === "FREE_LIMIT_REACHED" && error.data.type === type;
}

test("five free entries per type, then the sixth is refused", async () => {
  const { ctx, db } = fakeCtx();
  await share(db, baby, "users:mum");
  for (let i = 0; i < 5; i++) await log(ctx, baby, "nappy");
  await assert.rejects(log(ctx, baby, "nappy"), isFreeLimitFor("nappy"));
  await log(ctx, baby, "feed");
  assert.deepEqual(await usedForBaby(ctx, baby), { nappy: 5, feed: 1 });
});

test("sleep is never counted or refused", async () => {
  const { ctx, db } = fakeCtx();
  await share(db, baby, "users:mum");
  for (let i = 0; i < 50; i++) await log(ctx, baby, logTypeFor("sleep"));
  assert.deepEqual(await usedForBaby(ctx, baby), {});
});

test("partners share one allowance per baby, and each baby has its own", async () => {
  const { ctx, db } = fakeCtx();
  await share(db, baby, "users:mum");
  await share(db, baby, "users:dad");
  await share(db, otherBaby, "users:mum");
  for (let i = 0; i < 5; i++) await log(ctx, baby, "bottle");
  await assert.rejects(log(ctx, baby, "bottle"), isFreeLimitFor("bottle"));
  await log(ctx, otherBaby, "bottle");
});

test("a subscription from any caregiver unlocks the baby, and expiry locks it again", async () => {
  const { ctx, db } = fakeCtx();
  await share(db, baby, "users:mum");
  await share(db, baby, "users:dad");
  for (let i = 0; i < 5; i++) await log(ctx, baby, "pump");
  assert.equal(await babyUnlocked(ctx, baby), false);

  const sub = await db.insert("subscriptions", {
    userId: "users:dad",
    status: "active",
    expiresAt: Date.now() + 30 * 86_400_000,
  });
  assert.equal(await babyUnlocked(ctx, baby), true);
  await log(ctx, baby, "pump");
  assert.deepEqual(await usedForBaby(ctx, baby), { pump: 6 });

  await db.patch(sub, { status: "expired" });
  await assert.rejects(log(ctx, baby, "pump"), isFreeLimitFor("pump"));
});
