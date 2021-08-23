local Lib = require('auto-session-library')

-- Run comand hooks
local function run_hook_cmds(cmds, hook_name)
  if not Lib.is_empty_table(cmds) then
    for _,cmd in ipairs(cmds) do
      Lib.logger.debug(string.format("Running %s command: %s", hook_name, cmd))
      local success, result = pcall(vim.cmd, cmd)
      if not success then Lib.logger.error(string.format("Error running %s. error: %s", cmd, result)) end
    end
  end
end

----------- Setup ----------
local AutoSession = {
  conf = {}
}

local defaultConf = {
  log_level = vim.g.auto_session_log_level or AutoSession.conf.logLevel or AutoSession.conf.log_level or 'info', -- Sets the log level of the plugin (debug, info, error). camelCase logLevel for compatibility.
  auto_session_enable_last_session = vim.g.auto_session_enable_last_session or false, -- Enables/disables the "last session" feature
  auto_session_root_dir = vim.fn.stdpath('data').."/sessions/", -- Root dir where sessions will be stored
  auto_session_enabled = true, -- Enables/disables auto saving and restoring
  auto_save_enabled = nil, -- Enables/disables auto save feature
  auto_restore_enabled = nil, -- Enables/disables auto restore feature
  auto_session_suppress_dirs = nil -- Suppress session restore/create in certain directories
}

-- Set default config on plugin load
AutoSession.conf = defaultConf

-- Pass configs to Lib
Lib.conf = {
  log_level = AutoSession.conf.log_level
}
Lib.ROOT_DIR = defaultConf.ROOT_DIR

function AutoSession.setup(config)
  AutoSession.conf = Lib.Config.normalize(config, AutoSession.conf)
  Lib.ROOT_DIR = AutoSession.conf.auto_session_root_dir
  Lib.setup({
    log_level = AutoSession.conf.log_level
  })
end

local function is_enabled()
  if vim.g.auto_session_enabled ~= nil then
    return vim.g.auto_session_enabled == Lib._VIM_TRUE
  elseif AutoSession.conf.auto_session_enabled ~= nil then
    return AutoSession.conf.auto_session_enabled
  end

  return true
end

local pager_mode = nil
local in_pager_mode = function()
  if pager_mode ~= nil then return pager_mode end -- Only evaluate this once

  local opened_with_args = next(vim.fn.argv()) ~= nil -- Neovim was opened with args
  local reading_from_stdin = vim.g.in_pager_mode == Lib._VIM_TRUE -- Set from StdinReadPre

  pager_mode = opened_with_args or reading_from_stdin
  Lib.logger.debug("==== Pager mode", pager_mode)
  return pager_mode
end

local auto_save = function()
  if in_pager_mode() then return false end

  if vim.g.auto_session_enabled ~= nil then
    return vim.g.auto_save_enabled == Lib._VIM_TRUE
  elseif AutoSession.conf.auto_save_enabled ~= nil then
    return AutoSession.conf.auto_save_enabled
  end

  return true
end

local auto_restore = function()
  if in_pager_mode() then return false end

  if vim.g.auto_restore_enabled ~= nil then
    return vim.g.auto_restore_enabled == Lib._VIM_TRUE
  elseif AutoSession.conf.auto_restore_enabled ~= nil then
    return AutoSession.conf.auto_restore_enabled
  end

  return true
end

local function suppress_session()
  local dirs = vim.g.auto_session_suppress_dirs or AutoSession.conf.auto_session_suppress_dirs or {}

  local cwd = vim.fn.getcwd()
  for _, s in pairs(dirs) do
    s = string.gsub(vim.fn.simplify(vim.fn.expand(s)), '/+$', '')
    if cwd == s then
      return true
    end
  end
  return false
end

local function filter_session()
  local dirs = vim.g.auto_session_filter_dirs or
                   AutoSession.conf.auth_session_filter_dirs or {}
  local filter = vim.g.auto_session_filter_enable or
                     AutoSession.conf.auth_session_filter_enabled or {}
  local cwd = vim.fn.getcwd()
  for _, s in pairs(dirs) do
    s = string.gsub(vim.fn.simplify(vim.fn.expand(s)), '/+$', '')
    if cwd == s and filter then
      return true
    end
  end
  return false
end

do
  function AutoSession.get_latest_session()
    local dir = vim.fn.expand(AutoSession.conf.auto_session_root_dir)
    local latest_session = { session = nil, last_edited = 0 }

    for _, filename in ipairs(vim.fn.readdir(dir)) do
      local session = AutoSession.conf.auto_session_root_dir..filename
      local last_edited = vim.fn.getftime(session)

      if last_edited > latest_session.last_edited then
        latest_session.session = session
        latest_session.last_edited = last_edited
      end
    end

    if latest_session.session ~= nil then
      -- Need to escape % chars on the filename so expansion doesn't happen
      return latest_session.session:gsub("%%", "\\%%")
    else
      return nil
    end
  end
end


------ MAIN FUNCTIONS ------
function AutoSession.AutoSaveSession(sessions_dir)
  if is_enabled() and auto_save() and not suppress_session() and filter_session() then
    AutoSession.SaveSession(sessions_dir, true)
  end
end

function AutoSession.get_root_dir()
  if AutoSession.validated then
    return AutoSession.conf.auto_session_root_dir
  end

  local root_dir = vim.g["auto_session_root_dir"] or AutoSession.conf.auto_session_root_dir
  Lib.init_dir(root_dir)

  AutoSession.conf.auto_session_root_dir = Lib.validate_root_dir(root_dir)
  AutoSession.validated = true
  return root_dir
end

function AutoSession.get_cmds(typ)
  return AutoSession.conf[typ.."_cmds"] or vim.g["auto_session_"..typ.."_cmds"]
end

local function message_after_saving(path, auto)
  if auto then
    Lib.logger.debug("Session saved at "..path)
  else
    Lib.logger.info("Session saved at "..path)
  end
end

-- Saves the session, overriding if previously existing.
function AutoSession.SaveSession(sessions_dir, auto)
  -- To be used for saving by file path
  local session = sessions_dir and sessions_dir ~= "" and sessions_dir or nil

  if Lib.is_empty(sessions_dir) then
    sessions_dir = AutoSession.get_root_dir()
  else
    sessions_dir = Lib.append_slash(sessions_dir)
  end

  local pre_cmds = AutoSession.get_cmds("pre_save")
  run_hook_cmds(pre_cmds, "pre-save")

  if vim.fn.isdirectory(session or sessions_dir) == Lib._VIM_FALSE then
    Lib.logger.debug("SaveSession param is not a directory, saving as a file.")
    vim.cmd("mks! "..session)

    message_after_saving(session, auto)
  else
    local session_name = Lib.conf.last_loaded_session or Lib.escaped_session_name_from_cwd()
    Lib.logger.debug("==== Save - Session Name", session_name)
    local full_path = string.format(sessions_dir.."%s.vim", session_name)
    local cmd = "mks! "..full_path

    message_after_saving(full_path, auto)

    vim.cmd(cmd)
  end

  local post_cmds = AutoSession.get_cmds("post_save")
  run_hook_cmds(post_cmds, "post-save")
end

-- This function avoids calling RestoreSession automatically when argv is not nil.
function AutoSession.AutoRestoreSession(sessions_dir)
  if is_enabled() and auto_restore() and not suppress_session() then
    AutoSession.RestoreSession(sessions_dir)
  end
end

local function extract_dir_or_file(sessions_dir_or_file)
  local sessions_dir = nil
  local session_file = nil

  if Lib.is_empty(sessions_dir_or_file) then
    sessions_dir = AutoSession.get_root_dir()
  elseif vim.fn.isdirectory(vim.fn.expand(sessions_dir_or_file)) == Lib._VIM_TRUE then
    if not Lib.ends_with(sessions_dir_or_file, '/') then
      sessions_dir = Lib.append_slash(sessions_dir_or_file)
    else
      sessions_dir = sessions_dir_or_file
    end
  else
    session_file = sessions_dir_or_file
  end

  return sessions_dir, session_file
end

-- TODO: make this more readable!
-- Restores the session by sourcing the session file if it exists/is readable.
function AutoSession.RestoreSession(sessions_dir_or_file)
  Lib.logger.debug("sessions dir or file", sessions_dir_or_file)
  local sessions_dir, session_file = extract_dir_or_file(sessions_dir_or_file)

  local restore = function(file_path, session_name)
    local pre_cmds = AutoSession.get_cmds("pre_restore")
    run_hook_cmds(pre_cmds, "pre-restore")

    local cmd = "source "..file_path
    local success, result = pcall(vim.cmd, cmd)

    if not success then
      Lib.logger.error([[
        Error restoring session! The session might be corrupted.
        Disabling auto save. Please check for errors in your config. Error: 
      ]]..result)
      AutoSession.conf.auto_save_enabled = false
      return
    end

    Lib.logger.info("Session restored from "..file_path)
    Lib.conf.last_loaded_session = session_name

    local post_cmds = AutoSession.get_cmds("post_restore")
    run_hook_cmds(post_cmds, "post-restore")
  end

  -- I still don't like reading this chunk, please cleanup
  if sessions_dir then
    Lib.logger.debug("==== Using session DIR")
    local session_name = Lib.conf.last_loaded_session or Lib.escaped_session_name_from_cwd()
    Lib.logger.debug("==== Session Name", session_name)
    local session_file_path = string.format(sessions_dir.."%s.vim", session_name)

    local legacy_session_name = Lib.legacy_session_name_from_cwd()
    local legacy_file_path = string.format(sessions_dir.."%s.vim", legacy_session_name)

    if Lib.is_readable(session_file_path) then
      restore(session_file_path, session_name)
    elseif Lib.is_readable(legacy_file_path) then
      restore(legacy_file_path, session_name)
    else
      if AutoSession.conf.auto_session_enable_last_session then
        local last_session_file_path = AutoSession.get_latest_session()
        if last_session_file_path ~= nil then
          Lib.logger.info("Restoring last session", last_session_file_path)
          restore(last_session_file_path)
        end
      else
        Lib.logger.debug("File not readable, not restoring session")
      end
    end
  elseif session_file then
    Lib.logger.debug("==== Using session FILE")
    local escaped_file = session_file:gsub("%%", "\\%%")
    if Lib.is_readable(escaped_file) then
      Lib.logger.debug("isReadable, calling restore")
      restore(escaped_file)
    else
      Lib.logger.debug("File not readable, not restoring session")
    end
  else
    Lib.logger.error("Error while trying to parse session dir or file")
  end
end

local maybe_disable_autosave = function(session_name)
  local current_session = Lib.escaped_session_name_from_cwd()
  if session_name == current_session then
    Lib.logger.debug("Auto Save disabled for current session.", vim.inspect({
      session_name = session_name, current_session = current_session
    }))
    AutoSession.conf.auto_save_enabled = false
  else
    Lib.logger.debug("Auto Save is still enabled for current session.", vim.inspect({
      session_name = session_name, current_session = current_session
    }))
  end
end

function AutoSession.DisableAutoSave()
  Lib.logger.debug("Auto Save disabled manually.")
  AutoSession.conf.auto_save_enabled = false
end

function AutoSession.CompleteSessions()
  local session_files = vim.fn.glob(AutoSession.get_root_dir() .. '/*', true, true)
  local session_names = {}
  for _, sf in ipairs(session_files) do
    local name = Lib.unescape_dir(vim.fn.fnamemodify(sf,":t:r"))
    table.insert(session_names, name)
  end
  return table.concat(session_names, "\n")
end

function AutoSession.DeleteSessionByName(...)
  local session_paths = {}
  for _, name in ipairs{...} do
    local escaped_session = Lib.escape_dir(name)
    maybe_disable_autosave(escaped_session)
    local session_path = string.format("%s/%s.vim", AutoSession.get_root_dir(), escaped_session)
    table.insert(session_paths, session_path)
  end
  AutoSession.DeleteSession(unpack(session_paths))
end

function AutoSession.DeleteSession(...)
  local pre_cmds = AutoSession.get_cmds("pre_delete")
  run_hook_cmds(pre_cmds, "pre-delete")

  -- TODO: make the delete command customizable
  local cmd = "silent! !rm "
  local is_win32 = vim.fn.has('win32') == Lib._VIM_TRUE

  if not Lib.is_empty(...) then
    for _, file_path in ipairs{...} do
      Lib.logger.debug("session_file_path", file_path)

      local escaped_file_path = file_path:gsub("%%", "\\%%")
      vim.cmd(cmd..escaped_file_path)

      Lib.logger.info("Deleted session "..file_path)
    end
  else
    local session_name = Lib.escaped_session_name_from_cwd()
    if is_win32 then
      session_name = session_name:gsub('\\','')
    end

    local session_file_path = string.format(AutoSession.get_root_dir().."%s.vim", session_name)
    local _ = is_win32 and vim.fn.delete(session_file_path) or vim.cmd(cmd..session_file_path)

    maybe_disable_autosave(session_name)
    Lib.logger.info("Deleted session "..session_file_path)
  end


  local post_cmds = AutoSession.get_cmds("post_delete")
  run_hook_cmds(post_cmds, "post-delete")
end

return AutoSession
