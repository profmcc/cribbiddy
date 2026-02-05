local M = {}

M.FAMILY_CONFIG = {
  starting_slots = 3,
  max_slots = 6,
  sell_percentage = 0.5,
}

M.RARITY_WEIGHTS = {
  common = 50,
  uncommon = 30,
  rare = 15,
  legendary = 5,
}

M.EFFECT_TIMING = {
  ON_HAND_SCORE = "on_hand_score",
  ON_FIFTEEN = "on_fifteen",
  ON_PAIR = "on_pair",
  ON_RUN = "on_run",
  ON_FLUSH = "on_flush",
  ON_PEGGING = "on_pegging",
  ON_CRIB = "on_crib",
  ON_STREET_START = "on_street_start",
  ON_STREET_END = "on_street_end",
  ON_HAND_START = "on_hand_start",
  ON_DISCARD = "on_discard",
  PASSIVE = "passive",
  ON_SHOP = "on_shop",
}

M.AUNTIES_UNCLES = {
  uncle_earl = {
    name = "Uncle Earl",
    description = "+4 pegs per hand",
    cost = 4,
    rarity = "common",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    effect = function(_context)
      return { pegs = 4 }
    end,
  },

  auntie_mae = {
    name = "Auntie Mae",
    description = "+2 pegs per card in a run",
    cost = 5,
    rarity = "common",
    timing = M.EFFECT_TIMING.ON_RUN,
    board_specific = nil,
    effect = function(context)
      return { pegs = context.run_length * 2 }
    end,
  },

  uncle_bob = {
    name = "Uncle Bob",
    description = "+6 pegs if hand scores exactly 15",
    cost = 4,
    rarity = "common",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    effect = function(context)
      if context.base_score == 15 then
        return { pegs = 6 }
      end
      return { pegs = 0 }
    end,
  },

  auntie_dot = {
    name = "Auntie Dot",
    description = "+1 peg per card played during pegging",
    cost = 3,
    rarity = "common",
    timing = M.EFFECT_TIMING.ON_PEGGING,
    board_specific = nil,
    effect = function(context)
      return { pegs = context.cards_played }
    end,
  },

  auntie_bev = {
    name = "Auntie Bev",
    description = "+2 mult for every fifteen you count",
    cost = 6,
    rarity = "uncommon",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    effect = function(context)
      return { mult_add = context.fifteens_count * 2 }
    end,
  },

  uncle_clarence = {
    name = "Uncle Clarence",
    description = "+3 mult if your hand contains a pair",
    cost = 5,
    rarity = "uncommon",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    effect = function(context)
      if context.pairs_count > 0 then
        return { mult_add = 3 }
      end
      return { mult_add = 0 }
    end,
  },

  auntie_faye = {
    name = "Auntie Faye",
    description = "+1 mult per face card in your scoring hand",
    cost = 5,
    rarity = "uncommon",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    effect = function(context)
      return { mult_add = context.face_cards_count }
    end,
  },

  uncle_monty = {
    name = "Uncle Monty",
    description = "x1.5 mult if you score 20+ pegs base",
    cost = 7,
    rarity = "rare",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    effect = function(context)
      if context.base_score >= 20 then
        return { mult_multiply = 1.5 }
      end
      return { mult_multiply = 1 }
    end,
  },

  auntie_opal = {
    name = "Auntie Opal",
    description = "+4 mult if hand is all red or all black",
    cost = 6,
    rarity = "uncommon",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    effect = function(context)
      if context.all_red or context.all_black then
        return { mult_add = 4 }
      end
      return { mult_add = 0 }
    end,
  },

  uncle_hank = {
    name = "Uncle Hank",
    description = "Starts +20 pegs, loses 2 each hand. Resets each Street.",
    cost = 5,
    rarity = "uncommon",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    state = { current_bonus = 20 },
    effect = function(_context, state)
      local bonus = state.current_bonus
      state.current_bonus = math.max(0, state.current_bonus - 2)
      return { pegs = bonus }
    end,
    on_street_start = function(state)
      state.current_bonus = 20
    end,
  },

  auntie_gert = {
    name = "Auntie Gert",
    description = "+1 peg per hand played this Street (cumulative)",
    cost = 4,
    rarity = "common",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    effect = function(context)
      return { pegs = context.hands_played_this_street }
    end,
  },

  uncle_norm = {
    name = "Uncle Norm",
    description = "+1 mult per phase completed this board",
    cost = 8,
    rarity = "rare",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    effect = function(context)
      return { mult_add = context.phases_completed_this_board }
    end,
  },

  auntie_iris = {
    name = "Auntie Iris",
    description = "First hand each Street: x2 mult. Decreases by 0.25 each hand.",
    cost = 6,
    rarity = "uncommon",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    state = { current_mult = 2.0 },
    effect = function(_context, state)
      local mult = state.current_mult
      state.current_mult = math.max(1.0, state.current_mult - 0.25)
      return { mult_multiply = mult }
    end,
    on_street_start = function(state)
      state.current_mult = 2.0
    end,
  },

  auntie_rose = {
    name = "Auntie Rose",
    description = "+3 mult if your hand has a flush (4+ same suit)",
    cost = 6,
    rarity = "uncommon",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    effect = function(context)
      if context.has_flush then
        return { mult_add = 3 }
      end
      return { mult_add = 0 }
    end,
  },

  uncle_chip = {
    name = "Uncle Chip",
    description = "+2 pegs per spade in your hand",
    cost = 4,
    rarity = "common",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    effect = function(context)
      return { pegs = context.suits.spades * 2 }
    end,
  },

  auntie_blanche = {
    name = "Auntie Blanche",
    description = "+2 pegs per heart in your hand",
    cost = 4,
    rarity = "common",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    effect = function(context)
      return { pegs = context.suits.hearts * 2 }
    end,
  },

  uncle_clyde = {
    name = "Uncle Clyde",
    description = "+2 pegs per club in your hand",
    cost = 4,
    rarity = "common",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    effect = function(context)
      return { pegs = context.suits.clubs * 2 }
    end,
  },

  auntie_dee = {
    name = "Auntie Dee",
    description = "+2 pegs per diamond in your hand",
    cost = 4,
    rarity = "common",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    effect = function(context)
      return { pegs = context.suits.diamonds * 2 }
    end,
  },

  uncle_sully = {
    name = "Uncle Sully",
    description = "+5 pegs if your hand contains all four suits",
    cost = 5,
    rarity = "uncommon",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    effect = function(context)
      if context.suits.spades > 0 and context.suits.hearts > 0
        and context.suits.clubs > 0 and context.suits.diamonds > 0 then
        return { pegs = 5 }
      end
      return { pegs = 0 }
    end,
  },

  auntie_midge = {
    name = "Auntie Midge",
    description = "5s score +3 pegs each when part of a fifteen",
    cost = 5,
    rarity = "uncommon",
    timing = M.EFFECT_TIMING.ON_FIFTEEN,
    board_specific = nil,
    effect = function(context)
      local fives_in_fifteen = 0
      for _, card in ipairs(context.cards_in_fifteen) do
        if card.rank == 5 then
          fives_in_fifteen = fives_in_fifteen + 1
        end
      end
      return { pegs = fives_in_fifteen * 3 }
    end,
  },

  uncle_lenny = {
    name = "Uncle Lenny",
    description = "Face cards count as 9 for fifteens (new combos!)",
    cost = 6,
    rarity = "rare",
    timing = M.EFFECT_TIMING.PASSIVE,
    board_specific = nil,
    modifier = function(card)
      if card.rank >= 11 then
        return { fifteen_value = 9 }
      end
      return nil
    end,
  },

  auntie_wren = {
    name = "Auntie Wren",
    description = "Aces score +2 pegs each",
    cost = 4,
    rarity = "common",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    effect = function(context)
      return { pegs = context.aces_count * 2 }
    end,
  },

  uncle_dutch = {
    name = "Uncle Dutch",
    description = "Face cards score twice during counting",
    cost = 7,
    rarity = "rare",
    timing = M.EFFECT_TIMING.PASSIVE,
    board_specific = nil,
    modifier = function(card)
      if card.rank >= 11 then
        return { retrigger = true }
      end
      return nil
    end,
  },

  auntie_penny = {
    name = "Auntie Penny",
    description = "2s and 3s score +1 peg each",
    cost = 3,
    rarity = "common",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    effect = function(context)
      return { pegs = (context.twos_count + context.threes_count) }
    end,
  },

  auntie_mim = {
    name = "Auntie Mim",
    description = "+1 mult per card kept in hand (not cribbed)",
    cost = 5,
    rarity = "uncommon",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    effect = function(context)
      return { mult_add = context.cards_in_hand }
    end,
  },

  uncle_vern = {
    name = "Uncle Vern",
    description = "If you discard a pair to crib, +4 pegs",
    cost = 4,
    rarity = "common",
    timing = M.EFFECT_TIMING.ON_DISCARD,
    board_specific = nil,
    effect = function(context)
      if context.discarded_pair then
        return { pegs = 4 }
      end
      return { pegs = 0 }
    end,
  },

  auntie_june = {
    name = "Auntie June",
    description = "If you keep all four suits in hand, +6 pegs",
    cost = 5,
    rarity = "uncommon",
    timing = M.EFFECT_TIMING.ON_HAND_SCORE,
    board_specific = nil,
    effect = function(context)
      if context.suits and context.suits.spades > 0
        and context.suits.hearts > 0 and context.suits.clubs > 0
        and context.suits.diamonds > 0 then
        return { pegs = 6 }
      end
      return { pegs = 0 }
    end,
  },
}

return M
