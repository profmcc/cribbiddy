local quota_system = require("src.systems.quota_system")
local phase_objectives = require("src.systems.phase_objectives")

local M = {}

local BLIND_TYPE = quota_system.BLIND_TYPE
local QUOTA_CONFIG = quota_system.QUOTA_CONFIG
local HEART_CONFIG = quota_system.HEART_CONFIG
local CHARACTER_CONFIG = quota_system.CHARACTER_CONFIG

local function table_contains(list, value)
  for i = 1, #list do
    if list[i] == value then
      return true
    end
  end
  return false
end

local function clamp(value, min_value, max_value)
  if value < min_value then
    return min_value
  end
  if value > max_value then
    return max_value
  end
  return value
end

function M.init_run(character_key)
  local character = CHARACTER_CONFIG[character_key] or CHARACTER_CONFIG.novice
  local max_hearts = HEART_CONFIG.max_hearts
  local starting_hearts = HEART_CONFIG.starting_hearts[character_key] or character.starting_hearts
  return {
    current_board = "backyard",
    current_street = 1,
    current_blind_type = BLIND_TYPE.SMALL,
    ante = 1,
    hearts = clamp(starting_hearts, 1, max_hearts),
    max_hearts = max_hearts,
    money = 5,
    character = character_key,
  }
end

function M.init_street(run_state, street_number)
  local blind_type = run_state.current_blind_type
  local quota_target = M.calculate_quota(run_state.current_board, blind_type, run_state.ante)
  local hands_limit = M.calculate_hand_limit(blind_type, run_state.ante, run_state.character)
  return {
    quota_target = quota_target,
    quota_progress = 0,
    hands_used = 0,
    hands_limit = hands_limit,
    phase_objective = { type = "none", params = {} },
    phase_complete = false,
    quota_met = false,
    street_complete = false,
    street_number = street_number,
  }
end

function M.calculate_quota(board, blind_type, ante)
  local base = QUOTA_CONFIG.base[blind_type].quota
  local override = QUOTA_CONFIG.board_overrides[board] or {}
  local board_mult = override.quota_mult or 1.0
  local ante_mod = 0

  for _, scale in ipairs(QUOTA_CONFIG.ante_scaling) do
    if ante >= scale.ante then
      ante_mod = scale.quota_mod
    end
  end

  return math.floor((base + ante_mod) * board_mult)
end

function M.calculate_hand_limit(blind_type, ante, character)
  local base = QUOTA_CONFIG.base[blind_type].hands
  local char_mod = 0

  if character == "patient" then
    char_mod = 1
  elseif character == "efficient" then
    char_mod = -1
  end

  local ante_mod = 0
  for _, scale in ipairs(QUOTA_CONFIG.ante_scaling) do
    if ante >= scale.ante and scale.hand_mod then
      local applies = scale.applies_to == "all"
        or (type(scale.applies_to) == "table" and table_contains(scale.applies_to, blind_type))
      if applies then
        ante_mod = scale.hand_mod
      end
    end
  end

  local result = base + char_mod + ante_mod
  local min_hands = 2

  for _, scale in ipairs(QUOTA_CONFIG.ante_scaling) do
    if ante >= scale.ante and scale.min_hands then
      min_hands = scale.min_hands
    end
  end

  return math.max(result, min_hands)
end

function M.add_pegs_to_quota(street_state, pegs)
  street_state.quota_progress = street_state.quota_progress + pegs
  street_state.quota_met = street_state.quota_progress >= street_state.quota_target
  return street_state.quota_progress
end

function M.check_quota_status(street_state)
  if street_state.quota_progress >= street_state.quota_target * 1.5 then
    return "exceeded_50"
  end
  if street_state.quota_progress >= street_state.quota_target then
    return "met"
  end
  if street_state.hands_used >= street_state.hands_limit then
    return "missed"
  end
  return "in_progress"
end

function M.end_hand(run_state, street_state, hand_score)
  street_state.hands_used = street_state.hands_used + 1
  M.add_pegs_to_quota(street_state, hand_score)

  local status = M.check_quota_status(street_state)
  if status == "met" or status == "exceeded_50" then
    street_state.street_complete = true
  end
  if status == "missed" then
    street_state.street_complete = true
  end

  return status
end

function M.on_hand_complete(hand_result, run_state, street_state)
  M.add_pegs_to_quota(street_state, hand_result.score)

  if not street_state.phase_complete then
    if phase_objectives.check_phase_complete(street_state.phase_objective, hand_result) then
      street_state.phase_complete = true
    end
  end

  street_state.hands_used = street_state.hands_used + 1

  local status = M.check_quota_status(street_state)
  if status == "met" or status == "exceeded_50" then
    street_state.quota_met = true
  end

  return status
end

function M.end_street(run_state, street_state)
  local heart_change = 0
  local rewards = {}

  if street_state.quota_progress < street_state.quota_target then
    heart_change = heart_change - 1
    table.insert(rewards, { type = "heart_loss", reason = "missed_quota" })
  else
    table.insert(rewards, { type = "quota_met" })

    if street_state.quota_progress >= street_state.quota_target * 1.5 then
      heart_change = heart_change + 1
      table.insert(rewards, { type = "heart_gain", reason = "exceeded_50_percent" })
    end
  end

  if street_state.hands_used > street_state.hands_limit then
    heart_change = heart_change - 1
    table.insert(rewards, { type = "heart_loss", reason = "exceeded_hands" })
  end

  local blind_config = QUOTA_CONFIG.base[run_state.current_blind_type]
  if blind_config.phase_required and not street_state.phase_complete then
    heart_change = heart_change - 1
    table.insert(rewards, { type = "heart_loss", reason = "failed_required_phase" })
    table.insert(rewards, { type = "retry_street" })
  end

  if street_state.phase_complete and not blind_config.phase_required then
    if run_state.current_blind_type == BLIND_TYPE.SMALL then
      table.insert(rewards, { type = "money", amount = 2 })
    elseif run_state.current_blind_type == BLIND_TYPE.BIG then
      table.insert(rewards, { type = "money", amount = 3 })
      table.insert(rewards, { type = "side_dish", random = true })
    end
  end

  return heart_change, rewards
end

function M.lose_heart(run_state)
  run_state.hearts = run_state.hearts - 1
  return run_state.hearts <= 0
end

function M.gain_heart(run_state)
  run_state.hearts = math.min(run_state.hearts + 1, run_state.max_hearts)
  return run_state.hearts
end

return M
