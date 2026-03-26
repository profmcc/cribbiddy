local game = require("src.game")

local GameState = require("src.systems.game_state")
local QuotaSystem = require("src.systems.quota_system")
local PhaseObjectives = require("src.systems.phase_objectives")
local SaveSystem = require("src.systems.save_system")
local CharacterSelect = require("src.screens.character_select")
local QuotaDisplay = require("src.ui.quota_display")

local QuotaTests = require("src.debug.quota_tests")

current_run_state = nil
current_street_state = nil
current_screen = "main_menu"
save_timer = 30
DEBUG_MODE = false

local function get_phase_reward()
  return 0
end

function switch_screen(name, payload)
  current_screen = name
  if name == "game" and payload then
    current_run_state = payload.run_state
    current_street_state = payload.street_state
  end
end

function love.load()
  game.load()

  if SaveSystem.has_save() then
    current_run_state, current_street_state = SaveSystem.load_run()
    if current_run_state then
      switch_screen("game", {
        run_state = current_run_state,
        street_state = current_street_state,
      })
      return
    end
  end

  switch_screen("main_menu")

  if DEBUG_MODE then
    QuotaTests.run_all()
  end
end

function love.update(dt)
  game.update(dt)

  if current_run_state and save_timer then
    save_timer = save_timer - dt
    if save_timer <= 0 then
      SaveSystem.save_run(current_run_state, current_street_state)
      save_timer = 30
    end
  end
end

function love.draw()
  game.draw()

  if current_screen == "game" and current_run_state and current_street_state then
    QuotaDisplay.draw_street_header(
      current_run_state,
      current_street_state,
      current_run_state.current_blind_type,
      get_phase_reward,
      nil
    )
  end
end

function love.keypressed(key)
  game.keypressed(key)
end

function on_hand_scored(score_breakdown)
  if not current_run_state or not current_street_state then
    return
  end

  local hand_result = {
    score = score_breakdown.total,
    fifteens = score_breakdown.fifteens_count or 0,
    pairs = score_breakdown.pairs_count or 0,
    max_run_length = score_breakdown.max_run or 0,
    flush = score_breakdown.flush or false,
    pegging_score = score_breakdown.pegging or 0,
    opponent_pegging_score = score_breakdown.opponent_pegging or 0,
    crib_score = score_breakdown.crib or 0,
  }

  if current_street_state.next_hand_multiplier then
    hand_result.score = hand_result.score * current_street_state.next_hand_multiplier
    current_street_state.next_hand_multiplier = nil
  end

  GameState.on_hand_complete(hand_result, current_run_state, current_street_state)
end
