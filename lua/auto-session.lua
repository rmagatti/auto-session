-- helper functions
local function endsWith(str, ending)
  return ending == "" or str:sub(-#ending) == ending
end

local function isEmpty(s)
  return s == nil or s == ''
end

local function appendSlash(str)
  if not isEmpty(str) then
    if not endsWith(str, "/") then
      str = str.."/"
    end
  end
  return str
end

-- Default sessions dir including last slash /
local SESSIONS_DIR = "~/.config/nvim/sessions/"

-- Load user config
local user_defined_session_dir = vim.g.auto_session_root_dir
local user_pre_cmds = vim.g.auto_session_pre_cmds
if not isEmpty(user_defined_session_dir) then
  if not endsWith(user_defined_session_dir, "/") then
    user_defined_session_dir = user_defined_session_dir.."/"
  end

  if vim.fn.isdirectory(vim.fn.expand(user_defined_session_dir)) == 0 then
    vim.cmd("echoerr 'Invalid g:auto_sessions_dir. Path does not exist or is not a directory. AutoSession not loaded.'")
    return
  else
    SESSIONS_DIR = user_defined_session_dir
    print("Using custom session dir: "..user_defined_session_dir)
  end
else
  if vim.fn.isdirectory(vim.fn.expand(SESSIONS_DIR)) == 0 then
    vim.cmd("!mkdir -p "..SESSIONS_DIR)
  end
end


------ MAIN FUNCTIONS ------
local AutoSession = {}

local function getSessionNameFromCwd()
  local cwd = vim.fn.getcwd()
  return cwd:gsub("/", "-")
end

-- This function avoids calling SaveSession automatically when argv is not nil.
function AutoSession.AutoSaveSession(sessions_dir)
  if next(vim.fn.argv()) == nil then
    print("Auto saving session")
    AutoSession.SaveSession(sessions_dir)
  end
end

-- Saves the session, overriding if previously existing.
function AutoSession.SaveSession(sessions_dir)
  if isEmpty(sessions_dir) then
    sessions_dir = nil
  else
    sessions_dir = appendSlash(sessions_dir)
  end

  sessions_dir = sessions_dir or SESSIONS_DIR
  local session_name = getSessionNameFromCwd()
  local full_path = string.format(sessions_dir.."%s.vim", session_name)
  local cmd = "mks! "..full_path
  print("Session saved at "..full_path)

  vim.cmd(cmd)
end

-- This function avoids calling RestoreSession automatically when argv is not nil.
function AutoSession.AutoRestoreSession(sessions_dir)
  if next(vim.fn.argv()) == nil then
    print("Auto restoring session")
    AutoSession.RestoreSession(sessions_dir)
  end
end

-- Restores the session by sourcing the session file if it exists/is readable.
function AutoSession.RestoreSession(sessions_dir)
  if isEmpty(sessions_dir) then
    sessions_dir = nil
  else
    sessions_dir = appendSlash(sessions_dir)
  end

  sessions_dir = sessions_dir or SESSIONS_DIR
  local session_name = getSessionNameFromCwd()
  local session_file_path = string.format(sessions_dir.."%s.vim", session_name)

  if vim.fn.filereadable(vim.fn.expand(session_file_path)) ~= 0 then
    local cmd = "source "..session_file_path
    print("Session restored from "..session_file_path)

    vim.cmd(cmd)
  else
    print("File not readable, not restoring session")
  end
end

return AutoSession
