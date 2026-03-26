local cards = require("src.cards")

local M = {}

local function copy_table(list)
  local out = {}
  for i = 1, #list do
    out[i] = list[i]
  end
  return out
end

local function fifteens_score(all_cards)
  local values = {}
  for i = 1, #all_cards do
    values[i] = cards.card_value(all_cards[i])
  end

  local count = 0
  local n = #values
  local function search(start, total, picked)
    if total == 15 and picked >= 2 then
      count = count + 1
      return
    end
    if total >= 15 or start > n then
      return
    end
    for i = start, n do
      search(i + 1, total + values[i], picked + 1)
    end
  end

  search(1, 0, 0)
  return count * 2, count
end

local function fifteens_combos(all_cards)
  local values = {}
  for i = 1, #all_cards do
    values[i] = cards.card_value(all_cards[i])
  end

  local combos = {}
  local n = #values
  local function search(start, total, picked, chosen)
    if total == 15 and picked >= 2 then
      combos[#combos + 1] = { cards = copy_table(chosen), points = 2, label = "15" }
      return
    end
    if total >= 15 or start > n then
      return
    end
    for i = start, n do
      chosen[#chosen + 1] = all_cards[i]
      search(i + 1, total + values[i], picked + 1, chosen)
      chosen[#chosen] = nil
    end
  end

  search(1, 0, 0, {})
  return combos
end

local function cards_by_rank(all_cards)
  local map = {}
  for rank = 1, 13 do
    map[rank] = {}
  end
  for i = 1, #all_cards do
    local card = all_cards[i]
    map[card.rank][#map[card.rank] + 1] = card
  end
  return map
end

local function pair_combos(all_cards)
  local combos = {}
  local map = cards_by_rank(all_cards)
  for rank = 1, 13 do
    local list = map[rank]
    if #list >= 2 then
      for i = 1, #list - 1 do
        for j = i + 1, #list do
          combos[#combos + 1] = { cards = { list[i], list[j] }, points = 2, label = "Pair" }
        end
      end
    end
  end
  return combos
end

local function run_combos(all_cards)
  local combos = {}
  local map = cards_by_rank(all_cards)
  local counts = {}
  for rank = 1, 13 do
    counts[rank] = #map[rank]
  end

  local run_length = 0
  for length = 5, 3, -1 do
    local run_count = 0
    for start = 1, 14 - length do
      local multiplicity = 1
      for r = start, start + length - 1 do
        if counts[r] == 0 then
          multiplicity = 0
          break
        end
        multiplicity = multiplicity * counts[r]
      end
      run_count = run_count + multiplicity
    end
    if run_count > 0 then
      run_length = length
      break
    end
  end

  if run_length == 0 then
    return combos
  end

  local function build_runs(start_rank, idx, current)
    if idx > run_length then
      combos[#combos + 1] = { cards = copy_table(current), points = run_length, label = "Run " .. tostring(run_length) }
      return
    end
    local rank = start_rank + idx - 1
    for i = 1, #map[rank] do
      current[#current + 1] = map[rank][i]
      build_runs(start_rank, idx + 1, current)
      current[#current] = nil
    end
  end

  for start = 1, 14 - run_length do
    local ok = true
    for r = start, start + run_length - 1 do
      if counts[r] == 0 then
        ok = false
        break
      end
    end
    if ok then
      build_runs(start, 1, {})
    end
  end

  return combos
end

local flush_score

local function flush_combo(hand, starter, is_crib)
  local points = flush_score(hand, starter, is_crib)
  if points == 0 then
    return nil
  end
  local cards_list = copy_table(hand)
  if points == 5 and starter then
    cards_list[#cards_list + 1] = starter
  end
  return { cards = cards_list, points = points, label = "Flush" }
end

local function knobs_combo(hand, starter)
  if not starter then
    return nil
  end
  for i = 1, #hand do
    if hand[i].rank == 11 and hand[i].suit == starter.suit then
      return { cards = { hand[i], starter }, points = 1, label = "Knobs" }
    end
  end
  return nil
end

local function pairs_score(all_cards)
  local pairs = 0
  for i = 1, #all_cards - 1 do
    for j = i + 1, #all_cards do
      if all_cards[i].rank == all_cards[j].rank then
        pairs = pairs + 1
      end
    end
  end
  return pairs * 2, pairs
end

local function run_score(all_cards)
  local counts = {}
  for rank = 1, 13 do
    counts[rank] = 0
  end
  for i = 1, #all_cards do
    counts[all_cards[i].rank] = counts[all_cards[i].rank] + 1
  end

  for length = 5, 3, -1 do
    local run_count = 0
    for start = 1, 14 - length do
      local multiplicity = 1
      for r = start, start + length - 1 do
        if counts[r] == 0 then
          multiplicity = 0
          break
        end
        multiplicity = multiplicity * counts[r]
      end
      run_count = run_count + multiplicity
    end
    if run_count > 0 then
      return run_count * length, run_count, length
    end
  end

  return 0, 0, 0
end

flush_score = function(hand, starter, is_crib)
  if #hand ~= 4 then
    return 0
  end
  local suit = hand[1].suit
  for i = 2, 4 do
    if hand[i].suit ~= suit then
      return 0
    end
  end
  if starter and starter.suit == suit then
    return 5
  end
  if is_crib then
    return 0
  end
  return 4
end

local function knobs_score(hand, starter)
  if not starter then
    return 0
  end
  for i = 1, #hand do
    if hand[i].rank == 11 and hand[i].suit == starter.suit then
      return 1
    end
  end
  return 0
end

function M.score_hand(hand, starter, is_crib)
  local all_cards = copy_table(hand)
  all_cards[#all_cards + 1] = starter

  local breakdown = {}
  local total = 0
  local fifteen_details = fifteens_combos(all_cards)
  local pair_details = pair_combos(all_cards)
  local run_details = run_combos(all_cards)
  local flush_detail = flush_combo(hand, starter, is_crib)
  local knobs_detail = knobs_combo(hand, starter)

  local fifteens, fifteen_count = fifteens_score(all_cards)
  if fifteens > 0 then
    breakdown[#breakdown + 1] = "Fifteens (" .. tostring(fifteen_count) .. "): " .. tostring(fifteens)
    total = total + fifteens
  end

  local pairs, pair_count = pairs_score(all_cards)
  if pairs > 0 then
    breakdown[#breakdown + 1] = "Pairs (" .. tostring(pair_count) .. "): " .. tostring(pairs)
    total = total + pairs
  end

  local runs, run_count, run_length = run_score(all_cards)
  if runs > 0 then
    breakdown[#breakdown + 1] = "Runs (" .. tostring(run_count) .. "x" .. tostring(run_length) .. "): " .. tostring(runs)
    total = total + runs
  end

  local flush = flush_score(hand, starter, is_crib)
  if flush > 0 then
    breakdown[#breakdown + 1] = "Flush: " .. tostring(flush)
    total = total + flush
  end

  local knobs = knobs_score(hand, starter)
  if knobs > 0 then
    breakdown[#breakdown + 1] = "Knobs: " .. tostring(knobs)
    total = total + knobs
  end

  if #breakdown == 0 then
    breakdown[#breakdown + 1] = "No score"
  end

  return total, breakdown, {
    fifteens = fifteen_details,
    pairs = pair_details,
    runs = run_details,
    flush = flush_detail,
    knobs = knobs_detail,
  }
end

local function pegging_pair_points(stack, new_card)
  local count = 1
  for i = #stack, 1, -1 do
    if stack[i].rank == new_card.rank then
      count = count + 1
    else
      break
    end
  end
  if count == 2 then
    return 2
  end
  if count == 3 then
    return 6
  end
  if count == 4 then
    return 12
  end
  return 0
end

local function pegging_run_points(stack_with_new)
  local max_len = math.min(7, #stack_with_new)
  for length = max_len, 3, -1 do
    local ranks = {}
    local min_rank = 99
    local max_rank = 0
    local unique = true
    for i = #stack_with_new - length + 1, #stack_with_new do
      local rank = stack_with_new[i].rank
      if ranks[rank] then
        unique = false
        break
      end
      ranks[rank] = true
      if rank < min_rank then
        min_rank = rank
      end
      if rank > max_rank then
        max_rank = rank
      end
    end
    if unique and max_rank - min_rank + 1 == length then
      return length
    end
  end
  return 0
end

function M.pegging_points_for_play(stack, card, count)
  local points = 0
  local new_count = count + cards.card_value(card)
  if new_count == 15 or new_count == 31 then
    points = points + 2
  end

  points = points + pegging_pair_points(stack, card)

  local new_stack = copy_table(stack)
  new_stack[#new_stack + 1] = card
  points = points + pegging_run_points(new_stack)

  return points
end

return M
