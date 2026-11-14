/// <reference types="vite/client" />
import { convexTest, type TestConvex } from "convex-test";
import { afterEach, describe, expect, test, vi } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";

const modules = import.meta.glob("./**/*.ts");

const alice = { tokenIdentifier: "clerk|alice", name: "Alice", email: "alice@example.com" };
const bob = { tokenIdentifier: "clerk|bob", name: "Bob", email: "bob@example.com" };

async function setup() {
  const t = convexTest(schema, modules);
  const asAlice = t.withIdentity(alice);
  const asBob = t.withIdentity(bob);
  await asAlice.mutation(api.users.store, {});
  await asBob.mutation(api.users.store, {});
  return { t, asAlice, asBob };
}

const newBaby = (name: string) => ({
  name,
  dateOfBirth: Date.UTC(2026, 8, 1),
  weightGrams: 3400,
  careDataConsent: true as const,
});

async function seedChat(
  t: TestConvex<typeof schema>,
  babyId: string,
  tokenIdentifier: string,
) {
  await t.run(async (ctx) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_token", (q) => q.eq("tokenIdentifier", tokenIdentifier))
      .unique();
    const id = babyId as never;
    const threadId = await ctx.db.insert("chatThreads", {
      babyId: id,
      createdBy: user!._id,
      updatedAt: Date.now(),
    });
    await ctx.db.insert("chatMessages", {
      threadId,
      babyId: id,
      role: "user",
      content: "How warm should the room be?",
      createdAt: Date.now(),
    });
    await ctx.db.insert("babyMemories", {
      babyId: id,
      key: "settling_tip",
      content: "Likes white noise",
      updatedAt: Date.now(),
      createdBy: user!._id,
    });
  });
}

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

describe("account.deleteAccount", () => {
  test("deletes a baby only this user can see, with every log and chat", async () => {
    const { t, asAlice } = await setup();
    const babyId = await asAlice.mutation(api.babies.create, newBaby("Ada"));
    await asAlice.mutation(api.events.logNappy, {
      babyId,
      loggedAt: Date.now(),
      nappy: "wee",
      weeSize: "small",
    });
    await seedChat(t, babyId, alice.tokenIdentifier);

    const result = await asAlice.action(api.account.deleteAccount, {});
    expect(result).toEqual({ deletedBabies: 1, leftSharedBabies: 0, signInDeleted: false });
    await t.finishAllScheduledFunctions(() => {});

    await t.run(async (ctx) => {
      expect(await ctx.db.query("users").collect()).toHaveLength(1);
      expect(await ctx.db.query("babies").collect()).toHaveLength(0);
      expect(await ctx.db.query("babyMembers").collect()).toHaveLength(0);
      expect(await ctx.db.query("events").collect()).toHaveLength(0);
      expect(await ctx.db.query("chatThreads").collect()).toHaveLength(0);
      expect(await ctx.db.query("chatMessages").collect()).toHaveLength(0);
      expect(await ctx.db.query("babyMemories").collect()).toHaveLength(0);
    });
  });

  test("keeps a shared baby for the partner and removes only this user's chats", async () => {
    const { t, asAlice, asBob } = await setup();
    const babyId = await asAlice.mutation(api.babies.create, newBaby("Ada"));
    const baby = await asAlice.query(api.babies.get, { babyId });
    await asBob.mutation(api.babies.joinByCode, { code: baby.inviteCode });
    await seedChat(t, babyId, alice.tokenIdentifier);
    await seedChat(t, babyId, bob.tokenIdentifier);

    const result = await asAlice.action(api.account.deleteAccount, {});
    expect(result).toEqual({ deletedBabies: 0, leftSharedBabies: 1, signInDeleted: false });
    await t.finishAllScheduledFunctions(() => {});

    const kept = await asBob.query(api.babies.get, { babyId });
    const bobUser = await asBob.query(api.users.me, {});
    expect(kept.createdBy).toBe(bobUser._id);
    await t.run(async (ctx) => {
      expect(await ctx.db.query("babyMembers").collect()).toHaveLength(1);
      // Birth weight log from create() stays with the baby.
      expect(await ctx.db.query("events").collect()).toHaveLength(1);
      const threads = await ctx.db.query("chatThreads").collect();
      expect(threads.map((th) => th.createdBy)).toEqual([bobUser._id]);
      expect(await ctx.db.query("chatMessages").collect()).toHaveLength(1);
      const memories = await ctx.db.query("babyMemories").collect();
      expect(memories.map((m) => m.createdBy)).toEqual([bobUser._id]);
    });
    await expect(asAlice.query(api.users.current, {})).resolves.toBeNull();
  });

  test("purges large logs in batches", async () => {
    const { t, asAlice } = await setup();
    const babyId = await asAlice.mutation(api.babies.create, newBaby("Ada"));
    await t.run(async (ctx) => {
      const baby = await ctx.db.get(babyId);
      for (let i = 0; i < 950; i += 1) {
        await ctx.db.insert("events", {
          babyId,
          createdBy: baby!.createdBy,
          loggedAt: i * 60_000,
          kind: "sleep",
          durationMinutes: 30,
        });
      }
    });
    await asAlice.action(api.account.deleteAccount, {});
    await t.finishAllScheduledFunctions(() => {});
    await t.run(async (ctx) => {
      expect(await ctx.db.query("events").collect()).toHaveLength(0);
    });
  });

  test("is a no-op for a signed-in user with no Scrunch data yet", async () => {
    const t = convexTest(schema, modules);
    const result = await t
      .withIdentity({ tokenIdentifier: "clerk|new" })
      .action(api.account.deleteAccount, {});
    expect(result).toEqual({ deletedBabies: 0, leftSharedBabies: 0, signInDeleted: false });
  });

  test("deletes the Clerk user through the Backend API when the secret is set", async () => {
    const { t, asAlice } = await setup();
    vi.stubEnv("CLERK_SECRET_KEY", "sk_test_123");
    const fetchMock = vi.fn(async () => new Response("{}", { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);

    const result = await t
      .withIdentity({ ...alice, subject: "user_alice" })
      .action(api.account.deleteAccount, {});

    expect(result.signInDeleted).toBe(true);
    expect(fetchMock).toHaveBeenCalledWith(
      "https://api.clerk.com/v1/users/user_alice",
      { method: "DELETE", headers: { Authorization: "Bearer sk_test_123" } },
    );
    await expect(asAlice.query(api.users.current, {})).resolves.toBeNull();
  });

  test("reports a failed Clerk deletion so the app can retry on the device", async () => {
    const { t } = await setup();
    vi.stubEnv("CLERK_SECRET_KEY", "sk_test_123");
    vi.stubGlobal("fetch", vi.fn(async () => new Response("nope", { status: 403 })));
    vi.spyOn(console, "error").mockImplementation(() => {});
    const result = await t
      .withIdentity({ ...alice, subject: "user_alice" })
      .action(api.account.deleteAccount, {});
    expect(result.signInDeleted).toBe(false);
  });
});

describe("careExport.babyCareLog", () => {
  test("returns every log oldest first, members only", async () => {
    const { asAlice, asBob } = await setup();
    const babyId = await asAlice.mutation(api.babies.create, newBaby("Ada"));
    await asAlice.mutation(api.events.logSleep, {
      babyId,
      loggedAt: Date.UTC(2026, 8, 2, 10),
      durationMinutes: 45,
    });
    const log = await asAlice.query(api.careExport.babyCareLog, { babyId });
    expect(log.baby.name).toBe("Ada");
    expect(log.truncated).toBe(false);
    expect(log.events.map((e) => e.kind)).toEqual(["sleep", "weight"]);
    await expect(asBob.query(api.careExport.babyCareLog, { babyId })).rejects.toThrow(
      "Not a member of this baby",
    );
  });
});
