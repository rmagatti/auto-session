local Logger = require("auto-session.logger")

local Lib = {
  logger = {},
  _VIM_FALSE = 0,
  _VIM_TRUE = 1,
}

function Lib.setup(log_level)
  Lib.logger = Logger:new({
    log_level = log_level,
  })
end

local uv = vim.uv or vim.loop

---Returns the current session name. For an automatically generated session name, it
---will just be the same as vim.fn.getcwd(). For a named session, it will be the name
---without .vim
---@param tail_only? boolean Only return the last part of a path based session name
---@return string The current session name
function Lib.current_session_name(tail_only)
  tail_only = tail_only or false
  -- get the filename without the extension
  local file_name = vim.fn.fnamemodify(vim.v.this_session, ":t:r")
  if not tail_only then
    return Lib.get_session_display_name(file_name)
  end

  -- Have to get the display name sections if we want to shorten just the path in case
  -- there's a git branch
  local sections = Lib.get_session_display_name_as_table(file_name)
  sections[1] = vim.fn.fnamemodify(sections[1], ":t")
  if #sections == 1 then
    return sections[1]
  end

  return table.concat(sections, " ")
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
      local fallback = vim.fn.stdpath("data") .. "/sessions/"
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
  if vim.fn.has("win32") == 1 then
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
-- Will return '/' if that's the only part of the path
---@param dir string The directory path to make sure doesn't have a trailing separator
---@return string Dir guaranteed to not have a trailing separator
function Lib.remove_trailing_separator(dir)
  -- For windows, have to check for both as either could be used
  if vim.fn.has("win32") == 1 then
    dir = dir:gsub("\\$", "")
  end

  return (dir:gsub("(.)/$", "%1"))
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

local IS_WIN32 = vim.fn.has("win32") == Lib._VIM_TRUE

-- Modified from: https://gist.github.com/liukun/f9ce7d6d14fa45fe9b924a3eed5c3d99
---Converts a character to it's hex representation
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
  return (str:gsub("([/\\:*?\"'<>+ |%.%%])", char_to_hex))
end

---Converts a hex representation to a single character
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
---@param session_name string The session name to escape
---@return string The escaped string
function Lib.escape_session_name(session_name)
  return Lib.percent_encode(session_name)
end

---Returns a string with path characters unescaped. Works with both *nix and Windows
---@param escaped_session_name string The session name to unescape
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
    return file_name:match("^[%a]++") ~= nil
  end

  -- if it's all alphanumeric, it's not
  if file_name:match("^[%w]+%.vim$") then
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
  for encoded in file_name:gmatch("%%..") do
    local hex = encoded:sub(2)
    if not hex:match("^%x%x$") then
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
  local saved_wildignore = vim.api.nvim_get_option_value("wildignore", {})
  vim.api.nvim_set_option_value("wildignore", "", {})
  local ret = vim.fn.expand(file_or_dir, nil, nil)
  vim.api.nvim_set_option_value("wildignore", saved_wildignore, {})
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
            Lib.logger.debug("There are buffer(s) present: ")
          end
          Lib.logger.debug({ bufname = bufname })
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
      if vim.fn.tabpagenr("$") == 1 and vim.fn.winnr("$") == 1 then
        return
      end
      -- Sometimes closing one window can affect another so wrap in pcall
      local success, buffer = pcall(vim.api.nvim_win_get_buf, window)
      if success then
        local file_name = vim.api.nvim_buf_get_name(buffer)
        local buf_type = vim.api.nvim_get_option_value("buftype", { buf = buffer })
        -- Lib.logger.debug("file_name: " .. file_name .. " buf_type: " .. buf_type)
        if vim.fn.filereadable(file_name) == 0 and buf_type ~= "terminal" then
          Lib.logger.debug("closing window: " .. window .. " file_name: " .. file_name .. " buf_type: " .. buf_type)

          vim.api.nvim_win_close(window, true)
        end
      else
        Lib.logger.debug("Windows: " .. vim.inspect(windows) .. " window is no longer valid: " .. window)
      end
    end
  end
end

---Convert a session file name to a session_name that can be passed to SessionRestore/Delete.
---Although, those commands should also take a session name ending in .vim
---@param escaped_session_name string The session file name. It should not have a path component
---@return string session_name The session name, suitable for display or passing to other cmds
function Lib.escaped_session_name_to_session_name(escaped_session_name)
  return (Lib.unescape_session_name(escaped_session_name):gsub("%.vim$", ""))
end

---Get session name from escaped session path
---@param escaped_session_path string The session path, likely from vim.v.this_session
---@return string session_name
function Lib.escaped_session_path_to_session_name(escaped_session_path)
  return Lib.escaped_session_name_to_session_name(vim.fn.fnamemodify(escaped_session_path, ":t"))
end

---Get the session displayname as a table of components. Index 1 will always be the session
---name (but not file name) with any annotations coming after (like git branch)
---@param escaped_session_name string The session file name. It should not have a path component
---@return table The session name components
function Lib.get_session_display_name_as_table(escaped_session_name)
  -- session name contains a |, split on that and get git branch
  local session_name = Lib.escaped_session_name_to_session_name(escaped_session_name)
  local splits = vim.split(session_name, "|")

  if #splits == 1 then
    return splits
  end

  local suffix = {}
  local labels = { "", "branch", "tag" }
  for i = 2, #splits do
    if splits[i] and splits[i] ~= "" then
      table.insert(suffix, labels[i] .. ": " .. splits[i])
    end
  end

  return { splits[1], "(" .. table.concat(suffix, ", ") .. ")" }
end

---Convert a session file name to a display name The result cannot be used with commands
---like SessionRestore/SessionDelete as it might have additional annotations (like a git branch)
---@param escaped_session_name string The session file name. It should not have a path component
---@return string session_display_name The session name suitable for display
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
  if vim.fn.has("win32") == 1 then
    -- Matches any letter followed by a colon
    return not session_file_name:find("^%a:")
  end

  -- Matches / at the start of the string
  return not session_file_name:find("^/.*")
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

  local first_line = file:read("*line")
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

---Returns the name of the latest session. Uses session name instead of filename
---to handle conversion from legacy sessions
---@param session_dir string The session directory to look for sessions in
---@return string|nil the name of the latest session, if there is one
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

  return Lib.escaped_session_name_to_session_name(latest_session.session_name)
end

---complete_session is used by the vimscript command for session name/path completion.
---@param session_dir string The session directory look in
---@return table
function Lib.complete_session_for_dir(session_dir, arg_lead, _, _)
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
    return item:match("^" .. arg_lead)
  end, session_names)
end

---Iterates over dirs, looking to see if any of them match dirToFind
---dirs may contain globs as they will be expanded and checked
---@param dirs table
---@param dirToFind string
function Lib.find_matching_directory(dirToFind, dirs)
  local dirsToCheck = {}

  -- resolve any symlinks and also check those
  for _, dir in pairs(dirs) do
    -- first expand it
    local expanded_dir = Lib.expand(dir)

    -- resolve symlinks
    local resolved_dir = vim.fn.resolve(expanded_dir)

    -- Lib.logger.debug("dir: " .. dir .. " expanded_dir: " .. expanded_dir .. " resolved_dir: " .. resolved_dir)

    -- add the base expanded dir first. in theory, we should only need
    -- the resolved directory but other systems might behave differently so
    -- safer to check both
    table.insert(dirsToCheck, expanded_dir)

    -- add the resolved dir if it's different (e.g. a symlink)
    if resolved_dir ~= expanded_dir then
      table.insert(dirsToCheck, resolved_dir)
    end
  end

  Lib.logger.debug("find_matching_directory", { dirToFind = dirToFind, dirsToCheck = dirsToCheck })

  for _, dir in pairs(dirsToCheck) do
    ---@diagnostic disable-next-line: param-type-mismatch
    for path in string.gmatch(dir, "[^\r\n]+") do
      local simplified_path = vim.fn.simplify(path)
      local path_without_trailing_slashes = string.gsub(simplified_path, "([/~].*)/+$", "%1")

      -- Lib.logger.debug("find_matching_directory simplified: " .. simplified_path)

      if dirToFind == path_without_trailing_slashes then
        Lib.logger.debug("find find_matching_directory found match!")
        return true
      end
    end
  end

  return false
end

---@param cmds table Cmds to run
---@param hook_name string Name of the hook being run
---@return table|nil Results of the cmds
function Lib.run_hook_cmds(cmds, hook_name)
  if Lib.is_empty_table(cmds) then
    return nil
  end

  local results = {}
  for _, cmd in ipairs(cmds) do
    Lib.logger.debug(string.format("Running %s command: %s", hook_name, cmd))
    local success, result

    if type(cmd) == "function" then
      success, result = pcall(cmd)
    else
      ---@diagnostic disable-next-line: param-type-mismatch
      success, result = pcall(vim.cmd, cmd)
    end

    if not success then
      Lib.logger.error(string.format("Error running %s. error: %s", cmd, result))
    else
      table.insert(results, result)
    end
  end
  return results
end

---Split any strings on newlines and add each one to the output table
---Also flatten any embedded tables and and their values into the root table
---(non recursive so only one level deep)
---@param input table|nil
---@return table The flattened table
function Lib.flatten_table_and_split_strings(input)
  local output = {}

  if not input then
    return output
  end

  local function add_value_to_output(value)
    Lib.logger.debug("value: ", value)
    if value == nil then
      return
    end

    local value_type = type(value)
    if value_type == "number" then
      table.insert(output, value)
    elseif value_type == "string" then
      for s in value:gmatch("[^\r\n]+") do
        table.insert(output, s)
      end
    end
  end

  for _, value in pairs(input) do
    if type(value) == "table" then
      for _, subvalue in pairs(value) do
        add_value_to_output(subvalue)
      end
    else
      add_value_to_output(value)
    end
  end

  return output
end

---Returns the list of files in a directory, sorted by modification time
---@param dir string the directory to list
---@return table The filenames, sorted by modification time
function Lib.sorted_readdir(dir)
  -- Get list of files
  local files = vim.fn.readdir(dir)

  -- Create a table with file names and modification times
  local file_times = {}
  for _, file in ipairs(files) do
    local full_path = dir .. "/" .. file
    local mod_time = vim.fn.getftime(full_path)
    table.insert(file_times, { name = file, time = mod_time })
  end

  -- Sort the table based on modification times (most recent first)
  table.sort(file_times, function(a, b)
    return a.time > b.time
  end)

  -- Extract just the file names from the sorted table
  local sorted_files = {}
  for _, file in ipairs(file_times) do
    table.insert(sorted_files, file.name)
  end

  return sorted_files
end

---Get the list of session files. Will filter out any extra command session files
---@param sessions_dir string The directory where the sessions are stored
---@return table the list of session files
function Lib.get_session_list(sessions_dir)
  if vim.fn.isdirectory(sessions_dir) == Lib._VIM_FALSE then
    return {}
  end

  local files = Lib.sorted_readdir(sessions_dir)

  local session_entries = vim.tbl_map(function(file_name)
    local session_name
    local display_name_component

    if not Lib.is_session_file(sessions_dir .. file_name) then
      return nil
    end

    -- an annotation about the session, added to display_name after any path processing
    local annotation = ""
    if Lib.is_legacy_file_name(file_name) then
      session_name = (Lib.legacy_unescape_session_name(file_name):gsub("%.vim$", ""))
      display_name_component = session_name
      annotation = " (legacy)"
    else
      session_name = Lib.escaped_session_name_to_session_name(file_name)
      display_name_component = session_name
      local name_components = Lib.get_session_display_name_as_table(file_name)
      if #name_components > 1 then
        display_name_component = name_components[1]
        annotation = " " .. name_components[2]
      end
    end

    local display_name = display_name_component .. annotation

    return {
      session_name = session_name,
      -- include the components in case telescope wants to shorten the path
      display_name_component = display_name_component,
      annotation_component = annotation,
      display_name = display_name,
      file_name = file_name,
      path = sessions_dir .. file_name,
    }
  end, files)

  -- Filter out nil entries (files that didn't pass is_session_file check)
  local filtered_session_entries = vim.tbl_filter(function(entry)
    return entry ~= nil
  end, session_entries)

  return filtered_session_entries
end

---Get the name of the altnernate session stored in the session control file
---@return string|nil name of the alternate session, suitable for calls to LoadSession
function Lib.get_alternate_session_name(session_control_conf)
  if not session_control_conf then
    Lib.logger.error("No session_control in config!")
    return nil
  end

  local filepath = vim.fn.expand(session_control_conf.control_dir) .. session_control_conf.control_filename

  if vim.fn.filereadable(filepath) == 0 then
    return nil
  end

  local json = Lib.load_session_control_file(filepath)

  local sessions = {
    current = json.current,
    alternate = json.alternate,
  }

  Lib.logger.debug("get_alternate_session_name", { sessions = sessions, json = json })

  if sessions.current == sessions.alternate then
    Lib.logger.info("Current session is the same as alternate, returning nil")
    return nil
  end
  local file_name = vim.fn.fnamemodify(sessions.alternate, ":t")
  if Lib.is_legacy_file_name(file_name) then
    return (Lib.legacy_unescape_session_name(file_name):gsub("%.vim$", ""))
  end
  return Lib.escaped_session_name_to_session_name(file_name)
end

---Returns git branch name, if any, for the path (if passed in) or the cwd
---@param path string? Optional path to use when checking for git branch
---@return string|nil # Name of git branch or empty string
function Lib.get_git_branch_name(path)
  local git_cmd = string.format("git%s rev-parse --abbrev-ref HEAD", path and (" -C " .. path) or "")

  local out = vim.fn.systemlist(git_cmd)
  if vim.v.shell_error ~= 0 then
    Lib.logger.debug(string.format("git failed with: %s", table.concat(out, "\n")))
    return nil
  end
  return out[1]
end

---Adds the git branch name to the passwed in session name
---@param session_name string session name to add the git branch to
---@param git_branch_name string|nil git branch name to use
---@param custom_tag string|nil custom tag to use, can't be used with legacy names
---@param legacy boolean? whether to use current or legacy naming convention
---@return string # Session name with the git branch name added on (if there is one)
function Lib.combine_session_name_with_git_and_tag(session_name, git_branch_name, custom_tag, legacy)
  -- legacy session names only support git branch names
  if legacy then
    if git_branch_name then
      return session_name .. "_" .. git_branch_name
    end
    return session_name
  end

  if not git_branch_name then
    if not custom_tag then
      return session_name
    end
    -- if we have a custom tag, we still need to include an empty git branch section
    git_branch_name = ""
  end

  -- NOTE: By including these in the session name, there's the possibility of a collision
  -- with an actual directory named session_name|branch_name. Meaning, that if someone
  -- created a session in session_name (while branch_name is checked out) and then also
  -- went to edit in a directory literally called session_name|branch_name. the sessions
  -- would collide. Obviously, that's not perfect but I think it's an ok price to pay to
  -- get branch specific sessions and still have a cwd derived text key to identify sessions
  -- that can be used everywhere, including :SessionRestore

  local combined_session_name = session_name .. "|" .. git_branch_name

  if custom_tag then
    combined_session_name = combined_session_name .. "|" .. custom_tag
  end

  return combined_session_name
end

---Delete sessions that have access times older than purge_days_old old
---@param session_dir string The session directory to look for sessions in
---@param purge_older_than_minutes number in minutes, e.g. 14400, delete sessions older than 10 days ago
---@return string # json encoded string of escaped session filenames removed
function Lib.purge_old_sessions(session_dir, purge_older_than_minutes)
  local epoch = os.time()
  local garbage_collect_seconds = purge_older_than_minutes * 60
  local scan_dir = assert(vim.uv.fs_scandir(session_dir))
  local out = {}

  if purge_older_than_minutes == 0 or garbage_collect_seconds == 0 then
    return "[]"
  end

  local file = vim.uv.fs_scandir_next(scan_dir)
  while file do
    local abs_path = session_dir .. file
    local fd = assert(vim.uv.fs_open(abs_path, "r", 0))
    local stat = assert(vim.uv.fs_fstat(fd))
    local atime = stat["atime"]["sec"]
    assert(vim.uv.fs_close(fd))
    local age = epoch - atime
    -- print("file: " .. abs_path .. " age: " .. age)
    if age > garbage_collect_seconds then
      assert(vim.uv.fs_unlink(abs_path))
      table.insert(out, file)
    end

    file = vim.uv.fs_scandir_next(scan_dir)
  end

  return vim.json.encode(out)
end

---Checks to see if there are only empty/unnamed buffers left
---@return boolean # True if there are only empty/unnamed buffers left
function Lib.only_blank_buffers_left()
  local bufs = vim.api.nvim_list_bufs()
  for _, bufnr in ipairs(bufs) do
    -- Only consider listed buffers
    if vim.fn.buflisted(bufnr) == 1 then
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local is_empty = #lines <= 1 and (lines[1] == nil or lines[1] == "")
      local is_modified = vim.api.nvim_get_option_value("modified", { buf = bufnr })
      local has_name = vim.api.nvim_buf_get_name(bufnr) ~= ""

      -- If buffer has a name, is modified, or has content, it's meaningful
      if has_name or is_modified or not is_empty then
        return false
      end
    end
  end
  return true
end

---Returns true if there are any modified buffers
---@return boolean # True if there are any modified buffers
function Lib.has_modified_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_option_value("modified", { buf = buf }) then
      return true
    end
  end
  return false
end

---Close any buffers that have a ft that is in ignored_filetypes
---@param ignored_filetypes table list of filetypes to close
function Lib.close_ignored_filetypes(ignored_filetypes)
  local filetypes_to_ignore = ignored_filetypes or {}
  if vim.tbl_isempty(filetypes_to_ignore) then
    return
  end

  local buffers = vim.api.nvim_list_bufs()

  for _, buf in ipairs(buffers) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local buf_ft = vim.bo[buf].filetype
      if buf_ft and vim.tbl_contains(filetypes_to_ignore, buf_ft) then
        vim.api.nvim_buf_delete(buf, { force = true })
        break
      end
    end
  end
end

---Snacks (https://github.com/folke/snacks.nvim) debounce function
---@generic T
---@param fn T
---@param opts? {ms?:number}
---@return T
function Lib.debounce(fn, opts)
  local timer = assert(uv.new_timer())
  local ms = opts and opts.ms or 20
  return function()
    timer:start(ms, 0, vim.schedule_wrap(fn))
  end
end

---Wipeout buffers, checking callback if not nil
---@param should_preserve_buffer fun(bufnr:number): preserve_buffer:boolean
function Lib.conditional_buffer_wipeout(should_preserve_buffer)
  if not should_preserve_buffer then
    vim.cmd("silent %bw!")
    return
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if not should_preserve_buffer(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
end

return Lib
