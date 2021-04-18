local Config = {}
local Lib = {
  logger = {},
  conf = {
    logLevel = false
  },
  Config = Config,
  _VIM_FALSE = 0,
  _VIM_TRUE  = 1,
  ROOT_DIR = "~/.config/nvim/sessions/"
}


-- Setup ======================================================
function Lib.setup(config)
  Lib.conf = Config.normalize(config)
end

function Config.normalize(config, existing)
  local conf = existing or {}
  if Lib.isEmptyTable(config) then
    return conf
  end

  for k, v in pairs(config) do
    conf[k] = v
  end

  return conf
end
-- ====================================================

-- Helper functions ===============================================================
local function hasValue (tab, val)
  for _, value in ipairs(tab) do
    if value == val then
      return true
    end
  end

  return false
end


function Lib.isEmptyTable(t)
  if t == nil then return true end
  return next(t) == nil
end

function Lib.isEmpty(s)
  return s == nil or s == ''
end

function Lib.endsWith(str, ending)
  return ending == "" or str:sub(-#ending) == ending
end

function Lib.appendSlash(str)
  if not Lib.isEmpty(str) then
    if not Lib.endsWith(str, "/") then
      str = str.."/"
    end
  end
  return str
end

function Lib.validateRootDir(root_dir)
  if Lib.isEmpty(root_dir) or
    vim.fn.expand(root_dir) == vim.fn.expand(Lib.ROOT_DIR) then
    return Lib.ROOT_DIR
  end

  if not Lib.endsWith(root_dir, "/") then
    root_dir = root_dir.."/"
  end

  if vim.fn.isdirectory(vim.fn.expand(root_dir)) == Lib._VIM_FALSE then
    vim.cmd("echoerr 'Invalid g:auto_session_root_dir. " ..
    "Path does not exist or is not a directory. " ..
    "Use ~/.config/nvim/sessions by default.'")
    return Lib.ROOT_DIR
  else
    Lib.logger.debug("Using custom session dir: "..root_dir)
    return root_dir
  end
end

function Lib.initRootDir(root_dir)
  if vim.fn.isdirectory(vim.fn.expand(root_dir)) == Lib._VIM_FALSE then
    vim.cmd("!mkdir -p "..root_dir)
  end
end

function Lib.getEscapedSessionNameFromCwd()
  local cwd = vim.fn.getcwd()
  return cwd:gsub("/", "\\%%")
end

function Lib.getLegacySessionNameFromCmd()
  local cwd = vim.fn.getcwd()
  return cwd:gsub("/", "-")
end

function Lib.isReadable(file_path)
  return vim.fn.filereadable(vim.fn.expand(file_path)) ~= 0
end
-- ===================================================================================


-- Logger =========================================================
function Lib.logger.debug(...)
  if Lib.conf.logLevel == 'debug' then
    print(...)
  end
end

function Lib.logger.info(...)
  local valid_values = {'info', 'debug'}
  if hasValue(valid_values, Lib.conf.logLevel) then
    print(...)
  end
end

function Lib.logger.error(...)
   print(...)
end
-- =========================================================


return Lib
