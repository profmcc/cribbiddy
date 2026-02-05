local cards = require("src.cards")

local M = {}

local CARD_W = 70
local CARD_H = 100
local GAP = 10
local STACK_OFFSET = 18
local STARTER_X = 30
local STARTER_Y = 490

function M.set_font()
  local font = love.graphics.newFont(16)
  love.graphics.setFont(font)
end

function M.draw_card(card, x, y, highlighted)
  if highlighted then
    love.graphics.setColor(0.3, 0.6, 0.9, 0.4)
    love.graphics.rectangle("fill", x, y, CARD_W, CARD_H, 6, 6)
  end
  if card.vined then
    love.graphics.setColor(0.5, 0.6, 0.5)
  else
    love.graphics.setColor(1, 1, 1)
  end
  love.graphics.rectangle("line", x, y, CARD_W, CARD_H, 6, 6)
  if card.hidden then
    love.graphics.print("??", x + 10, y + 10)
  else
    love.graphics.print(cards.card_label(card), x + 10, y + 10)
  end
end

function M.draw_face_up_card(card, x, y)
  M.draw_card(card, x, y, false)
end

function M.draw_hand(hand, x, y, selected)
  for i = 1, #hand do
    local card = hand[i]
    local card_x = x + (i - 1) * (CARD_W + GAP)
    local is_selected = selected and selected[i]
    M.draw_card(card, card_x, y, is_selected)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(tostring(i), card_x + 30, y + CARD_H + 6)
  end
end

function M.draw_cards_row(cards_list, x, y)
  for i = 1, #cards_list do
    local card_x = x + (i - 1) * (CARD_W + GAP)
    M.draw_card(cards_list[i], card_x, y, false)
  end
end

function M.draw_combo_entries(entries, x, y)
  local cursor = y
  local row_height = CARD_H + 10
  for i = 1, #entries do
    local entry = entries[i]
    love.graphics.print(entry.label, x, cursor)
    if entry.cards and #entry.cards > 0 then
      M.draw_cards_row(entry.cards, x + 140, cursor - 10)
      cursor = cursor + row_height
    else
      cursor = cursor + 18
    end
  end
  return cursor
end

function M.draw_text_block(lines, x, y)
  for i = 1, #lines do
    love.graphics.print(lines[i], x, y + (i - 1) * 18)
  end
end

function M.draw_scoreboard(state)
  local lines = {
    "Level: " .. tostring(state.level),
    "Goal: 121",
    "Dealer: " .. state.dealer,
    "Player: " .. tostring(state.player_score),
    "AI: " .. tostring(state.ai_score),
  }
  M.draw_text_block(lines, 30, 20)
end

function M.draw_phase(phase, x, y)
  love.graphics.print("Phase: " .. phase, x, y)
end

function M.draw_peg_stack(stack, x, y)
  for i = 1, #stack do
    local card_x = x + (i - 1) * 40
    M.draw_card(stack[i], card_x, y, false)
  end
end

local function draw_face_down_card(x, y, alpha)
  love.graphics.setColor(0.12, 0.12, 0.18, alpha)
  love.graphics.rectangle("fill", x, y, CARD_W, CARD_H, 6, 6)
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.rectangle("line", x, y, CARD_W, CARD_H, 6, 6)
end

local function card_alpha_for_index(cut, index)
  if cut.selected and index == cut.selected then
    if cut.status == "reveal" or cut.status == "clear_right" or cut.status == "slide" then
      return 0
    end
  end
  if cut.status == "aim" then
    return 1
  end
  if not cut.selected then
    return 1
  end
  if index < cut.selected then
    if cut.status == "clear_left" then
      return cut.fade_left or 0
    end
    return 0
  end
  if index > cut.selected then
    if cut.status == "clear_right" then
      return cut.fade_right or 0
    end
    if cut.status == "drop" then
      return 1
    end
    if cut.status == "clear_left" then
      return 1
    end
    return 0
  end
  return 1
end

function M.draw_cut_stack(cut, x, y)
  for i = 1, cut.visual_size do
    local alpha = card_alpha_for_index(cut, i)
    if alpha > 0 then
      local x_offset = (i - 1) * STACK_OFFSET
      local y_offset = 0
      if cut.selected and i == cut.selected and cut.status == "drop" then
        y_offset = y_offset + (cut.drop_offset or 0)
      end
      draw_face_down_card(x + x_offset, y + y_offset, alpha)
    end
  end

  if cut.selected and (cut.status == "reveal" or cut.status == "clear_right") then
    local base_x = x + (cut.selected - 1) * STACK_OFFSET
    local base_y = y + (cut.drop_offset or 0)
    M.draw_face_up_card(cut.card, base_x, base_y)
  elseif cut.selected and cut.status == "slide" then
    local base_x = x + (cut.selected - 1) * STACK_OFFSET
    local base_y = y + (cut.drop_offset or 0)
    local t = cut.slide_progress or 0
    local target_x = cut.target_x or STARTER_X
    local target_y = cut.target_y or STARTER_Y
    local draw_x = base_x + (target_x - base_x) * t
    local draw_y = base_y + (target_y - base_y) * t
    M.draw_face_up_card(cut.card, draw_x, draw_y)
  end

  if cut.status == "aim" then
    local pointer_x = x + (cut.pointer - 1) * STACK_OFFSET + CARD_W / 2
    love.graphics.setColor(1, 0.8, 0.2, 0.9)
    love.graphics.polygon("fill", pointer_x - 8, y - 12, pointer_x + 8, y - 12, pointer_x, y)
    love.graphics.setColor(1, 1, 1, 1)
  end
end

function M.card_dimensions()
  return CARD_W, CARD_H, GAP
end

function M.starter_position()
  return STARTER_X, STARTER_Y
end

return M
