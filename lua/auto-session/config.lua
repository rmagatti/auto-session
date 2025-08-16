---@diagnostic disable: inject-field
---@type AutoSession.Config
local M = {}

---@toc toc

---@mod auto-session.config Config

---@class AutoSession.Config
---
---Saving / restoring
---@field enabled? boolean
---@field auto_save? boolean
---@field auto_restore? boolean
---@field auto_create? boolean|auto_create_fn
---@field auto_restore_last_session? boolean
---@field cwd_change_handling? boolean
---@field single_session_mode? boolean
---
---Filtering
---@field suppressed_dirs? table
---@field allowed_dirs? table
---@field bypass_save_filetypes? table
---@field close_filetypes_on_save? table
---@field close_unsupported_windows? boolean
---@field preserve_buffer_on_restore? should_preserve_buffer_fn
---
---Deleting
---@field auto_delete_empty_sessions? boolean
---@field purge_after_minutes? number
---
---Git
---@field git_use_branch_name? boolean
---@field git_auto_restore_on_branch_change? boolean
---
---Saving extra data
---@field save_extra_data? save_extra_data_fn
---@field restore_extra_data? restore_extra_data_fn
---
---Argument handling
---@field args_allow_single_directory? boolean
---@field args_allow_files_auto_save? boolean|allow_save_fn
---
---Misc
---@field log_level? string|integer
---@field root_dir? string
---@field show_auto_restore_notif? boolean
---@field restore_error_handler? restore_error_fn
---@field continue_restore_on_error? boolean
---@field lsp_stop_on_restore? boolean|function
---@field lazy_support? boolean
---
---@field session_lens? SessionLens
---
---Session Lens Config
---@class SessionLens
---@field picker? "telescope"|"snacks"|"fzf"|"select"
---@field load_on_setup? boolean
---@field picker_opts? table
---@field session_control? SessionControl
---@field mappings? SessionLensMappings
---
---@class SessionLensMappings
---@field delete_session? table
---@field alternate_session? table
---@field copy_session? table
---
---@class SessionControl
---@field control_dir? string
---@field control_filename? string
---
---Callback types
---@alias allow_save_fn fun(): should_save_session:boolean
---@alias auto_create_fn fun(): should_create_session:boolean
---@alias should_preserve_buffer_fn fun(bufnr:number): preserve_buffer:boolean
---@alias restore_error_fn fun(error_msg:string): disable_auto_save:boolean
---@alias save_extra_data_fn fun(session_name:string): extra_data:string
---@alias restore_extra_data_fn fun(session_name:string, extra_data:string)
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

---@type AutoSession.Config
local defaults = {
  -- Saving / restoring
  enabled = true, -- Enables/disables auto creating, saving and restoring
  auto_save = true, -- Enables/disables auto saving session on exit
  auto_restore = true, -- Enables/disables auto restoring session on start
  auto_create = true, -- Enables/disables auto creating new session files. Can take a function that should return true/false if a new session file should be created or not
  auto_restore_last_session = false, -- On startup, loads the last saved session if session for cwd does not exist
  cwd_change_handling = false, -- Automatically save/restore sessions when changing directories
  single_session_mode = false, -- Enable single session mode to keep all work in one session regardless of cwd changes. When enabled, prevents creation of separate sessions for different directories and maintains one unified session. Does not work with cwd_change_handling

  -- Filtering
  suppressed_dirs = nil, -- Suppress session restore/create in certain directories
  allowed_dirs = nil, -- Allow session restore/create in certain directories
  bypass_save_filetypes = nil, -- List of filetypes to bypass auto save when the only buffer open is one of the file types listed, useful to ignore dashboards
  close_filetypes_on_save = { "checkhealth" }, -- Buffers with matching filetypes will be closed before saving
  close_unsupported_windows = true, -- Close windows that aren't backed by normal file before autosaving a session
  preserve_buffer_on_restore = nil, -- should_preserve_buffer_fn, return true if a buffer should be preserved when restoring a session

  -- Git
  git_use_branch_name = false, -- Include git branch name in session name
  git_auto_restore_on_branch_change = false, -- Should we auto-restore the session when the git branch changes. Requires git_use_branch_name

  -- Deleting
  auto_delete_empty_sessions = true, -- Enables/disables deleting the session if there are only unnamed/empty buffers when auto-saving
  purge_after_minutes = nil, -- Sessions older than purge_after_minutes will be deleted asynchronously on startup, e.g. set to 14400 to delete sessions that haven't been accessed for more than 10 days, defaults to off (no purging), requires >= nvim 0.10

  -- Saving extra data
  save_extra_data = nil, -- Extra data that should be saved with the session. Will be passed to restore_extra_data on restore
  restore_extra_data = nil, -- Called when there's custom data saved for a session

  -- Argument handling
  args_allow_single_directory = true, -- Follow normal session save/load logic if launched with a single directory as the only argument
  args_allow_files_auto_save = false, -- Allow saving a session even when launched with a file argument (or multiple files/dirs). It does not load any existing session first. While you can just set this to true, you probably want to set it to a function that decides when to save a session when launched with file args. See documentation for more detail

  -- Misc
  log_level = "error", -- Sets the log level of the plugin (debug, info, warn, error).
  root_dir = vim.fn.stdpath "data" .. "/sessions/", -- Root dir where sessions will be stored
  show_auto_restore_notif = false, -- Whether to show a notification when auto-restoring
  restore_error_handler = nil, -- Called when there's an error restoring. By default, it ignores fold errors otherwise it displays the error and returns false to disable auto_save
  continue_restore_on_error = true, -- Keep loading the session even if there's an error
  lsp_stop_on_restore = false, -- Should language servers be stopped when restoring a session. Can also be a function that will be called if set. Not called on autorestore from startup
  lazy_support = true, -- Automatically detect if Lazy.nvim is being used and wait until Lazy is done to make sure session is restored correctly. Does nothing if Lazy isn't being used. Can be disabled if a problem is suspected or for debugging

  ---@type SessionLens
  session_lens = {
    picker = nil, -- "telescope"|"snacks"|"fzf"|"select"|nil Pickers are detected automatically but you can also manually choose one. Falls back to vim.ui.select
    load_on_setup = true, -- Only used for telescope, registers the telescope extension startup
    picker_opts = nil, -- Table passed to Telescope / Snacks / Fzf-Lua to configure the picker. See below for more information

    ---@type SessionLensMappings
    mappings = {
      -- Mode can be a string or a table, e.g. {"i", "n"} for both insert and normal mode
      delete_session = { "i", "<C-D>" }, -- mode and key for deleting a session from the picker
      alternate_session = { "i", "<C-S>" }, -- mode and key for swapping to alternate session from the picker
      copy_session = { "i", "<C-Y>" }, -- mode and key for copying a session from the picker
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
    ignore_filetypes_on_save = "close_filetypes_on_save",
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

  if M.single_session_mode and M.cwd_change_handling then
    logger.warn "single_session_mode and cwd_change_handling are conflicting options. Disabling single_session_mode."
    M.single_session_mode = false
    has_issues = true
  end

  if M.session_lens.load_on_setup and M.session_lens.picker and M.session_lens.picker ~= "telescope" then
    logger.warn 'session_lens.load_on_setup is not used with pickers other than "telescope"'
    M.session_lens.load_on_setup = false
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
  __newindex = function(_, key, value)
    if M.options == nil then
      M.setup()
    end
    M.options[key] = value
  end,
  __tostring = function(_)
    return vim.inspect(M.options)
  end,
})
