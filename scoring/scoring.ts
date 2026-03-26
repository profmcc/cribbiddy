import type { Card } from "./cards.ts";
import { cardValue } from "./cards.ts";

// ── Types ────────────────────────────────────────────────────────────────────

export interface Combo {
  cards: Card[];
  points: number;
  label: string;
}

export interface ScoreBreakdown {
  fifteens: Combo[];
  pairs: Combo[];
  runs: Combo[];
  flush: Combo | null;
  knobs: Combo | null;
}

export interface HandScore {
  total: number;
  breakdown: string[];
  details: ScoreBreakdown;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function copyCards(list: Card[]): Card[] {
  return list.slice();
}

// ── Fifteens ─────────────────────────────────────────────────────────────────

function fifteensScore(allCards: Card[]): [number, number] {
  const values = allCards.map(cardValue);
  let count = 0;
  const n = values.length;

  function search(start: number, total: number, picked: number) {
    if (total === 15 && picked >= 2) { count++; return; }
    if (total >= 15 || start >= n) return;
    for (let i = start; i < n; i++) {
      search(i + 1, total + values[i], picked + 1);
    }
  }

  search(0, 0, 0);
  return [count * 2, count];
}

function fifteensCombos(allCards: Card[]): Combo[] {
  const values = allCards.map(cardValue);
  const combos: Combo[] = [];
  const n = values.length;

  function search(start: number, total: number, picked: number, chosen: Card[]) {
    if (total === 15 && picked >= 2) {
      combos.push({ cards: copyCards(chosen), points: 2, label: "15" });
      return;
    }
    if (total >= 15 || start >= n) return;
    for (let i = start; i < n; i++) {
      chosen.push(allCards[i]);
      search(i + 1, total + values[i], picked + 1, chosen);
      chosen.pop();
    }
  }

  search(0, 0, 0, []);
  return combos;
}

// ── Pairs ────────────────────────────────────────────────────────────────────

function cardsByRank(allCards: Card[]): Map<number, Card[]> {
  const map = new Map<number, Card[]>();
  for (let rank = 1; rank <= 13; rank++) map.set(rank, []);
  for (const card of allCards) {
    if (!map.has(card.rank)) map.set(card.rank, []);
    map.get(card.rank)!.push(card);
  }
  return map;
}

function pairCombos(allCards: Card[]): Combo[] {
  const combos: Combo[] = [];
  const map = cardsByRank(allCards);
  for (let rank = 1; rank <= 13; rank++) {
    const list = map.get(rank) ?? [];
    if (list.length >= 2) {
      for (let i = 0; i < list.length - 1; i++) {
        for (let j = i + 1; j < list.length; j++) {
          combos.push({ cards: [list[i], list[j]], points: 2, label: "Pair" });
        }
      }
    }
  }
  return combos;
}

function pairsScore(allCards: Card[]): [number, number] {
  let pairs = 0;
  for (let i = 0; i < allCards.length - 1; i++) {
    for (let j = i + 1; j < allCards.length; j++) {
      if (allCards[i].rank === allCards[j].rank) pairs++;
    }
  }
  return [pairs * 2, pairs];
}

// ── Runs ─────────────────────────────────────────────────────────────────────

function runCombos(allCards: Card[]): Combo[] {
  const combos: Combo[] = [];
  const map = cardsByRank(allCards);
  const counts: number[] = new Array(14).fill(0);
  for (let rank = 1; rank <= 13; rank++) counts[rank] = (map.get(rank) ?? []).length;

  let runLength = 0;
  for (let length = 5; length >= 3; length--) {
    let runCount = 0;
    for (let start = 1; start <= 14 - length; start++) {
      let mult = 1;
      for (let r = start; r < start + length; r++) {
        if (counts[r] === 0) { mult = 0; break; }
        mult *= counts[r];
      }
      runCount += mult;
    }
    if (runCount > 0) { runLength = length; break; }
  }

  if (runLength === 0) return combos;

  function buildRuns(startRank: number, idx: number, current: Card[]) {
    if (idx > runLength) {
      combos.push({ cards: copyCards(current), points: runLength, label: `Run ${runLength}` });
      return;
    }
    const rank = startRank + idx - 1;
    for (const card of (map.get(rank) ?? [])) {
      current.push(card);
      buildRuns(startRank, idx + 1, current);
      current.pop();
    }
  }

  for (let start = 1; start <= 14 - runLength; start++) {
    let ok = true;
    for (let r = start; r < start + runLength; r++) {
      if (counts[r] === 0) { ok = false; break; }
    }
    if (ok) buildRuns(start, 1, []);
  }

  return combos;
}

function runScore(allCards: Card[]): [number, number, number] {
  const counts: number[] = new Array(14).fill(0);
  for (const card of allCards) counts[card.rank] = (counts[card.rank] ?? 0) + 1;

  for (let length = 5; length >= 3; length--) {
    let runCount = 0;
    for (let start = 1; start <= 14 - length; start++) {
      let mult = 1;
      for (let r = start; r < start + length; r++) {
        if (counts[r] === 0) { mult = 0; break; }
        mult *= counts[r];
      }
      runCount += mult;
    }
    if (runCount > 0) return [runCount * length, runCount, length];
  }

  return [0, 0, 0];
}

// ── Flush ────────────────────────────────────────────────────────────────────

function flushScore(hand: Card[], starter: Card | null, isCrib: boolean): number {
  if (hand.length !== 4) return 0;
  const suit = hand[0].suit;
  for (let i = 1; i < 4; i++) {
    if (hand[i].suit !== suit) return 0;
  }
  if (starter && starter.suit === suit) return 5;
  if (isCrib) return 0;
  return 4;
}

function flushCombo(hand: Card[], starter: Card | null, isCrib: boolean): Combo | null {
  const points = flushScore(hand, starter, isCrib);
  if (points === 0) return null;
  const cardsList = copyCards(hand);
  if (points === 5 && starter) cardsList.push(starter);
  return { cards: cardsList, points, label: "Flush" };
}

// ── Knobs ────────────────────────────────────────────────────────────────────

function knobsScore(hand: Card[], starter: Card | null): number {
  if (!starter) return 0;
  for (const card of hand) {
    if (card.rank === 11 && card.suit === starter.suit) return 1;
  }
  return 0;
}

function knobsCombo(hand: Card[], starter: Card | null): Combo | null {
  if (!starter) return null;
  for (const card of hand) {
    if (card.rank === 11 && card.suit === starter.suit) {
      return { cards: [card, starter], points: 1, label: "Knobs" };
    }
  }
  return null;
}

// ── Public API ───────────────────────────────────────────────────────────────

export function scoreHand(hand: Card[], starter: Card | null, isCrib = false): HandScore {
  const allCards = starter ? [...hand, starter] : [...hand];

  const fifteenDetails = fifteensCombos(allCards);
  const pairDetails = pairCombos(allCards);
  const runDetails = runCombos(allCards);
  const flushDetail = flushCombo(hand, starter, isCrib);
  const knobsDetail = knobsCombo(hand, starter);

  const breakdown: string[] = [];
  let total = 0;

  const [fifteens, fifteenCount] = fifteensScore(allCards);
  if (fifteens > 0) {
    breakdown.push(`Fifteens (${fifteenCount}): ${fifteens}`);
    total += fifteens;
  }

  const [pairs, pairCount] = pairsScore(allCards);
  if (pairs > 0) {
    breakdown.push(`Pairs (${pairCount}): ${pairs}`);
    total += pairs;
  }

  const [runs, runCount, runLength] = runScore(allCards);
  if (runs > 0) {
    breakdown.push(`Runs (${runCount}x${runLength}): ${runs}`);
    total += runs;
  }

  const flush = flushScore(hand, starter, isCrib);
  if (flush > 0) {
    breakdown.push(`Flush: ${flush}`);
    total += flush;
  }

  const knobs = knobsScore(hand, starter);
  if (knobs > 0) {
    breakdown.push(`Knobs: ${knobs}`);
    total += knobs;
  }

  if (breakdown.length === 0) breakdown.push("No score");

  return {
    total,
    breakdown,
    details: {
      fifteens: fifteenDetails,
      pairs: pairDetails,
      runs: runDetails,
      flush: flushDetail,
      knobs: knobsDetail,
    },
  };
}

// ── Pegging ──────────────────────────────────────────────────────────────────

function peggingPairPoints(stack: Card[], newCard: Card): number {
  let count = 1;
  for (let i = stack.length - 1; i >= 0; i--) {
    if (stack[i].rank === newCard.rank) count++;
    else break;
  }
  if (count === 2) return 2;
  if (count === 3) return 6;
  if (count === 4) return 12;
  return 0;
}

function peggingRunPoints(stackWithNew: Card[]): number {
  const maxLen = Math.min(7, stackWithNew.length);
  for (let length = maxLen; length >= 3; length--) {
    const ranks = new Set<number>();
    let minRank = 99;
    let maxRank = 0;
    let unique = true;
    for (let i = stackWithNew.length - length; i < stackWithNew.length; i++) {
      const rank = stackWithNew[i].rank;
      if (ranks.has(rank)) { unique = false; break; }
      ranks.add(rank);
      if (rank < minRank) minRank = rank;
      if (rank > maxRank) maxRank = rank;
    }
    if (unique && maxRank - minRank + 1 === length) return length;
  }
  return 0;
}

export function peggingPointsForPlay(stack: Card[], card: Card, count: number): number {
  let points = 0;
  const newCount = count + cardValue(card);
  if (newCount === 15 || newCount === 31) points += 2;
  points += peggingPairPoints(stack, card);
  const newStack = [...stack, card];
  points += peggingRunPoints(newStack);
  return points;
}
