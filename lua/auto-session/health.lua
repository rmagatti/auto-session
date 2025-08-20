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

local function check_lazy_settings()
  local success, lazy = pcall(require, "lazy")

  if not success or not lazy then
    return
  end

  start "Lazy.nvim settings"

  if not Config.lazy_support then
    warn(
      "Lazy.nvim is present but `lazy_support` is not enabled. This will cause problems when trying\n"
        .. "to auto-restore a session while the Lazy.nvim window is up. You probably want to add\n"
        .. "`lazy_support = true,` to your config (or remove the line that's setting it to false)"
    )
  else
    ok "Lazy.nvim support is enabled"
  end

  local plugins = lazy.plugins()
  for _, plugin in ipairs(plugins) do
    if plugin.name == "auto-session" then
      if plugin.lazy then
        warn(
          "auto-session is set to lazy load. This will prevent auto-restoring.\n"
            .. "You probably want to change your auto-session lazy spec to be something like\n\n"
            .. [[
{
  'rmagatti/auto-session',
  lazy = false,
  opts = {
    -- your config here
  }
}
            ]]
        )
      else
        ok "auto-session is not lazy loaded"
      end

      return
    end
  end
end

local function check_config()
  start "Config"
  local loggerObj = {
    error = error,
    info = info,
    warn = warn,
  }

  if not Config.check(loggerObj, true) then
    ok "No config issues detected"
  end
end

function M.check()
  start "Setup"
  if not Config.root_dir or vim.tbl_isempty(Lib.logger) then
    error(
      "Setup was not called. Auto-session will not work unless you call setup() somewhere, e.g.:\n\n"
        .. "require('auto-session').setup({})"
    )
    return
  else
    ok "setup() called"
  end

  check_lazy_settings()

  check_config()

  start "Current Config"
  if Config.has_old_config then
    info(
      "You have old config names. You can update your config to:\n"
        .. vim.inspect(Config.options_without_defaults)
        .. "\n\nYou can also remove any vim global config settings"
    )
  else
    info("\n" .. vim.inspect(Config.options_without_defaults))
  end

  start "General Info"
  info("Session directory: " .. AutoSession.get_root_dir())
  info("Current session: " .. Lib.current_session_name())
  info("Current session file: " .. vim.v.this_session)
  info("Selected picker: " .. require("auto-session.pickers").picker_name)
end

return M
