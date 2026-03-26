local game_state = require("src.systems.game_state")
local quota_system = require("src.systems.quota_system")

local CharacterSelect = {}

local CHARACTER_CONFIG = quota_system.CHARACTER_CONFIG

function CharacterSelect:init()
  self.selected_index = 1
  self.characters = {}

  for key, char in pairs(CHARACTER_CONFIG) do
    table.insert(self.characters, {
      key = key,
      config = char,
    })
  end

  table.sort(self.characters, function(a, b)
    if a.config.unlocked ~= b.config.unlocked then
      return a.config.unlocked
    end
    return a.config.starting_hearts > b.config.starting_hearts
  end)
end

function CharacterSelect:update(_dt)
  if input.pressed("up") then
    self.selected_index = math.max(1, self.selected_index - 1)
  elseif input.pressed("down") then
    self.selected_index = math.min(#self.characters, self.selected_index + 1)
  elseif input.pressed("confirm") then
    local selected = self.characters[self.selected_index]
    if selected.config.unlocked then
      self:start_run(selected.key)
    end
  elseif input.pressed("back") then
    switch_screen("main_menu")
  end
end

function CharacterSelect:draw()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print("SELECT YOUR CHARACTER", 20, 20, 0, 2, 2)

  local y = 80
  for i, char in ipairs(self.characters) do
    local is_selected = i == self.selected_index
    local is_unlocked = char.config.unlocked

    if is_selected then
      love.graphics.setColor(0.3, 0.3, 0.5, 1)
      love.graphics.rectangle("fill", 15, y - 5, 400, 70, 4)
    end

    if is_unlocked then
      love.graphics.setColor(1, 1, 1, 1)
    else
      love.graphics.setColor(0.5, 0.5, 0.5, 1)
    end

    love.graphics.print(char.config.name, 30, y)

    local hearts_str = string.rep("<3", char.config.starting_hearts)
      .. string.rep("x", 5 - char.config.starting_hearts)
    love.graphics.print(hearts_str, 30, y + 20)

    if is_unlocked then
      local ability_text = get_ability_description(char.config.special_ability)
      love.graphics.setColor(0.7, 0.9, 0.7, 1)
      love.graphics.print(ability_text or "No special ability", 30, y + 40)
    else
      love.graphics.setColor(0.9, 0.7, 0.7, 1)
      local unlock_text = get_unlock_description(char.config.unlock_condition)
      love.graphics.print("[LOCKED] " .. unlock_text, 30, y + 40)
    end

    y = y + 80
  end

  love.graphics.setColor(0.7, 0.7, 0.7, 1)
  love.graphics.print("UP/DOWN to select, ENTER to confirm, ESC to back", 20, love.graphics.getHeight() - 40)
end

function CharacterSelect:start_run(character_key)
  local run_state = game_state.init_run(character_key)
  switch_screen("board_select", { run_state = run_state })
end

function get_ability_description(ability)
  local descriptions = {
    start_money_8 = "Start with $8 instead of $5",
    start_with_auntie = "Start with 1 random Auntie/Uncle",
    bet_heart = "Can bet a heart for x2 money on a Street",
    first_loss_blocked = "First heart loss is blocked",
    exceed_restores_heart = "Exceeding quota by 50% restores 1 heart",
    plus_one_hand_limit = "+1 hand limit on all Streets",
    minus_hand_minus_quota = "-1 hand limit, but quotas are -10",
  }
  return descriptions[ability]
end

function get_unlock_description(condition)
  local descriptions = {
    complete_backyard = "Complete Backyard",
    complete_3_boards = "Complete 3 boards total",
    win_with_zero_money = "Win a board with exactly $0",
    lose_5_hearts_and_win = "Lose 5 hearts in one run and still win",
    exceed_50_percent_10_times = "Exceed quota by 50%+ on 10 Streets",
    never_exceed_hand_limit_full_board = "Never exceed hand limit on a full board",
    complete_board_2_hands_per_street = "Complete a board using <=2 hands per Street",
  }
  return descriptions[condition] or "???"
end

return CharacterSelect
