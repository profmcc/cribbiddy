local M = {}

M.universal = {
  { id = "honeycomb_card", name = "Honeycomb Card", effect = "Counts as any rank for pairs only", cost = 10 },
  { id = "patchwork_card", name = "Patchwork Card", effect = "Counts as two ranks simultaneously (choose when applied)", cost = 15 },
  { id = "pressed_flower_card", name = "Pressed Flower Card", effect = "Combination scores +3 bonus points when included", cost = 12 },
  { id = "candlelight_card", name = "Candlelight Card", effect = "Pairs this card is part of score double", cost = 14 },
  { id = "acorn_card", name = "Acorn Card", effect = "Starts A-3, permanently +1 rank each time played", cost = 8 },
  { id = "basket_weave_card", name = "Basket Weave Card", effect = "Hand counts as flush when this card is played", cost = 10 },
  { id = "morning_dew_card", name = "Morning Dew Card", effect = "Refreshes as a different random card next hand", cost = 9 },
  { id = "stone_card", name = "Stone Card", effect = "+6 flat points when played, cannot be in runs", cost = 11 },
  { id = "steel_card", name = "Steel Card", effect = "1.5x multiplier to hand score, cannot be discarded or transformed", cost = 13 },
  { id = "glass_card", name = "Glass Card", effect = "Doubles hand score, breaks if not played for 2 consecutive hands", cost = 15 },
  { id = "lucky_card", name = "Lucky Card", effect = "25% chance to score +10 points when played", cost = 10 },
  { id = "wild_card", name = "Wild Card", effect = "Counts as all suits for flush purposes", cost = 12 },
  { id = "bonus_card", name = "Bonus Card", effect = "+5 flat points every time it's played", cost = 9 },
  { id = "mult_card", name = "Mult Card", effect = "Multiplies hand score by 1.3x when played", cost = 14 },
  { id = "echo_card", name = "Echo Card", effect = "Combination this card is in scores twice", cost = 16 },
  { id = "foil_card", name = "Foil Card", effect = "+3 to every combo it's in and +3 flat bonus", cost = 18 },
  { id = "negative_card", name = "Negative Card", effect = "Allows +1 extra card in hand (10 instead of 9)", cost = 20 },
  { id = "eternal_card", name = "Eternal Card", effect = "Cannot be discarded or removed; +2 points per hand", cost = 8 },
  { id = "perishable_card", name = "Perishable Card", effect = "+8 bonus points when played, lasts 5 hands", cost = 6 },
  { id = "rental_card", name = "Rental Card", effect = "+6 bonus points when played, costs $1 each play", cost = 5 },
  { id = "pinned_card", name = "Pinned Card", effect = "Cannot be played, gives +1 point to every other card in hand", cost = 11 },
  { id = "grandmothers_recipe", name = "Grandmother's Recipe Book", effect = "Look at top 5 cards of your deck and reorder each round", cost = 22 },
  { id = "harvest_moon", name = "Harvest Moon", effect = "All scoring combinations worth 1.5x (rounded up)", cost = 25 },
  { id = "family_heirloom_deck", name = "Family Heirloom Deck", effect = "Start each round with +1 extra discard", cost = 20 },
  { id = "cozy_hearth", name = "Cozy Hearth", effect = "First hand each round scores double", cost = 24 },
}

M.board_specific = {}

return M
