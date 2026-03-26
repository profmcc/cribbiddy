local game_state = require("src.systems.game_state")
local quota_system = require("src.systems.quota_system")

local M = {}

local BLIND_TYPE = quota_system.BLIND_TYPE

M.QUOTA_SPECIAL_CARDS = {
  the_pardon = {
    name = "The Pardon",
    description = "Erase the quota for current Street",
    cost = 8,
    rarity = "rare",
    timing = "pre_street",
    effect = function(_run_state, street_state)
      street_state.quota_target = 0
      street_state.quota_met = true
      street_state.quota_erased = true
      return { message = "Quota erased for this Street" }
    end,
  },

  the_extension = {
    name = "The Extension",
    description = "+2 hand limit for current Street",
    cost = 5,
    rarity = "uncommon",
    timing = "pre_street",
    effect = function(_run_state, street_state)
      street_state.hands_limit = street_state.hands_limit + 2
      return { message = "Hand limit increased to " .. street_state.hands_limit }
    end,
  },

  the_delay = {
    name = "The Delay",
    description = "Move current quota to next Street (stacks!)",
    cost = 6,
    rarity = "uncommon",
    timing = "pre_street",
    can_use = function(run_state, _street_state)
      return run_state.current_blind_type ~= BLIND_TYPE.BOSS
    end,
    effect = function(run_state, street_state)
      local delayed_amount = street_state.quota_target
      street_state.quota_target = 0
      street_state.quota_met = true
      street_state.quota_erased = true
      run_state.delayed_quota = (run_state.delayed_quota or 0) + delayed_amount
      return { message = "Quota delayed! Next Street: +" .. delayed_amount }
    end,
  },

  the_freebie = {
    name = "The Freebie",
    description = "Auto-complete current quota (can still exceed)",
    cost = 10,
    rarity = "rare",
    timing = "pre_street",
    effect = function(_run_state, street_state)
      street_state.quota_progress = street_state.quota_target
      street_state.quota_met = true
      return { message = "Quota auto-completed! Chase the 50% bonus?" }
    end,
  },

  the_forgiveness = {
    name = "The Forgiveness",
    description = "Next heart loss is prevented",
    cost = 7,
    rarity = "uncommon",
    timing = "anytime",
    effect = function(run_state, _street_state)
      run_state.heart_shield = true
      return { message = "Protected from next heart loss" }
    end,
  },

  the_mulligan = {
    name = "The Mulligan",
    description = "Reset current Street completely",
    cost = 4,
    rarity = "common",
    timing = "during_street",
    can_use = function(_run_state, street_state)
      return street_state.hands_used > 0
    end,
    effect = function(run_state, street_state)
      local new_state = game_state.init_street(run_state, run_state.current_street)
      for k, v in pairs(new_state) do
        street_state[k] = v
      end
      return { message = "Street reset!", restart_hand = true }
    end,
  },

  the_shortcut = {
    name = "The Shortcut",
    description = "Skip current Street (no rewards)",
    cost = 6,
    rarity = "uncommon",
    timing = "pre_street",
    can_use = function(run_state, _street_state)
      return run_state.current_blind_type ~= BLIND_TYPE.BOSS
        and run_state.current_blind_type ~= BLIND_TYPE.BOSS_APPROACH
    end,
    effect = function(_run_state, street_state)
      street_state.skipped = true
      street_state.quota_met = true
      street_state.phase_complete = true
      return { message = "Street skipped!", skip_to_next = true }
    end,
  },
}

M.QUOTA_SIDE_DISHES = {
  second_wind = {
    name = "Second Wind",
    description = "+1 hand limit this Street",
    cost = 3,
    timing = "pre_hand",
    effect = function(_run_state, street_state)
      street_state.hands_limit = street_state.hands_limit + 1
      return { message = "+1 hand available" }
    end,
  },

  adrenaline = {
    name = "Adrenaline",
    description = "Quota reduced by 10 this Street",
    cost = 4,
    timing = "pre_street",
    effect = function(_run_state, street_state)
      street_state.quota_target = math.max(10, street_state.quota_target - 10)
      return { message = "Quota reduced to " .. street_state.quota_target }
    end,
  },

  heart_tonic = {
    name = "Heart Tonic",
    description = "+1 heart immediately",
    cost = 6,
    timing = "anytime",
    effect = function(run_state, _street_state)
      game_state.gain_heart(run_state)
      return { message = "+1 Heart!" }
    end,
  },

  cushion = {
    name = "Cushion",
    description = "Next missed quota costs no heart",
    cost = 5,
    timing = "pre_street",
    effect = function(_run_state, street_state)
      street_state.cushioned = true
      return { message = "Protected from quota failure" }
    end,
  },

  overdrive = {
    name = "Overdrive",
    description = "This hand counts double toward quota",
    cost = 4,
    timing = "pre_hand",
    effect = function(_run_state, street_state)
      street_state.next_hand_multiplier = 2
      return { message = "Next hand pegs count x2!" }
    end,
  },

  mercy = {
    name = "Mercy",
    description = "Missing quota by <=5 counts as met",
    cost = 3,
    timing = "pre_street",
    effect = function(_run_state, street_state)
      street_state.mercy_margin = 5
      return { message = "5-peg grace margin active" }
    end,
  },
}

return M
