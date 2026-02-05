local quota_system = require("src.systems.quota_system")

local M = {}

local QUOTA_CONFIG = quota_system.QUOTA_CONFIG

function M.draw_hearts(run_state, x, y, sprites)
  for i = 1, run_state.max_hearts do
    local icon = i <= run_state.hearts and "heart_full" or "heart_empty"
    if sprites and sprites[icon] then
      love.graphics.draw(sprites[icon], x + (i - 1) * 24, y)
    else
      if i <= run_state.hearts then
        love.graphics.setColor(0.9, 0.2, 0.2, 1)
        love.graphics.circle("fill", x + (i - 1) * 24 + 8, y + 8, 6)
      else
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        love.graphics.circle("line", x + (i - 1) * 24 + 8, y + 8, 6)
      end
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function M.draw_quota_bar(street_state, x, y, width, height)
  love.graphics.setColor(0.2, 0.2, 0.2, 1)
  love.graphics.rectangle("fill", x, y, width, height, 4)

  local progress = math.min(street_state.quota_progress / street_state.quota_target, 1.5)
  local fill_width = width * math.min(progress, 1)

  if street_state.quota_met then
    love.graphics.setColor(0.3, 0.8, 0.3, 1)
  elseif progress > 0.7 then
    love.graphics.setColor(0.9, 0.8, 0.2, 1)
  else
    love.graphics.setColor(0.8, 0.3, 0.3, 1)
  end

  love.graphics.rectangle("fill", x, y, fill_width, height, 4)

  local exceed_x = x + width * 1.0
  love.graphics.setColor(1, 0.8, 0, 0.5)
  love.graphics.line(exceed_x, y, exceed_x, y + height)

  love.graphics.setColor(1, 1, 1, 1)
  local text = string.format("%d / %d", street_state.quota_progress, street_state.quota_target)
  love.graphics.print(text, x + width / 2 - 20, y + height / 2 - 8)
end

function M.draw_hand_pips(street_state, x, y)
  local pip_radius = 8
  local pip_spacing = 24

  for i = 1, street_state.hands_limit do
    local pip_x = x + (i - 1) * pip_spacing

    if i <= street_state.hands_used then
      love.graphics.setColor(0.4, 0.4, 0.4, 1)
      love.graphics.circle("fill", pip_x, y, pip_radius)
    else
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.circle("line", pip_x, y, pip_radius)
    end
  end
end

function M.draw_phase_objective(street_state, current_blind_type, get_phase_reward, x, y)
  local phase = street_state.phase_objective

  love.graphics.setColor(0.15, 0.15, 0.15, 0.9)
  love.graphics.rectangle("fill", x, y, 300, 60, 4)

  if street_state.phase_complete then
    love.graphics.setColor(0.3, 0.9, 0.3, 1)
    love.graphics.print("✓", x + 10, y + 10)
  else
    love.graphics.setColor(0.9, 0.9, 0.3, 1)
    love.graphics.print("○", x + 10, y + 10)
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print("PHASE: " .. phase.display, x + 30, y + 10)

  if QUOTA_CONFIG.base[current_blind_type].phase_required then
    love.graphics.setColor(1, 0.5, 0.5, 1)
    love.graphics.print("(Required)", x + 30, y + 30)
  else
    local reward = get_phase_reward and get_phase_reward() or 0
    love.graphics.setColor(0.5, 1, 0.5, 1)
    love.graphics.print("(Optional - Reward: +$" .. tostring(reward) .. ")", x + 30, y + 30)
  end
end

function M.draw_street_header(run_state, street_state, current_blind_type, get_phase_reward, sprites)
  local header_y = 10

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(string.upper(run_state.current_board) .. ": Street " .. run_state.current_street, 20, header_y)

  local blind_names = { "SMALL BLIND", "BIG BLIND", "BOSS APPROACH", "BOSS" }
  love.graphics.print(blind_names[run_state.current_blind_type], 20, header_y + 20)

  M.draw_hearts(run_state, love.graphics.getWidth() - 140, header_y, sprites)

  M.draw_quota_bar(street_state, 20, header_y + 50, 400, 24)

  love.graphics.print("HANDS:", 20, header_y + 85)
  M.draw_hand_pips(street_state, 90, header_y + 93)

  M.draw_phase_objective(street_state, current_blind_type, get_phase_reward, love.graphics.getWidth() - 330, header_y + 50)
end

return M
