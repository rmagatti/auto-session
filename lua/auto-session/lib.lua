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
}

function Lib.setup(config)
  Lib.conf = vim.tbl_deep_extend("force", Lib.conf, config or {})
  Lib.logger = Logger:new {
    log_level = Lib.conf.log_level,
  }
end

function Lib.get_file_name(url)
  -- BUG: This is broken on windows when the path is only using blackslashes
  return url:match "^.+/(.+)$"
end

function Lib.get_file_extension(url)
  return url:match "^.+(%..+)$"
end

-- BUG: This doesn't work correctly for automatically created sessions on windows
-- because they have dashes in the name. Can also be broken for paths that only
-- have backslahes (see bug above)
function Lib.current_session_name()
  local fname = Lib.get_file_name(vim.v.this_session)
  local extension = Lib.get_file_extension(fname)
  local fname_without_extension = fname:gsub(extension:gsub("%.", "%%%.") .. "$", "")
  local fname_split = vim.split(fname_without_extension, "%%")
  local session_name = fname_split[#fname_split] or ""
  -- print(
  --   "fname: "
  --     .. fname
  --     .. " ext: "
  --     .. extension
  --     .. " fn w/o ext: "
  --     .. fname_without_extension
  --     .. " split: "
  --     .. vim.inspect(fname_split)
  --     .. " session_name: "
  --     .. session_name
  -- )
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

-- Makes sure the directory ends in a slash
-- Also creates it if necessary
-- Falls back to vim.fn.stdpath "data" .. "/sessions/" if the directory is invalid for some reason
function Lib.validate_root_dir(root_dir)
  root_dir = Lib.ensure_trailing_separator(root_dir)

  if vim.fn.isdirectory(Lib.expand(root_dir)) == Lib._VIM_FALSE then
    vim.fn.mkdir(root_dir, "p")

    -- NOTE: I don't think the code below will ever be triggered because the call to mkdir
    -- above will throw an error if it can't make the directory
    if vim.fn.isdirectory(Lib.expand(root_dir)) == Lib._VIM_FALSE then
      local fallback = vim.fn.stdpath "data" .. "/sessions/"
      vim.cmd(
        "echoerr 'Invalid auto_session_root_dir. "
          .. "Path does not exist or is not a directory. "
          .. string.format("Defaulting to %s.", fallback)
      )
      return fallback
    end
  end
  return root_dir
end

function Lib.init_dir(dir)
  if vim.fn.isdirectory(Lib.expand(dir)) == Lib._VIM_FALSE then
    vim.fn.mkdir(dir, "p")
  end
end

---Returns a string that's guaranteed to end in a path separator
---@param dir string
---@return string
function Lib.ensure_trailing_separator(dir)
  if vim.endswith(dir, "/") then
    return dir
  end

  -- For windows, have to also check if it ends in a \
  if vim.fn.has "win32" == 1 then
    if vim.endswith(dir, "\\") then
      return dir
    end
  end

  -- If not, a / will work for both systems
  return dir .. "/"
end

---Removes the trailing separator (if any) from a directory, for both unix and windows
---This is needed in some places to avoid duplicate separators that complicate
---the path and make equality checks fail (e.g. session control alternate)
---@param dir string
---@return string
function Lib.remove_trailing_separator(dir)
  -- For windows, have to check for both as either could be used
  if vim.fn.has "win32" == 1 then
    dir = dir:gsub("\\$", "")
  end

  return (dir:gsub("/$", ""))
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

-- NOTE: expand has the side effect of canonicalizing the path
-- separators on windows, meaning if it's a mix of \ and /, it
-- will come out of expand with all \ (or, if shellslash is on,
-- all /)

---Get the full path for the passed in path
--@param string
--@return string
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

-- Iterate over the tabpages and then the windows and close any window that has a buffer that isn't backed by
-- a real file
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

-- Count the number of supported buffers
function Lib.count_supported_buffers()
  local supported = 0

  local buffers = vim.api.nvim_list_bufs()

  for _, buf in ipairs(buffers) do
    -- Check if the buffer is valid and loaded
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      local file_name = vim.api.nvim_buf_get_name(buf)
      if Lib.is_readable(file_name) then
        supported = supported + 1
        Lib.logger.debug("is supported: " .. file_name .. " count: " .. vim.inspect(supported))
      end
    end
  end

  return supported
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

---Decodes the contents of session_control_file_path as a JSON object and returns it.
---Returns an empty table if the file doesn't exist or if the contents couldn't be decoded
--@param session_control_file_path string
--@return table
function Lib.load_session_control_file(session_control_file_path)
  -- No file, return empty table
  if vim.fn.filereadable(session_control_file_path) ~= 1 then
    return {}
  end

  local file_lines = vim.fn.readfile(session_control_file_path)
  local content = table.concat(file_lines, " ")

  local success, json = pcall(vim.json.decode, content)

  -- Failed to decode, return an empty table
  if not success or not json then
    return {}
  end

  return json
end

return Lib
