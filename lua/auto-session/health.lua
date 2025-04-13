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

local function check_lazy_settings()
  local success, lazy = pcall(require, "lazy")

  start "Lazy.nvim settings"

  if not success or not lazy then
    info "Lazy.nvim not loaded"
    return
  end

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

function check_features()
  if Config.purge_after_days and vim.fn.has "nvim-0.10" ~= 1 then
    warn "The purge_after_days config option requires nvim 0.10 or greater to work"
  end
end

function M.check()
  start "vim options"
  check_session_options()
  check_lazy_settings()
  check_features()

  start "Config"
  if Config.has_old_config then
    info(
      "You have old config names. You can update your config to:\n"
        .. vim.inspect(Config.options_without_defaults)
        .. "\n\nYou can also remove any vim global config settings"
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
