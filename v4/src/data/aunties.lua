local M = {}

M.universal = {
  {
    group = "Flat Bonus",
    items = {
      { id = "uncle_earl", name = "Uncle Earl", effect = "+4 pegs per hand", cost = 4 },
      { id = "auntie_mae", name = "Auntie Mae", effect = "+2 pegs per card in a run", cost = 5 },
      { id = "uncle_bob", name = "Uncle Bob", effect = "+6 pegs if you score exactly 15 total", cost = 4 },
      { id = "auntie_dot", name = "Auntie Dot", effect = "+1 peg per card played during pegging", cost = 3 },
    },
  },
  {
    group = "Multiplier-Based",
    items = {
      { id = "auntie_bev", name = "Auntie Bev", effect = "+2 mult for every fifteen you count", cost = 6 },
      { id = "uncle_clarence", name = "Uncle Clarence", effect = "+3 mult if your hand contains a pair", cost = 5 },
      { id = "auntie_faye", name = "Auntie Faye", effect = "+1 mult per face card in your scoring hand", cost = 5 },
      { id = "uncle_monty", name = "Uncle Monty", effect = "x1.5 mult if you score 20+ pegs base", cost = 7 },
      { id = "auntie_opal", name = "Auntie Opal", effect = "+4 mult if your hand is all red or all black", cost = 6 },
    },
  },
  {
    group = "Scaling/Degrading",
    items = {
      { id = "uncle_hank", name = "Uncle Hank", effect = "Starts at +20 pegs, loses 2 each hand. Resets each Street.", cost = 5 },
      { id = "auntie_gert", name = "Auntie Gert", effect = "+1 peg per hand played this Street (cumulative)", cost = 4 },
      { id = "uncle_norm", name = "Uncle Norm", effect = "+1 mult per phase completed this board (permanent scaling)", cost = 8 },
      { id = "auntie_iris", name = "Auntie Iris", effect = "First hand each Street: x2 mult. Decreases by 0.25 each hand after.", cost = 6 },
    },
  },
  {
    group = "Suit-Based",
    items = {
      { id = "auntie_rose", name = "Auntie Rose", effect = "+3 mult if your hand has a flush (4+ same suit)", cost = 6 },
      { id = "uncle_chip", name = "Uncle Chip", effect = "+2 pegs per spade in your hand", cost = 4 },
      { id = "auntie_blanche", name = "Auntie Blanche", effect = "+2 pegs per heart in your hand", cost = 4 },
      { id = "uncle_clyde", name = "Uncle Clyde", effect = "+2 pegs per club in your hand", cost = 4 },
      { id = "auntie_dee", name = "Auntie Dee", effect = "+2 pegs per diamond in your hand", cost = 4 },
      { id = "uncle_sully", name = "Uncle Sully", effect = "+5 pegs if your hand contains all four suits", cost = 5 },
    },
  },
  {
    group = "Rank-Based",
    items = {
      { id = "auntie_midge", name = "Auntie Midge", effect = "5s score +3 pegs each when part of a fifteen", cost = 5 },
      { id = "uncle_lenny", name = "Uncle Lenny", effect = "Face cards (J/Q/K) count as 9 for fifteens (opens new combos)", cost = 6 },
      { id = "auntie_wren", name = "Auntie Wren", effect = "Aces score +2 pegs each", cost = 4 },
      { id = "uncle_dutch", name = "Uncle Dutch", effect = "Face cards score twice during counting", cost = 7 },
      { id = "auntie_penny", name = "Auntie Penny", effect = "2s and 3s score +1 peg each", cost = 3 },
    },
  },
  {
    group = "Held Card / Hand Management",
    items = {
      { id = "auntie_mim", name = "Auntie Mim", effect = "Each card held in hand (not played to crib) gives +1 mult", cost = 5 },
      { id = "uncle_vern", name = "Uncle Vern", effect = "If you discard a pair to crib, +4 pegs", cost = 4 },
      { id = "auntie_june", name = "Auntie June", effect = "If you keep all four suits in hand, +6 pegs", cost = 5 },
      { id = "uncle_gus_no_faces", name = "Uncle Gus", effect = "+8 pegs if you keep no face cards in hand", cost = 5 },
    },
  },
  {
    group = "Crib Manipulation",
    items = {
      { id = "auntie_nettie", name = "Auntie Nettie", effect = "Crib penalty reduced by 25% (when crib works against you)", cost = 6 },
      { id = "uncle_walt", name = "Uncle Walt", effect = "When crib is yours, it scores x1.5", cost = 6 },
      { id = "auntie_cora", name = "Auntie Cora", effect = "You may look at one crib card before discarding", cost = 7 },
      { id = "uncle_red", name = "Uncle Red", effect = "If crib scores 0 against you, gain $3", cost = 5 },
    },
  },
  {
    group = "Risk/Reward",
    items = {
      { id = "uncle_gus_risk", name = "Uncle Gus", effect = "x2 mult, but one random Auntie/Uncle leaves after each Street", cost = 6 },
      { id = "auntie_hazel", name = "Auntie Hazel", effect = "+15 pegs per hand, but you draw one fewer card", cost = 7 },
      { id = "uncle_butch", name = "Uncle Butch", effect = "Pegging points doubled, but opponent pegs +2 per go", cost = 5 },
      { id = "auntie_trixie", name = "Auntie Trixie", effect = "+10 pegs if you complete the phase this hand, -5 if you don't", cost = 5 },
    },
  },
  {
    group = "Economy",
    items = {
      { id = "auntie_pearl", name = "Auntie Pearl", effect = "Earn $3 if your hand scores exactly a fifteen (the combo, not 15 pegs)", cost = 4 },
      { id = "uncle_mort", name = "Uncle Mort", effect = "+$1 per Street completed", cost = 5 },
      { id = "auntie_edna", name = "Auntie Edna", effect = "Shop prices reduced by $1 (minimum $1)", cost = 6 },
      { id = "uncle_sal", name = "Uncle Sal", effect = "Peg threshold bonuses give +50% money", cost = 6 },
      { id = "auntie_winnie", name = "Auntie Winnie", effect = "Earn $2 whenever you complete a phase in one hand", cost = 5 },
    },
  },
  {
    group = "Synergy / Copying",
    items = {
      { id = "uncle_vic", name = "Uncle Vic", effect = "Copies the Auntie/Uncle to his left", cost = 7 },
      { id = "auntie_fran", name = "Auntie Fran", effect = "Can hold +1 extra family member", cost = 8 },
      { id = "uncle_lou", name = "Uncle Lou", effect = "All Aunties give +1 additional peg", cost = 5 },
      { id = "auntie_bess", name = "Auntie Bess", effect = "All Uncles give +1 additional mult", cost = 5 },
    },
  },
  {
    group = "Pegging-Focused",
    items = {
      { id = "uncle_slim", name = "Uncle Slim", effect = "+3 pegs every time you hit exactly 15 during pegging", cost = 5 },
      { id = "auntie_dottie", name = "Auntie Dottie", effect = "+2 pegs every time you hit exactly 31", cost = 5 },
      { id = "uncle_frank", name = "Uncle Frank", effect = "+1 peg per \"go\" you force opponent into", cost = 4 },
      { id = "auntie_vera", name = "Auntie Vera", effect = "Your pegging runs score double", cost = 6 },
      { id = "uncle_ike", name = "Uncle Ike", effect = "Your pegging pairs score +2", cost = 4 },
    },
  },
  {
    group = "Retrigger / Multi-Score",
    items = {
      { id = "auntie_glenda", name = "Auntie Glenda", effect = "Fifteens score twice (but second time at half value)", cost = 7 },
      { id = "uncle_theo", name = "Uncle Theo", effect = "Pairs have 25% chance to score as trips", cost = 6 },
      { id = "auntie_mabel", name = "Auntie Mabel", effect = "Runs have 25% chance to score twice", cost = 6 },
    },
  },
  {
    group = "Defensive / Recovery",
    items = {
      { id = "uncle_roy", name = "Uncle Roy", effect = "If you score under 10 pegs, gain $2 (pity money)", cost = 3 },
      { id = "auntie_nell", name = "Auntie Nell", effect = "If crib scores 10+ against you, reduce penalty by half", cost = 5 },
      { id = "uncle_burt", name = "Uncle Burt", effect = "Start each Street with +5 pegs banked", cost = 5 },
    },
  },
}

M.board_specific = {
  Jungle = {
    { id = "auntie_liana", name = "Auntie Liana", effect = "Runs of 4+ trigger twice", cost = 7 },
    { id = "uncle_macaw", name = "Uncle Macaw", effect = "Cards that would be vined instead give +2 pegs", cost = 5 },
    { id = "auntie_orchid", name = "Auntie Orchid", effect = "Flushes ignore flood/vine penalties", cost = 6 },
  },
  Mountains = {
    { id = "uncle_sherpa", name = "Uncle Sherpa", effect = "Immune to hand size reductions", cost = 6 },
    { id = "auntie_frost", name = "Auntie Frost", effect = "Frostbitten cards give +3 pegs instead of 0", cost = 6 },
    { id = "uncle_summit", name = "Uncle Summit", effect = "Altitude multiplier increases by +0.25 per Street (instead of +0.5 every other)", cost = 7 },
  },
  Beach = {
    { id = "auntie_coral", name = "Auntie Coral", effect = "Flooded Streets give +4 bonus pegs instead of penalties", cost = 7 },
    { id = "uncle_gull", name = "Uncle Gull", effect = "Washed-away cards return next hand", cost = 5 },
    { id = "auntie_sandy", name = "Auntie Sandy", effect = "Tide roll always treated as one lower (reduces flood chance)", cost = 6 },
  },
  Cloudbenders = {
    { id = "uncle_zephyr", name = "Uncle Zephyr", effect = "May look at cut card before discarding to crib", cost = 8 },
    { id = "auntie_cirrus", name = "Auntie Cirrus", effect = "Cards swapped via Cloudwalk score +2 each", cost = 5 },
    { id = "uncle_nimbus", name = "Uncle Nimbus", effect = "Random Auntie/Uncle effects on Thunderhead Street are always beneficial", cost = 6 },
  },
  Cavedwellers = {
    { id = "auntie_glimmer", name = "Auntie Glimmer", effect = "Always reveals one extra card in Darkness", cost = 6 },
    { id = "uncle_bat", name = "Uncle Bat", effect = "Pairs in hidden cards still score (blind scoring)", cost = 7 },
    { id = "auntie_echo", name = "Auntie Echo", effect = "Echoing Street bonus (pairs as trips) applies to all Streets", cost = 8 },
  },
  Aquatic = {
    { id = "uncle_finnegan", name = "Uncle Finnegan", effect = "Currents don't affect your hand (suits stay true)", cost = 7 },
    { id = "auntie_nautia", name = "Auntie Nautia", effect = "3-card flushes always allowed (not just Coral Throne Street)", cost = 6 },
    { id = "uncle_depth", name = "Uncle Depth", effect = "Pressure (reduced hand) gives +5 pegs compensation", cost = 5 },
  },
  Space = {
    { id = "auntie_nova", name = "Auntie Nova", effect = "Orbited cards return with +2 rank", cost = 6 },
    { id = "uncle_cosmo", name = "Uncle Cosmo", effect = "Orbit time reduced to 1 hand (instead of 2)", cost = 7 },
    { id = "auntie_void", name = "Auntie Void", effect = "Effects still work on Void Street", cost = 8 },
  },
  Mars = {
    { id = "uncle_rusty", name = "Uncle Rusty", effect = "Supply drops trigger on d6 = 5 or 6 (instead of just 6)", cost = 5 },
    { id = "auntie_dusty", name = "Auntie Dusty", effect = "Dust Storm Street: you can see cut card", cost = 6 },
    { id = "uncle_colony", name = "Uncle Colony", effect = "Rare shops have +2 extra items", cost = 6 },
  },
  Dinosaurs = {
    { id = "auntie_amber", name = "Auntie Amber", effect = "Prehistoric cards (0, 11, 12) score double", cost = 7 },
    { id = "uncle_rex", name = "Uncle Rex", effect = "Extinction Event doesn't happen (keep all Aunties/Uncles)", cost = 9 },
    { id = "auntie_paleo", name = "Auntie Paleo", effect = "Tar Pit stuck cards go to crib instead of vanishing", cost = 5 },
  },
  Japan = {
    { id = "uncle_kenji", name = "Uncle Kenji", effect = "Reveals one possible Kata at start of each hand", cost = 6 },
    { id = "auntie_sakura", name = "Auntie Sakura", effect = "Completing a Kata gives +$3 in addition to other bonuses", cost = 5 },
    { id = "uncle_ronin", name = "Uncle Ronin", effect = "Kata requirements reduced by 1 card", cost = 8 },
  },
}

return M
