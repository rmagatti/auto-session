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

---Returns the current session name. For an automatically generated session name, it
---will just be the same as vim.fn.getcwd(). For a named session, it will be the name
---without .vim
---@return string The current session name
function Lib.current_session_name()
  -- get the filename without the extension
  local file_name = vim.fn.fnamemodify(vim.v.this_session, ":t:r")
  return Lib.get_session_display_name(file_name)
end

function Lib.is_empty_table(t)
  if t == nil then
    return true
  end
  return next(t) == nil
end

---Makes sure the directory ends in a slash
---Also creates it if necessary
---Falls back to vim.fn.stdpath "data" .. "/sessions/" if the directory is invalid for some reason
---@param root_dir string The session root directory
---@return string The validated session root directory with a trailing path separator
function Lib.validate_root_dir(root_dir)
  root_dir = Lib.ensure_trailing_separator(Lib.expand(root_dir))

  if vim.fn.isdirectory(root_dir) == Lib._VIM_FALSE then
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

---Legacy decoding function for windows. Replaces ++ with : and - with \
---Unfortunately, it is lossy when roundtripping between encoding and decoding
---because dashes in the session name are lost
---@param dir string Session name to be unescaped
---@return string The unescaped session name
local function legacy_win32_unescaped_dir(dir)
  dir = dir:gsub("++", ":")
  if not vim.o.shellslash then
    dir = dir:gsub("-", "\\")
  else
    dir = dir:gsub("-", "/")
  end
  return dir
end

---Legacy encoding function for windows. Replaces : with ++ and \ with -
---Unfortunately, it is lossy when roundtripping between encoding and decoding
---because dashes in the session name are lost
---@param dir string Session name to be escaped
---@return string The escaped session name
local function legacy_win32_escaped_dir(dir)
  dir = dir:gsub(":", "++")
  if not vim.o.shellslash then
    dir = dir:gsub("\\", "-")
  end
  -- need to escape forward slash as well for windows, see issue #202
  dir = dir:gsub("/", "-")

  return dir
end

local IS_WIN32 = vim.fn.has "win32" == Lib._VIM_TRUE

-- Modified from: https://gist.github.com/liukun/f9ce7d6d14fa45fe9b924a3eed5c3d99
---Convers a character to it's hex representation
---@param c string The single character to convert
---@return string The hex representation of that character
local char_to_hex = function(c)
  return string.format("%%%02X", string.byte(c))
end

---Returns the percent encoded version of str, similar to URI encoding
---@param str string The string to encode
---@return string The percent encoded string
function Lib.percent_encode(str)
  if str == nil then
    return ""
  end
  str = str:gsub("\n", "\r\n")

  -- Have to encode path separators for both unix and windows. also
  -- encode the invalid windows characters and a few others for portabiltiy
  -- This also works correctly with unicode characters (i.e. they are
  -- not encoded)
  return (str:gsub("([/\\:*?\"'<>+ |%%])", char_to_hex))
end

---Convers a hex representation to a single character
---@param x string The hex representation of a character to convert
---@return string The single character
local hex_to_char = function(x)
  return string.char(tonumber(x, 16))
end

---Returns the percent decoded version of str
---@param str string The string to decode
---@return string The decoded string
Lib.percent_decode = function(str)
  if str == nil then
    return ""
  end
  return (str:gsub("%%(%x%x)", hex_to_char))
end

---Returns a string with path characters escaped. Works with both *nix and Windows
---This string is not escaped for use in Vim commands. For that, call Lib.escape_for_vim
---@param session_name string The sesion name to escape
---@return string The escaped string
function Lib.escape_session_name(session_name)
  return Lib.percent_encode(session_name)
end

---Returns a string with path characters unescaped. Works with both *nix and Windows
---@param escaped_session_name string The sesion name to unescape
---@return string The unescaped string
function Lib.unescape_session_name(escaped_session_name)
  return Lib.percent_decode(escaped_session_name)
end

---Returns a string with path characters escaped. Works with both *nix and Windows
---This string is not escaped for use in Vim commands. For that, call Lib.escape_for_vim
---@param session_name string The string to escape, most likely a path to be used as a session_name
---@return string The escaped string
function Lib.legacy_escape_session_name(session_name)
  if IS_WIN32 then
    return legacy_win32_escaped_dir(session_name)
  end

  return (session_name:gsub("/", "%%"))
end

---Returns a string with path characters unescaped using the legacy mechanism
---Works with both *nix and Windows
---@param escaped_session_name string The string to unescape, most likely a path to be used as a session_name
---@return string The unescaped string
function Lib.legacy_unescape_session_name(escaped_session_name)
  if IS_WIN32 then
    return legacy_win32_unescaped_dir(escaped_session_name)
  end

  return (escaped_session_name:gsub("%%", "/"))
end

---Returns true if file_name is in the legacy format
---@param file_name string The filename to look at
---@return boolean True if file_name is in the legacy format
function Lib.is_legacy_file_name(file_name)
  -- print(file_name)
  if IS_WIN32 then
    return file_name:match "^[%a]++" ~= nil
  end

  -- if it's all alphanumeric, it's not
  if file_name:match "^[%w]+%.vim$" then
    return false
  end

  -- print("does it start with %?: " .. file_name)

  -- if it doesn't start with %, it's not
  if file_name:sub(1, 1) ~= "%" then
    return false
  end

  -- print("is it url encoded?: " .. file_name)

  -- check each characters after each % to make sure
  -- they're hexadecimal
  for encoded in file_name:gmatch "%%.." do
    local hex = encoded:sub(2)
    if not hex:match "^%x%x$" then
      return true
    end
  end

  return false
end

---Returns a sstring with % characters escaped, suitable for use with vim cmds
---@param str string The string to vim escape
---@return string The string escaped for use with vim.cmd
function Lib.escape_string_for_vim(str)
  return (str:gsub("%%", "\\%%"))
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
      if vim.fn.filereadable(file_name) == 0 then
        vim.api.nvim_win_close(window, true)
      end
    end
  end
end

---Convert a session file name to a session_name that can be passed to SessionRestore/Delete.
---Although, those commands should also take a session name ending in .vim
---@param escaped_session_name string The session file name. It should not have a path component
---@return string The session name, suitable for display or passing to other cmds
function Lib.escaped_session_name_to_session_name(escaped_session_name)
  return (Lib.unescape_session_name(escaped_session_name):gsub("%.vim$", ""))
end

---Get the session displayname as a table of components. Index 1 will always be the session
---name (but not file name) with any annotations coming after (like git branch)
---@param escaped_session_name string The session file name. It should not have a path component
---@return table The session name components
function Lib.get_session_display_name_as_table(escaped_session_name)
  -- sesssion name contains a |, split on that and get git branch
  local session_name = Lib.escaped_session_name_to_session_name(escaped_session_name)
  local splits = vim.split(session_name, "|")

  if #splits == 1 then
    return splits
  end

  splits[2] = "(branch: " .. splits[2] .. ")"
  return splits
end
---Convert a session file name to a display name The result cannot be used with commands
---like SessionRestore/SessionDelete as it might have additional annotations (like a git branch)
---@param escaped_session_name string The session file name. It should not have a path component
---@return string The session name suitable for display
function Lib.get_session_display_name(escaped_session_name)
  local splits = Lib.get_session_display_name_as_table(escaped_session_name)

  return table.concat(splits, " ")
end

---Returns if a session is a named session or not (i.e. from a cwd)
---@param session_file_name string The session_file_name. It should not have a path component
---@return boolean Whether the session is a named session (e.g. mysession.vim or one
---generated from a directory
function Lib.is_named_session(session_file_name)
  Lib.logger.debug("session_file_name: " .. session_file_name)
  if vim.fn.has "win32" == 1 then
    -- Matches any letter followed by a colon
    return not session_file_name:find "^%a:"
  end

  -- Matches / at the start of the string
  return not session_file_name:find "^/.*"
end

---When saving a session file, we may save an additional <filename>x.vim file
---with custom user commands. This function returns false if it's one of those files
---@param session_path string The file (full path) being considered
---@return boolean True if the file is a session file, false otherwise
function Lib.is_session_file(session_path)
  -- if it's a directory, don't include
  if vim.fn.isdirectory(session_path) ~= 0 then
    return false
  end

  -- if it's a file that doesn't end in x.vim, include
  if not string.find(session_path, "x.vim$") then
    return true
  end

  -- the file ends in x.vim, make sure it has SessionLoad on the first line
  local file = io.open(session_path, "r")
  if not file then
    Lib.logger.debug("Could not open file: " .. session_path)
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

---complete_session is used by the vimscript command for session name/path completion.
---@param session_dir string The session directory look in
---@return table
function Lib.complete_session_for_dir(session_dir, ArgLead, _, _)
  -- Lib.logger.debug("CompleteSessions: ", { ArgLead, CmdLine, CursorPos })
  local session_files = vim.fn.glob(session_dir .. "*", true, true)
  local session_names = {}

  for _, path in ipairs(session_files) do
    -- don't include extra user command files, aka *x.vim
    local file_name = vim.fn.fnamemodify(path, ":t:r")
    Lib.logger.debug(file_name)
    if Lib.is_session_file(session_dir .. file_name) then
      local name
      if Lib.is_legacy_file_name(file_name) then
        name = Lib.legacy_unescape_session_name(file_name)
      else
        name = Lib.unescape_session_name(file_name)
      end
      table.insert(session_names, name)
    end
  end

  return vim.tbl_filter(function(item)
    return item:match("^" .. ArgLead)
  end, session_names)
end

---Iterates over dirs, looking to see if any of them match dirToFind
---dirs may contain globs as they will be expanded and checked
---@param dirs table
---@param dirToFind string
function Lib.find_matching_directory(dirToFind, dirs)
  Lib.logger.debug("find_matching_directory", { dirToFind = dirToFind, dirs = dirs })
  for _, s in pairs(dirs) do
    local expanded = Lib.expand(s)
    -- Lib.logger.debug("find_matching_directory expanded: " .. s)
    ---@diagnostic disable-next-line: param-type-mismatch
    for path in string.gmatch(expanded, "[^\r\n]+") do
      local simplified_path = vim.fn.simplify(path)
      local path_without_trailing_slashes = string.gsub(simplified_path, "/+$", "")

      -- Lib.logger.debug("find_matching_directory simplified: " .. simplified_path)

      if dirToFind == path_without_trailing_slashes then
        Lib.logger.debug "find find_matching_directory found match!"
        return true
      end
    end
  end

  return false
end

return Lib
