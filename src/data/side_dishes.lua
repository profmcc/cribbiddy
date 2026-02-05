local M = {}

M.universal = {
  { id = "beer", name = "Beer", effect = "Downgrade a face card to a 10", cost = 2 },
  { id = "wine", name = "Wine", effect = "Upgrade a number card by +2 rank", cost = 3 },
  { id = "coffee", name = "Coffee", effect = "Draw 2 extra cards next hand", cost = 3 },
  { id = "cake", name = "Cake", effect = "+$5 immediately", cost = 2 },
  { id = "whiskey", name = "Whiskey", effect = "Destroy a card permanently, gain +10 pegs this hand", cost = 3 },
  { id = "pie", name = "Pie", effect = "Duplicate a card in your hand", cost = 4 },
  { id = "joint", name = "Joint", effect = "Shuffle your hand back, redraw same count", cost = 2 },
  { id = "edible", name = "Edible", effect = "Random effect (any Side Dish)", cost = 2 },
  { id = "lemonade", name = "Lemonade", effect = "Remove a card from the crib before it scores against you", cost = 4 },
  { id = "casserole", name = "Casserole", effect = "Add a random Auntie/Uncle for this Street only", cost = 5 },
  { id = "espresso", name = "Espresso", effect = "Take two shop actions instead of one", cost = 3 },
  { id = "moonshine", name = "Moonshine", effect = "Double your next Auntie/Uncle's effect, then they leave", cost = 4 },
  { id = "sushi", name = "Sushi", effect = "Peek at opponent's pegging hand before playing", cost = 3 },
  { id = "hot_dog", name = "Hot Dog", effect = "+3 pegs immediately", cost = 1 },
  { id = "popcorn", name = "Popcorn", effect = "See the cut card before discarding to crib", cost = 3 },
  { id = "pretzels", name = "Pretzels", effect = "Swap one card between hand and crib after discarding", cost = 3 },
  { id = "nachos", name = "Nachos", effect = "All pairs score +1 this hand", cost = 2 },
  { id = "wings", name = "Wings", effect = "All runs score +1 per card this hand", cost = 2 },
  { id = "cookies", name = "Cookies", effect = "All fifteens score +1 this hand", cost = 2 },
  { id = "tea", name = "Tea", effect = "Remove one negative Street condition for this hand", cost = 4 },
  { id = "water", name = "Water", effect = "Restore one destroyed card to deck", cost = 3 },
}

M.board_specific = {
  Jungle = { { id = "coconut", name = "Coconut", effect = "Vined cards are freed", cost = 2 } },
  Mountains = {
    { id = "trail_mix", name = "Trail Mix", effect = "+1 hand size for this Street", cost = 3 },
    { id = "hot_cocoa", name = "Hot Cocoa", effect = "Frostbitten card still scores half value", cost = 2 },
  },
  Beach = {
    { id = "sunscreen", name = "Sunscreen", effect = "Tide roll treated as 2 lower", cost = 3 },
    { id = "seaweed_wrap", name = "Seaweed Wrap", effect = "Washed-away card returns immediately", cost = 2 },
  },
  Cloudbenders = { { id = "cloud_candy", name = "Cloud Candy", effect = "Cloudwalk swaps increased by +1", cost = 3 } },
  Cavedwellers = { { id = "mushroom", name = "Mushroom", effect = "See +2 extra cards in Darkness", cost = 3 } },
  Aquatic = { { id = "kelp_chips", name = "Kelp Chips", effect = "Currents don't affect you this hand", cost = 3 } },
  Space = { { id = "freeze_dried_meal", name = "Freeze-Dried Meal", effect = "Orbited card returns immediately", cost = 3 } },
  Mars = { { id = "oxygen_tank", name = "Oxygen Tank", effect = "Guarantee supply drop this hand", cost = 2 } },
  Dinosaurs = { { id = "raw_meat", name = "Raw Meat", effect = "Prehistoric cards score triple this hand", cost = 4 } },
  Japan = {
    { id = "sake", name = "Sake", effect = "Next Kata requirement reduced by 1 card", cost = 4 },
    { id = "mochi", name = "Mochi", effect = "Completing a Kata also gives +$3", cost = 3 },
  },
}

return M
