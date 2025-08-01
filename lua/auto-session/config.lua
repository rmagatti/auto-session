---@diagnostic disable: inject-field
---@type AutoSession.Config
local M = {}

---@toc toc

---@mod auto-session.config Config

---@class AutoSession.Config
---@field enabled? boolean Enables/disables auto saving and restoring
---@field root_dir? string root directory for session files, by default is `vim.fn.stdpath('data') .. '/sessions/'`
---@field auto_save? boolean Enables/disables auto saving session on exit
---@field auto_restore? boolean Enables/disables auto restoring session on start
---@field auto_create? boolean|function Enables/disables auto creating new session files. Can take a function that should return true/false if a new session file should be created or not
---@field auto_delete_empty_sessions? boolean Enables/disables deleting the session if there no named, non-empty buffers when auto-saving
---@field suppressed_dirs? table Suppress auto session for directories
---@field allowed_dirs? table Allow auto session for directories, if empty then all directories are allowed except for suppressed ones
---@field auto_restore_last_session? boolean On startup, loads the last saved session if session for cwd does not exist
---@field git_use_branch_name? boolean Include git branch name in session name to differentiate between sessions for different git branches
---@field git_auto_restore_on_branch_change? boolean Should we auto-restore the session when the git branch changes. Requires git_use_branch_name
---@field lazy_support? boolean Automatically detect if Lazy.nvim is being used and wait until Lazy is done to make sure session is restored correctly. Does nothing if Lazy isn't being used. Can be disabled if a problem is suspected or for debugging
---@field bypass_save_filetypes? table List of file types to bypass auto save when the only buffer open is one of the file types listed, useful to ignore dashboards
---@field close_unsupported_windows? boolean Whether to close windows that aren't backed by a real file
---Argv Handling
---@field args_allow_single_directory? boolean Follow normal session save/load logic if launched with a single directory as the only argument
---@field args_allow_files_auto_save? boolean|function Allow saving a session even when launched with a file argument (or multiple files/dirs). It does not load any existing session first. While you can just set this to true, you probably want to set it to a function that decides when to save a session when launched with file args. See documentation for more detail
---@field continue_restore_on_error? boolean Keep loading the session even if there's an error. Set to false to get the line number of an error when loading a session
---@field show_auto_restore_notif? boolean Whether to show a notification when auto-restoring
---@field log_level? string|integer "debug", "info", "warn", "error" or vim.log.levels.DEBUG, vim.log.levels.INFO, vim.log.levels.WARN, vim.log.levels.ERROR
---@field cwd_change_handling? boolean Follow cwd changes, saving a session before change and restoring after
---@field lock_session_to_startup_cwd? boolean Lock session to the startup cwd, ensuring consistent single session even when cwd changes. This means that even if the cwd changes after startup, any buffers open in other cwds will still end up saving to the original startup cwd's session. Do not use this with cwd_change_handling
---@field lsp_stop_on_restore? boolean|function Should language servers be stopped when restoring a session. Can also be a function that will be called if set. Not called on autorestore from startup
---
---@field restore_error_handler? restore_error_fn Called when there's an error restoring. By default, it ignores fold errors otherwise it displays the error and returns false to disable auto_save
---@field purge_after_minutes? number|nil -- Sessions older than purge_after_minutes will be deleted asynchronously on startup, e.g. set to 14400 to delete sessions that haven't been accessed for more than 10 days, defaults to off (no purging), requires >= nvim 0.10
---
---@field session_lens? SessionLens Session lens configuration options
---
---Hooks
---@field pre_save_cmds? table executes before a session is saved
---@field save_extra_cmds? table executes before a session is saved
---@field post_save_cmds? table executes after a session is saved
---@field pre_restore_cmds? table executes before a session is restored
---@field post_restore_cmds? table executes after a session is restored
---@field pre_delete_cmds? table executes before a session is deleted
---@field post_delete_cmds? table executes after a session is deleted
---@field no_restore_cmds? table executes at VimEnter when no session is restored
---@field pre_cwd_changed_cmds? table executes before cwd is changed if cwd_change_handling is true
---@field post_cwd_changed_cmds? table executes after cwd is changed if cwd_change_handling is true
---
---Session Lens Cenfig
---@class SessionLens
---@field load_on_setup? boolean
---@field picker_opts? table Telescope/Snacks picker options
---@field session_control? SessionControl
---@field mappings? SessionLensMappings
---
---@class SessionControl
---@field control_dir? string
---@field control_filename? string
---
---Session Lens Mapping
---@class SessionLensMappings
---@field delete_session? table mode and key for deleting a session from the picker
---@field alternate_session? table mode and key for swapping to alertnate session from the picker
---@field copy_session? table mode and key for copying a session from the picker
---
---@alias restore_error_fn fun(error_msg:string): disable_auto_save:boolean

---@type AutoSession.Config
local defaults = {
  enabled = true, -- Enables/disables auto creating, saving and restoring
  root_dir = vim.fn.stdpath "data" .. "/sessions/", -- Root dir where sessions will be stored
  auto_save = true, -- Enables/disables auto saving session on exit
  auto_restore = true, -- Enables/disables auto restoring session on start
  auto_create = true, -- Enables/disables auto creating new session files. Can take a function that should return true/false if a new session file should be created or not
  auto_delete_empty_sessions = true, -- Enables/disables deleting the session if there no named, non-empty buffers when auto-saving
  suppressed_dirs = nil, -- Suppress session restore/create in certain directories
  allowed_dirs = nil, -- Allow session restore/create in certain directories
  auto_restore_last_session = false, -- On startup, loads the last saved session if session for cwd does not exist
  git_use_branch_name = false, -- Include git branch name in session name
  git_auto_restore_on_branch_change = false, -- Should we auto-restore the session when the git branch changes. Requires git_use_branch_name
  lazy_support = true, -- Automatically detect if Lazy.nvim is being used and wait until Lazy is done to make sure session is restored correctly. Does nothing if Lazy isn't being used. Can be disabled if a problem is suspected or for debugging
  bypass_save_filetypes = nil, -- List of filetypes to bypass auto save when the only buffer open is one of the file types listed, useful to ignore dashboards
  ignore_filetypes_on_save = { "checkhealth" }, -- List of filetypes to close buffers of before saving a session, ignores checkhealth by default
  close_unsupported_windows = true, -- Close windows that aren't backed by normal file before autosaving a session
  args_allow_single_directory = true, -- Follow normal session save/load logic if launched with a single directory as the only argument
  args_allow_files_auto_save = false, -- Allow saving a session even when launched with a file argument (or multiple files/dirs). It does not load any existing session first. While you can just set this to true, you probably want to set it to a function that decides when to save a session when launched with file args. See documentation for more detail
  continue_restore_on_error = true, -- Keep loading the session even if there's an error
  show_auto_restore_notif = false, -- Whether to show a notification when auto-restoring
  cwd_change_handling = false, -- Follow cwd changes, saving a session before change and restoring after
  lock_session_to_startup_cwd = false, -- Lock session to the startup cwd, ensuring consistent single session even when cwd changes. This means that even if the cwd changes after startup, any buffers open in other cwds will still end up saving to the original startup cwd's session. Do not use this with cwd_change_handling
  lsp_stop_on_restore = false, -- Should language servers be stopped when restoring a session. Can also be a function that will be called if set. Not called on autorestore from startup
  restore_error_handler = nil, -- Called when there's an error restoring. By default, it ignores fold errors otherwise it displays the error and returns false to disable auto_save
  purge_after_minutes = nil, -- Sessions older than purge_after_minutes will be deleted asynchronously on startup, e.g. set to 14400 to delete sessions that haven't been accessed for more than 10 days, defaults to off (no purging), requires >= nvim 0.10
  log_level = "error", -- Sets the log level of the plugin (debug, info, warn, error).

  ---@type SessionLens
  session_lens = {
    load_on_setup = true, -- Initialize on startup (requires Telescope)
    picker_opts = nil, -- Table passed to Telescope / Snacks to configure the picker

    ---@type SessionLensMappings
    mappings = {
      -- Mode can be a string or a table, e.g. {"i", "n"} for both insert and normal mode
      delete_session = { "i", "<C-D>" },
      alternate_session = { "i", "<C-S>" },
      copy_session = { "i", "<C-Y>" },
    },

    ---@type SessionControl
    session_control = {
      control_dir = vim.fn.stdpath "data" .. "/auto_session/", -- Auto session control dir, for control files, like alternating between two sessions with session-lens
      control_filename = "session_control.json", -- File name of the session control file
    },
  },
}

---@type AutoSession.Config
M.options = {}

---@type AutoSession.Config
---Used to show the user their config using the new names without the defaults
M.options_without_defaults = {}

---Does the config have old names. Used to show a warning in the health check
M.has_old_config = false

---Set config options based on vim globals
---@param config AutoSession.Config
local function check_for_vim_globals(config)
  local vim_globals_mapping = {
    auto_session_enabled = "enabled",
    auto_session_root_dir = "root_dir",
    auto_save_enabled = "auto_save",
    auto_restore_enabled = "auto_restore",
    auto_session_allowed_dirs = "allowed_dirs",
    auto_session_suppress_dirs = "suppressed_dirs",
    auto_session_create_enabled = "auto_create",
    auto_session_enable_last_session = "auto_restore_last_session",
    auto_session_use_git_branch = "git_use_branch_name",
    pre_save_cmds = "pre_save_cmds",
    save_extra_cmds = "save_extra_cmds",
    post_save_cmds = "post_save_cmds",
    pre_restore_cmds = "pre_restore_cmds",
    post_restore_cmds = "post_restore_cmds",
    pre_delete_cmds = "pre_delete_cmds",
    post_delete_cmds = "post_delete_cmds",
    no_restore_cmds = "no_restore_cmds",
  }

  for global_name, config_name in pairs(vim_globals_mapping) do
    -- if the global is set and the config isn't set, set the config
    if vim.g[global_name] ~= nil then
      M.has_old_config = true
      if config[config_name] == nil then
        config[config_name] = vim.g[global_name]
      end
    end
  end
end

---Look for old config names, and set them with the new names
---@param config AutoSession.Config
local function check_old_config_names(config)
  local old_config_names = {
    auto_session_enabled = "enabled",
    auto_session_root_dir = "root_dir",
    auto_save_enabled = "auto_save",
    auto_restore_enabled = "auto_restore",
    auto_session_allowed_dirs = "allowed_dirs",
    auto_session_suppress_dirs = "suppressed_dirs",
    auto_session_create_enabled = "auto_create",
    auto_session_enable_last_session = "auto_restore_last_session",
    auto_session_use_git_branch = "git_use_branch_name",
    use_git_branch = "git_use_branch_name",
    auto_restore_lazy_delay_enabled = "lazy_support",
    bypass_session_save_file_types = "bypass_save_filetypes",
    silent_restore = "continue_restore_on_error",
  }

  for old_name, new_name in pairs(old_config_names) do
    -- if old name is set and new name isn't set, then copy over the value to the new name
    -- and clear the old name
    if config[old_name] ~= nil then
      M.has_old_config = true
      if config[new_name] == nil then
        config[new_name] = config[old_name]
      end
      config[old_name] = nil
    end
  end

  if
    config["cwd_change_handling"]
    and type(config["cwd_change_handling"]) == "table"
    and config.cwd_change_handling["restore_upcoming_session"]
  then
    M.has_old_config = true
    local old_cwd_change_handling = config.cwd_change_handling or {} -- shouldn't be nil but placate LS
    config["cwd_change_handling"] = old_cwd_change_handling.restore_upcoming_session
    if old_cwd_change_handling["pre_cwd_changed_hook"] then
      config.pre_cwd_changed_cmds = { old_cwd_change_handling.pre_cwd_changed_hook }
    end
    if old_cwd_change_handling["post_cwd_changed_hook"] then
      config.post_cwd_changed_cmds = { old_cwd_change_handling.post_cwd_changed_hook }
    end
  end

  -- check session_lens for old config
  if config.session_lens then
    -- check for theme_conf first
    ---@diagnostic disable-next-line: undefined-field
    if config.session_lens.theme_conf then
      M.has_old_config = true
      config.session_lens.picker_opts = config.session_lens.theme_conf
      config.session_lens.theme_conf = nil
    end

    if config.session_lens.shorten_path then
      M.has_old_config = true
      if not config.session_lens.picker_opts then
        config.session_lens.picker_opts = {}
      end
      config.session_lens.picker_opts.path_display = { "shorten" }
      config.session_lens.shorten_path = nil
    end

    if config.session_lens.path_display then
      M.has_old_config = true
      if not config.session_lens.picker_opts then
        config.session_lens.picker_opts = {}
      end
      config.session_lens.picker_opts.path_display = config.session_lens.path_display
      config.session_lens.path_display = nil
    end
  end
end

---@param config? AutoSession.Config
function M.setup(config)
  -- Clear the flag in case setup is called again
  M.has_old_config = false

  ---@diagnostic disable-next-line: param-type-mismatch
  M.options_without_defaults = vim.deepcopy(config) or {}

  -- capture any old vim global config options
  check_for_vim_globals(M.options_without_defaults)

  -- capture any old config names
  check_old_config_names(M.options_without_defaults)

  M.options = vim.tbl_deep_extend("force", defaults, M.options_without_defaults)
end

---Show configuration warnings / errors. Used at startup and as part of checkhealth
---@param logger any object with a warn, info, error method
---@param show_full_message boolean? show short messages (e.g. used startup) or full messages (checkhealth)
function M.check(logger, show_full_message)
  show_full_message = show_full_message or false

  local has_issues = false
  if not vim.tbl_contains(vim.split(vim.o.sessionoptions, ","), "buffers") then
    if show_full_message then
      logger.warn(
        "`vim.o.sessionoptions` must contain 'buffers' otherwise not all buffers will be restored.\n"
          .. "Recommended setting is:\n\n"
          .. 'vim.o.sessionoptions="blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"\n'
      )
    else
      logger.warn "vim.o.sessionoptions is missing buffers. \nUse `:checkhealth autosession` for more info."
    end
    has_issues = true
  end

  if not vim.tbl_contains(vim.split(vim.o.sessionoptions, ","), "localoptions") then
    if show_full_message then
      logger.warn(
        "`vim.o.sessionoptions` should contain 'localoptions' to make sure\nfiletype and highlighting work correctly after a session is restored.\n"
          .. "Recommended setting is:\n\n"
          .. 'vim.o.sessionoptions="blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"\n'
      )
    else
      logger.warn "vim.o.sessionoptions is missing localoptions. \nUse `:checkhealth autosession` for more info."
    end
    has_issues = true
  end

  if M.purge_after_minutes and vim.fn.has "nvim-0.10" ~= 1 then
    logger.warn "the purge_after_minutes options requires nvim >= 0.10"
    has_issues = true
  end

  if not M.git_use_branch_name and M.git_auto_restore_on_branch_change then
    logger.error "git_auto_restore_on_branch_change requires git_use_branch_name = true"
    has_issues = true
  end

  if M.lock_session_to_startup_cwd and M.cwd_change_handling then
    logger.warn "lock_session_to_startup_cwd and cwd_change_handling are conflicting options. Disabling lock_session_to_startup_cwd."
    M.lock_session_to_startup_cwd = false
    has_issues = true
  end

  -- TODO: At some point, we should pop up a warning about old config if
  -- M.has_old_config but let's make sure everything is working well before doing that

  return has_issues
end

---@export Config
return setmetatable(M, {
  __index = function(_, key)
    if M.options == nil then
      M.setup()
    end
    ---@diagnostic disable-next-line: need-check-nil
    return M.options[key]
  end,
  __tostring = function(_)
    return vim.inspect(M.options)
  end,
})
