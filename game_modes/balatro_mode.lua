local cards = require("src.cards")
local scoring = require("src.scoring")
local ui = require("src.ui")
local aunties = require("src.data.aunties")
local side_dishes = require("src.data.side_dishes")
local boards = require("src.data.boards")

local M = {}

local state = {
  round_index = 1,
  target_score = 48,
  base_hand_size = 9,
  hand_size_bonus = 0,
}

local function target_for_round(round_index)
  return 48 + (round_index - 1) * 8
end

local function discards_for_round(_round_index)
  return 9
end

local function current_hand_size()
  return (state.base_hand_size or 9) + (state.hand_size_bonus or 0)
end

local function base_reward_for_round(round_index)
  if round_index == 1 then
    return 3
  end
  if round_index == 2 then
    return 4
  end
  if round_index == 3 then
    return 5
  end
  return 6
end

local function performance_bonus(score, target)
  if score <= target then
    return 0
  end
  local ratio = (score - target) / target
  if ratio >= 0.30 then
    return 3
  end
  if ratio >= 0.20 then
    return 2
  end
  if ratio >= 0.10 then
    return 1
  end
  return 0
end

local function calculate_round_reward(score, target, round_index, discards_remaining, hands_remaining)
  local base_reward = base_reward_for_round(round_index)
  local perf_bonus = performance_bonus(score, target)
  local discards_used = discards_for_round(round_index) - discards_remaining
  local perfect_bonus = discards_used == 0 and 1 or 0
  local hands_saved_bonus = math.max(0, hands_remaining)
  local total = base_reward + perf_bonus + perfect_bonus + hands_saved_bonus
  return total, {
    base = base_reward,
    performance = perf_bonus,
    perfect = perfect_bonus,
    hands_saved = hands_saved_bonus,
  }
end

local function begin_run_log()
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local name = "cribbiddy_run_" .. timestamp .. ".log"
  state.log_path = name
  local header = {
    "Cribbiddy run log",
    "Started: " .. os.date("%Y-%m-%d %H:%M:%S"),
    "Seed: " .. tostring(love.math.getRandomSeed()),
    "",
  }
  love.filesystem.write(name, table.concat(header, "\n"))
end

local function log_event(message)
  if not state.log_path then
    return
  end
  local line = os.date("%H:%M:%S") .. " | " .. message .. "\n"
  love.filesystem.append(state.log_path, line)
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

local function build_auntie_lookup()
  local lookup = {}
  for _, group in ipairs(aunties.universal or {}) do
    for _, item in ipairs(group.items or {}) do
      lookup[item.id] = item
    end
  end
  return lookup
end

local function build_dish_lookup()
  local lookup = {}
  for _, item in ipairs(side_dishes.universal or {}) do
    lookup[item.id] = item
  end
  return lookup
end

local function flatten_aunties()
  local list = {}
  for _, group in ipairs(aunties.universal or {}) do
    for _, item in ipairs(group.items or {}) do
      list[#list + 1] = item
    end
  end
  return list
end

local function flatten_dishes()
  local list = {}
  for _, item in ipairs(side_dishes.universal or {}) do
    list[#list + 1] = item
  end
  return list
end

local function pick_random(source, count)
  local pool = {}
  for i = 1, #source do
    pool[i] = source[i]
  end
  local picked = {}
  for _ = 1, math.min(count, #pool) do
    local index = love.math.random(#pool)
    picked[#picked + 1] = table.remove(pool, index)
  end
  return picked
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

local function collect_selected_cards(hand, selection)
  local picked = {}
  for i = 1, #hand do
    if selection[i] then
      picked[#picked + 1] = hand[i]
    end
  end
  return picked
end

local function collect_selected_indices(selection)
  local indices = {}
  for i, selected in pairs(selection) do
    if selected then
      indices[#indices + 1] = i
    end
  end
  table.sort(indices)
  return indices
end

local function single_selected_index(selection)
  local index = nil
  for i, selected in pairs(selection) do
    if selected then
      if index then
        return nil
      end
      index = i
    end
  end
  return index
end

local function most_common_rank_in_hand(hand, exclude_index)
  local counts = {}
  for i = 1, #hand do
    if i ~= exclude_index then
      counts[hand[i].rank] = (counts[hand[i].rank] or 0) + 1
    end
  end
  local best_rank = nil
  local best_count = 0
  for rank, count in pairs(counts) do
    if count > best_count then
      best_rank = rank
      best_count = count
    end
  end
  return best_rank
end

local function apply_uncle(item, target_index)
  if state.money < (item.cost or 0) then
    return false, "Not enough money for " .. item.name .. "."
  end

  local name = item.id
  if name == "uncle_bramble" then
    local card = state.player_hand[target_index]
    if not card then
      return false, "No card selected."
    end
    if card.locked or card.eternal then
      return false, "That card can't be transformed."
    end
    card.rank = 5
  elseif name == "uncle_cedar" then
    local card = state.player_hand[target_index]
    if not card then
      return false, "No card selected."
    end
    if card.locked or card.eternal then
      return false, "That card can't be transformed."
    end
    card.rank = math.min(card.rank + 1, 13)
  elseif name == "uncle_oakley" then
    local card = state.player_hand[target_index]
    if not card then
      return false, "No card selected."
    end
    if card.locked or card.eternal then
      return false, "That card can't be transformed."
    end
    local rank = most_common_rank_in_hand(state.player_hand, target_index)
    if not rank then
      return false, "No matching rank available."
    end
    card.rank = rank
  elseif name == "uncle_birch" then
    local card = state.player_hand[target_index]
    if not card then
      return false, "No card selected."
    end
    if card.locked or card.eternal then
      return false, "That card can't be transformed."
    end
    local choices = { 10, 11, 12, 13 }
    card.rank = choices[love.math.random(#choices)]
  elseif name == "uncle_sage" then
    for _ = 1, 2 do
      state.deck[#state.deck + 1] = {
        rank = love.math.random(1, 13),
        suit = love.math.random(1, 4),
      }
    end
  elseif name == "uncle_ash" then
    card.enhancement = "golden_card"
  elseif name == "uncle_rowan" then
    local card = state.player_hand[target_index]
    if not card then
      return false, "No card selected."
    end
    if card.locked or card.eternal then
      return false, "That card can't be transformed."
    end
    card.suit = 4
  elseif name == "uncle_sycamore" then
    local card = state.player_hand[target_index]
    if not card then
      return false, "No card selected."
    end
    if card.locked or card.eternal then
      return false, "That card can't be transformed."
    end
    card.suit = 2
  elseif name == "uncle_cypress" then
    local card = state.player_hand[target_index]
    if not card then
      return false, "No card selected."
    end
    if card.locked or card.eternal then
      return false, "That card can't be transformed."
    end
    card.suit = 3
  elseif name == "uncle_elm" then
    local card = state.player_hand[target_index]
    if not card then
      return false, "No card selected."
    end
    if card.locked or card.eternal then
      return false, "That card can't be transformed."
    end
    card.suit = 1
  elseif name == "uncle_hickory" then
    for _ = 1, math.min(2, #state.deck) do
      table.remove(state.deck, love.math.random(#state.deck))
    end
    state.money = state.money + 4
  elseif name == "uncle_willow" then
    local card = state.player_hand[target_index]
    if not card then
      return false, "No card selected."
    end
    if card.locked or card.eternal then
      return false, "That card can't be transformed."
    end
    local target_rank = card.rank
    for i = 1, #state.player_hand do
      state.player_hand[i].rank = target_rank
    end
  elseif name == "uncle_chestnut" then
    local card = state.player_hand[target_index]
    if not card then
      return false, "No card selected."
    end
    if card.locked or card.eternal then
      return false, "That card can't be transformed."
    end
    card.enhancement = "toy_card"
  elseif name == "uncle_alder" then
    for i = 1, #state.player_hand do
      state.player_hand[i].rank = love.math.random(1, 13)
    end
  elseif name == "uncle_linden" then
    local card = state.player_hand[target_index]
    if not card then
      return false, "No card selected."
    end
    state.deck[#state.deck + 1] = { rank = card.rank, suit = card.suit }
  else
    return false, "That Uncle's effect isn't available yet."
  end

  state.money = state.money - (item.cost or 0)
  return true, "Used " .. item.name .. "."
end

local function apply_side_dish(item, target_index)
  local card = state.player_hand[target_index]
  if not card then
    return false, "No card selected."
  end
  if card.locked or card.eternal then
    return false, "That card can't be modified."
  end

  if item.id == "negative_card" then
    state.hand_size_bonus = (state.hand_size_bonus or 0) + 1
    return true, "Used " .. item.name .. "."
  end

  if item.id == "pinned_card" then
    card.pinned = true
  elseif item.id == "steel_card" then
    card.locked = true
  elseif item.id == "eternal_card" then
    card.eternal = true
  end

  card.enhancement = item.id
  return true, "Used " .. item.name .. "."
end

local function point_in_rect(x, y, rect)
  return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function hand_index_at(x, y, hand_x, hand_y, hand_count)
  local card_w, card_h, gap = ui.card_dimensions()
  for i = 1, hand_count do
    local card_x = hand_x + (i - 1) * (card_w + gap)
    if x >= card_x and x <= card_x + card_w and y >= hand_y and y <= hand_y + card_h then
      return i
    end
  end
  return nil
end

local function inventory_hitbox()
  local label = "Inventory (I)"
  local font = love.graphics.getFont()
  local width = font and font:getWidth(label) or 110
  local height = font and font:getHeight() or 18
  return { x = 900, y = 20, w = width, h = height }
end

local function enter_button_rect()
  return { x = 30, y = 610, w = 90, h = 28 }
end

local function sort_rank_button_rect()
  return { x = 130, y = 610, w = 110, h = 28 }
end

local function sort_suit_button_rect()
  return { x = 250, y = 610, w = 110, h = 28 }
end

local function shop_family_item_rect(index)
  local y = 320 + (index - 1) * 18
  return { x = 30, y = y, w = 170, h = 18 }
end

local function shop_dish_item_rect(index, family_count)
  local base = 320 + (family_count * 18) + 48
  local y = base + (index - 1) * 18
  return { x = 30, y = y, w = 170, h = 18 }
end

local function inventory_family_item_rect(index)
  local y = 320 + (index - 1) * 18
  return { x = 30, y = y, w = 420, h = 18 }
end

local function inventory_dish_item_rect(index, family_count)
  local y = 320 + (family_count * 18) + 48 + (index - 1) * 18
  return { x = 30, y = y, w = 420, h = 18 }
end

local function confirm_accept_rect()
  return { x = 30, y = 610, w = 90, h = 28 }
end

local function confirm_cancel_rect()
  return { x = 130, y = 610, w = 90, h = 28 }
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

local function reset_selection()
  state.selected_cards = {}
end

local function sort_hand_by_rank(hand)
  table.sort(hand, function(a, b)
    if a.rank == b.rank then
      return a.suit < b.suit
    end
    return a.rank < b.rank
  end)
end

local function sort_hand_by_suit(hand)
  table.sort(hand, function(a, b)
    if a.suit == b.suit then
      return a.rank < b.rank
    end
    return a.suit < b.suit
  end)
end

local function draw_top_bar()
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Level: " .. tostring(state.round_index), 30, 20)
  love.graphics.print("Money: $" .. tostring(state.money or 0), 150, 20)
  love.graphics.print("Discards: " .. tostring(state.discards_remaining or 0), 280, 20)
  love.graphics.print("Hands: " .. tostring(state.hands_remaining or 0), 430, 20)
  love.graphics.print("Round Score: " .. tostring(state.current_round_score or 0), 560, 20)
  love.graphics.print("Target: " .. tostring(state.target_score or 0), 760, 20)
  local inv = inventory_hitbox()
  love.graphics.rectangle("line", inv.x - 6, inv.y - 4, inv.w + 12, inv.h + 8, 6, 6)
  love.graphics.print("Inventory (I)", 900, 20)
end

local function draw_board_panel()
  local board = state.board
  if not board then
    return
  end
  local street = board.streets[state.round_index]
  local next_street = board.streets[state.round_index + 1]
  local lines = {
    "Board: " .. board.name .. " (" .. board.subtitle .. ")",
  }
  if street then
    lines[#lines + 1] = "Street " .. tostring(street.id) .. ": " .. street.name
    lines[#lines + 1] = "Condition: " .. street.condition
    lines[#lines + 1] = "Objective: " .. street.objective
  end
  if next_street then
    lines[#lines + 1] = "Next: " .. tostring(next_street.id) .. " - " .. next_street.name
    lines[#lines + 1] = "Next condition: " .. next_street.condition
    lines[#lines + 1] = "Next objective: " .. next_street.objective
  end
  ui.draw_text_block(lines, 520, 70)
end

local function draw_family_panel()
  love.graphics.print("Family (" .. tostring(#state.family) .. "/" .. tostring(state.family_slots) .. "):", 520, 320)
  local y = 340
  for i = 1, #state.family do
    local item = state.auntie_lookup[state.family[i]]
    if item then
      love.graphics.print("- " .. item.name .. ": " .. item.effect, 520, y)
      y = y + 18
    end
  end
end

local function draw_starter()
  if not state.starter_card then
    return
  end
  love.graphics.print("Cut card", 30, 110)
  ui.draw_face_up_card(state.starter_card, 30, 130)
end

local function draw_discard_top()
  if not state.discard_pile or #state.discard_pile == 0 then
    return
  end
  local card = state.discard_pile[#state.discard_pile]
  love.graphics.print("Discard (top)", 160, 110)
  ui.draw_face_up_card(card, 160, 130)
end

local function draw_card_page(cards_list, page, per_page, x, y)
  local start_index = (page - 1) * per_page + 1
  local end_index = math.min(#cards_list, start_index + per_page - 1)
  local display = {}
  for i = start_index, end_index do
    display[#display + 1] = cards_list[i]
  end
  if #display > 0 then
    ui.draw_cards_row(display, x, y)
  end
  return start_index, end_index
end

function M.start_round()
  local deck = cards.shuffle(cards.build_deck({}))
  state.deck = deck
  state.player_hand = {}
  for _ = 1, current_hand_size() do
    state.player_hand[#state.player_hand + 1] = table.remove(deck)
  end
  state.starter_card = table.remove(deck)
  state.discards_remaining = discards_for_round(state.round_index)
  state.hands_remaining = 4
  state.current_round_score = 0
  state.hand_scores = {}
  state.last_hand = nil
  state.discard_pile = {}
  state.round_reward = nil
  state.reward_breakdown = nil
  state.objective = {
    label = "Score a fifteen every hand this round",
    failed = false,
    complete = false,
    hands_checked = 0,
  }
  state.phase = "select_hand"
  state.message = nil
  reset_selection()
end

function M.load()
  love.graphics.setBackgroundColor(0.12, 0.12, 0.16)
  ui.set_font()
  state.board = boards.boards and boards.boards.Backyard or nil
  state.money = 5
  state.total_earned = 0
  state.family = {}
  state.family_slots = 3
  state.side_pouch = {}
  state.side_pouch_capacity = 3
  state.auntie_lookup = build_auntie_lookup()
  state.dish_lookup = build_dish_lookup()
  state.auntie_pool = flatten_aunties()
  state.dish_pool = flatten_dishes()
  state.round_index = 1
  state.target_score = target_for_round(state.round_index)
  begin_run_log()
  log_event("Run start. Money=$" .. tostring(state.money))
  M.start_round()
end

function M.update(_dt)
  return
end

function M.keypressed(key)
  if key == "escape" then
    love.event.quit()
    return
  end

  if key == "i" then
    if state.phase == "inventory" then
      state.phase = state.inventory_return_phase or "select_hand"
      state.inventory_return_phase = nil
    else
      state.inventory_return_phase = state.phase
      state.phase = "inventory"
    end
    return
  end

  if key == "v" then
    if state.phase == "discard_view" then
      state.phase = state.discard_return_phase or "select_hand"
      state.discard_return_phase = nil
    else
      state.discard_return_phase = state.phase
      state.discard_view_page = 1
      state.phase = "discard_view"
    end
    return
  end

  if key == "k" then
    if state.phase == "deck_view" then
      state.phase = state.deck_return_phase or "select_hand"
      state.deck_return_phase = nil
    else
      state.deck_return_phase = state.phase
      state.deck_view_page = 1
      state.phase = "deck_view"
    end
    return
  end

  if state.phase == "discard_view" then
    if key == "n" then
      state.discard_view_page = (state.discard_view_page or 1) + 1
      return
    end
    if key == "p" and (state.discard_view_page or 1) > 1 then
      state.discard_view_page = state.discard_view_page - 1
      return
    end
    if key == "b" or key == "v" or key == "return" then
      state.phase = state.discard_return_phase or "select_hand"
      state.discard_return_phase = nil
      return
    end
    return
  end

  if state.phase == "deck_view" then
    if key == "n" then
      state.deck_view_page = (state.deck_view_page or 1) + 1
      return
    end
    if key == "p" and (state.deck_view_page or 1) > 1 then
      state.deck_view_page = state.deck_view_page - 1
      return
    end
    if key == "b" or key == "k" or key == "return" then
      state.phase = state.deck_return_phase or "select_hand"
      state.deck_return_phase = nil
      return
    end
    return
  end

  if key == "m" then
    if state.phase == "map" then
      state.phase = state.map_return_phase or "select_hand"
      state.map_return_phase = nil
    else
      state.map_return_phase = state.phase
      state.phase = "map"
    end
    return
  end

  if state.phase == "map" then
    if key == "b" or key == "m" or key == "return" then
      state.phase = state.map_return_phase or "select_hand"
      state.map_return_phase = nil
    end
    return
  end

  if state.phase == "inventory" then
    local index = tonumber(key)
    if index then
      if index >= 1 and index <= #state.family then
        local family_id = state.family[index]
        local item = state.auntie_lookup[family_id]
        if not item then
          state.message = "Invalid family member."
          return
        end
        if not tostring(item.id):match("^uncle_") then
          state.message = item.name .. " is passive."
          return
        end
        state.inventory_use = {
          kind = "uncle",
          item = item,
          requires_card = item.id ~= "uncle_sage" and item.id ~= "uncle_hickory" and item.id ~= "uncle_alder",
        }
        reset_selection()
        state.phase = "inventory_target"
        state.message = "Select card(s) for " .. item.name .. "."
        return
      end
      local dish_index = index - #state.family
      if dish_index >= 1 and dish_index <= #state.side_pouch then
        local dish = state.side_pouch[dish_index]
        state.inventory_use = {
          kind = "dish",
          item = dish,
          index = dish_index,
          requires_card = true,
        }
        reset_selection()
        state.phase = "inventory_target"
        state.message = "Select card(s) for " .. dish.name .. "."
        return
      end
    end
    if key == "b" then
      state.phase = state.inventory_return_phase or "select_hand"
      state.inventory_return_phase = nil
      return
    end
    return
  end

  if state.phase == "select_hand" or state.phase == "inventory_target" then
    local index = tonumber(key)
    if index and index >= 1 and index <= #state.player_hand then
      if state.player_hand[index] and state.player_hand[index].pinned then
        state.message = "That card is pinned and can't be played."
        return
      end
      if state.selected_cards[index] then
        state.selected_cards[index] = false
      else
        if count_selected(state.selected_cards) >= 6 then
          state.message = "Select up to 6 cards to score."
        else
          state.selected_cards[index] = true
        end
      end
      return
    end
    if key == "r" then
      sort_hand_by_rank(state.player_hand)
      reset_selection()
      return
    end
    if key == "s" then
      sort_hand_by_suit(state.player_hand)
      reset_selection()
      return
    end
    if state.phase == "inventory_target" then
      if key == "b" then
        state.inventory_use = nil
        reset_selection()
        state.phase = "inventory"
        return
      end
      if key == "return" then
        if state.inventory_use and state.inventory_use.requires_card then
          local count = count_selected(state.selected_cards)
          if count ~= 1 then
            state.message = "Select exactly 1 card."
            return
          end
        end
        state.phase = "inventory_confirm"
        state.message = "Confirm use? Enter=accept, N=cancel."
        return
      end
      if key == "n" then
        state.inventory_use = nil
        reset_selection()
        state.phase = "inventory"
        return
      end
      return
    end
    if key == "d" then
      if state.discards_remaining <= 0 then
        state.message = "No discards remaining this round."
        return
      end
      local count = count_selected(state.selected_cards)
      if count == 0 then
        state.message = "Select 1-" .. tostring(state.discards_remaining) .. " cards to discard."
        return
      end
      if count > state.discards_remaining then
        state.message = "Only " .. tostring(state.discards_remaining) .. " discards left this round."
        return
      end
      for i, selected in pairs(state.selected_cards) do
        if selected then
          local card = state.player_hand[i]
          if card and (card.locked or card.eternal) then
            state.message = "A selected card can't be discarded."
            return
          end
        end
      end
      local indices = {}
      for i, selected in pairs(state.selected_cards) do
        if selected then
          indices[#indices + 1] = i
        end
      end
      remove_indices(state.player_hand, indices)
      while #state.player_hand < current_hand_size() and #state.deck > 0 do
        state.player_hand[#state.player_hand + 1] = table.remove(state.deck)
      end
      state.discards_remaining = state.discards_remaining - count
      state.message = nil
      reset_selection()
      return
    end
    if key == "return" then
      local count = count_selected(state.selected_cards)
      if count < 1 or count > 6 then
        state.message = "Select 1-6 cards to score."
        return
      end
      local picked = collect_selected_cards(state.player_hand, state.selected_cards)
      local picked_indices = collect_selected_indices(state.selected_cards)
      local total, breakdown, details = scoring.score_hand(picked, state.starter_card, false)
      state.current_round_score = state.current_round_score + total
      state.hand_scores[#state.hand_scores + 1] = { total = total, breakdown = breakdown, details = details }
      state.last_hand = {
        cards = picked,
        total = total,
        breakdown = breakdown,
        details = details,
        indices = picked_indices,
      }
      if state.objective then
        state.objective.hands_checked = state.objective.hands_checked + 1
        local has_fifteen = details and details.fifteens and #details.fifteens > 0
        if not has_fifteen then
          state.objective.failed = true
        end
        if state.hands_remaining - 1 == 0 and not state.objective.failed then
          state.objective.complete = true
        end
      end
      local removed = remove_indices(state.player_hand, picked_indices)
      for i = 1, #removed do
        state.discard_pile[#state.discard_pile + 1] = removed[i]
      end
      while #state.player_hand < current_hand_size() and #state.deck > 0 do
        state.player_hand[#state.player_hand + 1] = table.remove(state.deck)
      end
      state.hands_remaining = state.hands_remaining - 1
      log_event("Hand scored: +" .. tostring(total) .. " (round total " .. tostring(state.current_round_score) .. ")")
      state.phase = "score_hand"
      state.message = nil
      reset_selection()
      return
    end
  elseif state.phase == "inventory_confirm" then
    if key == "n" then
      reset_selection()
      state.phase = "inventory"
      state.message = "Cancelled."
      return
    end
    if key == "return" then
      local target_index = single_selected_index(state.selected_cards)
      local use = state.inventory_use
      if not use then
        state.phase = "inventory"
        return
      end
      local ok, msg = false, "Invalid inventory use."
      if use.kind == "uncle" then
        ok, msg = apply_uncle(use.item, target_index)
      elseif use.kind == "dish" then
        ok, msg = apply_side_dish(use.item, target_index)
        if ok and use.index then
          table.remove(state.side_pouch, use.index)
        end
      end
      state.inventory_use = nil
      reset_selection()
      state.phase = "select_hand"
      state.message = msg
      return
    end
  elseif state.phase == "score_hand" then
    if key == "return" or key == "space" then
      if state.hands_remaining == 0 and state.current_round_score >= state.target_score and not state.round_reward then
        local total, breakdown = calculate_round_reward(
          state.current_round_score,
          state.target_score,
          state.round_index,
          state.discards_remaining,
          state.hands_remaining
        )
        state.round_reward = total
        state.reward_breakdown = breakdown
        state.money = state.money + total
        state.total_earned = state.total_earned + total
        log_event("Round reward: +" .. tostring(total) .. " (money $" .. tostring(state.money) .. ")")
      end
      if state.hands_remaining > 0 then
        state.phase = "select_hand"
      else
        state.phase = "round_end"
      end
      return
    end
  elseif state.phase == "shop" then
    local index = tonumber(key)
    if index then
      local stock_family = state.shop and state.shop.family_stock or {}
      local stock_dishes = state.shop and state.shop.dish_stock or {}
      if index >= 1 and index <= #stock_family then
        local item = stock_family[index]
        if state.money < item.cost then
          state.message = "Not enough money."
          return
        end
        if #state.family >= state.family_slots then
          state.message = "Family slots full."
          return
        end
        local before = state.money
        state.money = state.money - item.cost
        state.family[#state.family + 1] = item.id
        table.remove(state.shop.family_stock, index)
        state.message = "Hired " .. item.name .. "."
        log_event("Purchased family " .. item.name .. " for $" .. tostring(item.cost) .. " (money $" .. tostring(before) .. " -> $" .. tostring(state.money) .. ")")
        return
      end
      local dish_index = index - #stock_family
      if dish_index >= 1 and dish_index <= #stock_dishes then
        local item = stock_dishes[dish_index]
        if state.money < item.cost then
          state.message = "Not enough money."
          return
        end
        if #state.side_pouch >= state.side_pouch_capacity then
          state.message = "Side dish pouch full."
          return
        end
        local before = state.money
        state.money = state.money - item.cost
        state.side_pouch[#state.side_pouch + 1] = item
        table.remove(state.shop.dish_stock, dish_index)
        state.message = "Bought " .. item.name .. "."
        log_event("Purchased dish " .. item.name .. " for $" .. tostring(item.cost) .. " (money $" .. tostring(before) .. " -> $" .. tostring(state.money) .. ")")
        return
      end
    end
    if key == "return" then
      M.start_round()
      return
    end
  elseif state.phase == "round_end" then
    if key == "return" then
      if state.current_round_score >= state.target_score then
        state.round_index = state.round_index + 1
        state.target_score = target_for_round(state.round_index)
        state.shop = {
          family_stock = pick_random(state.auntie_pool, 3),
          dish_stock = pick_random(state.dish_pool, 3),
        }
        state.phase = "shop"
      end
      return
    end
    if key == "r" then
      state.round_index = 1
      state.target_score = target_for_round(state.round_index)
      M.start_round()
      return
    end
  end
end

function M.mousepressed(x, y, button)
  if button ~= 1 then
    return
  end

  if point_in_rect(x, y, inventory_hitbox()) then
    M.keypressed("i")
    return
  end

  if state.phase == "select_hand" then
    local index = hand_index_at(x, y, 30, 300, #state.player_hand)
    if index then
      M.keypressed(tostring(index))
      return
    end
    if point_in_rect(x, y, enter_button_rect()) then
      M.keypressed("return")
      return
    end
    if point_in_rect(x, y, sort_rank_button_rect()) then
      M.keypressed("r")
      return
    end
    if point_in_rect(x, y, sort_suit_button_rect()) then
      M.keypressed("s")
      return
    end
  elseif state.phase == "score_hand" then
    if point_in_rect(x, y, enter_button_rect()) then
      M.keypressed("return")
      return
    end
  elseif state.phase == "inventory_target" then
    local index = hand_index_at(x, y, 30, 300, #state.player_hand)
    if index then
      M.keypressed(tostring(index))
      return
    end
    if point_in_rect(x, y, confirm_accept_rect()) then
      M.keypressed("return")
      return
    end
    if point_in_rect(x, y, confirm_cancel_rect()) then
      M.keypressed("n")
      return
    end
  elseif state.phase == "inventory_confirm" then
    if point_in_rect(x, y, confirm_accept_rect()) then
      M.keypressed("return")
      return
    end
    if point_in_rect(x, y, confirm_cancel_rect()) then
      M.keypressed("n")
      return
    end
  elseif state.phase == "inventory" then
    local family_count = #state.family
    for i = 1, family_count do
      if point_in_rect(x, y, inventory_family_item_rect(i)) then
        M.keypressed(tostring(i))
        return
      end
    end
    for i = 1, #state.side_pouch do
      if point_in_rect(x, y, inventory_dish_item_rect(i, family_count)) then
        M.keypressed(tostring(i + family_count))
        return
      end
    end
  elseif state.phase == "shop" then
    if not state.shop then
      return
    end
    if point_in_rect(x, y, enter_button_rect()) then
      M.keypressed("return")
      return
    end
    local family_count = #state.shop.family_stock
    for i = 1, family_count do
      if point_in_rect(x, y, shop_family_item_rect(i)) then
        M.keypressed(tostring(i))
        return
      end
    end
    local dish_count = #state.shop.dish_stock
    for i = 1, dish_count do
      if point_in_rect(x, y, shop_dish_item_rect(i, family_count)) then
        M.keypressed(tostring(i + family_count))
        return
      end
    end
  end
end

function M.draw()
  draw_top_bar()
  draw_starter()
  draw_discard_top()
  draw_board_panel()
  draw_family_panel()
  love.graphics.setColor(1, 1, 1)

  if state.phase == "select_hand" then
    love.graphics.print("Select 1-6 cards. Enter=score, D=discard (1-" .. tostring(state.discards_remaining) .. "), I=inventory use, R=rank sort, S=suit sort.", 30, 260)
    ui.draw_hand(state.player_hand, 30, 300, state.selected_cards)
    love.graphics.rectangle("line", 30, 610, 90, 28, 6, 6)
    love.graphics.print("Enter", 50, 615)
    local rank_button = sort_rank_button_rect()
    local suit_button = sort_suit_button_rect()
    love.graphics.rectangle("line", rank_button.x, rank_button.y, rank_button.w, rank_button.h, 6, 6)
    love.graphics.print("Rank sort", rank_button.x + 8, rank_button.y + 5)
    love.graphics.rectangle("line", suit_button.x, suit_button.y, suit_button.w, suit_button.h, 6, 6)
    love.graphics.print("Suit sort", suit_button.x + 8, suit_button.y + 5)
    if state.objective then
      local tally = state.objective.complete and "1/1" or "0/1"
      love.graphics.print("Objective: " .. state.objective.label .. " (" .. tally .. ")", 30, 230)
    end
  elseif state.phase == "inventory_target" then
    love.graphics.print("Select target card(s). Enter to confirm, N to cancel.", 30, 260)
    ui.draw_hand(state.player_hand, 30, 300, state.selected_cards)
    local accept = confirm_accept_rect()
    local cancel = confirm_cancel_rect()
    love.graphics.rectangle("line", accept.x, accept.y, accept.w, accept.h, 6, 6)
    love.graphics.print("Accept", accept.x + 12, accept.y + 5)
    love.graphics.rectangle("line", cancel.x, cancel.y, cancel.w, cancel.h, 6, 6)
    love.graphics.print("Cancel", cancel.x + 12, cancel.y + 5)
  elseif state.phase == "inventory_confirm" then
    love.graphics.print("Confirm use? Enter=accept, N=cancel.", 30, 260)
    local accept = confirm_accept_rect()
    local cancel = confirm_cancel_rect()
    love.graphics.rectangle("line", accept.x, accept.y, accept.w, accept.h, 6, 6)
    love.graphics.print("Accept", accept.x + 12, accept.y + 5)
    love.graphics.rectangle("line", cancel.x, cancel.y, cancel.w, cancel.h, 6, 6)
    love.graphics.print("Cancel", cancel.x + 12, cancel.y + 5)
  elseif state.phase == "score_hand" then
    love.graphics.print("Hand scored. Press Enter to continue.", 30, 260)
    love.graphics.rectangle("line", 30, 610, 90, 28, 6, 6)
    love.graphics.print("Enter", 50, 615)
    if state.objective then
      local tally = state.objective.complete and "1/1" or "0/1"
      love.graphics.print("Objective: " .. state.objective.label .. " (" .. tally .. ")", 30, 230)
    end
    if state.last_hand then
      ui.draw_cards_row(state.last_hand.cards, 30, 300)
      local entries = build_combo_entries(state.last_hand.details)
      entries[#entries + 1] = { label = "Total: " .. tostring(state.last_hand.total) }
      ui.draw_combo_entries(entries, 30, 430)
    end
  elseif state.phase == "round_end" then
    love.graphics.print("Round complete.", 30, 260)
    love.graphics.print("Total score: " .. tostring(state.current_round_score), 30, 290)
    love.graphics.print("Target: " .. tostring(state.target_score), 30, 320)
    if state.objective then
      local tally = state.objective.complete and "1/1" or "0/1"
      love.graphics.print("Objective: " .. state.objective.label .. " (" .. tally .. ")", 30, 350)
    end
    local next_bonus_1 = math.floor(state.target_score * 1.10 + 0.5)
    local next_bonus_2 = math.floor(state.target_score * 1.20 + 0.5)
    local next_bonus_3 = math.floor(state.target_score * 1.30 + 0.5)
    love.graphics.print("Bonus thresholds: " .. tostring(next_bonus_1) .. " (+$1), " .. tostring(next_bonus_2) .. " (+$2), " .. tostring(next_bonus_3) .. " (+$3)", 30, 380)
    if state.current_round_score >= state.target_score then
      love.graphics.print("Success! Press Enter to open the shop.", 30, 360)
      if not state.round_reward then
        local total, breakdown = calculate_round_reward(
          state.current_round_score,
          state.target_score,
          state.round_index,
          state.discards_remaining,
          state.hands_remaining
        )
        state.reward_breakdown = breakdown
        state.round_reward = total
      end
      if state.reward_breakdown then
        love.graphics.print("Base: +$" .. tostring(state.reward_breakdown.base), 30, 410)
        love.graphics.print("Performance: +$" .. tostring(state.reward_breakdown.performance), 30, 430)
        love.graphics.print("Perfect (no discards): +$" .. tostring(state.reward_breakdown.perfect), 30, 450)
        love.graphics.print("Hands saved: +$" .. tostring(state.reward_breakdown.hands_saved), 30, 470)
        love.graphics.print("Total earned this round: +$" .. tostring(state.round_reward or 0), 30, 490)
        love.graphics.print("Total earned run: $" .. tostring(state.total_earned or 0), 30, 510)
      end
    else
      love.graphics.print("Failed. Press R to restart.", 30, 360)
    end
  elseif state.phase == "shop" then
    love.graphics.print("Shop - Money: $" .. tostring(state.money) .. " (Enter to continue)", 30, 260)
    love.graphics.print("Family for hire:", 30, 290)
    local y = 320
    for i = 1, #state.shop.family_stock do
      local item = state.shop.family_stock[i]
      love.graphics.print(tostring(i) .. ") " .. item.name .. " - $" .. tostring(item.cost), 30, y)
      love.graphics.print(item.effect, 220, y)
      y = y + 18
    end
    y = y + 18
    love.graphics.print("Side dishes:", 30, y)
    y = y + 30
    for i = 1, #state.shop.dish_stock do
      local item = state.shop.dish_stock[i]
      local index = i + #state.shop.family_stock
      love.graphics.print(tostring(index) .. ") " .. item.name .. " - $" .. tostring(item.cost), 30, y)
      love.graphics.print(item.effect, 220, y)
      y = y + 18
    end
    love.graphics.rectangle("line", 30, 610, 90, 28, 6, 6)
    love.graphics.print("Enter", 50, 615)
  elseif state.phase == "inventory" then
    love.graphics.print("Inventory (press I or B to return)", 30, 260)
    love.graphics.print("Family (" .. tostring(#state.family) .. "/" .. tostring(state.family_slots) .. "):", 30, 290)
    local y = 320
    for i = 1, #state.family do
      local item = state.auntie_lookup[state.family[i]]
      if item then
        love.graphics.print(tostring(i) .. ") " .. item.name .. " - " .. item.effect, 30, y)
        y = y + 18
      end
    end
    y = y + 18
    love.graphics.print("Side dishes (" .. tostring(#state.side_pouch) .. "/" .. tostring(state.side_pouch_capacity) .. "):", 30, y)
    y = y + 30
    for i = 1, #state.side_pouch do
      local item = state.side_pouch[i]
      local index = i + #state.family
      love.graphics.print(tostring(index) .. ") " .. item.name .. " - " .. item.effect, 30, y)
      y = y + 18
    end
  elseif state.phase == "map" then
    local board = state.board
    if board then
      love.graphics.print("Board Map - " .. board.name, 30, 240)
      local y = 270
      for i = 1, #board.streets do
        local street = board.streets[i]
        local prefix = "○ "
        if i < state.round_index then
          prefix = "✓ "
        elseif i == state.round_index then
          prefix = "► "
        end
        love.graphics.print(prefix .. "Street " .. tostring(street.id) .. ": " .. street.name, 30, y)
        love.graphics.print("Cond: " .. street.condition, 320, y)
        y = y + 18
      end
      love.graphics.print("Press M/B/Enter to close.", 30, y + 20)
    end
  elseif state.phase == "discard_view" then
    love.graphics.print("Discard pile (" .. tostring(#state.discard_pile) .. ")", 30, 260)
    local page = state.discard_view_page or 1
    local per_page = 9
    local start_index, end_index = draw_card_page(state.discard_pile, page, per_page, 30, 300)
    love.graphics.print("Showing " .. tostring(start_index) .. "-" .. tostring(end_index) .. " (N/P to page, B to close)", 30, 430)
  elseif state.phase == "deck_view" then
    love.graphics.print("Deck (" .. tostring(#state.deck) .. ")", 30, 260)
    local page = state.deck_view_page or 1
    local per_page = 9
    local start_index, end_index = draw_card_page(state.deck, page, per_page, 30, 300)
    love.graphics.print("Showing " .. tostring(start_index) .. "-" .. tostring(end_index) .. " (N/P to page, B to close)", 30, 430)
  end

  if state.message then
    love.graphics.print(state.message, 30, 620)
  end
end

return M
