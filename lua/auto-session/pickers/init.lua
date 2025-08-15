local Config = require "auto-session.config"
local Lib = require "auto-session.lib"

---@class Picker
---@field is_available fun(): boolean
---@field open_session_picker fun()

local M = {
  ---@type Picker
  picker = nil,
}

---Find an available picker. If Config.session_lens.picker is set, check that.
---Otherwise, check pickers in order to see which is available
---Fall back to vim.ui.select
---@return Picker # chosen picker
local function resolve_picker()
  local pickers = Config.session_lens.picker and { Config.session_lens.picker, "select" }
    or { "telescope", "fzf", "snacks", "select" }

  for _, name in ipairs(pickers) do
    local ok, picker = pcall(require, "auto-session.pickers." .. name)
    if ok and picker and picker.is_available() then
      Lib.logger.debug("Picking picker: " .. name)
      return picker
    end
  end

  -- should never get here
  Lib.logger.error "Could not find any pickers?"
  return require "auto-session.pickers.select"
end

function M.open_session_picker()
  M.picker.open_session_picker()
end

return setmetatable(M, {
  __index = function(table, key)
    if key == "picker" and not rawget(table, "picker") then
      rawset(table, "picker", resolve_picker())
    end
    return rawget(table, key)
  end,
})
