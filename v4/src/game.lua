local cards = require("src.cards")
local scoring = require("src.scoring")
local ui = require("src.ui")
local data = require("src.data")
local quota_system = require("src.systems.quota_system")
local game_state = require("src.systems.game_state")
local phase_objectives = require("src.systems.phase_objectives")

local GOAL_SCORE = 121
local CUT_CLEAR_ABOVE = 0.25
local CUT_DROP = 0.4
local CUT_REVEAL = 1.3
local CUT_CLEAR_BELOW = 0.25
local CUT_SLIDE = 0.5

local M = {}

local state = {}

local log_event
local write_history

local current_run_state = nil
local current_street_state = nil
local prompt_state = { active = false, selected = 1, options = {} }

local function copy_list(list)
  local out = {}
  for i = 1, #list do
    out[i] = list[i]
  end
  return out
end

local function append_card(list, card)
  local out = copy_list(list)
  out[#out + 1] = card
  return out
end

local function toggle_dealer(current)
  if current == "player" then
    return "ai"
  end
  return "player"
end

local function current_board()
  return data.boards.boards[state.meta.board_id]
end

local function current_street()
  local board = current_board()
  if not board then
    return nil
  end
  return board.streets[state.meta.street]
end

local function next_street()
  local board = current_board()
  if not board then
    return nil
  end
  return board.streets[state.meta.street + 1]
end

local function mark_street_complete()
  local board_id = state.meta.board_id
  local street = current_street()
  if not street then
    return
  end
  if not state.meta.completed_streets[board_id] then
    state.meta.completed_streets[board_id] = {}
  end
  state.meta.completed_streets[board_id][street.id] = true
end

local function get_phase_reward()
  if not current_run_state then
    return 0
  end
  if current_run_state.current_blind_type == quota_system.BLIND_TYPE.SMALL then
    return 2
  end
  if current_run_state.current_blind_type == quota_system.BLIND_TYPE.BIG then
    return 3
  end
  return 0
end

local function build_reward_preview()
  return "See summary for rewards"
end

local function trigger_phase_complete_feedback()
  state.message = "Phase complete!"
end

local function add_random_side_dish()
  local dish = pick_side_dish()
  if dish and #state.meta.side_pouch < state.meta.side_pouch_capacity then
    state.meta.side_pouch[#state.meta.side_pouch + 1] = dish
  end
end

local function show_street_summary(_rewards)
  state.message = "Street complete."
end

local function advance_to_next_street()
  current_run_state.current_street = math.min(current_run_state.current_street + 1, 10)
  current_street_state = game_state.init_street(current_run_state, current_run_state.current_street)
  current_street_state.phase_objective = phase_objectives.get_random_phase(current_run_state.current_blind_type)
  enter_street_preview()
end

local function start_new_hand()
  start_round()
end

local function count_selected(selection)
  local count = 0
  for _, selected in pairs(selection) do
    if selected then
      count = count + 1
    end
  end
  return count
end

local function remove_indices(list, indices)
  table.sort(indices, function(a, b)
    return a > b
  end)
  local removed = {}
  for i = 1, #indices do
    local index = indices[i]
    removed[#removed + 1] = table.remove(list, index)
  end
  return removed
end

local function ai_choose_discard(hand)
  local indexed = {}
  for i = 1, #hand do
    indexed[#indexed + 1] = { index = i, value = cards.card_value(hand[i]) }
  end
  table.sort(indexed, function(a, b)
    if a.value == b.value then
      return a.index < b.index
    end
    return a.value < b.value
  end)
  return { indexed[1].index, indexed[2].index }
end

local function ai_choose_play(hand, count, stack)
  local best_index = nil
  local best_points = -1
  local best_value = 99
  for i = 1, #hand do
    local card = hand[i]
    if cards.card_value(card) + count <= 31 then
      local points = scoring.pegging_points_for_play(stack, card, count)
      local value = cards.card_value(card)
      if points > best_points or (points == best_points and value < best_value) then
        best_points = points
        best_index = i
        best_value = value
      end
    end
  end
  return best_index
end

local function start_round()
  local deck = cards.shuffle(cards.build_deck({
    board_id = state.meta.board_id,
    deck_counts = state.meta.deck_counts,
    enhancements = state.meta.enhancements,
  }))
  local player_hand = {}
  local ai_hand = {}
  local draw_bonus = state.meta.side_effects.draw_bonus or 0
  local hand_bonus = state.meta.side_effects.hand_size_bonus or 0
  local player_draws = 6 + draw_bonus + hand_bonus
  for _ = 1, player_draws do
    player_hand[#player_hand + 1] = table.remove(deck)
  end
  for _ = 1, 6 do
    ai_hand[#ai_hand + 1] = table.remove(deck)
  end

  local board_id = state.meta.board_id
  local street = current_street()

  if board_id == "Space" then
    process_orbit_returns()
  end

  if board_id == "Aquatic" and street then
    local map = nil
    if street.id == 2 then
      map = { H = "S" }
    elseif street.id == 4 then
      map = { D = "C" }
    elseif street.id == 7 or street.id == 10 then
      local options = { { H = "S" }, { D = "C" }, { S = "H" }, { C = "D" } }
      map = options[love.math.random(#options)]
    end
    if state.meta.side_effects.kelp_chips then
      map = nil
      state.meta.side_effects.kelp_chips = false
      log_event("Kelp Chips: currents ignored.")
    end
    state.meta.side_effects.current_map = map
    if map then
      for i = 1, #player_hand do
        apply_current_to_card(player_hand[i])
      end
      for i = 1, #ai_hand do
        apply_current_to_card(ai_hand[i])
      end
      log_event("Current active.")
    end
  else
    state.meta.side_effects.current_map = nil
  end

  if board_id == "Cavedwellers" and street then
    local visible = nil
    if street.id == 2 then
      visible = 4
    elseif street.id == 3 then
      visible = 3
    elseif street.id == 5 then
      visible = 2
    elseif street.id == 6 then
      visible = 3
    elseif street.id == 7 then
      visible = 2
    elseif street.id == 9 then
      visible = 1
    elseif street.id == 10 then
      visible = 0
    end
    apply_visibility(player_hand, visible)
    log_event("Darkness visibility: " .. tostring(visible or #player_hand) .. " cards.")
  end

  if board_id == "Jungle" and street then
    local vine_count = 0
    if street.id == 2 then
      vine_count = 1
    elseif street.id == 7 then
      vine_count = 2
    end
    if vine_count > 0 then
      if state.meta.side_effects.coconut then
        log_event("Coconut freed vined cards this hand.")
        state.meta.side_effects.coconut = false
      else
        local indices = {}
        for i = 1, #player_hand do
          indices[#indices + 1] = i
        end
        for _ = 1, math.min(vine_count, #indices) do
          local pick = love.math.random(#indices)
          local index = table.remove(indices, pick)
          player_hand[index].vined = true
        end
        log_event("Vined " .. tostring(vine_count) .. " cards this hand.")
      end
    end
  end

  if board_id == "Beach" and street then
    local threshold = 0
    local wash_count = 0
    if street.id == 1 then
      threshold = 0
    elseif street.id == 2 then
      threshold = 1
      wash_count = 1
    elseif street.id == 3 then
      threshold = 2
    elseif street.id == 4 then
      threshold = 2
    elseif street.id == 5 then
      threshold = 3
      wash_count = 1
    elseif street.id == 6 then
      threshold = 3
      wash_count = 1
    elseif street.id == 7 then
      threshold = 4
      wash_count = 1
    elseif street.id == 8 then
      threshold = 4
    elseif street.id == 9 then
      threshold = 5
    elseif street.id == 10 then
      threshold = 6
      wash_count = 1
    end

    if threshold > 0 then
      local roll = love.math.random(1, 6)
      if state.meta.side_effects.sunscreen then
        roll = math.min(6, roll + 2)
        state.meta.side_effects.sunscreen = false
      end
      if roll <= threshold then
        state.meta.side_effects.flooded = true
        log_event("Flooded (roll " .. tostring(roll) .. ").")
        if wash_count > 0 and #player_hand > 0 then
          local washed = {}
          for _ = 1, math.min(wash_count, #player_hand) do
            local index = love.math.random(#player_hand)
            washed[#washed + 1] = table.remove(player_hand, index)
          end
          if state.meta.side_effects.seaweed_wrap then
            for i = 1, #washed do
              player_hand[#player_hand + 1] = washed[i]
            end
            log_event("Seaweed Wrap returned washed cards.")
            state.meta.side_effects.seaweed_wrap = false
          elseif street.id == 7 then
            for i = 1, #washed do
              remove_card_id(cards.card_id(washed[i]), 1)
            end
            log_event("Washed cards did not return.")
          else
            log_event("Washed away " .. tostring(#washed) .. " cards.")
          end
        end
      else
        state.meta.side_effects.flooded = false
      end
    end
  end

  if board_id == "Space" and street then
    local orbit_count = 0
    local orbit_turns = 2
    local destroy_count = 0
    if street.id == 2 then
      orbit_count = 1
    elseif street.id == 4 then
      orbit_count = 2
    elseif street.id == 8 then
      destroy_count = 1
    elseif street.id == 9 then
      orbit_count = 3
    elseif street.id == 10 then
      orbit_count = math.min(3, #player_hand)
      orbit_turns = 3
    end

    if orbit_count > 0 and #player_hand > 0 then
      local indices = {}
      for i = 1, #player_hand do
        indices[#indices + 1] = i
      end
      local to_orbit = math.min(orbit_count, #indices)
      for _ = 1, to_orbit do
        local pick = love.math.random(#indices)
        local index = table.remove(indices, pick)
        local card = table.remove(player_hand, index)
        local id = cards.card_id(card)
        if state.meta.side_effects.freeze_dried_meal then
          player_hand[#player_hand + 1] = card
        else
          remove_card_id(id, 1)
          enqueue_orbit(id, orbit_turns)
        end
      end
      if state.meta.side_effects.freeze_dried_meal then
        state.meta.side_effects.freeze_dried_meal = false
        log_event("Freeze-Dried Meal returned orbit card immediately.")
      else
        log_event("Orbiting " .. tostring(to_orbit) .. " cards.")
      end
      for _ = 1, to_orbit do
        if #deck > 0 then
          player_hand[#player_hand + 1] = table.remove(deck)
        end
      end
    end

    if destroy_count > 0 and #player_hand > 0 then
      for _ = 1, destroy_count do
        local index = love.math.random(#player_hand)
        local card = table.remove(player_hand, index)
        remove_card_id(cards.card_id(card), 1)
        log_event("Asteroid Belt destroyed " .. cards.card_label(card) .. ".")
      end
    end
  end

  if board_id == "Mars" and street then
    local roll = love.math.random(1, 6)
    local hit = false
    if street.id == 2 and roll == 6 then
      hit = true
    elseif street.id == 9 and roll >= 5 then
      hit = true
    end
    if state.meta.side_effects.oxygen_tank then
      hit = true
      state.meta.side_effects.oxygen_tank = false
    end
    if hit then
      local dish = pick_side_dish()
      if dish and #state.meta.side_pouch < state.meta.side_pouch_capacity then
        state.meta.side_pouch[#state.meta.side_pouch + 1] = dish
        log_event("Supply drop: " .. dish.name .. ".")
      else
        log_event("Supply drop triggered but pouch full.")
      end
    end
  end

  if state.meta.side_effects.redraw_next_hand then
    for i = 1, #player_hand do
      deck[#deck + 1] = player_hand[i]
    end
    player_hand = {}
    deck = cards.shuffle(deck)
    for _ = 1, player_draws do
      player_hand[#player_hand + 1] = table.remove(deck)
    end
    state.meta.side_effects.redraw_next_hand = false
    log_event("Joint redraw applied.")
  end

  state.meta.side_effects.draw_bonus = 0
  if state.meta.side_effects.peek_cut then
    if #deck > 0 then
      state.peek_cut_card_label = cards.card_label(deck[#deck])
      state.message = "Peek cut: " .. state.peek_cut_card_label
    end
    state.meta.side_effects.peek_cut = false
  else
    state.peek_cut_card_label = nil
  end

  state.round = (state.round or 0) + 1
  state.deck = deck
  state.player_hand = player_hand
  state.ai_hand = ai_hand
  state.player_show_hand = copy_list(player_hand)
  state.ai_show_hand = copy_list(ai_hand)
  state.crib = {}
  state.starter = nil
  state.discard_selection = {}
  state.phase = "discard"
  if state.dealer == "player" then
    state.message = "Your crib. Discard 2 cards (1-6), then Enter."
  else
    state.message = "Opponent's crib. Discard 2 cards (1-6), then Enter."
  end

  local handicap = math.max(0, state.level - 1)
  if handicap > 0 then
    state.ai_score = state.ai_score + handicap
    state.message = state.message .. " AI gets +" .. tostring(handicap) .. " handicap."
  end
  log_event("Start hand. Dealer: " .. state.dealer .. ".")
end

local start_pegging
local award_points

local function should_open_shop()
  local board = current_board()
  local street = current_street()
  if not board or not street then
    return false
  end
  if street.id >= 10 then
    return false
  end
  if state.meta.board_id == "Mars" then
    return street.id == 3 or street.id == 6 or street.id == 9
  end
  return true
end

local function random_choice(list)
  if not list or #list == 0 then
    return nil
  end
  return list[love.math.random(#list)]
end

local function pick_from_groups(groups)
  local options = {}
  for i = 1, #groups do
    for j = 1, #groups[i].items do
      options[#options + 1] = groups[i].items[j]
    end
  end
  return random_choice(options)
end

local function pick_auntie_uncle()
  local roll = love.math.random()
  if roll <= 0.6 then
    return pick_from_groups(data.aunties.universal)
  elseif roll <= 0.9 then
    local board_specific = data.aunties.board_specific[state.meta.board_id] or {}
    return random_choice(board_specific) or pick_from_groups(data.aunties.universal)
  end
  local unlocked = data.boards.unlock_tree[state.meta.board_id] or {}
  local adjacent = random_choice(unlocked)
  if adjacent and data.aunties.board_specific[adjacent] then
    return random_choice(data.aunties.board_specific[adjacent])
  end
  return pick_from_groups(data.aunties.universal)
end

local function pick_side_dish()
  local roll = love.math.random()
  if roll <= 0.7 then
    return random_choice(data.side_dishes.universal)
  elseif roll <= 0.95 then
    local board_specific = data.side_dishes.board_specific[state.meta.board_id] or {}
    return random_choice(board_specific) or random_choice(data.side_dishes.universal)
  end
  local unlocked = data.boards.unlock_tree[state.meta.board_id] or {}
  local adjacent = random_choice(unlocked)
  if adjacent and data.side_dishes.board_specific[adjacent] then
    return random_choice(data.side_dishes.board_specific[adjacent])
  end
  return random_choice(data.side_dishes.universal)
end

local function build_shop_stock()
  local family_stock = {}
  local dish_stock = {}
  local family_count = love.math.random(3, 5)
  local dish_count = love.math.random(3, 5)
  for i = 1, family_count do
    family_stock[#family_stock + 1] = pick_auntie_uncle()
  end
  for i = 1, dish_count do
    dish_stock[#dish_stock + 1] = pick_side_dish()
  end
  return family_stock, dish_stock
end

local function start_shop()
  local family_stock, dish_stock = build_shop_stock()
  local board_id = state.meta.board_id
  local special_rate = data.special_cards.shop_rates[board_id] or 0.1
  local special_offer = nil
  if love.math.random() <= special_rate then
    local pool = data.special_cards.shop_pool
    local special_id = pool[love.math.random(#pool)]
    special_offer = data.special_cards.by_id(special_id)
  end
  state.shop = {
    family_stock = family_stock,
    dish_stock = dish_stock,
    special_offer = special_offer,
    family_reroll_cost = 1,
    dish_reroll_cost = 1,
    message = "Press Enter to open shop.",
    state = "intro",
    enhancement_page = 1,
    selected_enhancement = nil,
    enhancement_message = nil,
  }
  state.phase = "shop"
end

local function current_deck_for_view()
  return cards.build_deck({
    board_id = state.meta.board_id,
    deck_counts = state.meta.deck_counts,
    enhancements = state.meta.enhancements,
  })
end

local function enhancement_shop_list()
  return data.boards.shop_structure.card_enhancements
end

local function enhancement_by_index(index)
  local list = enhancement_shop_list()
  return list[index]
end

local function deck_page(deck, page, per_page)
  local start_idx = (page - 1) * per_page + 1
  local items = {}
  for i = start_idx, math.min(#deck, start_idx + per_page - 1) do
    items[#items + 1] = deck[i]
  end
  return items, start_idx
end

local function list_page(list, page, per_page)
  local start_idx = (page - 1) * per_page + 1
  local items = {}
  for i = start_idx, math.min(#list, start_idx + per_page - 1) do
    items[#items + 1] = list[i]
  end
  return items, start_idx
end

log_event = function(message)
  if not state.history then
    return
  end
  local stamp = os.date("%Y-%m-%d %H:%M:%S")
  local phase = state.phase or "unknown"
  local street = state.meta and state.meta.street or "?"
  state.history[#state.history + 1] = "[" .. stamp .. "][Street " .. tostring(street) .. "][" .. phase .. "] " .. message
end

write_history = function()
  if state.history_written then
    return
  end
  state.history_written = true
  local filename = "cribbiddy_history_" .. tostring(os.time()) .. ".txt"
  local ok = love.filesystem.write(filename, table.concat(state.history or {}, "\n"))
  if ok then
    state.message = "History saved to " .. love.filesystem.getSaveDirectory() .. "/" .. filename
  else
    state.message = "Failed to save history."
  end
end

local function deck_entries()
  local entries = {}
  for card_id, count in pairs(state.meta.deck_counts) do
    local rank_name, suit_name = card_id:match("^([^%-]+)%-(.+)$")
    local label = (rank_name or "?") .. (suit_name or "?")
    entries[#entries + 1] = {
      id = card_id,
      label = label,
      count = count,
      rank = cards.rank_from_name(rank_name or "0") or 0,
      suit = suit_name or "?",
      enhancement = state.meta.enhancements[card_id],
    }
  end
  table.sort(entries, function(a, b)
    if a.suit == b.suit then
      return a.rank < b.rank
    end
    return a.suit < b.suit
  end)
  return entries
end

local function card_id_for(rank, suit_index)
  return cards.rank_name(rank) .. "-" .. cards.suit_name(suit_index)
end

local function deck_size()
  local total = 0
  for _, count in pairs(state.meta.deck_counts) do
    total = total + count
  end
  return total
end

local function can_delete(count)
  return deck_size() - count >= 40
end

local function can_add_card(card_id, amount)
  local total = deck_size() + amount
  if total > 60 then
    return false
  end
  local current = state.meta.deck_counts[card_id] or 0
  if current + amount > 6 then
    return false
  end
  return true
end

local function add_card_id(card_id, amount)
  if not can_add_card(card_id, amount) then
    return false
  end
  state.meta.deck_counts[card_id] = (state.meta.deck_counts[card_id] or 0) + amount
  return true
end

local function replace_card_id(old_id, new_id)
  local current = state.meta.deck_counts[old_id] or 0
  if current <= 0 then
    return false
  end
  if not can_add_card(new_id, 1) then
    return false
  end
  state.meta.deck_counts[old_id] = current - 1
  if state.meta.deck_counts[old_id] <= 0 then
    state.meta.deck_counts[old_id] = nil
  end
  state.meta.deck_counts[new_id] = (state.meta.deck_counts[new_id] or 0) + 1
  if state.meta.enhancements[old_id] then
    state.meta.enhancements[new_id] = state.meta.enhancements[old_id]
    state.meta.enhancements[old_id] = nil
  end
  return true
end

local function is_prehistoric(card)
  return card.rank == 0 or card.rank == 14 or card.rank == 15
end

local function apply_current_to_card(card)
  local map = state.meta.side_effects.current_map
  if not map then
    return
  end
  local suit_name = cards.suit_name(card.suit)
  local mapped = map[suit_name]
  if mapped then
    for i = 1, 4 do
      if cards.suit_name(i) == mapped then
        card.suit = i
        return
      end
    end
  end
end

local function apply_visibility(hand, visible_count)
  if visible_count == nil then
    return
  end
  if visible_count >= #hand then
    return
  end
  local indices = {}
  for i = 1, #hand do
    indices[#indices + 1] = i
  end
  for i = 1, #hand do
    hand[i].hidden = true
  end
  for _ = 1, math.max(0, visible_count) do
    local pick = love.math.random(#indices)
    local index = table.remove(indices, pick)
    hand[index].hidden = false
  end
end

local function enqueue_orbit(card_id, turns)
  state.meta.orbit_queue[#state.meta.orbit_queue + 1] = { id = card_id, turns = turns }
end

local function process_orbit_returns()
  local remaining = {}
  for i = 1, #state.meta.orbit_queue do
    local entry = state.meta.orbit_queue[i]
    entry.turns = entry.turns - 1
    if entry.turns <= 0 then
      add_card_id(entry.id, 1)
    else
      remaining[#remaining + 1] = entry
    end
  end
  state.meta.orbit_queue = remaining
end

local function apply_side_dish_effect(dish)
  if dish.id == "cake" then
    state.meta.money = state.meta.money + 5
    log_event("Cake: +$5.")
    return true
  end
  if dish.id == "hot_dog" then
    state.player_score = state.player_score + 3
    log_event("Hot Dog: +3 pegs.")
    return true
  end
  if dish.id == "coffee" then
    state.meta.side_effects.draw_bonus = state.meta.side_effects.draw_bonus + 2
    log_event("Coffee: draw +2 next hand.")
    return true
  end
  if dish.id == "espresso" then
    state.meta.side_effects.extra_shop_action = state.meta.side_effects.extra_shop_action + 1
    log_event("Espresso: extra shop action.")
    return true
  end
  if dish.id == "joint" then
    state.meta.side_effects.redraw_next_hand = true
    log_event("Joint: redraw next hand.")
    return true
  end
  if dish.id == "cookies" then
    state.meta.side_effects.fifteens_bonus = state.meta.side_effects.fifteens_bonus + 1
    log_event("Cookies: +1 per fifteen this hand.")
    return true
  end
  if dish.id == "hot_dog" then
    state.player_score = state.player_score + 3
    log_event("Hot Dog: +3 pegs.")
    return true
  end
  if dish.id == "lemonade" then
    state.meta.side_effects.remove_crib_card = true
    log_event("Lemonade: remove one crib card before scoring against you.")
    return true
  end
  if dish.id == "nachos" then
    state.meta.side_effects.pairs_bonus = state.meta.side_effects.pairs_bonus + 1
    log_event("Nachos: +1 per pair this hand.")
    return true
  end
  if dish.id == "moonshine" then
    state.meta.side_effects.next_score_multiplier = 2
    state.meta.side_effects.moonshine_active = true
    log_event("Moonshine: next score doubled, one family will leave.")
    return true
  end
  if dish.id == "popcorn" then
    state.meta.side_effects.peek_cut = true
    log_event("Popcorn: peek cut card before discard.")
    return true
  end
  if dish.id == "pretzels" then
    state.meta.side_effects.pretzels = true
    log_event("Pretzels: swap a card with crib after discard.")
    return true
  end
  if dish.id == "wings" then
    state.meta.side_effects.runs_bonus = state.meta.side_effects.runs_bonus + 1
    log_event("Wings: +1 per run card this hand.")
    return true
  end
  if dish.id == "casserole" then
    local temp = pick_auntie_uncle()
    if temp then
      temp.temp = true
      state.meta.family[#state.meta.family + 1] = temp
      state.meta.temp_family[#state.meta.temp_family + 1] = temp
      log_event("Casserole: temporary family " .. temp.name .. ".")
      return true
    end
    return false
  end
  if dish.id == "sushi" then
    state.meta.side_effects.show_ai_hand = true
    log_event("Sushi: reveal opponent pegging hand.")
    return true
  end
  if dish.id == "tea" then
    state.meta.side_effects.tea = true
    log_event("Tea: remove one negative condition (not yet implemented).")
    return true
  end
  if dish.id == "water" then
    local last = state.meta.graveyard[#state.meta.graveyard]
    if not last then
      return false
    end
    if not add_card_id(last.id, 1) then
      return false
    end
    last.count = last.count - 1
    if last.count <= 0 then
      table.remove(state.meta.graveyard, #state.meta.graveyard)
    end
    log_event("Water: restored " .. last.id .. ".")
    return true
  end
  if dish.id == "edible" then
    local list = data.side_dishes.universal
    local pick = list[love.math.random(#list)]
    if pick.id == "edible" then
      pick = list[(love.math.random(#list - 1)) + 1]
    end
    log_event("Edible: triggered " .. pick.name .. ".")
    return apply_side_dish_effect(pick)
  end
  if dish.id == "coconut" then
    state.meta.side_effects.coconut = true
    log_event("Coconut: vined cards freed (not yet implemented).")
    return true
  end
  if dish.id == "trail_mix" then
    state.meta.side_effects.hand_size_bonus = state.meta.side_effects.hand_size_bonus + 1
    log_event("Trail Mix: +1 hand size this Street.")
    return true
  end
  if dish.id == "hot_cocoa" then
    state.meta.side_effects.hot_cocoa = true
    log_event("Hot Cocoa: frostbitten scores half (not yet implemented).")
    return true
  end
  if dish.id == "sunscreen" then
    state.meta.side_effects.sunscreen = true
    log_event("Sunscreen: tide roll treated as 2 lower (not yet implemented).")
    return true
  end
  if dish.id == "seaweed_wrap" then
    state.meta.side_effects.seaweed_wrap = true
    log_event("Seaweed Wrap: washed-away card returns (not yet implemented).")
    return true
  end
  if dish.id == "cloud_candy" then
    state.meta.side_effects.cloud_candy = true
    log_event("Cloud Candy: cloudwalk swaps +1 (not yet implemented).")
    return true
  end
  if dish.id == "mushroom" then
    state.meta.side_effects.mushroom = true
    log_event("Mushroom: see +2 extra cards in darkness (not yet implemented).")
    return true
  end
  if dish.id == "kelp_chips" then
    state.meta.side_effects.kelp_chips = true
    log_event("Kelp Chips: currents don't affect this hand (not yet implemented).")
    return true
  end
  if dish.id == "freeze_dried_meal" then
    state.meta.side_effects.freeze_dried_meal = true
    log_event("Freeze-Dried Meal: orbit returns immediately (not yet implemented).")
    return true
  end
  if dish.id == "oxygen_tank" then
    state.meta.side_effects.oxygen_tank = true
    log_event("Oxygen Tank: supply drop guaranteed (not yet implemented).")
    return true
  end
  if dish.id == "raw_meat" then
    state.meta.side_effects.raw_meat = true
    log_event("Raw Meat: prehistoric cards score triple this hand.")
    return true
  end
  if dish.id == "sake" then
    state.meta.side_effects.sake = true
    log_event("Sake: next Kata requirement -1 (not yet implemented).")
    return true
  end
  if dish.id == "mochi" then
    state.meta.side_effects.mochi = true
    log_event("Mochi: Kata gives +$3 (not yet implemented).")
    return true
  end
  return false
end

local function begin_special_use(context, special_index)
  state.special_use = {
    page = 1,
    context = context,
    special_index = special_index or 1,
    message = "Pick a card to use " .. state.meta.special_pouch[special_index or 1].name .. ".",
  }
  state.phase = "special_use"
end

local function begin_side_dish_use(context, dish)
  state.side_dish_use = {
    page = 1,
    context = context,
    dish = dish,
    message = "Pick a card for " .. dish.name .. ".",
  }
  state.phase = "side_dish_use"
end

local function handle_side_dish_use_input(key)
  if key == "b" then
    state.phase = state.side_dish_use.context
    state.side_dish_use = nil
    return
  end
  if key == "n" then
    state.side_dish_use.page = state.side_dish_use.page + 1
    return
  end
  if key == "p" and state.side_dish_use.page > 1 then
    state.side_dish_use.page = state.side_dish_use.page - 1
    return
  end
  local index = tonumber(key)
  if not index then
    return
  end
  local deck = current_deck_for_view()
  local per_page = 9
  local page_items = deck_page(deck, state.side_dish_use.page, per_page)
  local card = page_items[index]
  if not card then
    return
  end
  local dish = state.side_dish_use.dish
  local card_id = cards.card_id(card)
  if dish.id == "beer" then
    if card.rank < 11 or card.rank > 13 then
      state.side_dish_use.message = "Pick a face card (J/Q/K)."
      return
    end
    local new_id = card_id_for(10, card.suit)
    if not replace_card_id(card_id, new_id) then
      state.side_dish_use.message = "Cannot downgrade this card."
      return
    end
    log_event("Beer downgraded " .. cards.card_label(card) .. " to 10.")
  elseif dish.id == "wine" then
    if card.rank < 2 or card.rank > 10 then
      state.side_dish_use.message = "Pick a number card (2-10)."
      return
    end
    local new_rank = card.rank + 2
    if new_rank > 13 then
      new_rank = 13
    end
    local new_id = card_id_for(new_rank, card.suit)
    if not replace_card_id(card_id, new_id) then
      state.side_dish_use.message = "Cannot upgrade this card."
      return
    end
    log_event("Wine upgraded " .. cards.card_label(card) .. " to " .. cards.rank_name(new_rank) .. cards.suit_name(card.suit) .. ".")
  elseif dish.id == "whiskey" then
    if not can_delete(1) then
      state.side_dish_use.message = "Cannot destroy (min deck size 40)."
      return
    end
    remove_card_id(card_id, 1)
    state.player_score = state.player_score + 10
    log_event("Whiskey destroyed " .. cards.card_label(card) .. " (+10 pegs).")
  elseif dish.id == "pie" then
    if not add_card_id(card_id, 1) then
      state.side_dish_use.message = "Cannot duplicate (max copies/deck size)."
      return
    end
    log_event("Pie duplicated " .. cards.card_label(card) .. ".")
  else
    state.side_dish_use.message = "This dish isn't implemented yet."
    return
  end
  state.side_dish_use = nil
  state.phase = state.view_prev or "street_preview"
end

local function handle_special_use_input(key)
  if key == "b" then
    state.phase = state.special_use.context
    state.special_use = nil
    return
  end
  if key == "n" then
    state.special_use.page = state.special_use.page + 1
    return
  end
  if key == "p" and state.special_use.page > 1 then
    state.special_use.page = state.special_use.page - 1
    return
  end
  local index = tonumber(key)
  if not index then
    return
  end
  local deck = current_deck_for_view()
  local per_page = 9
  local page_items = deck_page(deck, state.special_use.page, per_page)
  local card = page_items[index]
  if not card then
    return
  end
  local special = state.meta.special_pouch[state.special_use.special_index]
  local deleted = 0
  if special.id == "eraser" then
    deleted = delete_one_card(card)
  elseif special.id == "purge" then
    deleted = delete_rank(card, 3, false)
  elseif special.id == "cleanse" then
    deleted = delete_suit(card)
  elseif special.id == "cull" then
    deleted = delete_rank(card, nil, true)
  else
    state.special_use.message = "This special card isn't implemented yet."
    return
  end
  if deleted <= 0 then
    state.special_use.message = "Cannot delete (min deck size 40)."
    return
  end
  table.remove(state.meta.special_pouch, state.special_use.special_index)
  log_event("Used " .. special.name .. " on " .. cards.card_label(card) .. " (removed " .. tostring(deleted) .. ").")
  local return_phase = state.special_use.context
  state.special_use = nil
  state.phase = return_phase
end

local function advance_street()
  local board = current_board()
  if not board then
    return
  end
  if #state.meta.temp_family > 0 then
    local remaining = {}
    for i = 1, #state.meta.family do
      if not state.meta.family[i].temp then
        remaining[#remaining + 1] = state.meta.family[i]
      end
    end
    state.meta.family = remaining
    state.meta.temp_family = {}
    log_event("Temporary family removed at street end.")
  end
  state.meta.side_effects.hand_size_bonus = 0
  state.meta.side_effects.tea = false
  state.meta.side_effects.coconut = false
  state.meta.side_effects.hot_cocoa = false
  state.meta.side_effects.sunscreen = false
  state.meta.side_effects.seaweed_wrap = false
  state.meta.side_effects.cloud_candy = false
  state.meta.side_effects.mushroom = false
  state.meta.side_effects.kelp_chips = false
  state.meta.side_effects.freeze_dried_meal = false
  state.meta.side_effects.oxygen_tank = false
  state.meta.side_effects.raw_meat = false
  state.meta.side_effects.sake = false
  state.meta.side_effects.mochi = false
  if state.meta.street >= #board.streets then
    state.meta.street = 1
  else
    state.meta.street = state.meta.street + 1
  end
end

local function enter_street_preview()
  local board = current_board()
  local street = current_street()
  local next = next_street()
  state.preview = {
    board = board,
    street = street,
    next = next,
  }
  state.phase = "street_preview"
  state.message = "Street preview. Press Enter to begin. M for map."
end

local function remove_card_id(card_id, amount)
  local current = state.meta.deck_counts[card_id] or 0
  local to_remove = math.min(current, amount)
  if to_remove <= 0 then
    return 0
  end
  if not can_delete(to_remove) then
    return 0
  end
  state.meta.deck_counts[card_id] = current - to_remove
  if state.meta.deck_counts[card_id] <= 0 then
    state.meta.deck_counts[card_id] = nil
  end
  state.meta.graveyard[#state.meta.graveyard + 1] = { id = card_id, count = to_remove }
  return to_remove
end

local function rank_matches(card_id, target_rank)
  local rank_name = card_id:match("^([^%-]+)%-.+$")
  if not rank_name then
    return false
  end
  return cards.rank_from_name(rank_name) == target_rank
end

local function suit_matches(card_id, suit_name)
  local suit = card_id:match("^.+%-(.+)$")
  return suit == suit_name
end

local function delete_one_card(card)
  local card_id = cards.card_id(card)
  return remove_card_id(card_id, 1)
end

local function delete_rank(card, limit, only_unenhanced)
  local target_rank = card.rank
  local deleted = 0
  for card_id, count in pairs(state.meta.deck_counts) do
    if rank_matches(card_id, target_rank) then
      if not only_unenhanced or not state.meta.enhancements[card_id] then
        local remaining = limit and (limit - deleted) or count
        if remaining <= 0 then
          break
        end
        local removed = remove_card_id(card_id, remaining)
        deleted = deleted + removed
        if limit and deleted >= limit then
          break
        end
      end
    end
  end
  return deleted
end

local function delete_suit(card)
  local target_suit = cards.suit_name(card.suit)
  local deleted = 0
  for card_id, count in pairs(state.meta.deck_counts) do
    if suit_matches(card_id, target_suit) then
      local removed = remove_card_id(card_id, count)
      deleted = deleted + removed
    end
  end
  return deleted
end

local function start_cut()
  local target_x, target_y = ui.starter_position()
  state.cut = {
    visual_size = 52,
    deck_size = #state.deck,
    pointer = 1,
    direction = 1,
    velocity = 10,
    acceleration = 12,
    status = "aim",
    timer = 0,
    selected = nil,
    card = nil,
    drop_offset = 0,
    fade_left = 1,
    fade_right = 1,
    slide_progress = 0,
    target_x = target_x,
    target_y = target_y,
  }
  state.phase = "cut"
  state.message = "Stop the cursor (Enter) to cut."
  log_event("Cut phase started.")
end

local function select_cut_card()
  local ratio = 0
  if state.cut.visual_size > 1 then
    ratio = (state.cut.selected - 1) / (state.cut.visual_size - 1)
  end
  local deck_index = #state.deck - math.floor(ratio * (#state.deck - 1))
  if deck_index < 1 then
    deck_index = 1
  end
  if deck_index > #state.deck then
    deck_index = #state.deck
  end
  state.cut.card = table.remove(state.deck, deck_index)
  state.starter = state.cut.card
  apply_current_to_card(state.starter)
  log_event("Cut card: " .. cards.card_label(state.starter) .. ".")
end

local function finalize_cut()
  if state.starter and state.starter.rank == 11 then
    award_points(state.dealer, 2, "His heels")
  end
  start_pegging()
end

start_pegging = function()
  state.phase = "pegging"
  state.peg = {
    count = 0,
    stack = {},
    last_player = nil,
    player_passed = false,
    ai_passed = false,
  }
  state.pending_pass_key = nil
  state.player_peg_hand = copy_list(state.player_hand)
  state.ai_peg_hand = copy_list(state.ai_hand)
  state.pegging_player_points = 0
  state.pegging_ai_points = 0
  if state.dealer == "player" then
    state.turn = "ai"
  else
    state.turn = "player"
  end
  state.message = "Pegging: play cards with 1-4, or press G to pass."
  log_event("Pegging started. Turn: " .. state.turn .. ".")
end

award_points = function(target, points, reason)
  if points <= 0 then
    return
  end
  if target == "player" then
    state.player_score = state.player_score + points
  else
    state.ai_score = state.ai_score + points
  end
  state.last_score_event = reason .. " +" .. tostring(points)
end

local function apply_go_if_needed()
  local peg = state.peg
  if peg.player_passed and peg.ai_passed then
    if peg.count ~= 31 and peg.last_player then
      award_points(peg.last_player, 1, "Go")
      if peg.last_player == "player" then
        state.pegging_player_points = (state.pegging_player_points or 0) + 1
      else
        state.pegging_ai_points = (state.pegging_ai_points or 0) + 1
      end
    end
    peg.count = 0
    peg.stack = {}
    peg.player_passed = false
    peg.ai_passed = false
    if peg.last_player then
      state.turn = peg.last_player
    end
    peg.last_player = nil
  end
end

local function play_card(player, index)
  local peg = state.peg
  local hand = player == "player" and state.player_peg_hand or state.ai_peg_hand
  local card = table.remove(hand, index)
  local points = scoring.pegging_points_for_play(peg.stack, card, peg.count)
  peg.count = peg.count + cards.card_value(card)
  peg.stack[#peg.stack + 1] = card
  peg.last_player = player

  if player == "player" then
    peg.player_passed = false
  else
    peg.ai_passed = false
  end

  if points > 0 then
    award_points(player, points, "Peg")
    if player == "player" then
      state.pegging_player_points = (state.pegging_player_points or 0) + points
    else
      state.pegging_ai_points = (state.pegging_ai_points or 0) + points
    end
  end
  if player == "player" then
    state.pending_pass_key = nil
  end

  if peg.count == 31 then
    peg.count = 0
    peg.stack = {}
    peg.player_passed = false
    peg.ai_passed = false
    state.turn = player
    return
  end

  state.turn = player == "player" and "ai" or "player"
  log_event(player .. " played " .. cards.card_label(card) .. " (count " .. tostring(peg.count) .. ").")
end

local function can_play_any(hand, count)
  for i = 1, #hand do
    if not hand[i].vined and cards.card_value(hand[i]) + count <= 31 then
      return true
    end
  end
  return false
end

local function build_combo_entries(details)
  local entries = {}
  if details and details.fifteens then
    for i = 1, #details.fifteens do
      entries[#entries + 1] = {
        label = "15 for " .. tostring(details.fifteens[i].points),
        cards = details.fifteens[i].cards,
      }
    end
  end
  if details and details.pairs then
    for i = 1, #details.pairs do
      entries[#entries + 1] = {
        label = "Pair for " .. tostring(details.pairs[i].points),
        cards = details.pairs[i].cards,
      }
    end
  end
  if details and details.runs then
    for i = 1, #details.runs do
      entries[#entries + 1] = {
        label = details.runs[i].label .. " for " .. tostring(details.runs[i].points),
        cards = details.runs[i].cards,
      }
    end
  end
  if details and details.flush then
    entries[#entries + 1] = {
      label = details.flush.label .. " for " .. tostring(details.flush.points),
      cards = details.flush.cards,
    }
  end
  if details and details.knobs then
    entries[#entries + 1] = {
      label = details.knobs.label .. " for " .. tostring(details.knobs.points),
      cards = details.knobs.cards,
    }
  end
  if #entries == 0 then
    entries[#entries + 1] = { label = "No score" }
  end
  return entries
end

local function process_street_end(reason)
  local heart_change, rewards = game_state.end_street(current_run_state, current_street_state)

  if heart_change < 0 then
    for _ = 1, math.abs(heart_change) do
      local run_ended = game_state.lose_heart(current_run_state)
      if run_ended then
        state.phase = "run_end"
        state.message = "Game over. Press R to restart."
        return
      end
    end
  elseif heart_change > 0 then
    for _ = 1, heart_change do
      game_state.gain_heart(current_run_state)
    end
  end

  for _, reward in ipairs(rewards) do
    if reward.type == "money" then
      current_run_state.money = current_run_state.money + reward.amount
    elseif reward.type == "side_dish" then
      add_random_side_dish()
    elseif reward.type == "retry_street" then
      current_street_state = game_state.init_street(current_run_state, current_run_state.current_street)
      current_street_state.phase_objective = phase_objectives.get_random_phase(current_run_state.current_blind_type)
      start_new_hand()
      return
    end
  end

  show_street_summary(rewards)
  advance_to_next_street()
end

local function show_end_street_prompt()
  local quota_target = current_street_state.quota_target
  local quota_progress = current_street_state.quota_progress
  local exceed_target = quota_target * 1.5
  local hands_remaining = current_street_state.hands_limit - current_street_state.hands_used

  local can_chase_exceed = quota_progress < exceed_target and hands_remaining > 0
  local pegs_needed_for_exceed = exceed_target - quota_progress

  prompt_state = {
    active = true,
    selected = 1,
    options = {},
  }

  table.insert(prompt_state.options, {
    text = "End Street - Collect Rewards",
    action = function() process_street_end("player_choice") end,
    info = build_reward_preview(),
  })

  if can_chase_exceed then
    table.insert(prompt_state.options, {
      text = "Keep Playing - Chase +1 Heart",
      action = function()
        prompt_state.active = false
        start_new_hand()
      end,
      info = string.format("Need %d more pegs in %d hands", pegs_needed_for_exceed, hands_remaining),
    })
  end

  state.phase = "quota_prompt"
end

local function on_hand_complete(hand_result)
  game_state.add_pegs_to_quota(current_street_state, hand_result.score)

  if not current_street_state.phase_complete then
    if phase_objectives.check_phase_complete(current_street_state.phase_objective, hand_result) then
      current_street_state.phase_complete = true
      trigger_phase_complete_feedback()
    end
  end

  current_street_state.hands_used = current_street_state.hands_used + 1

  local status = game_state.check_quota_status(current_street_state)

  if status == "met" or status == "exceeded_50" then
    current_street_state.quota_met = true
  end

  local should_end = false
  local end_reason = nil

  if current_street_state.hands_used >= current_street_state.hands_limit then
    should_end = true
    end_reason = "hand_limit"
  end

  if current_street_state.quota_met then
    local phase_required = quota_system.QUOTA_CONFIG.base[current_run_state.current_blind_type].phase_required
    if current_street_state.phase_complete or not phase_required then
      show_end_street_prompt()
      return
    end
  end

  if should_end then
    process_street_end(end_reason)
  else
    start_new_hand()
  end
end

local function score_show()
  local player_points, player_breakdown, player_details = scoring.score_hand(state.player_show_hand, state.starter, false)
  local ai_points, ai_breakdown, ai_details = scoring.score_hand(state.ai_show_hand, state.starter, false)
  local crib_points, crib_breakdown, crib_details = scoring.score_hand(state.crib, state.starter, true)

  if state.meta.side_effects.remove_crib_card and state.dealer == "ai" and #state.crib > 0 then
    local index = love.math.random(#state.crib)
    local removed = table.remove(state.crib, index)
    log_event("Lemonade removed crib card " .. cards.card_label(removed) .. ".")
    state.meta.side_effects.remove_crib_card = false
    crib_points, crib_breakdown, crib_details = scoring.score_hand(state.crib, state.starter, true)
  end

  if state.meta.side_effects.fifteens_bonus > 0 and player_details and player_details.fifteens then
    local extra = #player_details.fifteens * state.meta.side_effects.fifteens_bonus
    if extra > 0 then
      player_points = player_points + extra
      player_breakdown[#player_breakdown + 1] = "Cookies: +" .. tostring(extra)
    end
    state.meta.side_effects.fifteens_bonus = 0
  end

  if state.meta.side_effects.pairs_bonus > 0 and player_details and player_details.pairs then
    local extra = #player_details.pairs * state.meta.side_effects.pairs_bonus
    if extra > 0 then
      player_points = player_points + extra
      player_breakdown[#player_breakdown + 1] = "Nachos: +" .. tostring(extra)
    end
    state.meta.side_effects.pairs_bonus = 0
  end

  if state.meta.side_effects.runs_bonus > 0 and player_details and player_details.runs then
    local extra = 0
    for i = 1, #player_details.runs do
      extra = extra + player_details.runs[i].points * state.meta.side_effects.runs_bonus
    end
    if extra > 0 then
      player_points = player_points + extra
      player_breakdown[#player_breakdown + 1] = "Wings: +" .. tostring(extra)
    end
    state.meta.side_effects.runs_bonus = 0
  end

  if state.meta.side_effects.raw_meat and player_details then
    local extra = 0
    local function add_if_prehistoric(entry)
      if not entry or not entry.cards then
        return
      end
      for i = 1, #entry.cards do
        if is_prehistoric(entry.cards[i]) then
          extra = extra + entry.points * 2
          return
        end
      end
    end
    if player_details.fifteens then
      for i = 1, #player_details.fifteens do
        add_if_prehistoric(player_details.fifteens[i])
      end
    end
    if player_details.pairs then
      for i = 1, #player_details.pairs do
        add_if_prehistoric(player_details.pairs[i])
      end
    end
    if player_details.runs then
      for i = 1, #player_details.runs do
        add_if_prehistoric(player_details.runs[i])
      end
    end
    if player_details.flush then
      add_if_prehistoric(player_details.flush)
    end
    if player_details.knobs then
      add_if_prehistoric(player_details.knobs)
    end
    if extra > 0 then
      player_points = player_points + extra
      player_breakdown[#player_breakdown + 1] = "Raw Meat: +" .. tostring(extra)
    end
    state.meta.side_effects.raw_meat = false
  end

  if state.meta.board_id == "Japan" and player_details then
    local kata_bonus = 0
    if player_details.runs then
      for i = 1, #player_details.runs do
        if player_details.runs[i].points >= 5 then
          kata_bonus = kata_bonus + 10
          break
        end
      end
    end
    if player_details.flush then
      kata_bonus = kata_bonus + 10
    end
    if kata_bonus > 0 then
      player_points = player_points + kata_bonus
      player_breakdown[#player_breakdown + 1] = "Kata: +" .. tostring(kata_bonus)
      if state.meta.side_effects.mochi then
        state.meta.money = state.meta.money + 3
        player_breakdown[#player_breakdown + 1] = "Mochi: +$3"
      end
    end
    state.meta.side_effects.mochi = false
    state.meta.side_effects.sake = false
  end

  if state.meta.side_effects.next_score_multiplier > 1 then
    player_points = player_points * state.meta.side_effects.next_score_multiplier
    player_breakdown[#player_breakdown + 1] = "Moonshine: x" .. tostring(state.meta.side_effects.next_score_multiplier)
    state.meta.side_effects.next_score_multiplier = 1
    if state.meta.side_effects.moonshine_active and #state.meta.family > 0 then
      local removed = table.remove(state.meta.family, #state.meta.family)
      log_event("Moonshine removed " .. removed.name .. ".")
    end
    state.meta.side_effects.moonshine_active = false
  end

  if state.dealer == "player" then
    award_points("player", player_points, "Hand")
    award_points("ai", ai_points, "Hand")
    award_points("player", crib_points, "Crib")
  else
    award_points("ai", ai_points, "Hand")
    award_points("player", player_points, "Hand")
    award_points("ai", crib_points, "Crib")
  end

  state.show_details = {
    player = {
      total = player_points,
      breakdown = player_breakdown,
      details = player_details,
    },
    ai = {
      total = ai_points,
      breakdown = ai_breakdown,
      details = ai_details,
    },
    crib = {
      total = crib_points,
      breakdown = crib_breakdown,
      owner = state.dealer == "player" and "yours" or "opponent",
      details = crib_details,
    },
  }
  local max_run_length = 0
  local run_count = 0
  if player_details and player_details.runs then
    run_count = #player_details.runs
    for i = 1, #player_details.runs do
      local label = player_details.runs[i].label or ""
      local length = tonumber(label:match("Run%s+(%d+)")) or 0
      if length > max_run_length then
        max_run_length = length
      end
    end
  end

  local is_player_crib = state.dealer == "player"
  local total_pegs = player_points + (state.pegging_player_points or 0)
  if is_player_crib then
    total_pegs = total_pegs + crib_points
  else
    total_pegs = total_pegs - crib_points
  end

  local hand_result = {
    score = total_pegs,
    fifteens = player_details and #player_details.fifteens or 0,
    pairs = player_details and #player_details.pairs or 0,
    runs = { length = max_run_length, count = run_count },
    max_run_length = max_run_length,
    flush = player_details and player_details.flush ~= nil,
    pegging_score = state.pegging_player_points or 0,
    opponent_pegging_score = state.pegging_ai_points or 0,
    crib_score = crib_points,
    is_player_crib = is_player_crib,
  }

  on_hand_complete(hand_result)
  log_event("Show scoring: player " .. tostring(player_points) .. ", opponent " .. tostring(ai_points) .. ", crib " .. tostring(crib_points) .. ".")
end

local function advance_show_phase()
  if state.phase == "show_ai" then
    state.phase = "show_crib"
    state.message = "Show: crib (" .. state.show_details.crib.owner .. "). Press Enter."
  elseif state.phase == "show_crib" then
    state.phase = "show_player"
    state.message = "Show: your hand. Press Enter."
  elseif state.phase == "show_player" then
    state.phase = "show_summary"
    state.message = "Summary. Press Enter."
  elseif state.phase == "show_summary" then
    mark_street_complete()
    if state.player_score >= GOAL_SCORE then
      state.level = state.level + 1
      state.player_score = 0
      state.ai_score = 0
      state.dealer = toggle_dealer(state.dealer)
      start_round()
      return
    end
    if state.ai_score >= GOAL_SCORE then
      state.phase = "run_end"
      state.message = "Game over. Press R to restart."
      write_history()
      return
    end
    if should_open_shop() then
      start_shop()
      return
    end
    state.dealer = toggle_dealer(state.dealer)
    advance_street()
    enter_street_preview()
  end
end

local function check_pegging_end()
  if #state.player_peg_hand == 0 and #state.ai_peg_hand == 0 then
    score_show()
    state.phase = "show_ai"
    state.message = "Show: opponent hand. Press Enter."
    state.meta.side_effects.show_ai_hand = false
  end
end

local function start_new_run()
  state = {
    phase = "title",
    level = 1,
    player_score = 0,
    ai_score = 0,
    dealer = "player",
    message = "Press Enter to start.",
    last_score_event = "",
    round = 0,
    history = {},
    history_written = false,
    meta = {
      board_id = "Backyard",
      street = 1,
      money = 5,
      family_slots = data.boards.family_slots.start,
      family = {},
      side_pouch = {},
      side_pouch_capacity = 3,
      completed_streets = {},
      deck_counts = cards.default_counts("Backyard"),
      enhancements = {},
      special_pouch = {},
      special_pouch_capacity = 2,
      graveyard = {},
      side_effects = {
        draw_bonus = 0,
        redraw_next_hand = false,
        fifteens_bonus = 0,
        pairs_bonus = 0,
        runs_bonus = 0,
        remove_crib_card = false,
        hand_size_bonus = 0,
        extra_shop_action = 0,
        next_score_multiplier = 1,
        moonshine_active = false,
        peek_cut = false,
        pretzels = false,
        show_ai_hand = false,
        flooded = false,
        current_map = nil,
        tea = false,
        coconut = false,
        hot_cocoa = false,
        sunscreen = false,
        seaweed_wrap = false,
        cloud_candy = false,
        mushroom = false,
        kelp_chips = false,
        freeze_dried_meal = false,
        oxygen_tank = false,
        raw_meat = false,
        sake = false,
        mochi = false,
      },
      temp_family = {},
      orbit_queue = {},
    },
  }
  log_event("New run started.")
  current_run_state = game_state.init_run("novice")
  current_street_state = game_state.init_street(current_run_state, current_run_state.current_street)
  current_street_state.phase_objective = phase_objectives.get_random_phase(current_run_state.current_blind_type)
  prompt_state = { active = false, selected = 1, options = {} }
end

function M.load()
  love.graphics.setBackgroundColor(0.12, 0.12, 0.16)
  ui.set_font()
  start_new_run()
end

function M.update(_dt)
  if state.phase == "cut" then
    if state.cut.status == "aim" then
      state.cut.velocity = state.cut.velocity + state.cut.acceleration * _dt
      state.cut.pointer = state.cut.pointer + (state.cut.velocity * state.cut.direction * _dt)
      if state.cut.pointer >= state.cut.visual_size then
        state.cut.pointer = state.cut.visual_size
        state.cut.direction = -1
      elseif state.cut.pointer <= 1 then
        state.cut.pointer = 1
        state.cut.direction = 1
      end
    else
      state.cut.timer = state.cut.timer + _dt
      if state.cut.status == "clear_left" then
        state.cut.fade_left = math.max(0, 1 - state.cut.timer / CUT_CLEAR_ABOVE)
        if state.cut.timer >= CUT_CLEAR_ABOVE then
          state.cut.status = "drop"
          state.cut.timer = 0
        end
      elseif state.cut.status == "drop" then
        local progress = math.min(1, state.cut.timer / CUT_DROP)
        state.cut.drop_offset = progress * 140
        if state.cut.timer >= CUT_DROP then
          state.cut.status = "reveal"
          state.cut.timer = 0
        end
      elseif state.cut.status == "reveal" then
        if state.cut.timer >= CUT_REVEAL then
          state.cut.status = "clear_right"
          state.cut.timer = 0
        end
      elseif state.cut.status == "clear_right" then
        state.cut.fade_right = math.max(0, 1 - state.cut.timer / CUT_CLEAR_BELOW)
        if state.cut.timer >= CUT_CLEAR_BELOW then
          state.cut.status = "slide"
          state.cut.timer = 0
          state.cut.slide_progress = 0
        end
      elseif state.cut.status == "slide" then
        state.cut.slide_progress = math.min(1, state.cut.timer / CUT_SLIDE)
        if state.cut.timer >= CUT_SLIDE then
          finalize_cut()
        end
      end
    end
    return
  end

  if state.phase ~= "pegging" then
    return
  end
  if state.turn ~= "ai" then
    return
  end

  local peg = state.peg
  local can_play = can_play_any(state.ai_peg_hand, peg.count)
  if not can_play then
    peg.ai_passed = true
    state.turn = "player"
    apply_go_if_needed()
    check_pegging_end()
    return
  end

  local index = ai_choose_play(state.ai_peg_hand, peg.count, peg.stack)
  if index then
    play_card("ai", index)
  end
  apply_go_if_needed()
  check_pegging_end()
end

function M.keypressed(key)
  if key == "escape" then
    love.event.quit()
    return
  end

  if key == "d" and state.phase ~= "deck_view" then
    state.view_prev = state.phase
    state.deck_view_page = 1
    state.phase = "deck_view"
    return
  end

  if key == "i" and state.phase ~= "inventory" then
    state.view_prev = state.phase
    state.phase = "inventory"
    return
  end

  if key == "u" and #state.meta.side_pouch > 0 then
    state.view_prev = state.phase
    state.phase = "eat_side_dish"
    return
  end

  if key == "h" then
    write_history()
    return
  end

  if state.phase == "title" then
    if key == "return" or key == "space" then
      enter_street_preview()
    end
    return
  end

  if state.phase == "discard" then
    local index = tonumber(key)
    if index and index >= 1 and index <= #state.player_hand then
      if state.player_hand[index].vined then
        state.message = "That card is vined this hand."
        return
      end
      if state.discard_selection[index] then
        state.discard_selection[index] = false
      else
        if count_selected(state.discard_selection) >= 2 then
          state.discard_overlimit_at = love.timer.getTime()
        else
          state.discard_selection[index] = true
        end
      end
    end
    if key == "return" then
      if count_selected(state.discard_selection) == 2 then
        state.discard_overlimit_at = nil
        local indices = {}
        for i, selected in pairs(state.discard_selection) do
          if selected then
            indices[#indices + 1] = i
          end
        end
        local removed = remove_indices(state.player_hand, indices)
        for i = 1, #removed do
          state.crib[#state.crib + 1] = removed[i]
        end
        local removed_labels = {}
        for i = 1, #removed do
          removed_labels[#removed_labels + 1] = cards.card_label(removed[i])
        end
        log_event("Player discarded: " .. table.concat(removed_labels, ", ") .. ".")

        local ai_indices = ai_choose_discard(state.ai_hand)
        local ai_removed = remove_indices(state.ai_hand, ai_indices)
        for i = 1, #ai_removed do
          state.crib[#state.crib + 1] = ai_removed[i]
        end
        local ai_labels = {}
        for i = 1, #ai_removed do
          ai_labels[#ai_labels + 1] = cards.card_label(ai_removed[i])
        end
        log_event("Opponent discarded: " .. table.concat(ai_labels, ", ") .. ".")

        if state.meta.side_effects.pretzels and #state.player_hand > 0 and #state.crib > 0 then
          local hand_index = love.math.random(#state.player_hand)
          local crib_index = love.math.random(#state.crib)
          local hand_card = state.player_hand[hand_index]
          local crib_card = state.crib[crib_index]
          state.player_hand[hand_index] = crib_card
          state.crib[crib_index] = hand_card
          log_event("Pretzels swapped " .. cards.card_label(hand_card) .. " with crib " .. cards.card_label(crib_card) .. ".")
          state.meta.side_effects.pretzels = false
        end

        state.player_show_hand = copy_list(state.player_hand)
        state.ai_show_hand = copy_list(state.ai_hand)
        start_cut()
      end
    end
    return
  end

  if state.phase == "cut" then
    if state.cut.status == "aim" then
      if key == "return" or key == "space" then
        state.cut.selected = math.max(1, math.min(state.cut.visual_size, math.floor(state.cut.pointer + 0.5)))
        select_cut_card()
        state.cut.status = "clear_left"
        state.cut.timer = 0
        state.message = "Cutting..."
      end
    end
    return
  end

  if state.phase == "pegging" then
    local peg = state.peg
    if state.turn == "player" then
      if key == "g" or key == "return" or key == "space" then
        if can_play_any(state.player_peg_hand, peg.count) then
          if key == "g" then
            state.message = "You can't pass. You must play if you can peg under 31."
          end
        else
          peg.player_passed = true
          state.turn = "ai"
          apply_go_if_needed()
          check_pegging_end()
        end
        return
      end
      local index = tonumber(key)
      if index then
        if not can_play_any(state.player_peg_hand, peg.count) then
          if state.pending_pass_key == key then
            peg.player_passed = true
            state.pending_pass_key = nil
            state.turn = "ai"
            apply_go_if_needed()
            check_pegging_end()
          else
            state.pending_pass_key = key
            state.message = "Press '" .. tostring(key) .. "' again to pass."
          end
          return
        end
      end
      if index and index >= 1 and index <= #state.player_peg_hand then
        local card = state.player_peg_hand[index]
        if card.vined then
          state.message = "That card is vined this hand."
          return
        end
        if cards.card_value(card) + peg.count <= 31 then
          play_card("player", index)
          apply_go_if_needed()
          check_pegging_end()
        end
      end
    end
    return
  end

  if state.phase == "show_ai" or state.phase == "show_crib" or state.phase == "show_player" or state.phase == "show_summary" then
    if key == "return" or key == "space" then
      advance_show_phase()
    end
    return
  end

  if state.phase == "quota_prompt" then
    if key == "up" then
      prompt_state.selected = math.max(1, prompt_state.selected - 1)
    elseif key == "down" then
      prompt_state.selected = math.min(#prompt_state.options, prompt_state.selected + 1)
    elseif key == "return" or key == "space" then
      local option = prompt_state.options[prompt_state.selected]
      if option and option.action then
        prompt_state.active = false
        option.action()
      end
    end
    return
  end

  if state.phase == "street_preview" then
    if key == "m" then
      state.phase_before_map = "street_preview"
      state.phase = "board_map"
      return
    end
    if key == "return" or key == "space" then
      start_round()
    end
    return
  end

  if state.phase == "special_use" then
    handle_special_use_input(key)
    return
  end

  if state.phase == "side_dish_use" then
    handle_side_dish_use_input(key)
    return
  end

  if state.phase == "inventory" then
    if key == "b" or key == "i" or key == "escape" then
      state.phase = state.view_prev or "street_preview"
      return
    end
    local index = tonumber(key)
    if index then
      local special = state.meta.special_pouch[index]
      if special then
        begin_special_use("inventory", index)
      end
    end
    return
  end

  if state.phase == "eat_side_dish" then
    if key == "b" or key == "u" or key == "escape" then
      state.phase = state.view_prev or "street_preview"
      return
    end
    local index = tonumber(key)
    if index then
      local item = state.meta.side_pouch[index]
      if item then
        table.remove(state.meta.side_pouch, index)
        if item.id == "beer" or item.id == "wine" or item.id == "whiskey" or item.id == "pie" then
          begin_side_dish_use(state.view_prev or "street_preview", item)
          return
        end
        local applied = apply_side_dish_effect(item)
        if applied then
          state.message = "Ate " .. item.name .. "."
        else
          state.message = "No effect for " .. item.name .. "."
        end
        state.phase = state.view_prev or "street_preview"
      end
    end
    return
  end

  if state.phase == "deck_view" then
    if key == "b" or key == "d" or key == "escape" then
      state.phase = state.view_prev or "street_preview"
      return
    end
    if key == "n" then
      state.deck_view_page = state.deck_view_page + 1
      return
    end
    if key == "p" and state.deck_view_page > 1 then
      state.deck_view_page = state.deck_view_page - 1
      return
    end
  end

  if state.phase == "board_map" then
    if key == "m" or key == "escape" or key == "return" then
      state.phase = state.phase_before_map or "street_preview"
      return
    end
  end

  if state.phase == "shop" then
    local shop = state.shop
    if key == "return" or key == "space" then
      if shop.state == "intro" then
        shop.state = "active"
        shop.message = "Shop: 1-5 buy family, 6-0 buy dishes, R/T reroll, X sell last, E enhancements, C buy special, U use special."
      elseif shop.state == "active" then
        if state.meta.side_effects.extra_shop_action > 0 then
          state.meta.side_effects.extra_shop_action = state.meta.side_effects.extra_shop_action - 1
          shop.message = "Extra shop action used. Continue shopping."
          return
        end
        state.dealer = toggle_dealer(state.dealer)
        advance_street()
        enter_street_preview()
      end
      return
    end

    if shop.state ~= "active" then
      return
    end

    if key == "e" then
      shop.state = "enhance_select"
      shop.selected_enhancement = nil
      shop.enhancement_message = "Select enhancement (1-9)."
      return
    end

    if key == "c" and shop.special_offer then
      if #state.meta.special_pouch >= state.meta.special_pouch_capacity then
        shop.message = "Special pouch full."
      elseif state.meta.money < shop.special_offer.cost then
        shop.message = "Not enough money."
      else
        state.meta.money = state.meta.money - shop.special_offer.cost
        state.meta.special_pouch[#state.meta.special_pouch + 1] = shop.special_offer
        shop.message = "Bought " .. shop.special_offer.name .. "."
        log_event("Bought special card: " .. shop.special_offer.name .. ".")
        shop.special_offer = nil
      end
      return
    end

    if key == "u" and #state.meta.side_pouch > 0 then
      state.view_prev = "shop"
      state.phase = "eat_side_dish"
      return
    end

    if key == "r" then
      if state.meta.money >= shop.family_reroll_cost then
        state.meta.money = state.meta.money - shop.family_reroll_cost
        shop.family_reroll_cost = math.min(5, shop.family_reroll_cost + 1)
        shop.family_stock, _ = build_shop_stock()
      else
        shop.message = "Not enough money to reroll family."
      end
      return
    end

    if key == "t" then
      if state.meta.money >= shop.dish_reroll_cost then
        state.meta.money = state.meta.money - shop.dish_reroll_cost
        shop.dish_reroll_cost = math.min(5, shop.dish_reroll_cost + 1)
        _, shop.dish_stock = build_shop_stock()
      else
        shop.message = "Not enough money to reroll dishes."
      end
      return
    end

    if key == "x" then
      local last = state.meta.family[#state.meta.family]
      if last then
        local refund = math.max(1, math.floor((last.cost or 1) / 2))
        state.meta.money = state.meta.money + refund
        table.remove(state.meta.family, #state.meta.family)
        shop.message = "Sold " .. last.name .. " for $" .. tostring(refund) .. "."
      else
        shop.message = "No family to sell."
      end
      return
    end

    local index = tonumber(key)
    if index then
      if index >= 1 and index <= 5 then
        local item = shop.family_stock[index]
        if item then
          if #state.meta.family >= state.meta.family_slots then
            shop.message = "Family slots full. Sell one first."
            return
          end
          if state.meta.money >= item.cost then
            state.meta.money = state.meta.money - item.cost
            state.meta.family[#state.meta.family + 1] = item
            shop.message = "Hired " .. item.name .. "."
            log_event("Hired family: " .. item.name .. ".")
          else
            shop.message = "Not enough money."
          end
        end
        return
      end

      if index == 0 then
        index = 10
      end
      if index >= 6 and index <= 10 then
        local dish_index = index - 5
        local item = shop.dish_stock[dish_index]
        if item then
          if #state.meta.side_pouch >= state.meta.side_pouch_capacity then
            shop.message = "Side dish pouch full."
            return
          end
          if state.meta.money >= item.cost then
            state.meta.money = state.meta.money - item.cost
            state.meta.side_pouch[#state.meta.side_pouch + 1] = item
            shop.message = "Bought " .. item.name .. "."
            log_event("Bought side dish: " .. item.name .. ".")
          else
            shop.message = "Not enough money."
          end
        end
        return
      end
    end
  end

  if state.phase == "shop" then
    local shop = state.shop
    if shop.state == "enhance_select" then
      if key == "n" then
        shop.enhancement_select_page = (shop.enhancement_select_page or 1) + 1
        return
      end
      if key == "p" and (shop.enhancement_select_page or 1) > 1 then
        shop.enhancement_select_page = (shop.enhancement_select_page or 1) - 1
        return
      end
      local index = tonumber(key)
      if index then
        local list = enhancement_shop_list()
        local per_page = 9
        local page_items = list_page(list, shop.enhancement_select_page or 1, per_page)
        local enhancement = page_items[index]
        if enhancement then
          shop.selected_enhancement = enhancement
          shop.state = "enhance_card"
          shop.enhancement_page = 1
          shop.enhancement_message = "Pick a card (1-9). N/P to page. B to back."
        else
          shop.enhancement_message = "Invalid enhancement."
        end
      elseif key == "b" then
        shop.state = "active"
        shop.enhancement_message = nil
      end
      return
    end

    if shop.state == "enhance_card" then
      if key == "b" then
        shop.state = "enhance_select"
        shop.enhancement_message = "Select enhancement (1-9)."
        return
      end
      if key == "n" then
        shop.enhancement_page = shop.enhancement_page + 1
        return
      end
      if key == "p" and shop.enhancement_page > 1 then
        shop.enhancement_page = shop.enhancement_page - 1
        return
      end
      local index = tonumber(key)
      if index then
        local deck = current_deck_for_view()
        local per_page = 9
        local page_items, start_idx = deck_page(deck, shop.enhancement_page, per_page)
        local card = page_items[index]
        if card and shop.selected_enhancement then
          local card_id = cards.card_id(card)
          if state.meta.enhancements[card_id] then
            shop.enhancement_message = "Card already enhanced."
            return
          end
          if state.meta.money < shop.selected_enhancement.cost then
            shop.enhancement_message = "Not enough money."
            return
          end
          state.meta.money = state.meta.money - shop.selected_enhancement.cost
          state.meta.enhancements[card_id] = shop.selected_enhancement.id
          shop.state = "active"
          shop.enhancement_message = "Enhanced " .. cards.card_label(card) .. " with " .. shop.selected_enhancement.name .. "."
          log_event("Enhanced " .. cards.card_label(card) .. " with " .. shop.selected_enhancement.name .. ".")
        end
      end
      return
    end
  end

  if state.phase == "run_end" then
    if key == "r" then
      start_new_run()
    end
  end
end

function M.draw()
  ui.draw_scoreboard(state)
  ui.draw_phase(state.phase, 30, 130)
  ui.draw_text_block({ state.message or "" }, 30, 160)
  if state.last_score_event and state.last_score_event ~= "" then
    ui.draw_text_block({ "Last: " .. state.last_score_event }, 30, 190)
  end

  local board = current_board()
  local street = current_street()
  local next = next_street()
  if board and street then
    local lines = {
      "Board: " .. board.name .. " (" .. board.subtitle .. ")",
      "Street " .. tostring(street.id) .. ": " .. street.name,
      "Condition: " .. street.condition,
      "Objective: " .. street.objective,
      "Money: $" .. tostring(state.meta.money),
      "Family slots: " .. tostring(state.meta.family_slots),
      "I: inventory  D: deck  U: eat side dish",
    }
    if state.meta.side_effects.flooded then
      lines[#lines + 1] = "Flooded!"
    end
    if next then
      lines[#lines + 1] = "Next: " .. tostring(next.id) .. " - " .. next.name
      lines[#lines + 1] = "Next condition: " .. next.condition
      lines[#lines + 1] = "Next objective: " .. next.objective
    end
    ui.draw_text_block(lines, 520, 20)
  end

  if state.phase == "discard" then
    love.graphics.print("Your hand:", 30, 240)
    ui.draw_hand(state.player_hand, 30, 270, state.discard_selection)
    if state.discard_overlimit_at then
      local age = love.timer.getTime() - state.discard_overlimit_at
      if age < 0.6 then
        love.graphics.setColor(0.6, 0.6, 0.6, 0.5)
        local card_w, card_h, gap = ui.card_dimensions()
        local x = 30
        local y = 270
        love.graphics.rectangle("fill", x - 6, y - 6, (card_w + gap) * #state.player_hand - gap + 12, card_h + 12, 6, 6)
        love.graphics.setColor(1, 1, 1, 1)
      else
        state.discard_overlimit_at = nil
      end
    end
  elseif state.phase == "cut" then
    love.graphics.print("Cut the deck:", 30, 240)
    ui.draw_cut_stack(state.cut, 30, 270)
  elseif state.phase == "pegging" then
    love.graphics.print("Peg count: " .. tostring(state.peg.count), 30, 230)
    love.graphics.print("Peg turn: " .. state.turn, 30, 250)
    love.graphics.print("Your peg hand:", 30, 280)
    ui.draw_hand(state.player_peg_hand, 30, 310)
    if state.meta.side_effects.show_ai_hand then
      love.graphics.print("Opponent peg hand:", 30, 460)
      ui.draw_hand(state.ai_peg_hand, 30, 490)
    end
    if state.starter then
      local starter_x, starter_y = ui.starter_position()
      love.graphics.print("Cut card", starter_x, starter_y - 20)
      ui.draw_face_up_card(state.starter, starter_x, starter_y)
    end
    if state.turn == "player" and not can_play_any(state.player_peg_hand, state.peg.count) then
      love.graphics.print("PASS available (G/Enter).", 30, 620)
    end
  elseif state.phase == "show_ai" then
    love.graphics.print("Opponent show hand:", 30, 240)
    ui.draw_cards_row(append_card(state.ai_show_hand, state.starter), 30, 270)
    if state.show_details and state.show_details.ai then
      local entries = build_combo_entries(state.show_details.ai.details)
      entries[#entries + 1] = { label = "Total: " .. tostring(state.show_details.ai.total) }
      ui.draw_combo_entries(entries, 30, 420)
    end
  elseif state.phase == "show_crib" then
    local crib_owner = state.show_details and state.show_details.crib and state.show_details.crib.owner or "?"
    love.graphics.print("Crib (" .. crib_owner .. "):", 30, 240)
    ui.draw_cards_row(append_card(state.crib, state.starter), 30, 270)
    if state.show_details and state.show_details.crib then
      local entries = build_combo_entries(state.show_details.crib.details)
      entries[#entries + 1] = { label = "Total: " .. tostring(state.show_details.crib.total) }
      ui.draw_combo_entries(entries, 30, 420)
    end
  elseif state.phase == "show_player" then
    love.graphics.print("Your show hand:", 30, 240)
    ui.draw_cards_row(append_card(state.player_show_hand, state.starter), 30, 270)
    if state.show_details and state.show_details.player then
      local entries = build_combo_entries(state.show_details.player.details)
      entries[#entries + 1] = { label = "Total: " .. tostring(state.show_details.player.total) }
      ui.draw_combo_entries(entries, 30, 420)
    end
  elseif state.phase == "show_summary" then
    if state.show_details and state.show_details.player then
      ui.draw_text_block({
        "Player total: " .. tostring(state.show_details.player.total),
        "Opponent total: " .. tostring(state.show_details.ai.total),
        "Crib (" .. state.show_details.crib.owner .. ") total: " .. tostring(state.show_details.crib.total),
      }, 30, 240)
    end
  elseif state.phase == "street_preview" then
    local preview = state.preview
    if preview and preview.board and preview.street then
      love.graphics.print("ENTERING: " .. preview.street.name, 30, 240)
      love.graphics.print("Street " .. tostring(preview.street.id) .. " of " .. tostring(#preview.board.streets), 30, 265)
      ui.draw_text_block({
        "Board: " .. preview.board.name .. " (" .. preview.board.subtitle .. ")",
        "Condition: " .. preview.street.condition,
        "Objective: " .. preview.street.objective,
      }, 30, 300)
      if preview.next then
        ui.draw_text_block({
          "Next: " .. tostring(preview.next.id) .. " - " .. preview.next.name,
          "Next condition: " .. preview.next.condition,
          "Next objective: " .. preview.next.objective,
        }, 30, 400)
      end
      love.graphics.print("Press Enter to begin. M for board map. U to eat dish.", 30, 520)
    end
  elseif state.phase == "special_use" then
    local special = state.meta.special_pouch[state.special_use.special_index or 1]
    love.graphics.print("Use Special Card: " .. special.name, 30, 240)
    local deck = current_deck_for_view()
    local per_page = 9
    local page_items = deck_page(deck, state.special_use.page, per_page)
    for i = 1, #page_items do
      local card = page_items[i]
      local label = cards.card_label(card)
      if card.enhancement then
        label = label .. " [" .. card.enhancement .. "]"
      end
      love.graphics.print(tostring(i) .. ") " .. label, 30, 265 + (i - 1) * 18)
    end
    love.graphics.print("Page " .. tostring(state.special_use.page) .. "  (N/P)", 30, 440)
    love.graphics.print("Press B to cancel.", 30, 460)
    if state.special_use.message then
      love.graphics.print(state.special_use.message, 30, 490)
    end
  elseif state.phase == "side_dish_use" then
    local dish = state.side_dish_use.dish
    love.graphics.print("Eat Side Dish: " .. dish.name, 30, 240)
    local deck = current_deck_for_view()
    local per_page = 9
    local page_items = deck_page(deck, state.side_dish_use.page, per_page)
    for i = 1, #page_items do
      local card = page_items[i]
      local label = cards.card_label(card)
      if card.enhancement then
        label = label .. " [" .. card.enhancement .. "]"
      end
      love.graphics.print(tostring(i) .. ") " .. label, 30, 265 + (i - 1) * 18)
    end
    love.graphics.print("Page " .. tostring(state.side_dish_use.page) .. "  (N/P)", 30, 440)
    love.graphics.print("Press B to cancel.", 30, 460)
    if state.side_dish_use.message then
      love.graphics.print(state.side_dish_use.message, 30, 490)
    end
  elseif state.phase == "inventory" then
    love.graphics.print("Inventory", 30, 240)
    love.graphics.print("Aunties/Uncles (" .. tostring(#state.meta.family) .. "/" .. tostring(state.meta.family_slots) .. ")", 30, 270)
    for i = 1, #state.meta.family do
      local item = state.meta.family[i]
      love.graphics.print("- " .. item.name .. ": " .. item.effect, 30, 295 + (i - 1) * 18)
    end
    local dishes_y = 295 + (#state.meta.family * 18) + 18
    love.graphics.print("Side Dishes (" .. tostring(#state.meta.side_pouch) .. "/" .. tostring(state.meta.side_pouch_capacity) .. ")", 30, dishes_y)
    for i = 1, #state.meta.side_pouch do
      local item = state.meta.side_pouch[i]
      love.graphics.print("- " .. item.name .. " - " .. item.effect, 30, dishes_y + 25 + (i - 1) * 18)
    end
    local specials_y = dishes_y + 25 + (#state.meta.side_pouch * 18) + 18
    love.graphics.print("Special Cards (" .. tostring(#state.meta.special_pouch) .. "/" .. tostring(state.meta.special_pouch_capacity) .. ")", 30, specials_y)
    for i = 1, #state.meta.special_pouch do
      local item = state.meta.special_pouch[i]
      love.graphics.print(tostring(i) .. ") " .. item.name .. " - " .. item.effect, 30, specials_y + 25 + (i - 1) * 18)
    end
    love.graphics.print("Press number to use Special. D to view deck. U to eat dish. B to return.", 30, specials_y + 25 + (#state.meta.special_pouch * 18) + 18)
  elseif state.phase == "deck_view" then
    love.graphics.print("Deck Viewer", 30, 240)
    local entries = deck_entries()
    local per_page = 9
    local page_items = list_page(entries, state.deck_view_page, per_page)
    for i = 1, #page_items do
      local entry = page_items[i]
      local line = tostring(i) .. ") " .. entry.label .. " x" .. tostring(entry.count)
      if entry.enhancement then
        line = line .. " [" .. entry.enhancement .. "]"
      end
      love.graphics.print(line, 30, 265 + (i - 1) * 18)
    end
    love.graphics.print("Page " .. tostring(state.deck_view_page) .. "  (N/P)", 30, 440)
    love.graphics.print("Press B to return.", 30, 460)
  elseif state.phase == "board_map" then
    local board = current_board()
    if board then
      love.graphics.print(board.name .. " (" .. board.subtitle .. ")", 30, 240)
      local completed = state.meta.completed_streets[state.meta.board_id] or {}
      local y = 270
      for i = 1, #board.streets do
        local street = board.streets[i]
        local marker = "○"
        if street.id == state.meta.street then
          marker = "►"
        elseif completed[street.id] then
          marker = "✓"
        end
        love.graphics.print(marker .. " Street " .. tostring(street.id) .. ": " .. street.name, 30, y)
        love.graphics.print("  Condition: " .. street.condition, 30, y + 16)
        love.graphics.print("  Objective: " .. street.objective, 30, y + 32)
        y = y + 56
      end
      love.graphics.print("Press M or Enter to return.", 30, y + 10)
    end
  elseif state.phase == "shop" then
    local shop = state.shop
    love.graphics.print("AUNTIE EDNA'S ROADSIDE STAND", 30, 240)
    if shop.state == "intro" then
      love.graphics.print("Press Enter to open the shop.", 30, 270)
      if shop.message then
        love.graphics.print(shop.message, 30, 300)
      end
      return
    end
    if shop.state == "enhance_select" then
      love.graphics.print("Card Enhancements", 30, 270)
      local list = enhancement_shop_list()
      local per_page = 9
      local page_items = list_page(list, shop.enhancement_select_page or 1, per_page)
      for i = 1, #page_items do
        local item = page_items[i]
        love.graphics.print(tostring(i) .. ") " .. item.name .. " $" .. tostring(item.cost) .. " - " .. item.effect, 30, 295 + (i - 1) * 18)
      end
      love.graphics.print("Page " .. tostring(shop.enhancement_select_page or 1) .. "  (N/P)", 30, 470)
      love.graphics.print("Press B to return to shop.", 30, 520)
      if shop.enhancement_message then
        love.graphics.print(shop.enhancement_message, 30, 550)
      end
      return
    end
    if shop.state == "enhance_card" then
      local enhancement = shop.selected_enhancement
      love.graphics.print("Select card for " .. enhancement.name .. " ($" .. tostring(enhancement.cost) .. ")", 30, 270)
      local deck = current_deck_for_view()
      local per_page = 9
      local page_items, start_idx = deck_page(deck, shop.enhancement_page, per_page)
      for i = 1, #page_items do
        local card = page_items[i]
        local id = cards.card_id(card)
        local label = cards.card_label(card)
        if state.meta.enhancements[id] then
          label = label .. " [" .. state.meta.enhancements[id] .. "]"
        end
        love.graphics.print(tostring(i) .. ") " .. label, 30, 295 + (i - 1) * 18)
      end
      love.graphics.print("Page " .. tostring(shop.enhancement_page) .. "  (N/P)", 30, 480)
      love.graphics.print("Press B to go back.", 30, 500)
      if shop.enhancement_message then
        love.graphics.print(shop.enhancement_message, 30, 530)
      end
      return
    end
    love.graphics.print("Family for Hire (Reroll $" .. tostring(shop.family_reroll_cost) .. ")", 30, 270)
    for i = 1, #shop.family_stock do
      local item = shop.family_stock[i]
      love.graphics.print(tostring(i) .. ") " .. item.name .. " - " .. item.effect .. " ($" .. tostring(item.cost) .. ")", 30, 295 + (i - 1) * 18)
    end

    love.graphics.print("Side Dishes (Reroll $" .. tostring(shop.dish_reroll_cost) .. ")", 30, 420)
    for i = 1, #shop.dish_stock do
      local item = shop.dish_stock[i]
      love.graphics.print(tostring(i + 5) .. ") " .. item.name .. " - " .. item.effect .. " ($" .. tostring(item.cost) .. ")", 30, 445 + (i - 1) * 18)
    end

    if shop.special_offer then
      local offer = shop.special_offer
      local offer_y = 470 + (#shop.dish_stock * 18) + 18
      love.graphics.print("Special Card: " .. offer.name .. " ($" .. tostring(offer.cost) .. ") [C to buy]", 30, offer_y)
      love.graphics.print(offer.effect, 30, offer_y + 18)
    end

    local coming_y = 470 + (#shop.dish_stock * 18) + 54
    love.graphics.print("Card Enhancements: press E", 30, coming_y)
    for i = 1, math.min(3, #data.boards.shop_structure.card_enhancements) do
      local item = data.boards.shop_structure.card_enhancements[i]
      love.graphics.print(item.name .. " $" .. tostring(item.cost), 30, coming_y + 25 + (i - 1) * 18)
    end
    local family_preview_y = coming_y + 25 + (#data.boards.shop_structure.card_enhancements * 18) + 18
    love.graphics.print("Coming soon family:", 30, family_preview_y)
    for i = 1, #data.boards.shop_structure.coming_soon_family do
      local item = data.boards.shop_structure.coming_soon_family[i]
      love.graphics.print("- " .. item.name, 30, family_preview_y + 18 + (i - 1) * 18)
    end
    local dish_preview_y = family_preview_y + 18 + (#data.boards.shop_structure.coming_soon_family * 18) + 18
    love.graphics.print("Coming soon side dishes:", 30, dish_preview_y)
    for i = 1, #data.boards.shop_structure.coming_soon_dishes do
      local item = data.boards.shop_structure.coming_soon_dishes[i]
      love.graphics.print("- " .. item.name, 30, dish_preview_y + 18 + (i - 1) * 18)
    end

    love.graphics.print("Your Family (" .. tostring(#state.meta.family) .. "/" .. tostring(state.meta.family_slots) .. ")", 560, 270)
    for i = 1, #state.meta.family do
      local item = state.meta.family[i]
      love.graphics.print("- " .. item.name, 560, 295 + (i - 1) * 18)
    end

    love.graphics.print("Side Dish Pouch (" .. tostring(#state.meta.side_pouch) .. "/" .. tostring(state.meta.side_pouch_capacity) .. ")", 560, 420)
    for i = 1, #state.meta.side_pouch do
      local item = state.meta.side_pouch[i]
      love.graphics.print("- " .. item.name, 560, 445 + (i - 1) * 18)
    end
    love.graphics.print("Special Pouch (" .. tostring(#state.meta.special_pouch) .. "/" .. tostring(state.meta.special_pouch_capacity) .. ")", 560, 520)
    for i = 1, #state.meta.special_pouch do
      local item = state.meta.special_pouch[i]
      love.graphics.print("- " .. item.name, 560, 545 + (i - 1) * 18)
    end

    love.graphics.print("Press Enter to continue. U to eat dish.", 560, 570)
    if shop.message then
      love.graphics.print(shop.message, 30, 720)
    end
  elseif state.phase == "eat_side_dish" then
    love.graphics.print("Eat Side Dish", 30, 240)
    love.graphics.print("Pick a dish to consume (number). B to cancel.", 30, 270)
    for i = 1, #state.meta.side_pouch do
      local item = state.meta.side_pouch[i]
      love.graphics.print(tostring(i) .. ") " .. item.name .. " - " .. item.effect, 30, 295 + (i - 1) * 18)
    end
  elseif state.phase == "run_end" then
    love.graphics.print("Final level: " .. tostring(state.level), 30, 240)
  elseif state.phase == "quota_prompt" then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Street Complete", 30, 240)
    local y = 280
    for i, option in ipairs(prompt_state.options) do
      if i == prompt_state.selected then
        love.graphics.setColor(0.3, 0.3, 0.5, 1)
        love.graphics.rectangle("fill", 20, y - 5, 560, 40, 4)
        love.graphics.setColor(1, 1, 1, 1)
      end
      love.graphics.print(option.text, 30, y)
      if option.info then
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.print(option.info, 30, y + 18)
        love.graphics.setColor(1, 1, 1, 1)
      end
      y = y + 50
    end
  end
end

return M
