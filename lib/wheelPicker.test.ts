import { describe, expect, test } from "bun:test";
import { shouldCommitOnEndDrag, wheelIndexFromOffset } from "./wheelPicker";

describe("shouldCommitOnEndDrag", () => {
  test("commits when the drag stopped still", () => {
    expect(shouldCommitOnEndDrag(0)).toBe(true);
    expect(shouldCommitOnEndDrag(undefined)).toBe(true);
  });

  test("waits for momentum after a flick", () => {
    expect(shouldCommitOnEndDrag(1.2)).toBe(false);
    expect(shouldCommitOnEndDrag(-800)).toBe(false);
  });
});

describe("wheelIndexFromOffset", () => {
  test("clamps past the last item", () => {
    expect(wheelIndexFromOffset(10_000, 60, 44)).toBe(59);
    expect(wheelIndexFromOffset(-20, 24, 44)).toBe(0);
  });
});
