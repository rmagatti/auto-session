local Config = require("auto-session.config")
local Lib = require("auto-session.lib")

---@class Picker
---@field is_available fun(): boolean
---@field open_session_picker fun()

local M = {
  ---@type Picker
  picker = nil,
  picker_name = nil,
}

---Find an available picker. If Config.session_lens.picker is set, check that.
---Otherwise, check pickers in order to see which is available
---Fall back to vim.ui.select
---@return Picker,string # chosen picker and it's string name
local function resolve_picker()
  local pickers = Config.session_lens.picker and { Config.session_lens.picker }
    or { "telescope", "fzf", "snacks", "select" }

  for _, name in ipairs(pickers) do
    local ok, picker = pcall(require, "auto-session.pickers." .. name)
    if ok and picker and picker.is_available() then
      Lib.logger.debug("Picking picker: " .. name)
      return picker, name
    end
  end

  Lib.logger.error("Could not find requested picker: " .. Config.session_lens.picker)
  return require("auto-session.pickers.select"), "select"
end

function M.open_session_picker()
  M.picker.open_session_picker()
end

return setmetatable(M, {
  __index = function(table, key)
    if (key == "picker" or key == "picker_name") and not rawget(table, key) then
      local picker, picker_name = resolve_picker()
      rawset(table, "picker", picker)
      rawset(table, "picker_name", picker_name)
    end
    return rawget(table, key)
  end,
})
