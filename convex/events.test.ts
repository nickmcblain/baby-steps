/// <reference types="vite/client" />
import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";

const modules = import.meta.glob("./**/*.ts");

async function twoParents() {
  const t = convexTest(schema, modules);
  const mum = t.withIdentity({ tokenIdentifier: "test|mum", name: "Mum" });
  const dad = t.withIdentity({ tokenIdentifier: "test|dad", name: "Dad" });
  await mum.mutation(api.users.store, {});
  await dad.mutation(api.users.store, {});
  const babyId = await mum.mutation(api.babies.create, {
    name: "Ada",
    dateOfBirth: Date.now() - 30 * 86_400_000,
    weightGrams: 3400,
    careDataConsent: true,
  });
  const baby = await mum.query(api.babies.get, { babyId });
  await dad.mutation(api.babies.joinByCode, { code: baby.inviteCode });
  return { t, mum, dad, babyId };
}

const minutesAgo = (n: number) => Date.now() - n * 60_000;

/** Creating a baby also logs its birth weight, so tests look at one kind at a time. */
async function eventsOf(t: ReturnType<typeof convexTest>, kind: string) {
  const events = await t.run((ctx) => ctx.db.query("events").collect());
  return events.filter((e) => e.kind === kind);
}

describe("offline replay", () => {
  test("a replayed log with the same clientId returns the first event", async () => {
    const { t, mum, babyId } = await twoParents();
    const args = {
      babyId,
      loggedAt: minutesAgo(10),
      nappy: "wee" as const,
      weeSize: "medium" as const,
      clientId: "6f1c2a7e-0d4b-4a8e-9b1f-2c3d4e5f6a7b",
    };
    const first = await mum.mutation(api.events.logNappy, args);
    const replay = await mum.mutation(api.events.logNappy, args);
    expect(replay).toEqual(first);
    const events = await eventsOf(t, "nappy");
    expect(events).toHaveLength(1);
    expect(events[0].clientId).toBe(args.clientId);
  });

  test("concurrent replays of one entry still insert once", async () => {
    const { t, mum, babyId } = await twoParents();
    const args = { babyId, loggedAt: minutesAgo(30), durationMinutes: 45, clientId: "same-entry" };
    const ids = await Promise.all([
      mum.mutation(api.events.logSleep, args),
      mum.mutation(api.events.logSleep, args),
      mum.mutation(api.events.logSleep, args),
    ]);
    expect(new Set(ids).size).toBe(1);
    expect(await eventsOf(t, "sleep")).toHaveLength(1);
  });

  test("logs without a clientId keep inserting, as older clients expect", async () => {
    const { t, mum, babyId } = await twoParents();
    const args = { babyId, loggedAt: minutesAgo(5), feedKind: "breast" as const, side: "left" as const };
    await mum.mutation(api.events.logFeed, args);
    await mum.mutation(api.events.logFeed, args);
    expect(await eventsOf(t, "feed")).toHaveLength(2);
  });

  test("synced events still pass the list return validator", async () => {
    const { mum, babyId } = await twoParents();
    await mum.mutation(api.events.logCustom, {
      babyId,
      loggedAt: minutesAgo(1),
      title: "Bath",
      clientId: "bath-1",
    });
    const page = await mum.query(api.events.list, {
      babyId,
      paginationOpts: { numItems: 10, cursor: null },
    });
    expect(page.page.find((e) => e.kind === "custom")?.clientId).toBe("bath-1");
  });

  test("a rejected log does not consume its clientId", async () => {
    const { mum, babyId } = await twoParents();
    const bad = { babyId, loggedAt: minutesAgo(1), title: " ", clientId: "retry-me" };
    await expect(mum.mutation(api.events.logMedicine, bad)).rejects.toThrow("Give the medicine a name");
    const id = await mum.mutation(api.events.logMedicine, { ...bad, title: "Calpol" });
    expect(id).toBeTruthy();
  });
});

describe("two parents logging at once", () => {
  test("simultaneous logs from both devices all land", async () => {
    const { mum, dad, babyId } = await twoParents();
    await Promise.all([
      mum.mutation(api.events.logFeed, {
        babyId,
        loggedAt: minutesAgo(2),
        feedKind: "bottle",
        amountMl: 90,
        milk: "formula",
        clientId: "mum-feed",
      }),
      dad.mutation(api.events.logNappy, {
        babyId,
        loggedAt: minutesAgo(2),
        nappy: "poo",
        pooSize: "small",
        clientId: "dad-nappy",
      }),
      mum.mutation(api.events.logWeight, {
        babyId,
        loggedAt: minutesAgo(1),
        weightGrams: 4100,
        clientId: "mum-weight",
      }),
      dad.mutation(api.events.logHeight, {
        babyId,
        loggedAt: minutesAgo(1),
        heightCm: 55,
        clientId: "dad-height",
      }),
    ]);
    const page = await dad.query(api.events.list, {
      babyId,
      paginationOpts: { numItems: 10, cursor: null },
    });
    const synced = page.page.filter((e) => e.clientId !== undefined);
    expect(synced.map((e) => e.clientId).sort()).toEqual(["dad-height", "dad-nappy", "mum-feed", "mum-weight"]);
    const baby = await mum.query(api.babies.get, { babyId });
    expect(baby.heightCm).toBe(55);
  });
});
