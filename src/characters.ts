// characters.ts
// Defines all playable starting characters and their abilities

export interface ScoreEntry {
  type: string;
  points: number;
  length?: number;
}

export interface GameState {
  [key: string]: any;
}

export interface CharacterPassive {
  name: string;
  description: string;
  onScore: (self: CharacterPassive, scoreBreakdown: ScoreEntry[], gameState: GameState) => number;
}

export interface CharacterActive {
  name: string;
  description: string;
  usesRemaining: number;
  canTrigger: (self: CharacterActive, gameState: GameState) => boolean;
  onActivate: (self: CharacterActive, gameState: GameState) => number | string;
  onStreetStart?: (self: CharacterActive, gameState?: GameState) => void;
  stainedCard?: { suit: number; originalRank: number } | null;
  getStainedCardRank?: (self: CharacterActive, card: any, neededRank: number) => number;
}

export interface Character {
  id: string;
  name: string;
  visiting: string;
  description: string;
  color: [number, number, number];
  passive: CharacterPassive;
  active: CharacterActive;
  deathText: string;
}

export const characterList: Character[] = [
  {
    id: "benny",
    name: "Benny Biscuit",
    visiting: "Auntie Clover the Baker",
    description: "You've played cribbage with Auntie Clover a hundred times.",
    color: [0.85, 0.75, 0.80],

    passive: {
      name: "Extra Cookie",
      description: "Pairs always score +1 bonus peg.",
      onScore(self: CharacterPassive, scoreBreakdown: ScoreEntry[], gameState: GameState): number {
        let bonus = 0;
        for (const entry of scoreBreakdown) {
          if (entry.type === "pair" || entry.type === "triple" || entry.type === "quad") {
            bonus += 1;
          }
        }
        return bonus;
      },
    },

    active: {
      name: "Save Me a Slice",
      description: "Once per run: if you fail a street, score your hand a second time.",
      usesRemaining: 1,
      canTrigger(self: CharacterActive, gameState: GameState): boolean {
        return self.usesRemaining > 0 && gameState.street_failed === true;
      },
      onActivate(self: CharacterActive, gameState: GameState): number {
        self.usesRemaining -= 1;
        return gameState.last_hand_score ?? 0;
      },
    },

    deathText:
      "Auntie Clover shuffles over in her slippers and drapes a crocheted throw over you. She turns off the lamp and whispers 'you were so close, buttercup.' A small glass of water appears on the side table.",
  },

  {
    id: "marigold",
    name: "Marigold Mosswick",
    visiting: "Uncle Barnaby the Woodcarver",
    description: "You don't care about fifteens. You care about sequences.",
    color: [0.72, 0.80, 0.68],

    passive: {
      name: "Grain of the Wood",
      description: "Runs of 3 or more score +1 bonus peg.",
      onScore(self: CharacterPassive, scoreBreakdown: ScoreEntry[], gameState: GameState): number {
        let bonus = 0;
        for (const entry of scoreBreakdown) {
          if (entry.type === "run" && (entry.length ?? 0) >= 3) {
            bonus += 1;
          }
        }
        return bonus;
      },
    },

    active: {
      name: "One More Pass",
      description: "Once per street: after seeing the starter card, swap one card in your hand with the top of your deck.",
      usesRemaining: 0,
      canTrigger(self: CharacterActive, gameState: GameState): boolean {
        return self.usesRemaining > 0 && gameState.phase === "discard";
      },
      onActivate(self: CharacterActive, gameState: GameState): string {
        self.usesRemaining -= 1;
        return "swap_one";
      },
      onStreetStart(self: CharacterActive): void {
        self.usesRemaining = 1;
      },
    },

    deathText:
      "Uncle Barnaby sets down his carving. He puts a big warm hand on your head and says 'good effort, sprout.' He covers you up. There's a glass of water and a small wood chip on the table — he was carving while you played.",
  },

  {
    id: "pip",
    name: "Pip Tanglewood",
    visiting: "Auntie Vesper the Night Owl",
    description: "You're not sure you even know the rules. You know vibes.",
    color: [0.78, 0.72, 0.85],

    passive: {
      name: "Lucky Dip",
      description: "Nobs scores +2 pegs instead of +1.",
      onScore(self: CharacterPassive, scoreBreakdown: ScoreEntry[], gameState: GameState): number {
        let bonus = 0;
        for (const entry of scoreBreakdown) {
          if (entry.type === "nobs") {
            bonus += 2;
          }
        }
        return bonus;
      },
    },

    active: {
      name: "Tea Stain",
      description:
        "Once per run: choose a card. A tea stain permanently marks it — it counts as any rank you need each hand.",
      usesRemaining: 1,
      stainedCard: null,
      canTrigger(self: CharacterActive, gameState: GameState): boolean {
        return self.usesRemaining > 0;
      },
      onActivate(self: CharacterActive, gameState: GameState): string {
        self.usesRemaining -= 1;
        return "pick_tea_stain";
      },
      getStainedCardRank(self: CharacterActive, card: any, neededRank: number): number {
        if (
          self.stainedCard != null &&
          card.suit === self.stainedCard.suit &&
          card.original_rank === self.stainedCard.originalRank
        ) {
          return neededRank;
        }
        return card.rank;
      },
    },

    deathText:
      "Auntie Vesper is still awake when you drift off. She wraps you in her big quilted cardigan and leaves a note on the water glass: 'better luck next time, little chaos gremlin 🦊'",
  },

  {
    id: "rosette",
    name: "Rosette Puddingstone",
    visiting: "Uncle Pemberton the Retired Accountant",
    description: "Fifteen-two, fifteen-four, fifteen-six — you hear it in your dreams.",
    color: [0.91, 0.87, 0.70],

    passive: {
      name: "Perfect Accounting",
      description: "Any hand scoring 8+ pegs earns +$1 in the shop.",
      onScore(self: CharacterPassive, scoreBreakdown: ScoreEntry[], gameState: GameState): number {
        let total = 0;
        for (const entry of scoreBreakdown) {
          total += entry.points ?? 0;
        }
        if (total >= 8) {
          gameState.bonus_shop_gold = (gameState.bonus_shop_gold ?? 0) + 1;
        }
        return 0;
      },
    },

    active: {
      name: "Run the Numbers",
      description: "Once per street: peek at the next starter card before discarding.",
      usesRemaining: 0,
      canTrigger(self: CharacterActive, gameState: GameState): boolean {
        return (
          self.usesRemaining > 0 &&
          gameState.phase === "discard" &&
          gameState.starter_peeked === false
        );
      },
      onActivate(self: CharacterActive, gameState: GameState): string {
        self.usesRemaining -= 1;
        gameState.starter_peeked = true;
        return "peek_starter";
      },
      onStreetStart(self: CharacterActive, gameState?: GameState): void {
        self.usesRemaining = 1;
        if (gameState) {
          gameState.starter_peeked = false;
        }
      },
    },

    deathText:
      "Uncle Pemberton closes his ledger, gives a small nod, and says 'statistically sound effort.' He tucks you in with military precision. The water glass is placed at exactly a 90-degree angle from the corner of the table.",
  },
];

export function getById(id: string): Character | undefined {
  return characterList.find((char) => char.id === id);
}

export function onStreetStart(character: Character, gameState: GameState): void {
  if (character.active.onStreetStart) {
    character.active.onStreetStart(character.active, gameState);
  }
}

export function applyPassive(
  character: Character,
  scoreBreakdown: ScoreEntry[],
  gameState: GameState
): number {
  return character.passive.onScore(character.passive, scoreBreakdown, gameState);
}
