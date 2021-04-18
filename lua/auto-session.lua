local Lib = require('auto-session-library')

-- Run comand hooks
local function runHookCmds(cmds, hook_name)
  if not Lib.isEmptyTable(cmds) then
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
  logLevel = vim.g["auto_session_log_level"] or AutoSession.conf.logLevel or 'info',
  auto_session_last_session_dir = "~/.config/nvim/sessions/last_session/",
  auto_session_enable_last_session = false,
  last_session = nil
}

-- Set default config on plugin load
AutoSession.conf = defaultConf
Lib.conf = {
  logLevel = AutoSession.conf.logLevel
}

function AutoSession.setup(config)
  AutoSession.conf = Lib.Config.normalize(config, AutoSession.conf)
  Lib.setup({
    logLevel = AutoSession.conf.logLevel
  })
end

do
  local file_name = "last_session.conf"
  local last_session_file_path = AutoSession.conf.auto_session_last_session_dir..file_name

  function GetLastSession()
    if AutoSession.conf.auto_session_enable_last_session then
      Lib.initDir(AutoSession.conf.auto_session_last_session_dir)
      Lib.initFile(last_session_file_path)
      local last_session = table.load(vim.fn.expand(last_session_file_path))
      Lib.logger.debug("==== GetLastSession called, got session", last_session.session_path)
      return last_session.session_path
    end
  end

  function SetLastSession(session_path)
    if AutoSession.conf.auto_session_enable_last_session then
      Lib.initDir(AutoSession.conf.auto_session_last_session_dir)
      Lib.initFile(last_session_file_path)
      local expanded_path = vim.fn.expand(last_session_file_path)

      -- Only do file operation if the values are different to avoid unnecessary io operations.
      if not (AutoSession.conf.last_session == session_path) then
        Lib.logger.debug("==== SetLastSession called for session", session_path)
        AutoSession.conf.last_session = session_path
        local last_session = {session_path = session_path}
        return table.save(last_session, expanded_path)
      end
    end
  end
end


------ MAIN FUNCTIONS ------
function AutoSession.AutoSaveSession(sessions_dir)
  if next(vim.fn.argv()) == nil then
    AutoSession.SaveSession(sessions_dir, true)
  end
end

function AutoSession.getRootDir()
  if AutoSession.valiated then
    return AutoSession.conf.auto_session_root_dir
  end

  local root_dir = vim.g["auto_session_root_dir"] or AutoSession.conf.auto_session_root_dir or Lib.ROOT_DIR
  Lib.initDir(root_dir)

  AutoSession.conf.auto_session_root_dir = Lib.validateRootDir(root_dir)
  AutoSession.validated = true
  return root_dir
end


function AutoSession.getCmds(typ)
  return AutoSession.conf[typ.."_cmds"] or vim.g["auto_session_"..typ.."_cmds"]
end

-- Saves the session, overriding if previously existing.
function AutoSession.SaveSession(sessions_dir, auto)
  if Lib.isEmpty(sessions_dir) then
    sessions_dir = AutoSession.getRootDir()
  else
    sessions_dir = Lib.appendSlash(sessions_dir)
  end

  local pre_cmds = AutoSession.getCmds("pre_save")
  runHookCmds(pre_cmds, "pre-save")

  local session_name = Lib.getEscapedSessionNameFromCwd()
  local full_path = string.format(sessions_dir.."%s.vim", session_name)
  local cmd = "mks! "..full_path

  if auto then
    Lib.logger.debug("Session saved at "..full_path)
  else
    Lib.logger.info("Session saved at "..full_path)
  end

  vim.cmd(cmd)
  SetLastSession(full_path)

  local post_cmds = AutoSession.getCmds("post_save")
  runHookCmds(post_cmds, "post-save")
end

-- This function avoids calling RestoreSession automatically when argv is not nil.
function AutoSession.AutoRestoreSession(sessions_dir)
  if next(vim.fn.argv()) == nil then
    AutoSession.RestoreSession(sessions_dir)
  end
end

local function extractDirOrFile(sessions_dir_or_file)
  local sessions_dir = nil
  local session_file = nil

  if Lib.isEmpty(sessions_dir_or_file) then
    sessions_dir = AutoSession.getRootDir()
  elseif vim.fn.isdirectory(vim.fn.expand(sessions_dir_or_file)) == Lib._VIM_TRUE then
    if not Lib.endsWith(sessions_dir_or_file, '/') then
      sessions_dir = Lib.appendSlash(sessions_dir_or_file)
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
  local sessions_dir, session_file = extractDirOrFile(sessions_dir_or_file)

  local restore = function(file_path)
    local pre_cmds = AutoSession.getCmds("pre_restore")
    runHookCmds(pre_cmds, "pre-restore")

    local cmd = "source "..file_path
    vim.cmd(cmd)
    Lib.logger.info("Session restored from "..file_path)

    local post_cmds = AutoSession.getCmds("post_restore")
    runHookCmds(post_cmds, "post-restore")
  end

  if sessions_dir then
    Lib.logger.debug("==== Using session DIR")
    local session_name = Lib.getEscapedSessionNameFromCwd()
    local session_file_path = string.format(sessions_dir.."%s.vim", session_name)

    local legacy_session_name = Lib.getLegacySessionNameFromCmd()
    local legacy_file_path = string.format(sessions_dir.."%s.vim", legacy_session_name)

    if Lib.isReadable(session_file_path) then
      restore(session_file_path)
    elseif Lib.isReadable(legacy_file_path) then
      restore(legacy_file_path)
    else
      if AutoSession.conf.auto_session_enable_last_session then
        local last_session_file_path = GetLastSession()
        restore(last_session_file_path)
      else
        Lib.logger.debug("File not readable, not restoring session")
      end
    end
  elseif session_file then
    Lib.logger.debug("==== Using session FILE")
    local escaped_file = session_file:gsub("%%", "\\%%")
    if Lib.isReadable(escaped_file) then
      Lib.logger.debug("isReadable, calling restore")
      restore(escaped_file)
    else
      Lib.logger.debug("File not readable, not restoring session")
    end
  else
    Lib.logger.error("Error while trying to parse session dir or file")
  end
end

function AutoSession.DeleteSession(file_path)
  Lib.logger.debug("session_file_path", file_path)

  local pre_cmds = AutoSession.getCmds("pre_delete")
  runHookCmds(pre_cmds, "pre-delete")

  -- TODO: make the delete command customizable
  local cmd = "!rm "

  if file_path then
    local escaped_file_path = file_path:gsub("%%", "\\%%")
    vim.cmd(cmd..escaped_file_path)
    Lib.logger.info("Deleted session "..file_path)
  else
    local session_name = Lib.getEscapedSessionNameFromCwd()
    local session_file_path = string.format(AutoSession.getRootDir().."%s.vim", session_name)

    vim.cmd(cmd..session_file_path)
    Lib.logger.info("Deleted session "..session_file_path)
  end

  local post_cmds = AutoSession.getCmds("post_delete")
  runHookCmds(post_cmds, "post-delete")
end

return AutoSession
