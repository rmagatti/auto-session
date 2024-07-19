local Logger = require "auto-session.logger"

local Config = {}
local Lib = {
  logger = {},
  conf = {
    log_level = false,
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

---Makes sure the directory ends in a slash
---Also creates it if necessary
---Falls back to vim.fn.stdpath "data" .. "/sessions/" if the directory is invalid for some reason
---@param root_dir string The session root directory
---@return string The validated session root directory with a trailing path separator
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
---@param dir string The directory path to make sure has a trailing separator
---@return string Dir guaranteed to have a trailing separator
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
---@param dir string The directory path to make sure doesn't have a trailing separator
---@return string Dir guaranteed to not have a trailing separator
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
  return IS_WIN32 and Lib.escape_dir(vim.fn.getcwd()) or Lib.escape_dir(vim.fn.getcwd())
end

function Lib.escape_branch_name(branch_name)
  return IS_WIN32 and Lib.escape_dir(branch_name) or Lib.escape_dir(branch_name)
end

-- FIXME:These escape functions should be replaced with something better, probably urlencoding

---Returns a string with path characters escaped. Works with both *nix and Windows
---This string is not escaped for use in Vim commands. For that, call Lib.escape_for_vim
---@param str string The string to escape, most likely a path to be used as a session_name
---@return string The escaped string
function Lib.escape_path(str)
  if IS_WIN32 then
    return win32_escaped_dir(str)
  end

  return (str:gsub("/", "%%"))
end

---Returns a string with path characters unescaped. Works with both *nix and Windows
---@param str string The string to unescape, most likely a path to be used as a session_name
---@return string The unescaped string
function Lib.unescape_path(str)
  if IS_WIN32 then
    return win32_unescaped_dir(str)
  end

  return (str:gsub("%%", "/"))
end

---Returns a sstring with % characters escaped, suitable for use with vim cmds
---@param str string The string to vim escape
---@return string The string escaped for use with vim.cmd
function Lib.escape_string_for_vim(str)
  return (str:gsub("%%", "\\%%"))
end

---Returns the session file name from a full path
---@param session_path string The file path, with path and file name components
---@return string The session name component
function Lib.get_session_name_from_path(session_path)
  if vim.fn.has "win32" == 1 then
    -- On windows, the final path separator could be a / or a \
    return session_path:match ".*[/\\](.+)$" or session_path
  end

  return session_path:match ".*[/](.+)$" or session_path
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
---@param file_or_dir string
---@return string
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

---Iterate over the tabpages and then the windows and close any window that has a buffer that isn't backed by
---a real file
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

---Convert a session file name to a session_name, which is useful for display
---and can also be passed to SessionRestore/Delete
---@param session_file_name string The session file name. It should not have a path component
---@return string The session name, suitable for display or passing to other cmds
function Lib.session_file_name_to_session_name(session_file_name)
  return Lib.unescape_dir(session_file_name):gsub("%.vim$", "")
end

---Returns if a session is a named session or not (i.e. from a cwd)
---@param session_file_name string The session_file_name. It should not have a path component
---@return boolean Whether the session is a named session (e.g. mysession.vim or one
---generated from a directory
function Lib.is_named_session(session_file_name)
  if vim.fn.has "win32" == 1 then
    -- Matches any letter followed by a colon
    return not session_file_name:find "^%a:"
  end

  -- Matches / at the start of the string
  return not session_file_name:find "^/.*"
end

---When saving a session file, we may save an additional <filename>x.vim file
---with custom user commands. This function returns false if it's one of those files
---@param session_dir string The session directory
---@param file_name string The file being considered
---@return boolean True if the file is a session file, false otherwise
function Lib.is_session_file(session_dir, file_name)
  -- if it's a directory, don't include
  if vim.fn.isdirectory(file_name) ~= 0 then
    return false
  end

  -- if it's a file that doesn't end in x.vim, include
  if not string.find(file_name, "x.vim$") then
    return true
  end

  -- the file ends in x.vim, make sure it has SessionLoad on the first line
  local file_path = session_dir .. "/" .. file_name
  local file = io.open(file_path, "r")
  if not file then
    Lib.logger.debug("Could not open file: " .. file_path)
    return false
  end

  local first_line = file:read "*line"
  file:close()

  return first_line and string.find(first_line, "SessionLoad") ~= nil
end

---Decodes the contents of session_control_file_path as a JSON object and returns it.
---Returns an empty table if the file doesn't exist or if the contents couldn't be decoded
---@param session_control_file_path string
---@return table Contents of the decoded JSON file, or an empty table
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

---Get latest session for the "last session" feature
---@param session_dir string The session directory to look for sessions in
---@return string|nil
function Lib.get_latest_session(session_dir)
  if not session_dir then
    return nil
  end

  local latest_session = { session_path = nil, last_edited = 0 }

  for _, session_name in ipairs(vim.fn.readdir(session_dir)) do
    local session = session_dir .. session_name
    local last_edited = vim.fn.getftime(session)

    if last_edited > latest_session.last_edited then
      latest_session.session_name = session_name
      latest_session.last_edited = last_edited
    end
  end

  if not latest_session.session_name then
    return nil
  end

  return latest_session.session_name
end

return Lib
