local Characters = require("characters")

local CharacterSelect = {}
CharacterSelect.selected = 1

local CARD_W = 230
local CARD_H = 320
local PADDING = 24

local function card_bounds(index, card_w, card_h, padding, start_x, y)
  local x = start_x + (index - 1) * (card_w + padding)
  return { x = x, y = y, w = card_w, h = card_h }
end

function CharacterSelect.card_dimensions()
  return CARD_W, CARD_H, PADDING
end

function CharacterSelect.draw_card(char, x, y, scale, is_selected)
  local s = scale or 1
  local w = CARD_W * s
  local h = CARD_H * s
  local inset = 10 * s

  if is_selected then
    love.graphics.setColor(char.color[1], char.color[2], char.color[3], 1.0)
  else
    love.graphics.setColor(char.color[1], char.color[2], char.color[3], 0.8)
  end
  love.graphics.rectangle("fill", x, y, w, h, 12 * s, 12 * s)

  love.graphics.setColor(0.43, 0.37, 0.31)
  love.graphics.setLineWidth(is_selected and 3 or 1)
  love.graphics.rectangle("line", x, y, w, h, 12 * s, 12 * s)

  love.graphics.setColor(0.25, 0.18, 0.12)
  love.graphics.printf(char.name, x + inset, y + 12 * s, w - inset * 2, "center")

  love.graphics.setColor(0.45, 0.35, 0.28)
  love.graphics.printf(char.visiting, x + inset, y + 35 * s, w - inset * 2, "center")

  love.graphics.setColor(0.25, 0.18, 0.12)
  love.graphics.printf("✦ " .. char.passive.name, x + inset, y + 80 * s, w - inset * 2, "left")
  love.graphics.setColor(0.45, 0.35, 0.28)
  love.graphics.printf(char.passive.description, x + inset, y + 100 * s, w - inset * 2, "left")

  love.graphics.setColor(0.25, 0.18, 0.12)
  love.graphics.printf("⚡ " .. char.active.name, x + inset, y + 160 * s, w - inset * 2, "left")
  love.graphics.setColor(0.45, 0.35, 0.28)
  love.graphics.printf(char.active.description, x + inset, y + 180 * s, w - inset * 2, "left")
end

function CharacterSelect.draw()
  local chars = Characters.list
  local card_w = CARD_W
  local card_h = CARD_H
  local padding = PADDING
  local total_w = #chars * (card_w + padding) - padding
  local start_x = (love.graphics.getWidth() - total_w) / 2
  local y = love.graphics.getHeight() / 2 - card_h / 2

  for i, char in ipairs(chars) do
    local x = start_x + (i - 1) * (card_w + padding)
    local is_selected = i == CharacterSelect.selected
    CharacterSelect.draw_card(char, x, y, 1, is_selected)
  end

  love.graphics.setColor(0.43, 0.37, 0.31)
  love.graphics.printf("← → to browse   ENTER to choose", 0, y + card_h + 30, love.graphics.getWidth(), "center")
end

function CharacterSelect.keypressed(key, game_state)
  if key == "left" then
    CharacterSelect.selected = math.max(1, CharacterSelect.selected - 1)
  elseif key == "right" then
    CharacterSelect.selected = math.min(#Characters.list, CharacterSelect.selected + 1)
  elseif key == "return" or key == "space" then
    game_state.character = Characters.list[CharacterSelect.selected]
    return "start_run"
  end
  return nil
end

function CharacterSelect.mousepressed(x, y, button, game_state)
  if button ~= 1 then
    return nil
  end
  local chars = Characters.list
  local card_w = CARD_W
  local card_h = CARD_H
  local padding = PADDING
  local total_w = #chars * (card_w + padding) - padding
  local start_x = (love.graphics.getWidth() - total_w) / 2
  local top_y = love.graphics.getHeight() / 2 - card_h / 2
  for i = 1, #chars do
    local bounds = card_bounds(i, card_w, card_h, padding, start_x, top_y)
    if x >= bounds.x and x <= bounds.x + bounds.w and y >= bounds.y and y <= bounds.y + bounds.h then
      CharacterSelect.selected = i
      game_state.character = Characters.list[CharacterSelect.selected]
      return "start_run"
    end
  end
  return nil
end

return CharacterSelect
