local Logger = require "auto-session.logger"

local Config = {}
local Lib = {
  logger = {},
  conf = {
    log_level = false,
    last_loaded_session = nil,
  },
  Config = Config,
  _VIM_FALSE = 0,
  _VIM_TRUE = 1,
  ROOT_DIR = nil,
}

function Lib.setup(config)
  Lib.conf = vim.tbl_deep_extend("force", Lib.conf, config or {})
  Lib.logger = Logger:new {
    log_level = Lib.conf.log_level,
  }
end

function Lib.get_file_name(url)
  return url:match "^.+/(.+)$"
end

function Lib.get_file_extension(url)
  return url:match "^.+(%..+)$"
end

function Lib.current_session_name()
  local fname = Lib.get_file_name(vim.v.this_session)
  local extension = Lib.get_file_extension(fname)
  local fname_without_extension = fname:gsub(extension:gsub("%.", "%%%.") .. "$", "")
  local fname_split = vim.split(fname_without_extension, "%%")
  local session_name = fname_split[#fname_split] or ""
  return session_name
end

function Lib.is_empty_table(t)
  if t == nil then
    return true
  end
  return next(t) == nil
end

function Lib.is_empty(s)
  return s == nil or s == ""
end

function Lib.ends_with(str, ending)
  return ending == "" or str:sub(-#ending) == ending
end

function Lib.append_slash(str)
  if not Lib.is_empty(str) then
    if not Lib.ends_with(str, "/") then
      str = str .. "/"
    end
  end
  return str
end

function Lib.validate_root_dir(root_dir)
  if Lib.is_empty(root_dir) or Lib.expand(root_dir) == Lib.expand(Lib.ROOT_DIR) then
    return Lib.ROOT_DIR
  end

  if not Lib.ends_with(root_dir, "/") then
    root_dir = root_dir .. "/"
  end

  if vim.fn.isdirectory(Lib.expand(root_dir)) == Lib._VIM_FALSE then
    vim.cmd(
      "echoerr 'Invalid g:auto_session_root_dir. "
        .. "Path does not exist or is not a directory. "
        .. string.format("Defaulting to %s.", Lib.ROOT_DIR)
    )
    return Lib.ROOT_DIR
  else
    Lib.logger.debug("Using custom session dir: " .. root_dir)
    return root_dir
  end
end

function Lib.init_dir(dir)
  if vim.fn.isdirectory(Lib.expand(dir)) == Lib._VIM_FALSE then
    vim.fn.mkdir(dir, "p")
  end
end

function Lib.init_file(file_path)
  if not Lib.is_readable(file_path) then
    vim.cmd("!touch " .. file_path)
  end
end

local function win32_unescaped_dir(dir)
  dir = dir:gsub("++", ":")
  if not vim.o.shellslash then
    dir = dir:gsub("-", "\\")
  end

  return dir
end

local function win32_escaped_dir(dir)
  dir = dir:gsub(":", "++")
  if not vim.o.shellslash then
    dir = dir:gsub("\\", "-")
    -- need to escape forward slash as well for windows, see issue #202
    dir = dir:gsub("/", "-")
  end

  return dir
end

local IS_WIN32 = vim.fn.has "win32" == Lib._VIM_TRUE

function Lib.unescape_dir(dir)
  return IS_WIN32 and win32_unescaped_dir(dir) or dir:gsub("%%", "/")
end

function Lib.escape_dir(dir)
  return IS_WIN32 and win32_escaped_dir(dir) or dir:gsub("/", "\\%%")
end

function Lib.escaped_session_name_from_cwd()
  return IS_WIN32 and Lib.unescape_dir(vim.fn.getcwd()) or Lib.escape_dir(vim.fn.getcwd())
end

function Lib.escape_branch_name(branch_name)
  return IS_WIN32 and Lib.unescape_dir(branch_name) or Lib.escape_dir(branch_name)
end

local function get_win32_legacy_cwd(cwd)
  cwd = cwd:gsub(":", "++")
  if not vim.o.shellslash then
    cwd = cwd:gsub("\\", "-")
  end

  return cwd
end

function Lib.legacy_session_name_from_cwd()
  local cwd = vim.fn.getcwd()
  return IS_WIN32 and get_win32_legacy_cwd(cwd) or cwd:gsub("/", "-")
end

function Lib.is_readable(file_path)
  local path, _ = file_path:gsub("\\%%", "%%")
  path = Lib.expand(path)
  local readable = vim.fn.filereadable(path) == Lib._VIM_TRUE

  Lib.logger.debug { path = path, readable = readable }

  return readable
end

function Lib.expand(file_or_dir)
  local saved_wildignore = vim.api.nvim_get_option "wildignore"
  vim.api.nvim_set_option("wildignore", "")
  ---@diagnostic disable-next-line: param-type-mismatch
  local ret = vim.fn.expand(file_or_dir, nil, nil)
  vim.api.nvim_set_option("wildignore", saved_wildignore)
  return ret
end

function Lib.has_open_buffers()
  local result = false
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fn.bufloaded(bufnr) then
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      if bufname ~= "" then
        if vim.fn.bufwinnr(bufnr) ~= -1 then
          if result then
            result = true
            Lib.logger.debug "There are buffer(s) present: "
          end
          Lib.logger.debug { bufname = bufname }
        end
      end
    end
  end
  return result
end

function Lib.close_unsupported_windows()
  local tabpages = vim.api.nvim_list_tabpages()
  for _, tabpage in ipairs(tabpages) do
    local windows = vim.api.nvim_tabpage_list_wins(tabpage)
    for _, window in ipairs(windows) do
      -- Never try to close the last window of the last tab
      if vim.fn.tabpagenr "$" == 1 and vim.fn.winnr "$" == 1 then
        return
      end
      local buffer = vim.api.nvim_win_get_buf(window)
      local file_name = vim.api.nvim_buf_get_name(buffer)
      if not Lib.is_readable(file_name) then
        vim.api.nvim_win_close(window, true)
      end
    end
  end
end

function Lib.get_path_separator()
  -- Get cross platform path separator
  return package.config:sub(1, 1)
end

-- When Neovim makes a session file, it may save an additional <filename>x.vim file
-- with custom user commands. This function returns false if it's one of those files
function Lib.is_session_file(session_dir, file_path)
  -- if it's a directory, don't include
  if vim.fn.isdirectory(file_path) ~= 0 then
    return false
  end

  -- if it's a file that doesn't end in x.vim, include
  if not string.find(file_path, "x.vim$") then
    return true
  end

  local path_separator = Lib.get_path_separator()

  -- the file ends in x.vim, make sure it has SessionLoad on the first line
  local file = io.open(session_dir .. path_separator .. file_path, "r")
  if not file then
    Lib.logger.debug("Could not open file: " .. session_dir .. path_separator .. file_path)
    return false
  end

  local first_line = file:read "*line"
  file:close()

  return first_line and string.find(first_line, "SessionLoad") ~= nil
end

return Lib
