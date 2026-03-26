import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { makeCard } from "./cards.ts";
import { scoreHand, peggingPointsForPlay } from "./scoring.ts";

// ── scoreHand ────────────────────────────────────────────────────────────────

describe("scoreHand", () => {
  it("perfect 29 hand", () => {
    // J♠ must match starter suit (♠) for knobs; four 5s for max fifteens+pairs
    const hand = [
      makeCard(11, "S"),
      makeCard(5, "H"),
      makeCard(5, "D"),
      makeCard(5, "C"),
    ];
    const starter = makeCard(5, "S");
    const { total } = scoreHand(hand, starter);
    assert.strictEqual(total, 29);
  });

  it("simple fifteen two + pair", () => {
    // 6+9=15, pair of 9s → 4 + 2 = 6
    const hand = [
      makeCard(6, "H"),
      makeCard(9, "C"),
      makeCard(9, "D"),
      makeCard(1, "S"),
    ];
    const starter = makeCard(2, "H");
    const { total, breakdown } = scoreHand(hand, starter);
    assert.strictEqual(total, 6);
    assert.ok(breakdown.some(b => b.startsWith("Fifteens")));
    assert.ok(breakdown.some(b => b.startsWith("Pairs")));
  });

  it("flush four in hand (starter different suit)", () => {
    const hand = [
      makeCard(1, "H"),
      makeCard(3, "H"),
      makeCard(7, "H"),
      makeCard(9, "H"),
    ];
    const starter = makeCard(2, "D");
    const { breakdown } = scoreHand(hand, starter, false);
    assert.ok(breakdown.some(b => b.startsWith("Flush")));
  });

  it("flush five with matching starter", () => {
    const hand = [
      makeCard(1, "H"),
      makeCard(3, "H"),
      makeCard(7, "H"),
      makeCard(9, "H"),
    ];
    const starter = makeCard(2, "H");
    const { total } = scoreHand(hand, starter, false);
    assert.ok(total >= 5);
  });

  it("knobs scores 1", () => {
    const hand = [
      makeCard(11, "S"),
      makeCard(3, "H"),
      makeCard(7, "D"),
      makeCard(9, "C"),
    ];
    const starter = makeCard(2, "S");
    const { breakdown } = scoreHand(hand, starter, false);
    assert.ok(breakdown.some(b => b.startsWith("Knobs")));
  });

  it("run of 3", () => {
    const hand = [
      makeCard(4, "S"),
      makeCard(5, "H"),
      makeCard(6, "D"),
      makeCard(1, "C"),
    ];
    const starter = makeCard(10, "S");
    const { breakdown } = scoreHand(hand, starter, false);
    assert.ok(breakdown.some(b => b.startsWith("Runs")));
  });

  it("no score hand", () => {
    const hand = [
      makeCard(1, "S"),
      makeCard(3, "H"),
      makeCard(7, "D"),
      makeCard(9, "C"),
    ];
    const starter = makeCard(12, "S");
    const { total, breakdown } = scoreHand(hand, starter, false);
    assert.strictEqual(total, 0);
    assert.deepStrictEqual(breakdown, ["No score"]);
  });
});

// ── peggingPointsForPlay ─────────────────────────────────────────────────────

describe("peggingPointsForPlay", () => {
  it("fifteen counts as 2", () => {
    const stack = [makeCard(6, "H")];
    const card = makeCard(9, "S");
    assert.strictEqual(peggingPointsForPlay(stack, card, 6), 2);
  });

  it("31 counts as 2", () => {
    const stack = [makeCard(10, "H"), makeCard(10, "D"), makeCard(10, "C")];
    const card = makeCard(1, "S");
    assert.strictEqual(peggingPointsForPlay(stack, card, 30), 2);
  });

  it("pair scores 2", () => {
    const stack = [makeCard(7, "H")];
    const card = makeCard(7, "D");
    assert.strictEqual(peggingPointsForPlay(stack, card, 7), 2);
  });

  it("three of a kind scores 6", () => {
    const stack = [makeCard(7, "H"), makeCard(7, "D")];
    const card = makeCard(7, "C");
    assert.strictEqual(peggingPointsForPlay(stack, card, 14), 6);
  });

  it("run of 3 in pegging (plus fifteen)", () => {
    // stack=[4,5] running count=9, play 6 → newCount=15, plus run of 3 → 2+3=5
    const stack = [makeCard(4, "H"), makeCard(5, "D")];
    const card = makeCard(6, "C");
    assert.strictEqual(peggingPointsForPlay(stack, card, 9), 5);
  });
});
