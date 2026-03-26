local game_state = require("src.systems.game_state")
local phase_objectives = require("src.systems.phase_objectives")
local quota_system = require("src.systems.quota_system")

local QuotaTests = {}

local BLIND_TYPE = quota_system.BLIND_TYPE

function QuotaTests.test_quota_calculation()
  print("=== QUOTA CALCULATION TESTS ===")

  local boards = { "backyard", "jungle", "mountains", "japan" }
  local antes = { 1, 3, 6 }

  for _, board in ipairs(boards) do
    for _, ante in ipairs(antes) do
      print(string.format("\n%s @ Ante %d:", board, ante))
      for blind_type = 1, 4 do
        local quota = game_state.calculate_quota(board, blind_type, ante)
        local hands = game_state.calculate_hand_limit(blind_type, ante, "novice")
        local blind_name = ({ "Small", "Big", "Approach", "Boss" })[blind_type]
        print(string.format("  %s: %d quota in %d hands", blind_name, quota, hands))
      end
    end
  end
end

function QuotaTests.test_phase_objectives()
  print("\n=== PHASE OBJECTIVE TESTS ===")

  local test_hands = {
    { score = 12, fifteens = 2, pairs = 1, max_run_length = 3, flush = false, pegging_score = 5, opponent_pegging_score = 3, crib_score = 4 },
    { score = 20, fifteens = 4, pairs = 2, max_run_length = 4, flush = true, pegging_score = 8, opponent_pegging_score = 2, crib_score = 0 },
    { score = 6, fifteens = 1, pairs = 0, max_run_length = 0, flush = false, pegging_score = 2, opponent_pegging_score = 5, crib_score = 8 },
  }

  for blind_type = 1, 4 do
    local phase = phase_objectives.get_random_phase(blind_type)
    print(string.format("\nBlind %d phase: %s", blind_type, phase.display))

    for i, hand in ipairs(test_hands) do
      local complete = phase_objectives.check_phase_complete(phase, hand)
      print(string.format("  Hand %d (score %d): %s", i, hand.score, complete and "COMPLETE" or "incomplete"))
    end
  end
end

function QuotaTests.test_street_flow()
  print("\n=== STREET FLOW TEST ===")

  local run_state = game_state.init_run("novice")
  run_state.current_board = "jungle"
  run_state.current_street = 5
  run_state.current_blind_type = BLIND_TYPE.BIG

  local street_state = game_state.init_street(run_state, 5)
  street_state.phase_objective = phase_objectives.get_random_phase(run_state.current_blind_type)

  print(string.format("Street 5 (Big Blind): Quota %d, Hands %d",
    street_state.quota_target, street_state.hands_limit))
  print(string.format("Phase: %s", street_state.phase_objective.display))

  local simulated_scores = { 14, 8, 12, 10 }

  for i, score in ipairs(simulated_scores) do
    if i > street_state.hands_limit then
      break
    end

    game_state.add_pegs_to_quota(street_state, score)
    street_state.hands_used = street_state.hands_used + 1

    print(string.format("  Hand %d: +%d pegs → %d/%d (%s)",
      i, score, street_state.quota_progress, street_state.quota_target,
      game_state.check_quota_status(street_state)))
  end

  local heart_change, rewards = game_state.end_street(run_state, street_state)
  print(string.format("Street end: heart_change = %d", heart_change))
  for _, r in ipairs(rewards) do
    print(string.format("  Reward: %s", r.type))
  end
end

function QuotaTests.run_all()
  QuotaTests.test_quota_calculation()
  QuotaTests.test_phase_objectives()
  QuotaTests.test_street_flow()
  print("\n=== ALL TESTS COMPLETE ===")
end

return QuotaTests
