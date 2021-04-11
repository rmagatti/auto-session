local Lib = require('library')

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
  logLevel = vim.g["auto_session_log_level"] or AutoSession.conf.logLevel or 'info'
}

-- Set default config on plugin load
AutoSession.conf = defaultConf
Lib.conf = {
  logLevel = AutoSession.conf.logLevel
}

function AutoSession.setup(config)
  AutoSession.conf = Lib.Config.normalize(config)
  Lib.setup({
    logLevel = AutoSession.conf.logLevel
  })
end


------ MAIN FUNCTIONS ------
-- This function avoids calling SaveSession automatically when argv is not nil.
function AutoSession.AutoSaveSession(sessions_dir)
  if next(vim.fn.argv()) == nil then
    AutoSession.SaveSession(sessions_dir, true)
  end
end

function AutoSession.getRootDir()
  if AutoSession.valiated then
    return AutoSession.conf.root_dir
  end

  local root_dir = vim.g["auto_session_root_dir"] or AutoSession.conf.root_dir or Lib.ROOT_DIR
  Lib.initRootDir(root_dir)

  AutoSession.conf.root_dir = Lib.validateRootDir(root_dir)
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

  local post_cmds = AutoSession.getCmds("post_save")
  runHookCmds(post_cmds, "post-save")
end

-- This function avoids calling RestoreSession automatically when argv is not nil.
function AutoSession.AutoRestoreSession(sessions_dir)
  if next(vim.fn.argv()) == nil then
    AutoSession.RestoreSession(sessions_dir)
  end
end

-- TODO: make this more readable!
-- Restores the session by sourcing the session file if it exists/is readable.
function AutoSession.RestoreSession(sessions_dir_or_file)
  Lib.logger.debug("sessions dir or file", sessions_dir_or_file)
  local sessions_dir = nil
  local session_file = nil

  if Lib.isEmpty(sessions_dir_or_file) then
    sessions_dir = AutoSession.getRootDir()
  elseif vim.fn.isdirectory(vim.fn.expand(sessions_dir_or_file)) == Lib._VIM_TRUE then
    sessions_dir = Lib.appendSlash(sessions_dir_or_file)
  else
    session_file = sessions_dir_or_file
  end

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
      Lib.logger.debug("File not readable, not restoring session")
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

return AutoSession
