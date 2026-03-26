export interface ShopItem {
  id: string;
  name: string;
  effect: string;
  cost: number;
}

export interface ShopGroup {
  group: string;
  items: ShopItem[];
}

export const universal: ShopGroup[] = [
  {
    group: "Aunties",
    items: [
      { id: "auntie_rosemary", name: "Auntie Rosemary", effect: "All 5-value cards score +2 when part of a fifteen", cost: 6 },
      { id: "auntie_clover", name: "Auntie Clover", effect: "All pairs score +2 bonus points", cost: 7 },
      { id: "auntie_meadow", name: "Auntie Meadow", effect: "Runs score +1 per card in the run", cost: 8 },
      { id: "auntie_willow_story", name: "Auntie Willow", effect: "Nobs worth 3 points instead of 1", cost: 5 },
      { id: "auntie_hazel_blend", name: "Auntie Hazel", effect: "If all 4 cards are different ranks, gain +3 bonus points", cost: 6 },
      { id: "auntie_poppy", name: "Auntie Poppy", effect: "If hand has a pair and a fifteen, gain +5 bonus points", cost: 7 },
      { id: "auntie_maple", name: "Auntie Maple", effect: "At round start, copy a random Auntie you own for the round", cost: 10 },
      { id: "auntie_dahlia", name: "Auntie Dahlia", effect: "+4 points at end of each hand scored", cost: 5 },
      { id: "auntie_fern", name: "Auntie Fern", effect: "Face cards score +3 bonus points when played", cost: 6 },
      { id: "auntie_ivy", name: "Auntie Ivy", effect: "First scored hand each round counts twice", cost: 12 },
      { id: "auntie_juniper", name: "Auntie Juniper", effect: "Every 3rd hand each round scores +8 bonus points", cost: 7 },
      { id: "auntie_magnolia", name: "Auntie Magnolia", effect: "If all 4 cards are same suit, gain +6 bonus points", cost: 8 },
      { id: "auntie_laurel", name: "Auntie Laurel", effect: "Each card played gives +1 point (always +4)", cost: 6 },
      { id: "auntie_violet", name: "Auntie Violet", effect: "All hearts score +3 bonus when played", cost: 7 },
      { id: "auntie_heather", name: "Auntie Heather", effect: "If hand has a King and Queen, gain +10 bonus points", cost: 9 },
      { id: "auntie_marigold", name: "Auntie Marigold", effect: "Number cards +2 bonus, face cards -1 penalty", cost: 7 },
      { id: "auntie_primrose", name: "Auntie Primrose", effect: "All clubs score +3 bonus; all-clubs hand doubles score", cost: 8 },
      { id: "auntie_tansy", name: "Auntie Tansy", effect: "Each discard used this round gives +2 to round score", cost: 6 },
    ],
  },
  {
    group: "Uncles",
    items: [
      { id: "uncle_bramble", name: "Uncle Bramble", effect: "Transform any card into a 5 of any suit", cost: 4 },
      { id: "uncle_cedar", name: "Uncle Cedar", effect: "Transform any card into the next rank you need", cost: 5 },
      { id: "uncle_oakley", name: "Uncle Oakley", effect: "Transform any card to match a rank you already have", cost: 3 },
      { id: "uncle_birch", name: "Uncle Birch", effect: "Transform any card into a 10 or face card", cost: 4 },
      { id: "uncle_sage", name: "Uncle Sage", effect: "Add 2 new cards of your choice to your deck", cost: 6 },
      { id: "uncle_ash", name: "Uncle Ash", effect: "Transform any card into a Golden Card (1.5x rank for fifteens)", cost: 8 },
      { id: "uncle_rowan", name: "Uncle Rowan", effect: "Change any card's suit to clubs", cost: 3 },
      { id: "uncle_sycamore", name: "Uncle Sycamore", effect: "Change any card's suit to hearts", cost: 3 },
      { id: "uncle_cypress", name: "Uncle Cypress", effect: "Change any card's suit to diamonds", cost: 3 },
      { id: "uncle_elm", name: "Uncle Elm", effect: "Change any card's suit to spades", cost: 3 },
      { id: "uncle_hickory", name: "Uncle Hickory", effect: "Destroy 2 cards permanently. Gain $4", cost: 5 },
      { id: "uncle_willow", name: "Uncle Willow", effect: "Transform all cards in hand to match one chosen rank", cost: 7 },
      { id: "uncle_chestnut", name: "Uncle Chestnut", effect: "Transform any card into a Toy Card (random rank each play)", cost: 6 },
      { id: "uncle_alder", name: "Uncle Alder", effect: "Randomize all ranks in your hand (keeps suits)", cost: 4 },
      { id: "uncle_linden", name: "Uncle Linden", effect: "Duplicate any card in your deck", cost: 9 },
    ],
  },
  {
    group: "Legendary Items",
    items: [
      { id: "grandmothers_recipe", name: "Grandmother's Recipe Book", effect: "Look at top 5 cards of your deck and reorder each round", cost: 22 },
      { id: "harvest_moon", name: "Harvest Moon", effect: "All scoring combinations worth 1.5x (rounded up)", cost: 25 },
      { id: "family_heirloom_deck", name: "Family Heirloom Deck", effect: "Start each round with +1 extra discard", cost: 20 },
      { id: "cozy_hearth", name: "Cozy Hearth", effect: "First hand each round scores double", cost: 24 },
    ],
  },
];

export const boardSpecific: Record<string, ShopItem[]> = {};
