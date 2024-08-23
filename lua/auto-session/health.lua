local AutoSession = require "auto-session"
local Lib = require "auto-session.lib"
local Config = require "auto-session.config"

local M = {}

---@diagnostic disable-next-line: deprecated
local start = vim.health.start or vim.health.report_start
---@diagnostic disable-next-line: deprecated
local ok = vim.health.ok or vim.health.report_ok
---@diagnostic disable-next-line: deprecated
local warn = vim.health.warn or vim.health.report_warn
---@diagnostic disable-next-line: deprecated, unused-local
local error = vim.health.error or vim.health.report_error
---@diagnostic disable-next-line: deprecated
local info = vim.health.info or vim.health.report_info

local function check_session_options()
  if not vim.tbl_contains(vim.split(vim.o.sessionoptions, ","), "localoptions") then
    warn(
      "`vim.o.sessionoptions` should contain 'localoptions' to make sure\nfiletype and highlighting work correctly after a session is restored.\n\n"
        .. "Recommended setting is:\n\n"
        .. 'vim.o.sessionoptions="blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"\n'
    )
  else
    ok "vim.o.sessionoptions"
  end
end

function M.check()
  start "vim options"
  check_session_options()

  start "Config"
  if Config.has_old_config then
    warn(
      "You have old config names. You should update your config to:\n"
        .. vim.inspect(Config.options_without_defaults)
        .. "\n\nYou may also need to remove any vim global config settings"
    )
  else
    ok("\n" .. vim.inspect(Config.options_without_defaults))
  end

  start "General Info"
  info("Session directory: " .. AutoSession.get_root_dir())
  info("Current session: " .. Lib.current_session_name())
  info("Current session file: " .. vim.v.this_session)
end

return M
