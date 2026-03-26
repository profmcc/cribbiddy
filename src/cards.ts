export type Suit = 1 | 2 | 3 | 4;

export interface Card {
  rank: number;
  suit: Suit;
  enhancement?: string;
}

const SUITS = ["S", "H", "D", "C"] as const;
const RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"] as const;

export function cardValue(card: Card): number {
  if (card.rank === 14) return 11;
  if (card.rank === 15) return 12;
  if (card.rank > 10) return 10;
  return card.rank;
}

export function rankName(rank: number): string {
  if (rank === 0) return "0";
  if (rank === 14) return "11";
  if (rank === 15) return "12";
  return RANKS[rank - 1];
}

export function suitName(suit: Suit): string {
  return SUITS[suit - 1];
}

export function cardLabel(card: Card): string {
  return rankName(card.rank) + suitName(card.suit);
}

export function cardId(card: Card): string {
  return rankName(card.rank) + "-" + suitName(card.suit);
}

/** Parse "A-S", "10-H", "K-D" etc. into a Card */
export function parseCard(id: string): Card | null {
  const match = id.match(/^([^-]+)-(.+)$/);
  if (!match) return null;
  const rank = rankFromName(match[1]);
  const suitIndex = SUITS.indexOf(match[2] as any) + 1;
  if (rank === null || suitIndex === 0) return null;
  return { rank, suit: suitIndex as Suit };
}

export function rankFromName(name: string): number | null {
  if (name === "A") return 1;
  if (name === "J") return 11;
  if (name === "Q") return 12;
  if (name === "K") return 13;
  if (name === "0") return 0;
  if (name === "11") return 14;
  if (name === "12") return 15;
  const n = parseInt(name, 10);
  return isNaN(n) ? null : n;
}

/** Convenience: make a card from rank number and suit letter */
export function makeCard(rank: number, suit: "S" | "H" | "D" | "C"): Card {
  return { rank, suit: (SUITS.indexOf(suit) + 1) as Suit };
}

// ── Deck helpers ──────────────────────────────────────────────────────────────

function baseRanksForBoard(boardId?: string): number[] {
  const ranks: number[] = [];
  for (let rank = 1; rank <= 13; rank++) ranks.push(rank);
  if (boardId === "Dinosaurs") {
    ranks.push(0);
    ranks.push(14);
    ranks.push(15);
  }
  return ranks;
}

/** Fisher-Yates shuffle using Math.random(). Mutates and returns the deck. */
export function shuffle(deck: Card[]): Card[] {
  for (let i = deck.length - 1; i >= 1; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    const tmp = deck[i];
    deck[i] = deck[j];
    deck[j] = tmp;
  }
  return deck;
}

/**
 * Draw `count` cards from the end of the deck.
 * Returns [drawn, remaining] — does not mutate the original array.
 */
export function draw(deck: Card[], count: number): [Card[], Card[]] {
  const remaining = deck.slice(0, deck.length - count);
  const drawn = deck.slice(deck.length - count);
  return [drawn, remaining];
}

/**
 * Return the default per-card counts for a given board.
 * Each card appears once in a standard deck; the Dinosaurs board adds ranks 0, 14, 15.
 */
export function defaultCounts(boardId?: string): Record<string, number> {
  const counts: Record<string, number> = {};
  const ranks = baseRanksForBoard(boardId);
  for (let suit = 1; suit <= 4; suit++) {
    for (const rank of ranks) {
      const card: Card = { rank, suit: suit as Suit };
      const id = cardId(card);
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  return counts;
}

/**
 * Build a full deck of Card objects.
 *
 * Options:
 *   boardId      — selects the rank set (e.g. "Dinosaurs" adds ranks 0/14/15)
 *   deckCounts   — map of cardId → count; overrides the default full deck
 *   enhancements — map of cardId → enhancement string applied to each card
 */
export function buildDeck(options?: {
  boardId?: string;
  deckCounts?: Record<string, number>;
  enhancements?: Record<string, string>;
}): Card[] {
  const boardId = options?.boardId;
  const deckCounts = options?.deckCounts;
  const enhancements = options?.enhancements ?? {};
  const deck: Card[] = [];

  if (deckCounts) {
    for (const [id, count] of Object.entries(deckCounts)) {
      const parsed = parseCard(id);
      if (!parsed) continue;
      for (let n = 0; n < count; n++) {
        const card: Card = { rank: parsed.rank, suit: parsed.suit };
        if (enhancements[id]) card.enhancement = enhancements[id];
        deck.push(card);
      }
    }
  } else {
    const ranks = baseRanksForBoard(boardId);
    for (let suit = 1; suit <= 4; suit++) {
      for (const rank of ranks) {
        const card: Card = { rank, suit: suit as Suit };
        const id = cardId(card);
        if (enhancements[id]) card.enhancement = enhancements[id];
        deck.push(card);
      }
    }
  }

  return deck;
}
