local Config = require "auto-session.config"
local Lib = require "auto-session.lib"
local AutoSession = require "auto-session"

local function is_available()
  if vim.fn.exists ":FzfLua" ~= 2 then
    return false
  end

  local ok, fzf = pcall(require, "fzf-lua")
  return ok and fzf
end

local function open_session_picker()
  -- FIXME:
end

---@type Picker
local M = {
  is_available = is_available,
  open_session_picker = open_session_picker,
}

return M
