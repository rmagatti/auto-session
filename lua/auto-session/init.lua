local Lib = require("auto-session.lib")
local Config = require("auto-session.config")

local uv = vim.uv or vim.loop

----------- Setup ----------

---@mod auto-session.api API
local AutoSession = {}

---Tracks the arguments nvim was launched with. Will be set to nil if a session is restored
local launch_argv = nil

---Setup function for AutoSession
---@param config AutoSession.Config|nil Config for auto session
function AutoSession.setup(config)
  Config.setup(config)
  Lib.logger.debug("Config at start of setup", tostring(Config))
  Config.check(Lib.logger)

  -- Validate the root dir here so it's always set up correctly
  AutoSession.get_root_dir()

  -- Set up single session mode if enabled
  if Config.single_session_mode then
    AutoSession.manually_named_session = true
    Lib.logger.debug("Single session mode enabled")
  end

  require("auto-session.autocmds").setup_autocmds()

  -- save argv
  launch_argv = vim.fn.argv()
  Lib.logger.debug("Saving argv at setup: " .. vim.inspect(launch_argv))
end

---Determines the session name based on current state and parameters
---@param legacy? boolean Whether to use legacy session name format
---@param use_cwd? boolean Whether to force using current working directory (ignoring manually named sessions)
---@return string session_name The determined session name for the given parameters and current state
local function get_session_name(legacy, use_cwd)
  -- Sometimes we want to see what the default session name would be for the cwd, so
  -- if this flag is set, we should ignore the manually named session
  if not use_cwd and AutoSession.manually_named_session and vim.v.this_session and vim.v.this_session ~= "" then
    local session_name = Lib.escaped_session_path_to_session_name(vim.v.this_session)
    Lib.logger.debug("get_session_name - manually_named_session is true, session_name: " .. session_name)
    return session_name
  end

  local cwd = vim.fn.getcwd(-1, -1)
  local git_branch_name = Config.git_use_branch_name and Lib.get_git_branch_name(nil, Config.git_use_branch_name) or nil
  local custom_tag = Config.custom_session_tag and Config.custom_session_tag(cwd) or nil

  local session_name = Lib.combine_session_name_with_git_and_tag(cwd, git_branch_name, custom_tag, legacy)
  Lib.logger.debug("get_session_name, session_name: ", session_name)
  return session_name
end

local function is_enabled()
  return Config.enabled
end

local function is_allowed_dirs_enabled()
  return not vim.tbl_isempty(Config.allowed_dirs or {})
end

local function is_auto_create_enabled()
  if type(Config.auto_create) ~= "function" then
    return Config.auto_create
  end

  local result = Config.auto_create()
  Lib.logger.debug("auto_create() returned: ", result)
  return result
end

local in_pager_mode = function()
  return vim.g.in_pager_mode == Lib._VIM_TRUE
end

---Returns whether Auto restoring / saving is enabled for the args nvim was launched with
---@param is_save boolean Is this being called during saving or restoring
---@return boolean Whether to allow saving/restoring
local function enabled_for_command_line_argv(is_save)
  is_save = is_save or false

  -- If no args (or launch_argv has been unset, allow restoring/saving)
  if not launch_argv then
    Lib.logger.debug("launch_argv is nil, saving/restoring enabled")
    return true
  end

  local argc = #launch_argv

  Lib.logger.debug("enabled_for_command_line_argv, launch_argv: " .. vim.inspect(launch_argv))

  if argc == 0 then
    -- Launched with no args, saving is enabled
    Lib.logger.debug("No arguments, saving/restoring enabled")
    return true
  end

  -- if Config.args_allow_single_directory = true, then enable session handling if only param is a directory
  if argc == 1 and vim.fn.isdirectory(launch_argv[1]) == Lib._VIM_TRUE and Config.args_allow_single_directory then
    -- Actual session will be loaded in auto_restore_session_at_vim_enter
    Lib.logger.debug("Allowing restore when launched with a single directory argument: " .. launch_argv[1])
    return true
  end

  if not Config.args_allow_files_auto_save then
    Lib.logger.debug("args_allow_files_auto_save is false, not enabling restoring/saving")
    return false
  end

  if not is_save then
    Lib.logger.debug("Not allowing restore when launched with argument")
    return false
  end

  if type(Config.args_allow_files_auto_save) == "function" then
    local ret = Config.args_allow_files_auto_save()
    Lib.logger.debug("args_allow_files_auto_save() returned: " .. vim.inspect(ret))
    return ret
  end

  Lib.logger.debug("Allowing possible save when launched with argument")
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
    Lib.logger.debug("auto_save, pager, headless, or enabled_for_command_line_argv returned false")
    return false
  end

  return Config.auto_save
end

local auto_restore = function()
  if in_pager_mode() or in_headless_mode() or not enabled_for_command_line_argv(false) then
    return false
  end

  return Config.auto_restore
end

local function bypass_save_by_filetype()
  local filetypes_to_bypass = Config.bypass_save_filetypes or {}
  local windows = vim.api.nvim_list_wins()

  for _, current_window in ipairs(windows) do
    local buf = vim.api.nvim_win_get_buf(current_window)

    local buf_ft = vim.bo[buf].filetype

    local local_return = false
    for _, ft_to_bypass in ipairs(filetypes_to_bypass) do
      if buf_ft == ft_to_bypass then
        local_return = true
        break
      end
    end

    if local_return == false then
      Lib.logger.debug("bypass_save_by_filetype: false")
      return false
    end
  end

  Lib.logger.debug("bypass_save_by_filetype: true")
  return true
end

local function suppress_session(session_dir)
  local dirs = Config.suppressed_dirs or {}

  -- If session_dir is set, use that otherwise use cwd
  -- session_dir will be set when loading a session from a directory at launch (i.e. from argv)
  local cwd = session_dir or vim.fn.getcwd(-1, -1)

  if Lib.find_matching_directory(cwd, dirs) then
    Lib.logger.debug("suppress_session found a match, suppressing")
    return true
  end

  Lib.logger.debug("suppress_session didn't find a match, returning false")
  return false
end

local function is_allowed_dir()
  if not is_allowed_dirs_enabled() then
    return true
  end

  local dirs = Config.allowed_dirs or {}
  local cwd = vim.fn.getcwd(-1, -1)

  if Lib.find_matching_directory(cwd, dirs) then
    Lib.logger.debug("is_allowed_dir found a match, allowing")
    return true
  end

  Lib.logger.debug("is_allowed_dir didn't find a match, returning false")
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
    session_name = get_session_name(legacy, true) -- Use cwd to determine session name
    Lib.logger.debug("get_session_file_name no session_name, using name: " .. session_name)
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
    Lib.logger.debug("auto_save_conditions_met: is_enabled() is false, returning false")
    return false
  end

  if not auto_save() then
    Lib.logger.debug("auto_save_conditions_met: auto_save() is false, returning false")
    return false
  end

  if suppress_session() then
    Lib.logger.debug("auto_save_conditions_met: suppress_session() is true, returning false")
    return false
  end

  if not is_allowed_dir() then
    Lib.logger.debug("auto_save_conditions_met: is_allowed_dir() is false, returning false")
    return false
  end

  if bypass_save_by_filetype() then
    Lib.logger.debug("auto_save_conditions_met: bypass_save_by_filetype() is true, returning false")
    return false
  end

  Lib.logger.debug("auto_save_conditions_met: returning true")
  return true
end

---Quickly checks if a session file exists for the current working directory.
---This is useful for starter plugins which don't want to display 'restore session'
---unless a session for the current working directory exists.
---@return boolean True if a session exists for the cwd
function AutoSession.session_exists_for_cwd()
  local session_file = get_session_file_name(nil)
  if vim.fn.filereadable(AutoSession.get_root_dir() .. session_file) ~= 0 then
    return true
  end

  -- Check legacy sessions
  session_file = get_session_file_name(nil, true)
  return vim.fn.filereadable(AutoSession.get_root_dir() .. session_file) ~= 0
end

---Function called by auto_session to trigger auto_saving sessions, for example on VimExit events.
---@return boolean True if a session was saved
function AutoSession.auto_save_session()
  if not auto_save_conditions_met() then
    Lib.logger.debug("Auto save conditions not met")
    return false
  end

  -- If there's a manually named session, use that on exit instead of one named for cwd
  local current_session = nil

  if AutoSession.manually_named_session then
    current_session = Lib.escaped_session_path_to_session_name(vim.v.this_session)
    Lib.logger.debug("Using existing session name: " .. current_session)
  end

  if not is_auto_create_enabled() then
    local session_file_name = get_session_file_name(current_session)
    if vim.fn.filereadable(AutoSession.get_root_dir() .. session_file_name) == 0 then
      Lib.logger.debug("Create not enabled and no existing session, not creating session")
      return false
    end
  end

  if Config.auto_delete_empty_sessions and Lib.only_blank_buffers_left() then
    -- don't auto-delete the session unless we actually loaded a session
    if vim.v.this_session ~= "" then
      vim.notify("would auto delete")
      AutoSession.delete_session(current_session)
    end
    return false
  end

  if Config.close_unsupported_windows then
    -- Wrap in pcall in case there's an error while trying to close windows
    local success, result = pcall(Lib.close_unsupported_windows)
    if not success then
      Lib.logger.debug("Error closing unsupported windows: " .. result)
    end
  end

  -- Don't try to show a message as we're exiting
  return AutoSession.save_session(current_session, { show_message = false, is_autosave = true })
end

---@private
---Gets the root directory of where to save the sessions.
---By default this resolves to `vim.fn.stdpath "data" .. "/sessions/"`
---@param with_trailing_separator? boolean whether to include the trailing separator. A few places (e.g. telescope picker) don't expect a trailing separator (Defaults to true)
---@return string
function AutoSession.get_root_dir(with_trailing_separator)
  if with_trailing_separator == nil then
    with_trailing_separator = true
  end

  if not AutoSession.validated then
    Config.root_dir = Lib.validate_root_dir(Config.root_dir)
    Lib.logger.debug("Root dir set to: " .. Config.root_dir)
    AutoSession.validated = true
  end

  if with_trailing_separator then
    return Config.root_dir
  end

  return Lib.remove_trailing_separator(Config.root_dir)
end

---@private
---Get the hook commands from the config and run them
---@param hook_name string
---@param arg? any Optional argument for a lua hook function
---@return table|nil Results of the commands
function AutoSession.run_cmds(hook_name, arg)
  local cmds = Config[hook_name .. "_cmds"]
  return Lib.run_hook_cmds(cmds, hook_name, arg)
end

---Calls a hook to get any user/extra commands and if any, saves them to *x.vim
---@param session_path string The path of the session file to save the extra params for
---@param session_name string The name of the session being saved
---@return boolean Returns whether extra commands were saved
local function save_extra_cmds(session_path, session_name)
  local data = AutoSession.run_cmds("save_extra")
  local extra_file = string.gsub(session_path, "%.vim$", "x.vim")

  -- data is a table of strings or tables, one for each hook function
  -- need to combine them all here into a single table of strings
  local data_to_write = Lib.flatten_table_and_split_strings(data)

  -- get any extra data to save
  if Config.save_extra_data then
    local extra_data = Config.save_extra_data(session_name)
    if extra_data then
      local delim = ""
      -- find an escape sequence that's not used by extra_data
      while
        string.find(extra_data, "[" .. delim .. "[", 1, true) or string.find(extra_data, "]" .. delim .. "]", 1, true)
      do
        delim = delim .. "="
      end
      local escaped_extra_data = "[" .. delim .. "[" .. extra_data .. "]" .. delim .. "]"
      table.insert(data_to_write, "lua require('auto-session').restore_extra_data(" .. escaped_extra_data .. ")")
    end
  end

  if not data_to_write or vim.tbl_isempty(data_to_write) then
    -- Have to delete the file just in case there's an old file from a previous save
    vim.fn.delete(extra_file)
    return false
  end

  if vim.fn.writefile(data_to_write, extra_file) ~= 0 then
    return false
  end

  return true
end

---@private
---Restores extra data saved to the extra cmds file. Should only be called by nvim
---when reading the extra cmds file. Should not be called manually
---@param extra_data any
function AutoSession.restore_extra_data(extra_data)
  if Config.restore_extra_data then
    local session_name = Lib.escaped_session_path_to_session_name(vim.v.this_session)
    Config.restore_extra_data(session_name, extra_data)
  end
end

---@private
---Handler for when a session is picked from the UI via a picker
---Save the current session if the session we're loading isn't also for the cwd (if autosave allows)
---and then restore the selected session
---@param session_name string The session name to restore
---@return boolean Was the session restored successfully
function AutoSession.autosave_and_restore(session_name)
  local cwd_session_name = Lib.escaped_session_name_to_session_name(get_session_file_name(nil))
  if cwd_session_name ~= session_name then
    Lib.logger.debug("Autosaving before restoring", { cwd = cwd_session_name, session_name = session_name })
    AutoSession.auto_save_session()
  else
    Lib.logger.debug("Not autosaving, cwd == session_name for: ", session_name)
  end

  return AutoSession.restore_session(session_name)
end

local function write_to_session_control_json(session_file_name)
  local control_dir = Config.session_lens.session_control.control_dir
  local control_file = Config.session_lens.session_control.control_filename
  session_file_name = Lib.expand(session_file_name)

  if not control_dir or not control_file then
    Lib.logger.error("control_dir or control_file are nil", control_dir, control_file)
    return
  end

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

---Function called by AutoSession when automatically restoring a session. Calls
---no_restore only if not in startup mode as startup may try to restore
---several different ways
---@param session_name? string An optional session to load
---@param is_startup? boolean|nil Is this autorestore happening on startup
---@return boolean boolean returns whether restoring the session was successful or not.
function AutoSession.auto_restore_session(session_name, is_startup)
  -- WARN: should this be checking is_allowed_dir as well?
  if is_enabled() and auto_restore() and not suppress_session(session_name) then
    local opts = {
      show_message = Config.show_auto_restore_notif,
      is_autorestore = true,
      is_startup_autorestore = is_startup,
    }
    if AutoSession.restore_session(session_name, opts) then
      return true
    end
  end

  -- Because of the last session feature, startup calls no_restore hooks itself
  if not is_startup then
    AutoSession.run_cmds("no_restore", false)
  end
  return false
end

---@private
---Called at VimEnter to start AutoSession
---Will call auto_restore_session_at_vim_enter and also purge sessions (if enabled)
---@return boolean # Was a session restored
function AutoSession.start()
  local did_auto_restore = AutoSession.auto_restore_session_at_vim_enter()

  if Config.purge_after_minutes then
    local work = vim.uv.new_work(Lib.purge_old_sessions, function(purged_sessions_json)
      vim.schedule(function()
        local purged_sessions = vim.json.decode(purged_sessions_json)
        if not vim.tbl_isempty(purged_sessions) then
          Lib.logger.info(
            "Deleted old sessions:\n"
              .. table.concat(vim.tbl_map(Lib.escaped_session_name_to_session_name, purged_sessions), "\n")
          )
        end
      end)
    end)
    work:queue(AutoSession.get_root_dir(), Config.purge_after_minutes)
  end

  return did_auto_restore
end

---@private
---Called at VimEnter (after Lazy is done) to see if we should automatically restore a session
---If launched with a single directory parameter and Config.args_allow_single_directory is true, pass
---that in as the session_dir. Handles both 'nvim .' and 'nvim some/dir'
---Also make sure to call no_restore if no session was restored
---@return boolean # Was a session restored
function AutoSession.auto_restore_session_at_vim_enter()
  -- launch_argv is captured during setup as that happens before `VimEnter` which
  -- is important because some plugins (.e.g. NvimTree) rewrite the arguments before
  -- we get to see them

  -- Is there exactly one argument and is it a directory?
  if
    Config.args_allow_single_directory
    and launch_argv
    and #launch_argv == 1
    and vim.fn.isdirectory(launch_argv[1]) == Lib._VIM_TRUE
  then
    -- Get the full path of the directory and make sure it doesn't have a trailing path_separator
    -- to make sure we find the session
    local session_name = Lib.remove_trailing_separator(vim.fn.fnamemodify(launch_argv[1], ":p"))
    Lib.logger.debug("Launched with single directory, using as session_dir: " .. session_name)

    if Config.git_use_branch_name then
      -- Get the git branch for that directory, no legacy git name support
      local branch_name = Lib.get_git_branch_name(session_name, Config.git_use_branch_name)
      local custom_tag = Config.custom_session_tag and Config.custom_session_tag(session_name) or nil
      session_name = Lib.combine_session_name_with_git_and_tag(session_name, branch_name, custom_tag, false)
      Lib.logger.debug("git enabled, launch argument with potential git branch: " .. session_name)
    end

    if AutoSession.auto_restore_session(session_name, true) then
      return true
    end

    -- We failed to load a session for the other directory. Unless session name matches cwd, we don't
    -- want to enable autosaving since it might replace the session for the cwd
    if vim.fn.getcwd(-1, -1) ~= session_name then
      Lib.logger.debug("Not enabling autosave because launch argument didn't load session and doesn't match cwd")
      Config.auto_save = false
    end
  else
    if AutoSession.auto_restore_session(nil, true) then
      return true
    end

    -- Check to see if the last session feature is on
    if Config.auto_restore_last_session then
      Lib.logger.debug("Last session is enabled, checking for session")
      local last_session_name = Lib.get_latest_session(AutoSession.get_root_dir())
      if last_session_name then
        Lib.logger.debug("Found last session: " .. last_session_name)
        if AutoSession.auto_restore_session(last_session_name, true) then
          return true
        end
      end
      Lib.logger.debug("Failed to load last session")
    end
  end

  -- No session was restored, dispatch no-restore hook
  Lib.logger.debug("No session restored, call no_restore hooks")
  AutoSession.run_cmds("no_restore", true)

  return false
end

---@class SaveOpts
---@field show_message boolean|nil Should messages be shown
---@field is_autosave boolean|nil True if this is part of an auto-save

---Saves a session to the dir specified in the config. If no optional
---session name is passed in, it uses the cwd as the session name
---@param session_name? string|nil Optional session name
---@param opts? SaveOpts save options
---@return boolean
function AutoSession.save_session(session_name, opts)
  opts = opts or {}
  local session_dir = AutoSession.get_root_dir()
  Lib.logger.debug("save_session start", { session_dir, session_name, opts })

  -- Canonicalize and create session_dir if needed
  session_dir = Lib.validate_root_dir(session_dir)
  Lib.logger.debug("save_session validated session_dir: ", session_dir)

  if not session_name or session_name == "" then
    -- If no session name is passed in, retrieve the current session name
    session_name = get_session_name()
    Lib.logger.debug("save_session no session_name, using: " .. session_name)
  end

  local escaped_session_name = get_session_file_name(session_name)

  Lib.logger.debug("save_session escaped session name: " .. escaped_session_name)

  -- If we have a current session name and it's different than the one for
  -- the cwd, we know it's a manually named session. We track that so we
  -- can write to that session on exit
  if session_name then
    local cwd_escaped_session_name = get_session_file_name(nil)

    if escaped_session_name ~= cwd_escaped_session_name then
      AutoSession.manually_named_session = true
      Lib.logger.debug("Session is manually named")
    end
  end

  local session_path = session_dir .. escaped_session_name

  Lib.close_ignored_filetypes(Config.close_filetypes_on_save)

  local results = AutoSession.run_cmds("pre_save", session_name) or {}

  if opts.is_autosave then
    Lib.logger.debug("pre_save results:", results)
    for _, result in ipairs(results) do
      if result == false then
        Lib.logger.debug("pre_save hook returned false, will not auto-save", results)
        vim.notify("Not auto-saving session because a pre_save hook returned false")
        return false
      end
    end
  end

  -- We don't want to save arguments to the session as that can cause issues
  -- with buffers that can't be removed from the session as they keep being
  -- added back through an argadd
  vim.cmd("%argdelete")

  Lib.logger.debug("save_session writing session to: " .. session_path)

  -- Vim cmds require escaping any % with a \ but we don't want to do that
  -- for direct filesystem operations (like in save_extra_cmds) so we
  -- that here, as late as possible and only for this operation
  local vim_session_path = Lib.escape_string_for_vim(session_path)
  vim.cmd("mks! " .. vim_session_path)

  save_extra_cmds(session_path, session_name)

  AutoSession.run_cmds("post_save", session_name)

  -- session_name might be nil (e.g. when using cwd), unescape escaped_session_name instead
  Lib.logger.debug("Saved session: " .. Lib.unescape_session_name(escaped_session_name))
  if opts.show_message == nil or opts.show_message then
    vim.notify("Saved session: " .. Lib.get_session_display_name(escaped_session_name))
  end

  return true
end

---@class RestoreOpts
---@field show_message boolean|nil Should messages be shown
---@field is_autorestore boolean|nil True if this is part of an auto-restore (startup, cwd, git)
---@field is_startup_autorestore boolean|nil True if this is specifically a startup auto-restore

---Restores a session from the passed in directory. If no optional session name
---is passed in, it uses the cwd as the session name
---@param session_name? string|nil Optional session name
---@param opts? RestoreOpts|nil restore options
function AutoSession.restore_session(session_name, opts)
  local session_dir = AutoSession.get_root_dir()
  Lib.logger.debug("restore_session start", { session_dir, session_name })
  opts = opts or {}
  -- Canonicalize and create session_dir if needed
  session_dir = Lib.validate_root_dir(session_dir)
  Lib.logger.debug("restore_session validated session_dir: ", session_dir)

  local escaped_session_name = get_session_file_name(session_name)

  Lib.logger.debug("restore_session escaped session name: " .. escaped_session_name)

  local session_path = session_dir .. escaped_session_name

  -- We need to reset manually named session here in case we are restoring a
  -- session that is not manually named.
  -- In single_session_mode, every session is considered manually named
  AutoSession.manually_named_session = Config.single_session_mode

  -- If a session_name was passed in and it's different than the one for
  -- the cwd, we know it's a manually named session. We track that so we
  -- can write to that session on exit
  if session_name then
    local cwd_escaped_session_name = get_session_file_name(nil)

    if escaped_session_name ~= cwd_escaped_session_name then
      AutoSession.manually_named_session = true
      Lib.logger.debug("Session is manually named")
    end
  end

  if vim.fn.filereadable(session_path) ~= 1 then
    Lib.logger.debug("restore_session session does not exist: " .. session_path)

    -- NOTE: This won't work for legacy window session names containing dashes because
    -- information was lost (i.e. was the dash part of the original path or was it
    -- a path separator).
    local legacy_escaped_session_name = get_session_file_name(session_name, true)
    local legacy_session_path = session_dir .. legacy_escaped_session_name

    if vim.fn.filereadable(legacy_session_path) ~= 1 then
      if opts.show_message == nil or opts.show_message then
        vim.notify("Could not restore session: " .. Lib.get_session_display_name(escaped_session_name))
      end
      return false
    end

    Lib.logger.debug("restore_session renaming legacy session: " .. legacy_escaped_session_name)
    ---@diagnostic disable-next-line: undefined-field
    if not uv.fs_rename(legacy_session_path, session_path) then
      Lib.logger.debug(
        "restore_session rename failed!",
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
        Lib.logger.debug("restore_session Renaming legacy user commands" .. legacy_user_commands_path)
        uv.fs_rename(legacy_user_commands_path, user_commands_path)
      end
    end
  end

  return AutoSession.restore_session_file(session_path, opts)
end

---Handles errors on restore. Will ignore fold errors but will pop a notification for all other
---errors and return false, which will disable auto-save
---@param error_msg string error message
---@return boolean enable_auto_save Return false to disable auto-saving, true to leave it on
local function restore_error_handler(error_msg)
  -- Ignore fold errors as discussed in https://github.com/rmagatti/auto-session/issues/409
  if error_msg and (string.find(error_msg, "E490: No fold found") or string.find(error_msg, "E16: Invalid range")) then
    Lib.logger.debug("Ignoring fold error on restore")
    return true
  end

  Lib.logger.error([[
Error restoring session, disabling auto save.
Error: ]] .. error_msg)
  return false
end

---Restores a session from a specific file
---@param session_path string The session file to load
---@param opts? RestoreOpts|nil restore options
---@return boolean Was a session restored
function AutoSession.restore_session_file(session_path, opts)
  Lib.logger.debug("restore_session_file restoring session from: " .. session_path)
  opts = opts or {}

  local session_name = Lib.get_session_display_name(vim.fn.fnamemodify(session_path, ":t"))
  local results = AutoSession.run_cmds("pre_restore", session_name) or {}

  -- If this is an auto-restore and a pre_restore hook returned false
  -- then abort restoring the session
  if opts.is_autorestore then
    Lib.logger.debug("pre_restore results:", results)
    for _, result in ipairs(results) do
      if result == false then
        Lib.logger.debug("pre_restore hook returned false, will not auto-restore", results)
        vim.notify("Not auto-restoring session because a pre_restore hook returned false")
        return false
      end
    end
  end

  -- Stop any language servers if config is set but don't do
  -- this on startup as it causes a perceptible delay (and we
  -- know there aren't any language servers anyway)
  if not opts.is_startup_autorestore then
    if Config.lsp_stop_on_restore then
      if type(Config.lsp_stop_on_restore) == "function" then
        Config.lsp_stop_on_restore()
      else
        local clients = vim.lsp.get_clients()
        if #clients > 0 then
          vim.lsp.stop_client(clients)
        end
      end
    end
  end
  -- Vim cmds require escaping any % with a \ but we don't want to do that
  -- for direct filesystem operations (like in save_extra_cmds_new) so we
  -- that here, as late as possible and only for this operation
  local vim_session_path = Lib.escape_string_for_vim(session_path)
  local cmd = "source " .. vim_session_path

  -- Set restore_in_progress here so we won't also try to save/load the session if
  -- cwd_change_handling = true and the session contains a cd command
  -- The session file will also set SessionLoad so we'll check that too but feels
  -- safer to have our own flag as well, in case the vim flag changes
  AutoSession.restore_in_progress = true

  if Config.git_auto_restore_on_branch_change then
    require("auto-session.git").stop_watcher()
  end

  -- Clear the buffers and jumps
  Lib.conditional_buffer_wipeout(Config.preserve_buffer_on_restore)
  vim.cmd("silent clearjumps")

  ---@diagnostic disable-next-line: param-type-mismatch
  local success, result = pcall(vim.cmd, "silent " .. cmd)

  -- normal restore failed, source again but with silent! to restore as much as possible
  if not success and Config.continue_restore_on_error then
    Lib.conditional_buffer_wipeout(Config.preserve_buffer_on_restore)
    vim.cmd("silent clearjumps")

    -- don't capture return values as we'll use success and result from the first call
    ---@diagnostic disable-next-line: param-type-mismatch
    pcall(vim.cmd, "silent! " .. cmd)
  end

  if Config.single_session_mode then
    -- Maintain manually named session flag when restoring in single session mode
    AutoSession.manually_named_session = true
  end

  AutoSession.restore_in_progress = false

  -- Clear any saved command line args since we don't need them anymore
  launch_argv = nil

  if not success then
    ---@type fun(error_msg:string): disable_auto_save:boolean
    local error_handler = type(Config.restore_error_handler) == "function" and Config.restore_error_handler
      or restore_error_handler
    if not error_handler(result) then
      Lib.logger.debug("Error while restoring, disabling autosave")
      Config.auto_save = false
      return false
    end
  end

  Lib.logger.debug("Restored session: " .. session_name)
  if opts.show_message == nil or opts.show_message then
    vim.notify("Restored session: " .. session_name)
  end

  if Config.git_use_branch_name and Config.git_auto_restore_on_branch_change then
    -- start watching for branch changes
    require("auto-session.git").start_watcher(vim.fn.getcwd(-1, -1), ".git/HEAD")
  end

  AutoSession.run_cmds("post_restore", session_name)

  write_to_session_control_json(session_path)
  return true
end

---Deletes a session from the config session dir. If no optional session name
---is passed in, it uses the cwd as the session name
---@param session_name? string|nil Optional session name
function AutoSession.delete_session(session_name)
  local session_dir = AutoSession.get_root_dir()
  Lib.logger.debug("delete_session start", { session_dir, session_name })

  -- Canonicalize and create session_dir if needed
  session_dir = Lib.validate_root_dir(session_dir)
  Lib.logger.debug("delete_session validated session_dir ", session_dir)

  local escaped_session_name = get_session_file_name(session_name)

  Lib.logger.debug("delete_session escaped session name: " .. escaped_session_name)

  local session_path = session_dir .. escaped_session_name

  if vim.fn.filereadable(session_path) ~= 1 then
    Lib.logger.debug("delete_session session does not exist: " .. session_path)

    -- Check for a legacy session to delete
    local legacy_escaped_session_name = get_session_file_name(session_name, true)
    local legacy_session_path = session_dir .. legacy_escaped_session_name

    if vim.fn.filereadable(legacy_session_path) ~= 1 then
      vim.notify("Session does not exist: " .. Lib.get_session_display_name(escaped_session_name))
      return false
    end
    Lib.logger.debug("delete_session using legacy session: " .. legacy_escaped_session_name)
    session_path = legacy_session_path
  end

  -- session_name could be nil, so get name from escaped_session_name
  return AutoSession.delete_session_file(session_path, Lib.get_session_display_name(escaped_session_name))
end

---Delete a session file
---@param session_path string The filename to delete
---@param session_name string Session name being deleted, just use to display messages
---@return boolean # Was the session file deleted
function AutoSession.delete_session_file(session_path, session_name)
  AutoSession.run_cmds("pre_delete", session_name)

  Lib.logger.debug("delete_session_file deleting: " .. session_path)

  local result = vim.fn.delete(Lib.expand(session_path)) == 0

  if not result then
    Lib.logger.error("delete_session_file Failed to delete session: " .. session_name)
  else
    if Config.auto_save and vim.fn.fnamemodify(vim.v.this_session, ":t") == vim.fn.fnamemodify(session_path, ":t") then
      -- session_name might be nil (e.g. when using cwd), unescape escaped_session_name instead
      Lib.logger.debug("delete_session_file Current session deleted, auto save off: " .. session_name)
      vim.notify("Auto saving disabled because the current session was deleted: " .. session_name)
      vim.v.this_session = ""
      Config.auto_save = false
    else
      Lib.logger.debug("delete_session_file Session deleted: " .. session_name)
      vim.notify("Session deleted: " .. session_name)
    end
  end

  -- check for extra user commands
  local extra_commands_path = session_path:gsub("%.vim$", "x.vim")
  if vim.fn.filereadable(extra_commands_path) == 1 and not Lib.is_session_file(extra_commands_path) then
    vim.fn.delete(extra_commands_path)
    Lib.logger.debug("delete_session_file deleting extra user commands: " .. extra_commands_path)
  end

  AutoSession.run_cmds("post_delete", session_name)
  return result
end

---Disables autosave. Enables autosave if enable is true
---@param enable? boolean Optional parameter to enable autosaving
---@return boolean # Whether autosaving is enabled or not
function AutoSession.disable_auto_save(enable)
  Config.auto_save = enable or false
  if Config.auto_save then
    vim.notify("Session auto-save enabled")
  else
    vim.notify("Session auto-save disabled")
  end
  return Config.auto_save
end

---Open a session search picker
function AutoSession.search()
  require("auto-session.pickers").open_session_picker()
end

---Open a session delete picker
function AutoSession.delete_picker()
  require("auto-session.pickers.select").open_delete_picker()
end

--- Legacy API functions ---
--- Remove at some point, 6 months?

function AutoSession.SaveSession(session_name, show_message)
  vim.notify("SaveSession() is deprecated, use save_session()")
  return AutoSession.save_session(session_name, { show_message = show_message })
end

function AutoSession.RestoreSession(session_name, opts)
  vim.notify("RestoreSession() is deprecated, use restore_session()")
  return AutoSession.restore_session(session_name, opts)
end

function AutoSession.RestoreSessionFile(session_path, opts)
  vim.notify("RestoreSessionFile() is deprecated, use restore_session_file()")
  return AutoSession.restore_session_file(session_path, opts)
end

function AutoSession.DeleteSession(session_name)
  vim.notify("DeleteSession() is deprecated, use delete_session()")
  return AutoSession.delete_session(session_name)
end

function AutoSession.DeleteSessionFile(session_path, session_name)
  vim.notify("DeleteSessionFile() is deprecated, use delete_session_file()")
  return AutoSession.delete_session_file(session_path, session_name)
end

function AutoSession.DisableAutoSave(enable)
  vim.notify("DisableAutoSave() is deprecated, use disable_auto_save()")
  return AutoSession.disable_auto_save(enable)
end

function AutoSession.AutoSaveSession()
  vim.notify("AutoSaveSession() is deprecated, use auto_save_session()")
  return AutoSession.auto_save_session()
end

function AutoSession.AutoRestoreSession(session_name, is_startup)
  vim.notify("AutoRestoreSession() is deprecated, use auto_restore_session()")
  return AutoSession.auto_restore_session(session_name, is_startup)
end

return AutoSession
