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
