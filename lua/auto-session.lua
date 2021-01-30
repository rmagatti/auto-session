-- helper function
local function endsWith(str, ending)
  return ending == "" or str:sub(-#ending) == ending
end

-- directory path including last slash /
local SESSIONS_DIR = "~/.config/nvim/sessions/"
if vim.fn.isdirectory(vim.fn.expand(SESSIONS_DIR)) == 0 then
  vim.cmd("!mkdir -p "..SESSIONS_DIR)
end

-- Load user config
local auto_session_root_dir = vim.g.auto_session_root_dir
if auto_session_root_dir ~= nil then
  if not endsWith(auto_session_root_dir, "/") then
    auto_session_root_dir = auto_session_root_dir.."/"
  end

  print(auto_session_root_dir)
  if vim.fn.isdirectory(vim.fn.expand(auto_session_root_dir)) == 0 then
    vim.cmd("echoerr 'Invalid g:auto_sessions_dir. Path does not exist or is not a directory. AutoSession not loaded.'")
    return
  else
    SESSIONS_DIR = auto_session_root_dir
  end
end


-- MAIN FUNCTIONS --
local AutoSession = {}

local function getProjectDir()
  local cwd = vim.fn.getcwd()
  local project_dir = cwd:gsub("/", "-")
  return project_dir
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
  local sessions_dir = sessions_dir or SESSIONS_DIR
  local project_dir = getProjectDir()
  local full_path = string.format(sessions_dir.."%s.vim", project_dir)
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
  local sessions_dir = sessions_dir or SESSIONS_DIR
  local project_dir = getProjectDir()
  local session_file_path = string.format(sessions_dir.."%s.vim", project_dir)

  if vim.fn.filereadable(vim.fn.expand(session_file_path)) ~= 0 then
    local cmd = "source "..session_file_path
    print("Session restored from "..session_file_path)

    vim.cmd(cmd)
  else
    print("File not readable, not restoring session")
  end
end

return AutoSession
