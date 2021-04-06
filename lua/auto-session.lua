-- helper functions
local function endsWith(str, ending)
  return ending == "" or str:sub(-#ending) == ending
end

local function isEmpty(s)
  return s == nil or s == ''
end

local function isEmptyTable(t)
  if t == nil then return true end
  return next(t) == nil
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
local ROOT_DIR = "~/.config/nvim/sessions/"

local function validateRootDir(root_dir)
  if isEmpty(root_dir) or
    vim.fn.expand(root_dir) == vim.fn.expand(ROOT_DIR) then
    return ROOT_DIR
  end

  if not endsWith(root_dir, "/") then
    root_dir = root_dir.."/"
  end

  if not vim.fn.isdirectory(vim.fn.expand(root_dir)) then
    vim.cmd("echoerr 'Invalid g:auto_session_root_dir. " ..
      "Path does not exist or is not a directory. " ..
      "Use ~/.config/nvim/sessions by default.'")
    return ROOT_DIR
  else
    print("Using custom session dir: "..root_dir)
    return root_dir
  end
end

local function initRootDir(root_dir)
  if not vim.fn.isdirectory(vim.fn.expand(root_dir)) then
    vim.cmd("!mkdir -p "..root_dir)
  end
end

-- Run comand hooks
local function runHookCmds(cmds, hook_name)
  if not isEmptyTable(cmds) then
    for _,cmd in ipairs(cmds) do
      print(string.format("Running %s command: %s", hook_name, cmd))
      local success, result = pcall(vim.cmd, cmd)
      if not success then print(string.format("Error running %s. error: %s", cmd, result)) end
    end
  end
end


------ MAIN FUNCTIONS ------
local Config = {}

function Config.normalize(config)
  local conf = {}
  if isEmptyTable(config) then
    return conf
  end

  for k, v in pairs(config) do
    conf[k] = v
  end

  return conf
end

local AutoSession = {
  conf = {}
}

local function getEscapedSessionNameFromCwd()
  local cwd = vim.fn.getcwd()
  return cwd:gsub("/", "\\%%")
end

local function getLegacySessionNameFromCmd()
  local cwd = vim.fn.getcwd()
  return cwd:gsub("/", "-")
end

local function isReadable(file_path)
  return vim.fn.filereadable(vim.fn.expand(file_path)) ~= 0
end

-- This function avoids calling SaveSession automatically when argv is not nil.
function AutoSession.AutoSaveSession(sessions_dir)
  if next(vim.fn.argv()) == nil then
    AutoSession.SaveSession(sessions_dir)
  end
end

function AutoSession.getRootDir()
  if AutoSession.valiated then
    return AutoSession.conf.root_dir
  end

  local root_dir = AutoSession.conf.root_dir or ROOT_DIR
  initRootDir(root_dir)

  AutoSession.conf.root_dir = validateRootDir(root_dir)
  AutoSession.validated = true
  return root_dir
end


function AutoSession.getCmds(typ)
  return AutoSession.conf[typ.."_cmds"] or vim.g["auto_session_"..typ.."_cmds"]
end

-- Saves the session, overriding if previously existing.
function AutoSession.SaveSession(sessions_dir)
  if isEmpty(sessions_dir) then
    sessions_dir = AutoSession.getRootDir()
  else
    sessions_dir = appendSlash(sessions_dir)
  end

  local pre_cmds = AutoSession.getCmds("pre_save")
  runHookCmds(pre_cmds, "pre-save")

  local session_name = getEscapedSessionNameFromCwd()
  local full_path = string.format(sessions_dir.."%s.vim", session_name)
  local cmd = "mks! "..full_path
  print("Session saved at "..full_path)

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

-- Restores the session by sourcing the session file if it exists/is readable.
function AutoSession.RestoreSession(sessions_dir)
  if isEmpty(sessions_dir) then
    sessions_dir = AutoSession.getRootDir()
  else
    sessions_dir = appendSlash(sessions_dir)
  end

  local session_name = getEscapedSessionNameFromCwd()
  local session_file_path = string.format(sessions_dir.."%s.vim", session_name)

  local legacy_session_name = getLegacySessionNameFromCmd()
  local legacy_file_path = string.format(sessions_dir.."%s.vim", legacy_session_name)

  local restore = function(file_path)
    local pre_cmds = AutoSession.getCmds("pre_restore")
    runHookCmds(pre_cmds, "pre-restore")

    local cmd = "source "..file_path
    print("Session restored from "..file_path)

    vim.cmd(cmd)

    local post_cmds = AutoSession.getCmds("post_restore")
    runHookCmds(post_cmds, "post-restore")
  end

  if isReadable(session_file_path) then
    restore(session_file_path)
  elseif isReadable(legacy_file_path) then
    restore(legacy_file_path)
  else
    print("File not readable, not restoring session")
  end
end

-- setup
function AutoSession.setup(config)
  AutoSession.conf = Config.normalize(config)
end

return AutoSession
