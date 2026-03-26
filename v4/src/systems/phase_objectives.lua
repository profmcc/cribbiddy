local quota_system = require("src.systems.quota_system")

local M = {}

M.PHASE_OBJECTIVE_TYPES = {
  SCORE_PAIR = "score_pair",
  SCORE_FIFTEEN = "score_fifteen",
  SCORE_RUN_3 = "score_run_3",
  SCORE_RUN_4 = "score_run_4",
  SCORE_RUN_5 = "score_run_5",
  SCORE_FLUSH = "score_flush",
  SCORE_THRESHOLD = "score_threshold",
  FIFTEENS_COUNT = "fifteens_count",
  WIN_PEGGING = "win_pegging",
  WIN_PEGGING_BY = "win_pegging_by",
  CRIB_UNDER = "crib_under",
  CRIB_ZERO = "crib_zero",
}

M.PHASE_POOLS = {
  small_blind = {
    { type = "score_pair", display = "Score a pair" },
    { type = "score_fifteen", display = "Score a fifteen" },
    { type = "score_threshold", params = { threshold = 8 }, display = "Score 8+ in one hand" },
    { type = "win_pegging", display = "Win pegging" },
  },
  big_blind = {
    { type = "score_run_3", display = "Score a run of 3+" },
    { type = "fifteens_count", params = { count = 2 }, display = "Score 2 fifteens in one hand" },
    { type = "score_flush", display = "Score a flush" },
    { type = "score_threshold", params = { threshold = 12 }, display = "Score 12+ in one hand" },
    { type = "crib_under", params = { threshold = 4 }, display = "Make crib score 4 or less" },
  },
  boss_approach = {
    { type = "score_run_4", display = "Score a run of 4+" },
    { type = "fifteens_count", params = { count = 3 }, display = "Score 3 fifteens in one hand" },
    { type = "score_threshold", params = { threshold = 16 }, display = "Score 16+ in one hand" },
    { type = "win_pegging_by", params = { margin = 5 }, display = "Win pegging by 5+" },
    { type = "crib_zero", display = "Make crib score 0" },
  },
  boss = {
    { type = "score_threshold", params = { threshold = 20 }, display = "Score 20+ in one hand" },
    { type = "score_run_5", display = "Score a run of 5+" },
    { type = "fifteens_count", params = { count = 4 }, display = "Score 4 fifteens in one hand" },
    { type = "win_pegging_by", params = { margin = 8 }, display = "Win pegging by 8+" },
  },
}

local function deep_copy(value)
  if type(value) ~= "table" then
    return value
  end
  local out = {}
  for k, v in pairs(value) do
    out[k] = deep_copy(v)
  end
  return out
end

function M.get_random_phase(blind_type)
  local pool_key = nil
  if blind_type == quota_system.BLIND_TYPE.SMALL then
    pool_key = "small_blind"
  elseif blind_type == quota_system.BLIND_TYPE.BIG then
    pool_key = "big_blind"
  elseif blind_type == quota_system.BLIND_TYPE.BOSS_APPROACH then
    pool_key = "boss_approach"
  elseif blind_type == quota_system.BLIND_TYPE.BOSS then
    pool_key = "boss"
  end

  local pool = M.PHASE_POOLS[pool_key]
  local index = math.random(1, #pool)
  return deep_copy(pool[index])
end

function M.check_phase_complete(phase_objective, hand_result)
  local t = phase_objective.type
  local p = phase_objective.params or {}

  if t == "score_pair" then
    return hand_result.pairs > 0
  elseif t == "score_fifteen" then
    return hand_result.fifteens > 0
  elseif t == "score_run_3" then
    return hand_result.max_run_length >= 3
  elseif t == "score_run_4" then
    return hand_result.max_run_length >= 4
  elseif t == "score_run_5" then
    return hand_result.max_run_length >= 5
  elseif t == "score_flush" then
    return hand_result.flush
  elseif t == "score_threshold" then
    return hand_result.score >= p.threshold
  elseif t == "fifteens_count" then
    return hand_result.fifteens >= p.count
  elseif t == "win_pegging" then
    return hand_result.pegging_score > hand_result.opponent_pegging_score
  elseif t == "win_pegging_by" then
    return (hand_result.pegging_score - hand_result.opponent_pegging_score) >= p.margin
  elseif t == "crib_under" then
    return hand_result.crib_score <= p.threshold
  elseif t == "crib_zero" then
    return hand_result.crib_score == 0
  end

  return false
end

return M
