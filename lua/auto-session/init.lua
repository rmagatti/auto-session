local Lib = require "auto-session.lib"
local AutoCmds = require "auto-session.autocmds"

----------- Setup ----------
local AutoSession = {
  ---@type luaOnlyConf
  conf = {},

  -- Hold on to the lib object here, useful to have the same Lib object for unit
  -- testing, especially since the logger needs the config to be functional
  Lib = Lib,

  -- Hold onto session_lens object for popping search on :SessionSearch
  session_lens = nil,
}

-- Run command hooks
local function run_hook_cmds(cmds, hook_name)
  local results = {}
  if not Lib.is_empty_table(cmds) then
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
  end
  return results
end

---table default config for auto session
---@class defaultConf
---@field auto_session_enabled? boolean Enables/disables auto saving and restoring
---@field auto_session_root_dir? string root directory for session files, by default is `vim.fn.stdpath('data') .. '/sessions/'`
---@field auto_save_enabled? boolean Enables/disables auto saving session on exit
---@field auto_restore_enabled? boolean Enables/disables auto restoring session on start
---@field auto_session_suppress_dirs? table Suppress auto session for directories
---@field auto_session_allowed_dirs? table Allow auto session for directories, if empty then all directories are allowed except for suppressed ones
---@field auto_session_create_enabled? boolean|function Enables/disables auto creating new sessions. Can take a function that should return true/false if a session should be created or not
---@field auto_session_enable_last_session? boolean On startup, loads the last saved session if session for cwd does not exist
---@field auto_session_use_git_branch? boolean Include git branch name in session name to differentiate between sessions for different git branches
---@field auto_restore_lazy_delay_enabled? boolean Automatically detect if Lazy.nvim is being used and wait until Lazy is done to make sure session is restored correctly. Does nothing if Lazy isn't being used. Can be disabled if a problem is suspected or for debugging
---@field log_level? string|integer "debug", "info", "warn", "error" or vim.log.levels.DEBUG, vim.log.levels.INFO, vim.log.levels.WARN, vim.log.levels.ERROR

---Default config for auto session
---@type defaultConf
local defaultConf = {
  auto_session_enabled = true, -- Enables/disables auto creating, saving and restoring
  auto_session_root_dir = vim.fn.stdpath "data" .. "/sessions/", -- Root dir where sessions will be stored
  auto_save_enabled = true, -- Enables/disables auto save feature
  auto_restore_enabled = true, -- Enables/disables auto restore feature
  auto_session_suppress_dirs = nil, -- Suppress session restore/create in certain directories
  auto_session_allowed_dirs = nil, -- Allow session restore/create in certain directories
  auto_session_create_enabled = true, -- Enables/disables auto creating new sessions. Can take a function that should return true/false if a session should be created or not
  auto_session_enable_last_session = vim.g.auto_session_enable_last_session or false, -- Enables/disables the "last session" feature
  auto_session_use_git_branch = vim.g.auto_session_use_git_branch or false, -- Include git branch name in session name
  auto_restore_lazy_delay_enabled = true, -- Enables/disables Lazy delay feature
  log_level = vim.g.auto_session_log_level or AutoSession.conf.log_level or AutoSession.conf.log_level or "error", -- Sets the log level of the plugin (debug, info, error). camelCase logLevel for compatibility.
}

---Lua Only Configs for Auto Session
---@class luaOnlyConf
---@field cwd_change_handling? boolean|CwdChangeHandling
---@field bypass_session_save_file_types? table List of file types to bypass auto save when the only buffer open is one of the file types listed
---@field close_unsupported_windows? boolean Whether to close windows that aren't backed by a real file
---@field silent_restore? boolean Suppress extraneous messages and source the whole session, even if there's an error. Set to false to get the line number of a restore error
---@field log_level? string|integer "debug", "info", "warn", "error" or vim.log.levels.DEBUG, vim.log.levels.INFO, vim.log.levels.WARN, vim.log.levels.ERROR
---Argv Handling
---@field args_allow_single_directory? boolean Follow normal sesion save/load logic if launched with a single directory as the only argument
---@field args_allow_files_auto_save? boolean|function Allow saving a session even when launched with a file argument (or multiple files/dirs). It does not load any existing session first. While you can just set this to true, you probably want to set it to a function that decides when to save a session when launched with file args. See documentation for more detail
---@field session_lens? session_lens_config Session lens configuration options

local luaOnlyConf = {
  bypass_session_save_file_types = nil, -- Bypass auto save when only buffer open is one of these file types
  close_unsupported_windows = true, -- Close windows that aren't backed by normal file
  args_allow_single_directory = true, -- Allow single directory arguments by default
  args_allow_files_auto_save = false, -- Don't save session for file args by default
  ---CWD Change Handling Config
  ---@class CwdChangeHandling
  ---@field restore_upcoming_session boolean {true} restore session for upcoming cwd on cwd change
  ---@field pre_cwd_changed_hook? boolean {true} This is called after auto_session code runs for the DirChangedPre autocmd
  ---@field post_cwd_changed_hook? boolean {true} This is called after auto_session code runs for the DirChanged autocmd

  ---@type boolean|CwdChangeHandling this config can also be set to `false` to disable cwd change handling altogether.
  ---Can also be set to a table with any of the following keys:
  --- {
  ---   restore_upcoming_session = true,
  ---   pre_cwd_changed_hook = nil, -- lua function hook. This is called after auto_session code runs for the `DirChangedPre` autocmd
  ---   post_cwd_changed_hook = nil, -- lua function hook. This is called after auto_session code runs for the `DirChanged` autocmd
  --- }
  cwd_change_handling = false,
  ---Session Control Config
  ---@class session_control
  ---@field control_dir string
  ---@field control_filename string

  ---@type session_lens_config
  session_lens = {
    buftypes_to_ignore = {}, -- list of bufftypes to ignore when switching between sessions
    load_on_setup = true,
    session_control = {
      control_dir = vim.fn.stdpath "data" .. "/auto_session/", -- Auto session control dir, for control files, like alternating between two sessions with session-lens
      control_filename = "session_control.json", -- File name of the session control file
    },
  },
  silent_restore = true, --  Suppress extraneous messages and source the whole session, even if there's an error. Set to false to get the line number of a restore error
}

-- Set default config on plugin load
AutoSession.conf = vim.tbl_deep_extend("force", defaultConf, luaOnlyConf)

-- Pass configs to Lib
Lib.conf = {
  log_level = AutoSession.conf.log_level,
}

local function check_config()
  if not vim.tbl_contains(vim.split(vim.o.sessionoptions, ","), "localoptions") then
    Lib.logger.warn "vim.o.sessionoptions is missing localoptions. \nUse `:checkhealth autosession` for more info."
  end
end

---Setup function for AutoSession
---@param config defaultConf|nil Config for auto session
function AutoSession.setup(config)
  AutoSession.conf = vim.tbl_deep_extend("force", AutoSession.conf, config or {})
  Lib.setup(AutoSession.conf)
  Lib.logger.debug("Config at start of setup", { conf = AutoSession.conf })

  -- Validate the root dir here so AutoSession.conf.auto_session_root_dir is set
  -- correctly in all cases
  AutoSession.get_root_dir()

  check_config()

  if AutoSession.conf.session_lens.load_on_setup then
    Lib.logger.debug "Loading session lens on setup"
    AutoSession.setup_session_lens()
  end

  AutoCmds.setup_autocmds(AutoSession.conf, AutoSession)

  SetupAutocmds()
end

---@private
---Make sure session_lens is setup. Ok to call multiple times
function AutoSession.setup_session_lens()
  if AutoSession.session_lens then
    return true
  end

  local has_telescope, telescope = pcall(require, "telescope")

  if not has_telescope then
    Lib.logger.info "Telescope.nvim is not installed. Session Lens cannot be setup!"
    return false
  end

  AutoSession.session_lens = require "auto-session.session-lens"
  AutoSession.session_lens.setup()
  -- Register session-lens as an extension so :Telescope will complete on session-lens
  telescope.load_extension "session-lens"
  return true
end

local function is_enabled()
  if vim.g.auto_session_enabled ~= nil then
    return vim.g.auto_session_enabled == Lib._VIM_TRUE
  elseif AutoSession.conf.auto_session_enabled ~= nil then
    return AutoSession.conf.auto_session_enabled
  end

  return true
end

local function is_allowed_dirs_enabled()
  local enabled = false

  if vim.g.auto_session_allowed_dirs ~= nil then
    enabled = not vim.tbl_isempty(vim.g.auto_session_allowed_dirs)
  else
    enabled = not vim.tbl_isempty(AutoSession.conf.auto_session_allowed_dirs or {})
  end

  Lib.logger.debug("is_allowed_dirs_enabled", enabled)
  return enabled
end

local function is_auto_create_enabled()
  if vim.g.auto_session_create_enabled ~= nil then
    if type(vim.g.auto_session_create_enabled) == "function" then
      if vim.g.auto_session_create_enabled() then
        Lib.logger.debug "vim.g.auto_session_create_enabled returned true, allowing creation"
        return true
      else
        Lib.logger.debug "vim.g.auto_session_create_enabled returned false, not allowing creation"
        return false
      end
    else
      return vim.g.auto_session_create_enabled == Lib._VIM_TRUE
    end
  end

  if AutoSession.conf.auto_session_create_enabled ~= nil then
    if type(AutoSession.conf.auto_session_create_enabled) == "function" then
      if AutoSession.conf.auto_session_create_enabled() then
        Lib.logger.debug "AutoSession.conf.auto_session_create_enabled returned true, allowing creation"
        return true
      else
        Lib.logger.debug "AutoSession.conf.auto_session_create_enabled returned false, not allowing creation"
        return false
      end
    else
      return AutoSession.conf.auto_session_create_enabled
    end
  end

  return true
end

-- get the current git branch name, if any, and only if configured to do so
local function get_git_branch_name()
  if AutoSession.conf.auto_session_use_git_branch then
    -- WARN: this assumes you want the branch of the cwd
    local out = vim.fn.systemlist "git rev-parse --abbrev-ref HEAD"
    if vim.v.shell_error ~= 0 then
      Lib.logger.debug(string.format("git failed with: %s", table.concat(out, "\n")))
      return ""
    end
    return out[1]
  end

  return ""
end

local in_pager_mode = function()
  return vim.g.in_pager_mode == Lib._VIM_TRUE
end

---Tracks the arguments nvim was launched with. Will be set to nil if a session is restored
local launch_argv = nil

---Returns whether Auto restoring / saving is enabled for the args nvim was launched with
---@param is_save boolean Is this being called during saving or restoring
---@return boolean Whether to allow saving/restoring
local function enabled_for_command_line_argv(is_save)
  is_save = is_save or false

  -- If no args (or launch_argv has been unset, allow restoring/saving)
  if not launch_argv then
    Lib.logger.debug "launch_argv is nil, saving/restoring enabled"
    return true
  end

  local argc = #launch_argv

  Lib.logger.debug("enabled_for_command_line_argv, launch_argv: " .. vim.inspect(launch_argv))

  if argc == 0 then
    -- Launched with no args, saving is enabled
    Lib.logger.debug "No arguments, saving/restoring enabled"
    return true
  end

  -- if conf.args_allow_single_directory = true, then enable session handling if only param is a directory
  if
    argc == 1
    and vim.fn.isdirectory(launch_argv[1]) == Lib._VIM_TRUE
    and AutoSession.conf.args_allow_single_directory
  then
    -- Actual session will be loaded in auto_restore_session_at_vim_enter
    Lib.logger.debug("Allowing restore when launched with a single directory argument: " .. launch_argv[1])
    return true
  end

  if not AutoSession.conf.args_allow_files_auto_save then
    Lib.logger.debug "args_allow_files_auto_save is false, not enabling restoring/saving"
    return false
  end

  if not is_save then
    Lib.logger.debug "Not allowing restore when launched with argument"
    return false
  end

  if type(AutoSession.conf.args_allow_files_auto_save) == "function" then
    local ret = AutoSession.conf.args_allow_files_auto_save()
    Lib.logger.debug("conf.args_allow_files_auto_save() returned: " .. vim.inspect(ret))
    return ret
  end

  Lib.logger.debug "Allowing possible save when launched with argument"
  return true
end

local in_headless_mode = function()
  -- Allow testing in headless mode
  -- In theory, we could mock out vim.api.nvim_list_uis but that was causing
  -- downstream issues with nvim_list_wins
  if vim.env.AUTOSESSION_UNIT_TESTING then
    return false
  end

  return not vim.tbl_contains(vim.v.argv, "--embed") and not next(vim.api.nvim_list_uis())
end

local auto_save = function()
  if in_pager_mode() or in_headless_mode() or not enabled_for_command_line_argv(true) then
    Lib.logger.debug "auto_save, pager, headless, or enabled_for_command_line_argv returned false"
    return false
  end

  if vim.g.auto_save_enabled ~= nil then
    return vim.g.auto_save_enabled == Lib._VIM_TRUE
  end

  return AutoSession.conf.auto_save_enabled
end

local auto_restore = function()
  if in_pager_mode() or in_headless_mode() or not enabled_for_command_line_argv(false) then
    return false
  end

  if vim.g.auto_restore_enabled ~= nil then
    return vim.g.auto_restore_enabled == Lib._VIM_TRUE
  end

  return AutoSession.conf.auto_restore_enabled
end

local function bypass_save_by_filetype()
  local file_types_to_bypass = AutoSession.conf.bypass_session_save_file_types or {}
  local windows = vim.api.nvim_list_wins()

  for _, current_window in ipairs(windows) do
    local buf = vim.api.nvim_win_get_buf(current_window)

    -- Deprecated as 0.9.0, should update to following when we only want to support 0.9.0+
    -- local buf_ft = vim.bo[buf].filetype
    local buf_ft = vim.api.nvim_buf_get_option(buf, "filetype")

    local local_return = false
    for _, ft_to_bypass in ipairs(file_types_to_bypass) do
      if buf_ft == ft_to_bypass then
        local_return = true
        break
      end
    end

    if local_return == false then
      Lib.logger.debug "bypass_save_by_filetype: false"
      return false
    end
  end

  Lib.logger.debug "bypass_save_by_filetype: true"
  return true
end

local function suppress_session(session_dir)
  local dirs = vim.g.auto_session_suppress_dirs or AutoSession.conf.auto_session_suppress_dirs or {}

  -- If session_dir is set, use that otherwise use cwd
  -- session_dir will be set when loading a session from a directory at lauch (i.e. from argv)
  local cwd = session_dir or vim.fn.getcwd()

  if Lib.find_matching_directory(cwd, dirs) then
    Lib.logger.debug "suppress_session found a match, suppressing"
    return true
  end

  Lib.logger.debug "suppress_session didn't find a match, returning false"
  return false
end

local function is_allowed_dir()
  if not is_allowed_dirs_enabled() then
    return true
  end

  local dirs = vim.g.auto_session_allowed_dirs or AutoSession.conf.auto_session_allowed_dirs or {}
  local cwd = vim.fn.getcwd()

  if Lib.find_matching_directory(cwd, dirs) then
    Lib.logger.debug "is_allowed_dir found a match, allowing"
    return true
  end

  Lib.logger.debug "is_allowed_dir didn't find a match, returning false"
  return false
end

---Gets the file name for a session name.
---If no filename is passed it, will generate one using the cwd and, if enabled, the git
---branchname.
---@param session_name string|nil The session name to use or nil
---@param legacy? boolean Generate a legacy filename (default: false)
---@return string Returns the escaped version of the name with .vim appended.
local function get_session_file_name(session_name, legacy)
  if not session_name or session_name == "" then
    session_name = vim.fn.getcwd()
    Lib.logger.debug("get_session_file_name no session_name, using cwd: " .. session_name)

    local git_branch_name = get_git_branch_name()
    if git_branch_name and git_branch_name ~= "" then
      -- NOTE: By including it in the session name, there's the possibility of a collision
      -- with an actual directory named session_name|branch_name. Meaning, that if someone
      -- created a session in session_name (while branch_name is checked out) and then also
      -- went to edit in a directory literally called session_name|branch_name. the sessions
      -- would collide. Obviously, that's not perfect but I think it's an ok price to pay to
      -- get branch specific sessions and still have a cwd derived text key to identify sessions
      -- that can be used everywhere, incuding :SessionRestore
      if legacy then
        session_name = session_name .. "_" .. git_branch_name
      else
        -- now that we're percent encoding, we can pick a less likely character, even if it doesn't
        -- avoid the problem entirely
        session_name = session_name .. "|" .. git_branch_name
      end
    end
  end

  local escaped_session_name
  if legacy then
    escaped_session_name = Lib.legacy_escape_session_name(session_name)
  else
    escaped_session_name = Lib.escape_session_name(session_name)
  end

  -- Always add extension to session name
  escaped_session_name = escaped_session_name .. ".vim"

  return escaped_session_name
end

local function auto_save_conditions_met()
  if not is_enabled() then
    Lib.logger.debug "auto_save_conditions_met: is_enabled() is false, returning false"
    return false
  end

  if not auto_save() then
    Lib.logger.debug "auto_save_conditions_met: auto_save() is false, returning false"
    return false
  end

  if suppress_session() then
    Lib.logger.debug "auto_save_conditions_met: suppress_session() is true, returning false"
    return false
  end

  if not is_allowed_dir() then
    Lib.logger.debug "auto_save_conditions_met: is_allowed_dir() is false, returning false"
    return false
  end

  if bypass_save_by_filetype() then
    Lib.logger.debug "auto_save_conditions_met: bypass_save_by_filetype() is true, returning false"
    return false
  end

  Lib.logger.debug "auto_save_conditions_met: returning true"
  return true
end

---Quickly checks if a session file exists for the current working directory.
---This is useful for starter plugins which don't want to display 'restore session'
---unless a session for the current working directory exists.
---@return boolean True if a session exists for the cwd
function AutoSession.session_exists_for_cwd()
  local session_file = get_session_file_name(vim.fn.getcwd())
  if vim.fn.filereadable(AutoSession.get_root_dir() .. session_file) ~= 0 then
    return true
  end

  -- Check legacy sessions
  local session_file = get_session_file_name(vim.fn.getcwd(), true)
  return vim.fn.filereadable(AutoSession.get_root_dir() .. session_file) ~= 0
end

---AutoSaveSession
---Function called by auto_session to trigger auto_saving sessions, for example on VimExit events.
---@return boolean True if a session was saved
function AutoSession.AutoSaveSession()
  if not auto_save_conditions_met() then
    Lib.logger.debug "Auto save conditions not met"
    return false
  end

  if not is_auto_create_enabled() then
    local session_file_name = get_session_file_name()
    if vim.fn.filereadable(AutoSession.get_root_dir() .. session_file_name) == 0 then
      Lib.logger.debug "Create not enabled and no existing session, not creating session"
      return false
    end
  end

  if AutoSession.conf.close_unsupported_windows then
    -- Wrap in pcall in case there's an error while trying to close windows
    local success, result = pcall(Lib.close_unsupported_windows)
    if not success then
      Lib.logger.debug("Error closing unsupported windows: " .. result)
    end
  end

  -- Don't try to show a message as we're exiting
  return AutoSession.SaveSession(nil, false)
end

---@private
---Gets the root directory of where to save the sessions.
---By default this resolves to `vim.fn.stdpath "data" .. "/sessions/"`
---@param with_trailing_separator? boolean whether to incude the trailing separator. A few places (telescope picker don't expect a trailing separator) (Defaults to true)
---@return string
function AutoSession.get_root_dir(with_trailing_separator)
  if with_trailing_separator == nil then
    with_trailing_separator = true
  end

  if not AutoSession.validated then
    local root_dir = vim.g["auto_session_root_dir"] or AutoSession.conf.auto_session_root_dir

    AutoSession.conf.auto_session_root_dir = Lib.validate_root_dir(root_dir)
    Lib.logger.debug("Root dir set to: " .. AutoSession.conf.auto_session_root_dir)
    AutoSession.validated = true
  end

  if with_trailing_separator then
    return AutoSession.conf.auto_session_root_dir
  end

  return Lib.remove_trailing_separator(AutoSession.conf.auto_session_root_dir)
end

---@private
---Get the hook commands to run
---This function gets cmds from both lua and vimscript configs
---@param typ string
---@return function[]|string[]
function AutoSession.get_cmds(typ)
  return AutoSession.conf[typ .. "_cmds"] or vim.g["auto_session_" .. typ .. "_cmds"]
end

---Calls a hook to get any user/extra commands and if any, saves them to *x.vim
---@param session_path string The path of the session file to save the extra params for
---@return boolean Returns whether extra commands were saved
local function save_extra_cmds_new(session_path)
  local extra_cmds = AutoSession.get_cmds "save_extra"
  if not extra_cmds then
    return false
  end

  local data = run_hook_cmds(extra_cmds, "save-extra")
  if not data then
    return false
  end

  local extra_file = string.gsub(session_path, "%.vim$", "x.vim")
  if vim.fn.writefile(data, extra_file) ~= 0 then
    return false
  end

  return true
end

---@private
---@class PickerItem
---@field session_name string
---@field display_name string
---@field path string

---@return PickerItem[]
local function get_session_files()
  local files = {}
  local sessions_dir = AutoSession.get_root_dir()

  if vim.fn.isdirectory(sessions_dir) == Lib._VIM_FALSE then
    return files
  end

  local entries = vim.fn.readdir(sessions_dir, function(item)
    return Lib.is_session_file(sessions_dir .. item)
  end)

  return vim.tbl_map(function(file_name)
    --  sessions_dir is guaranteed to have a trailing separator so don't need to add another one here
    local session_name
    local display_name
    if Lib.is_legacy_file_name(file_name) then
      session_name = (Lib.legacy_unescape_session_name(file_name):gsub("%.vim$", ""))
      display_name = session_name .. " (legacy)"
    else
      session_name = Lib.escaped_session_name_to_session_name(file_name)
      display_name = Lib.get_session_display_name(file_name)
    end

    return {
      session_name = session_name,
      display_name = display_name,
      path = sessions_dir .. file_name,
    }
  end, entries)
end

---@param files string[]
---@param prompt string
---@param callback fun(choice: PickerItem)
local function open_picker(files, prompt, callback)
  vim.ui.select(files, {
    prompt = prompt,
    kind = "auto-session",
    format_item = function(item)
      return item.display_name
    end,
  }, function(choice)
    if choice then
      callback(choice)
    end
  end)
end

---@param data table
local function handle_autosession_command(data)
  local files = get_session_files()
  if data.args:match "search" then
    open_picker(files, "Select a session:", function(choice)
      AutoSession.autosave_and_restore(choice.session_name)
    end)
  elseif data.args:match "delete" then
    open_picker(files, "Delete a session:", function(choice)
      AutoSession.DeleteSessionFile(choice.path, choice.display_name)
    end)
  end
end

---@private
---Handler for when a session is picked from the UI, either via Telescope or via AutoSession.select_session
---Save the current session (if autosave allows) and restore the selected session
---@param session_name string The session name to restore
---@return boolean Was the session restored successfully
function AutoSession.autosave_and_restore(session_name)
  AutoSession.AutoSaveSession()
  return AutoSession.RestoreSession(session_name)
end

local function write_to_session_control_json(session_file_name)
  local control_dir = AutoSession.conf.session_lens.session_control.control_dir
  local control_file = AutoSession.conf.session_lens.session_control.control_filename
  session_file_name = Lib.expand(session_file_name)

  -- expand the path
  control_dir = vim.fn.expand(control_dir)
  Lib.init_dir(control_dir)

  -- Get the full path
  local session_control_file_path = control_dir .. control_file

  -- Load existing data, if it exists
  local session_control = Lib.load_session_control_file(session_control_file_path)
  Lib.logger.debug("Loaded session control data: ", session_control)

  -- If there's existing data
  if session_control.current then
    if session_control.current == session_file_name then
      Lib.logger.debug(
        "Not writing to session control file, current is same as session_file_name: " .. session_file_name
      )
      return
    end
    session_control.alternate = session_control.current
  end

  session_control.current = session_file_name

  Lib.logger.debug("Saving session control", session_control)

  local json_to_save = vim.json.encode(session_control)

  vim.fn.writefile({ json_to_save }, session_control_file_path)
end

---Function called by AutoSession when automatically restoring a session.
---@param session_name? string An optional session to load
---@return boolean boolean returns whether restoring the session was successful or not.
function AutoSession.AutoRestoreSession(session_name)
  -- WARN: should this be checking is_allowed_dir as well?
  if not is_enabled() or not auto_restore() or suppress_session(session_name) then
    return false
  end

  return AutoSession.RestoreSession(session_name, false)
end

---Called at VimEnter (after Lazy is done) to see if we should automatically restore a session
---If launched with a single directory parameter and conf.args_allow_single_directory is true, pass
---that in as the session_dir. Handles both 'nvim .' and 'nvim some/dir'
---Also make sure to call no_restore if no session was restored
---@return boolean Was a session restored
local function auto_restore_session_at_vim_enter()
  -- Save the launch args here as restoring a session will replace vim.fn.argv. We clear
  -- launch_argv in restore session so it's only used for the session launched from the command
  -- line
  launch_argv = vim.fn.argv()

  -- Is there exactly one argument and is it a directory?
  if
    AutoSession.conf.args_allow_single_directory
    and #launch_argv == 1
    and vim.fn.isdirectory(launch_argv[1]) == Lib._VIM_TRUE
  then
    -- Get the full path of the directory and make sure it doesn't have a trailing path_separator
    -- to make sure we find the session
    local session_name = Lib.remove_trailing_separator(vim.fn.fnamemodify(launch_argv[1], ":p"))
    Lib.logger.debug("Launched with single directory, using as session_dir: " .. session_name)

    if AutoSession.AutoRestoreSession(session_name) then
      return true
    end

    -- We failed to load a session for the other directory. Unless session name matches cwd, we don't
    -- want to enable autosaving since it might replace the session for the cwd
    if vim.fn.getcwd() ~= session_name then
      Lib.logger.debug "Not enabling autosave because launch argument didn't load session and doesn't match cwd"
      AutoSession.conf.auto_save_enabled = false
    end
  else
    if AutoSession.AutoRestoreSession() then
      return true
    end

    -- Check to see if the last session feature is on
    if AutoSession.conf.auto_session_enable_last_session then
      Lib.logger.debug "Last session is enabled, checking for session"

      local last_session_name = Lib.get_latest_session(AutoSession.get_root_dir())
      if last_session_name then
        Lib.logger.debug("Found last session: " .. last_session_name)
        if AutoSession.RestoreSession(last_session_name, false) then
          return true
        end
      end
      Lib.logger.debug "Failed to load last session"
    end
  end

  -- No session was restored, dispatch no-restore hook
  local no_restore_cmds = AutoSession.get_cmds "no_restore"
  Lib.logger.debug "No session restored, call no_restore hooks"
  run_hook_cmds(no_restore_cmds, "no-restore")

  return false
end

-- If we're unit testing, we need this entry point since the test harness loads our tests after
-- VimEnter has been called
if vim.env.AUTOSESSION_UNIT_TESTING then
  AutoSession.auto_restore_session_at_vim_enter = auto_restore_session_at_vim_enter
end

---Calls lib function for completeing session names with session dir
local function complete_session(ArgLead, CmdLine, CursorPos)
  return Lib.complete_session_for_dir(AutoSession.get_root_dir(), ArgLead, CmdLine, CursorPos)
end

--- Deletes sessions where the original directory no longer exists
function AutoSession.PurgeOrphanedSessions()
  local orphaned_sessions = {}

  for _, session in ipairs(get_session_files()) do
    if
      not Lib.is_named_session(session.session_name) and vim.fn.isdirectory(session.session_name) == Lib._VIM_FALSE
    then
      Lib.logger.debug("purge: " .. session.session_name)
      table.insert(orphaned_sessions, session.session_name)
    end
  end

  if Lib.is_empty_table(orphaned_sessions) then
    Lib.logger.info "Nothing to purge"
    return
  end

  for _, session_name in ipairs(orphaned_sessions) do
    Lib.logger.info("Purging: ", session_name)
    local escaped_session = Lib.escape_session_name(session_name)
    local session_path = string.format("%s/%s.vim", AutoSession.get_root_dir(), escaped_session)
    Lib.logger.debug("purging: " .. session_path)
    vim.fn.delete(Lib.expand(session_path))
  end
end

---Saves a session to the dir specified in the config. If no optional
---session name is passed in, it uses the cwd as the session name
---@param session_name? string|nil Optional session name
---@param show_message? boolean Optional, whether to show a message on save (true by default)
---@return boolean
function AutoSession.SaveSession(session_name, show_message)
  return AutoSession.SaveSessionToDir(AutoSession.get_root_dir(), session_name, show_message)
end

---Saves a session to the passed in directory. If no optional
---session name is passed in, it uses the cwd as the session name
---@param session_dir string Directory to write the session file to
---@param session_name? string|nil Optional session name
---@param show_message? boolean Optional, whether to show a message on save (true by default)
---@return boolean
function AutoSession.SaveSessionToDir(session_dir, session_name, show_message)
  Lib.logger.debug("SaveSessionToDir start", { session_dir, session_name, show_message })

  -- Canonicalize and create session_dir if needed
  session_dir = Lib.validate_root_dir(session_dir)
  Lib.logger.debug("SaveSessionToDir validated session_dir: ", session_dir)

  local escaped_session_name = get_session_file_name(session_name)

  Lib.logger.debug("SaveSessionToDir escaped session name: " .. escaped_session_name)

  local session_path = session_dir .. escaped_session_name

  local pre_cmds = AutoSession.get_cmds "pre_save"
  run_hook_cmds(pre_cmds, "pre-save")

  -- We don't want to save arguments to the session as that can cause issues
  -- with buffers that can't be removed from the session as they keep being
  -- added back through an argadd
  vim.cmd "%argdelete"

  Lib.logger.debug("SaveSessionToDir writing session to: " .. session_path)

  -- Vim cmds require escaping any % with a \ but we don't want to do that
  -- for direct filesystem operations (like in save_extra_cmds_new) so we
  -- that here, as late as possible and only for this operation
  local vim_session_path = Lib.escape_string_for_vim(session_path)
  vim.cmd("mks! " .. vim_session_path)

  save_extra_cmds_new(session_path)

  local post_cmds = AutoSession.get_cmds "post_save"
  run_hook_cmds(post_cmds, "post-save")

  -- session_name might be nil (e.g. when using cwd), unescape escaped_session_name instead
  Lib.logger.debug("Saved session: " .. Lib.unescape_session_name(escaped_session_name))
  if show_message == nil or show_message then
    vim.notify("Saved session: " .. Lib.get_session_display_name(escaped_session_name))
  end

  return true
end

---Restores a session from the passed in directory. If no optional session name
---is passed in, it uses the cwd as the session name
---@param session_name? string|nil Optional session name
---@param show_message? boolean Optional, whether to show a message on restore (true by default)
function AutoSession.RestoreSession(session_name, show_message)
  return AutoSession.RestoreSessionFromDir(AutoSession.get_root_dir(), session_name, show_message)
end

---Restores a session from the passed in directory. If no optional session name
---is passed in, it uses the cwd as the session name
---@param session_dir string Directory to write the session file to
---@param session_name? string|nil Optional session name
---@param show_message? boolean Optional, whether to show a message on restore (true by default)
function AutoSession.RestoreSessionFromDir(session_dir, session_name, show_message)
  Lib.logger.debug("RestoreSessionFromDir start", { session_dir, session_name })
  -- Canonicalize and create session_dir if needed
  session_dir = Lib.validate_root_dir(session_dir)
  Lib.logger.debug("RestoreSessionFromDir validated session_dir: ", session_dir)

  local escaped_session_name = get_session_file_name(session_name)

  Lib.logger.debug("RestoreSessionFromDir escaped session name: " .. escaped_session_name)

  local session_path = session_dir .. escaped_session_name

  if vim.fn.filereadable(session_path) ~= 1 then
    Lib.logger.debug("RestoreSessionFromDir session does not exist: " .. session_path)

    -- NOTE: This won't work for legacy window session names containing dashes because
    -- information was lost (i.e. was the dash part of the original parth or was it
    -- a parth separator).
    local legacy_escaped_session_name = get_session_file_name(session_name, true)
    local legacy_session_path = session_dir .. legacy_escaped_session_name

    if vim.fn.filereadable(legacy_session_path) ~= 1 then
      if show_message == nil or show_message then
        vim.notify("Could not restore session: " .. Lib.get_session_display_name(escaped_session_name))
      end
      return false
    end

    Lib.logger.debug("RestoreSessionFromDir renaming legacy session: " .. legacy_escaped_session_name)
    ---@diagnostic disable-next-line: undefined-field
    if not vim.loop.fs_rename(legacy_session_path, session_path) then
      Lib.logger.debug(
        "RestoreSessionFromDir rename failed!",
        { session_path = session_path, legacy_session_path = legacy_session_path }
      )
      return false
    end

    -- Check for user commands
    local legacy_user_commands_path = legacy_session_path:gsub("%.vim", "x.vim")
    local user_commands_path = session_path:gsub("%.vim", "x.vim")

    -- If there is a legacy commands file and it's not actually a session and there is already a user commands file,
    -- then migrate
    if vim.fn.filereadable(legacy_user_commands_path) == 1 and not Lib.is_session_file(legacy_user_commands_path) then
      if vim.fn.filereadable(user_commands_path) == 0 then
        Lib.logger.debug("RestoreSessionFromDir Renaming legacy user commands" .. legacy_user_commands_path)
        vim.loop.fs_rename(legacy_user_commands_path, user_commands_path)
      end
    end
  end

  return AutoSession.RestoreSessionFile(session_path, show_message)
end

---Restores a session from a specific file
---@param session_path string The session file to load
---@param show_message? boolean Optional, whether to show a message on restore (true by default)
---@return boolean Was a session restored
function AutoSession.RestoreSessionFile(session_path, show_message)
  local pre_cmds = AutoSession.get_cmds "pre_restore"
  run_hook_cmds(pre_cmds, "pre-restore")

  Lib.logger.debug("RestoreSessionFile restoring session from: " .. session_path)

  -- Vim cmds require escaping any % with a \ but we don't want to do that
  -- for direct filesystem operations (like in save_extra_cmds_new) so we
  -- that here, as late as possible and only for this operation
  local vim_session_path = Lib.escape_string_for_vim(session_path)
  local cmd = "source " .. vim_session_path

  if AutoSession.conf.silent_restore then
    cmd = "silent! " .. cmd
    -- clear errors here so we can
    vim.v.errmsg = ""
  end

  -- Set restore_in_progress here so we won't also try to save/load the session if
  -- cwd_change_handling = true and the session contains a cd command
  -- The session file will also set SessionLoad so we'll check that too but feels
  -- safer to have our own flag as well, in case the vim flag changes
  AutoSession.restore_in_progress = true

  -- Clear the buffers and jumps
  vim.cmd "%bw!"
  vim.cmd "clearjumps"

  ---@diagnostic disable-next-line: param-type-mismatch
  local success, result = pcall(vim.cmd, cmd)
  AutoSession.restore_in_progress = false

  -- Clear any saved command line args since we don't need them anymore
  launch_argv = nil

  if AutoSession.conf.silent_restore and vim.v.errmsg and vim.v.errmsg ~= "" then
    -- we had an error while sourcing silently so surface it
    success = false
    result = vim.v.errmsg
  end

  if not success then
    Lib.logger.error([[
Error restoring session, disabling auto save.
Set silent_restore = false in the config for a more detailed error message.
Error: ]] .. result)
    AutoSession.conf.auto_save_enabled = false
    return false
  end

  local session_name = Lib.escaped_session_name_to_session_name(vim.fn.fnamemodify(session_path, ":t"))
  Lib.logger.debug("Restored session: " .. session_name)
  if show_message == nil or show_message then
    vim.notify("Restored session: " .. session_name)
  end

  local post_cmds = AutoSession.get_cmds "post_restore"
  run_hook_cmds(post_cmds, "post-restore")

  write_to_session_control_json(session_path)
  return true
end

---Deletes a session from the config session dir. If no optional session name
---is passed in, it uses the cwd as the session name
---@param session_name? string|nil Optional session name
function AutoSession.DeleteSession(session_name)
  return AutoSession.DeleteSessionFromDir(AutoSession.get_root_dir(), session_name)
end

---Deletes a session from the passed in directory. If no optional session
---name is passed in, it uses the cwd as the session name
---@param session_dir string Directory to delete the session from
---@param session_name? string|nil Optional session name
function AutoSession.DeleteSessionFromDir(session_dir, session_name)
  Lib.logger.debug("DeleteSessionFromDir start", { session_dir, session_name })

  -- Canonicalize and create session_dir if needed
  session_dir = Lib.validate_root_dir(session_dir)
  Lib.logger.debug("DeleteSessionFromDir validated session_dir ", session_dir)

  local escaped_session_name = get_session_file_name(session_name)

  Lib.logger.debug("DeleteSessionFromDir escaped session name: " .. escaped_session_name)

  local session_path = session_dir .. escaped_session_name

  if vim.fn.filereadable(session_path) ~= 1 then
    Lib.logger.debug("DeleteSessionFromDir session does not exist: " .. session_path)

    -- Check for a legacy session to delete
    local legacy_escaped_session_name = get_session_file_name(session_name, true)
    local legacy_session_path = session_dir .. legacy_escaped_session_name

    if vim.fn.filereadable(legacy_session_path) ~= 1 then
      vim.notify("Session does not exist: " .. Lib.get_session_display_name(escaped_session_name))
      return false
    end
    Lib.logger.debug("DeleteSessionFromDir using legacy session: " .. legacy_escaped_session_name)
    session_path = legacy_session_path
  end

  -- session_name could be nil, so get name from escaped_session_name
  return AutoSession.DeleteSessionFile(session_path, Lib.get_session_display_name(escaped_session_name))
end

---Delete a session file
---@param session_path string The filename to delete
---@param session_name string Session name being deleted, just use to display messages
---@return boolean Was the session file delted
function AutoSession.DeleteSessionFile(session_path, session_name)
  local pre_cmds = AutoSession.get_cmds "pre_delete"
  run_hook_cmds(pre_cmds, "pre-delete")

  Lib.logger.debug("DeleteSessionFile deleting: " .. session_path)

  local result = vim.fn.delete(Lib.expand(session_path)) == 0

  if not result then
    Lib.logger.error("DeleteSessionFile Failed to delete session: " .. session_name)
  else
    if vim.fn.fnamemodify(vim.v.this_session, ":t") == vim.fn.fnamemodify(session_path, ":t") then
      -- session_name might be nil (e.g. when using cwd), unescape escaped_session_name instead
      Lib.logger.info("Auto saving disabled because the current session was deleted: " .. session_name)
      vim.v.this_session = ""
      AutoSession.conf.auto_save_enabled = false
    else
      Lib.logger.debug("DeleteSessionFile Session deleted: " .. session_name)
      vim.notify("Session deleted: " .. session_name)
    end
  end

  -- check for extra user commands
  local extra_commands_path = session_path:gsub("%.vim$", "x.vim")
  if vim.fn.filereadable(extra_commands_path) == 1 and not Lib.is_session_file(extra_commands_path) then
    vim.fn.delete(extra_commands_path)
    Lib.logger.debug("DeleteSessionFile deleting extra user commands: " .. extra_commands_path)
  end

  local post_cmds = AutoSession.get_cmds "post_delete"
  run_hook_cmds(post_cmds, "post-delete")
  return result
end

---Disables autosave. Enables autosave if enable is true
---@param enable? boolean Optional paramter to enable autosaving
---@return boolean Whether autosaving is enabled or not
function AutoSession.DisableAutoSave(enable)
  AutoSession.conf.auto_save_enabled = enable or false
  if AutoSession.conf.auto_save_enabled then
    vim.notify "Session auto-save enabled"
  else
    vim.notify "Session auto-save disabled"
  end
  return AutoSession.conf.auto_save_enabled
end

function SetupAutocmds()
  -- Check if the auto-session plugin has already been loaded to prevent loading it twice
  if vim.g.loaded_auto_session ~= nil then
    return
  end

  -- Initialize variables
  vim.g.in_pager_mode = false

  local function SessionPurgeOrphaned()
    return AutoSession.PurgeOrphanedSessions()
  end

  vim.api.nvim_create_user_command("SessionSave", function(args)
    return AutoSession.SaveSession(args.args)
  end, {
    bang = true,
    nargs = "?",
    desc = "Save session using current working directory as the session name or an optional session name",
  })

  vim.api.nvim_create_user_command("SessionRestore", function(args)
    return AutoSession.RestoreSession(args.args)
  end, {
    complete = complete_session,
    bang = true,
    nargs = "?",
    desc = "Restore session using current working directory as the session name or an optional session name",
  })

  vim.api.nvim_create_user_command("SessionDelete", function(args)
    return AutoSession.DeleteSession(args.args)
  end, {
    complete = complete_session,
    bang = true,
    nargs = "*",
    desc = "Delete session using the current working directory as the session name or an optional session name",
  })

  vim.api.nvim_create_user_command("SessionDisableAutoSave", function(args)
    return AutoSession.DisableAutoSave(args.bang)
  end, {
    bang = true,
    desc = "Disable autosave. Enable with a !",
  })

  vim.api.nvim_create_user_command("SessionToggleAutoSave", function()
    return AutoSession.DisableAutoSave(not AutoSession.conf.auto_save_enabled)
  end, {
    bang = true,
    desc = "Toggle autosave",
  })

  vim.api.nvim_create_user_command("SessionSearch", function()
    -- If Telescope is installed, use that otherwise use vim.ui.select
    if AutoSession.setup_session_lens() and AutoSession.session_lens then
      vim.cmd "Telescope session-lens"
      return
    end

    handle_autosession_command { "search" }
  end, {
    desc = "Open a session picker",
  })

  vim.api.nvim_create_user_command("Autosession", handle_autosession_command, {
    complete = function(_, _, _)
      return { "search", "delete" }
    end,
    nargs = 1,
  })

  vim.api.nvim_create_user_command(
    "SessionPurgeOrphaned",
    SessionPurgeOrphaned,
    { desc = "Remove all orphaned sessions with no directory left" }
  )

  local group = vim.api.nvim_create_augroup("auto_session_group", {})

  vim.api.nvim_create_autocmd({ "StdinReadPre" }, {
    group = group,
    pattern = "*",
    callback = function()
      vim.g.in_pager_mode = true
    end,
  })

  -- Used to track the Lazy window if we're delaying loading until it's dismissed
  local lazy_view_win = nil
  vim.api.nvim_create_autocmd({ "VimEnter" }, {
    group = group,
    pattern = "*",
    nested = true,
    callback = function()
      if vim.g.in_pager_mode then
        -- Don't auto restore session in pager mode
        local no_restore_cmds = AutoSession.get_cmds "no_restore"
        Lib.logger.debug("In pager mode, skipping auto restore", no_restore_cmds)
        run_hook_cmds(no_restore_cmds, "no-restore")
        return
      end

      if not AutoSession.conf.auto_restore_lazy_delay_enabled then
        -- If auto_restore_lazy_delay_enabled is false, just restore the session as normal
        auto_restore_session_at_vim_enter()
        return
      end

      -- Not in pager mode, auto_restore_lazy_delay_enabled is true, check for Lazy
      local ok, lazy_view = pcall(require, "lazy.view")
      if not ok then
        -- No Lazy, load as usual
        auto_restore_session_at_vim_enter()
        return
      end

      if not lazy_view.visible() then
        -- Lazy isn't visible, load as usual
        Lib.logger.debug "Lazy is loaded, but not visible, will try to restore session"
        auto_restore_session_at_vim_enter()
        return
      end

      -- If the Lazy window is visibile, hold onto it for later
      lazy_view_win = lazy_view.view.win
      Lib.logger.debug "Lazy window is still visible, waiting for it to close"
    end,
  })

  vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
    group = group,
    pattern = "*",
    callback = function()
      if not vim.g.in_pager_mode then
        AutoSession.AutoSaveSession()
      end
    end,
  })

  -- Set a flag to indicate that the plugin has been loaded
  vim.g.loaded_auto_session = true

  if AutoSession.conf.auto_restore_lazy_delay_enabled then
    -- Helper to delay loading the session if the Lazy.nvim window is open
    vim.api.nvim_create_autocmd("WinClosed", {
      callback = function(event)
        -- If we we're in pager mode or we have no Lazy window, bail out
        if vim.g.in_pager_mode or not lazy_view_win then
          return
        end

        if event.match ~= tostring(lazy_view_win) then
          -- A window was closed, but it wasn't Lazy's window so keep waiting
          Lib.logger.debug "A window was closed but it was not Lazy, keep waiting"
          return
        end

        Lib.logger.debug "Lazy window was closed, restore the session!"

        -- Clear lazy_view_win so we stop processing future WinClosed events
        lazy_view_win = nil
        -- Schedule restoration for the next pass in the event loop to time for the window to close
        -- Not doing this could create a blank buffer in the restored session
        vim.schedule(function()
          auto_restore_session_at_vim_enter()
        end)
      end,
    })
  end
end

return AutoSession
