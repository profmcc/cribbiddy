local json = require("lib.json")

local SaveSystem = {}

local SAVE_PATH = love.filesystem.getSaveDirectory() .. "/v4_save.json"

function SaveSystem.save_run(run_state, street_state)
  local save_data = {
    version = "4.0.0",
    timestamp = os.time(),
    run_state = run_state,
    street_state = street_state,
  }

  local json_str = json.encode(save_data)
  local success, err = love.filesystem.write("v4_save.json", json_str)

  if not success then
    print("Failed to save: " .. tostring(err))
    return false
  end

  return true
end

function SaveSystem.load_run()
  if not love.filesystem.getInfo("v4_save.json") then
    return nil, nil
  end

  local json_str, err = love.filesystem.read("v4_save.json")
  if not json_str then
    print("Failed to load: " .. tostring(err))
    return nil, nil
  end

  local save_data = json.decode(json_str)

  if save_data.version ~= "4.0.0" then
    print("Save version mismatch, starting fresh")
    return nil, nil
  end

  return save_data.run_state, save_data.street_state
end

function SaveSystem.delete_run()
  love.filesystem.remove("v4_save.json")
end

function SaveSystem.has_save()
  return love.filesystem.getInfo("v4_save.json") ~= nil
end

return SaveSystem
