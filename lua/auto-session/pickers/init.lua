local Config = require "auto-session.config"
local Lib = require "auto-session.lib"

---@class Picker
---@field is_available fun(): boolean
---@field open_session_picker fun()

local M = {
  ---@type Picker
  picker = nil,
}

---Open a session picker. If Config.session_lens.picker is set, check that.
---Otherwise, check pickers in order to see which is installed
---Fall back to vim.ui.select
function M.open_session_picker()
  if M.picker then
    return M.picker.open_session_picker()
  end

  local pickers = Config.session_lens.picker and { Config.session_lens.picker, "select" }
    or { "telescope", "fzf", "snacks", "select" }

  for _, name in ipairs(pickers) do
    local ok, picker = pcall(require, "auto-session.pickers." .. name)
    if ok and picker and picker.is_available() then
      M.picker = picker
      return M.picker.open_session_picker()
    end
  end

  Lib.logger.error "Could not find any pickers?"
end

return M
