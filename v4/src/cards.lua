local M = {}

local SUITS = { "S", "H", "D", "C" }
local RANKS = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }

local function base_ranks_for_board(board_id)
  local ranks = {}
  for rank = 1, 13 do
    ranks[#ranks + 1] = rank
  end
  if board_id == "Dinosaurs" then
    ranks[#ranks + 1] = 0
    ranks[#ranks + 1] = 14
    ranks[#ranks + 1] = 15
  end
  return ranks
end

local function rank_from_name(rank_name)
  if rank_name == "A" then
    return 1
  end
  if rank_name == "J" then
    return 11
  end
  if rank_name == "Q" then
    return 12
  end
  if rank_name == "K" then
    return 13
  end
  if rank_name == "0" then
    return 0
  end
  if rank_name == "11" then
    return 14
  end
  if rank_name == "12" then
    return 15
  end
  return tonumber(rank_name)
end

local function parse_card_id(card_id)
  local rank_name, suit_name = card_id:match("^([^%-]+)%-(.+)$")
  if not rank_name or not suit_name then
    return nil
  end
  return rank_from_name(rank_name), suit_name
end

function M.build_deck(options)
  local board_id = options and options.board_id or nil
  local deck_counts = options and options.deck_counts or nil
  local enhancements = options and options.enhancements or {}
  local deck = {}
  if deck_counts then
    for id, count in pairs(deck_counts) do
      local rank, suit_name = parse_card_id(id)
      if rank and suit_name then
        local suit_index = nil
        for i = 1, #SUITS do
          if SUITS[i] == suit_name then
            suit_index = i
            break
          end
        end
        if suit_index then
          for _ = 1, count do
            local card = { rank = rank, suit = suit_index }
            if enhancements and enhancements[id] then
              card.enhancement = enhancements[id]
            end
            deck[#deck + 1] = card
          end
        end
      end
    end
  else
    local ranks = base_ranks_for_board(board_id)
    for suit = 1, 4 do
      for i = 1, #ranks do
        local rank = ranks[i]
        local card = { rank = rank, suit = suit }
        local id = M.card_id(card)
        if enhancements and enhancements[id] then
          card.enhancement = enhancements[id]
        end
        deck[#deck + 1] = card
      end
    end
  end
  return deck
end

function M.shuffle(deck)
  for i = #deck, 2, -1 do
    local j = love.math.random(i)
    deck[i], deck[j] = deck[j], deck[i]
  end
  return deck
end

function M.draw(deck, count)
  local drawn = {}
  for _ = 1, count do
    drawn[#drawn + 1] = table.remove(deck)
  end
  return drawn, deck
end

function M.card_label(card)
  return M.rank_name(card.rank) .. SUITS[card.suit]
end

function M.card_value(card)
  if card.rank == 14 then
    return 11
  end
  if card.rank == 15 then
    return 12
  end
  if card.rank > 10 then
    return 10
  end
  return card.rank
end

function M.rank_name(rank)
  if rank == 0 then
    return "0"
  end
  if rank == 14 then
    return "11"
  end
  if rank == 15 then
    return "12"
  end
  return RANKS[rank]
end

function M.card_id(card)
  return M.rank_name(card.rank) .. "-" .. M.suit_name(card.suit)
end

function M.default_counts(board_id)
  local counts = {}
  local ranks = base_ranks_for_board(board_id)
  for suit = 1, 4 do
    for i = 1, #ranks do
      local card = { rank = ranks[i], suit = suit }
      local id = M.card_id(card)
      counts[id] = (counts[id] or 0) + 1
    end
  end
  return counts
end

function M.rank_from_name(name)
  return rank_from_name(name)
end

function M.suit_name(suit)
  return SUITS[suit]
end

return M
