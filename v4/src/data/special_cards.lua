local M = {}

M.cards = {
  { id = "eraser", name = "The Eraser", effect = "Delete one card from your deck", cost = 6, rarity = "common", kind = "deletion" },
  { id = "purge", name = "The Purge", effect = "Delete up to 3 cards of the same rank", cost = 10, rarity = "uncommon", kind = "deletion" },
  { id = "cleanse", name = "The Cleanse", effect = "Delete all cards of one suit", cost = 15, rarity = "rare", kind = "deletion" },
  { id = "cull", name = "The Cull", effect = "Delete all unenhanced cards of one rank", cost = 8, rarity = "uncommon", kind = "deletion" },

  { id = "shifter", name = "The Shifter", effect = "Shift rank ±1 to ±3", cost = 5, rarity = "common", kind = "transform" },
  { id = "mimic", name = "The Mimic", effect = "Transform a card into a copy of another", cost = 7, rarity = "uncommon", kind = "transform" },
  { id = "suit_changer", name = "The Suit Changer", effect = "Change one card's suit", cost = 4, rarity = "common", kind = "transform" },
  { id = "wildcard_maker", name = "The Wildcard Maker", effect = "Make a card Wild", cost = 12, rarity = "rare", kind = "transform" },
  { id = "joker", name = "The Joker", effect = "Make a true Joker", cost = 20, rarity = "legendary", kind = "transform" },
  { id = "fossil", name = "The Fossil", effect = "Transform into 0/11/12", cost = 8, rarity = "uncommon", kind = "transform" },
  { id = "royal_decree", name = "The Royal Decree", effect = "Number -> face card", cost = 6, rarity = "common", kind = "transform" },
  { id = "humble", name = "The Humble", effect = "Face -> 5", cost = 6, rarity = "common", kind = "transform" },

  { id = "twin", name = "The Twin", effect = "Duplicate a card", cost = 9, rarity = "uncommon", kind = "duplicate" },
  { id = "triplet", name = "The Triplet", effect = "Create two copies", cost = 15, rarity = "rare", kind = "duplicate" },
  { id = "echo", name = "The Echo", effect = "Copy card, but Cursed", cost = 5, rarity = "common", kind = "duplicate" },
  { id = "shadow", name = "The Shadow", effect = "Copy card, but Phantom", cost = 12, rarity = "rare", kind = "duplicate" },

  { id = "fusion", name = "The Fusion", effect = "Merge two cards into a hybrid", cost = 10, rarity = "rare", kind = "merge" },
  { id = "pair_bond", name = "The Pair Bond", effect = "Merge a pair into a Double card", cost = 12, rarity = "rare", kind = "merge" },
  { id = "run_welder", name = "The Run Welder", effect = "Merge a run of 3 into a Sequence card", cost = 18, rarity = "legendary", kind = "merge" },

  { id = "splitter", name = "The Splitter", effect = "Split into adjacent ranks", cost = 7, rarity = "uncommon", kind = "split" },
  { id = "shatter", name = "The Shatter", effect = "Destroy one card, add 4 random cards", cost = 4, rarity = "common", kind = "split" },
  { id = "prism", name = "The Prism", effect = "Split into all four suits", cost = 14, rarity = "rare", kind = "split" },
}

M.shop_pool = {
  "eraser",
  "purge",
  "cleanse",
  "cull",
}

M.shop_rates = {
  Backyard = 0.05,
  Jungle = 0.10,
  Mountains = 0.15,
  Beach = 0.10,
  Cloudbenders = 0.20,
  Cavedwellers = 0.15,
  Aquatic = 0.10,
  Space = 0.20,
  Mars = 0.25,
  Dinosaurs = 0.15,
  Japan = 0.10,
}

function M.by_id(id)
  for i = 1, #M.cards do
    if M.cards[i].id == id then
      return M.cards[i]
    end
  end
  return nil
end

return M
