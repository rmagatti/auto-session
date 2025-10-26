---@diagnostic disable: inject-field
local M = {}

---@toc toc

---@mod auto-session.config Config

---@class AutoSession.Config
---
---Saving / restoring
---@field enabled? boolean
---@field auto_save? boolean
---@field auto_restore? boolean
---@field auto_create? boolean|fun(): should_create_session:boolean
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
---@field preserve_buffer_on_restore? fun(bufnr:number): preserve_buffer:boolean
---
---Git / Session naming
---@field git_use_branch_name? boolean|fun(path:string?): branch_name:string|nil
---@field git_auto_restore_on_branch_change? boolean
---@field custom_session_tag? fun(session_name:string): tag:string
---
---Deleting
---@field auto_delete_empty_sessions? boolean
---@field purge_after_minutes? number
---
---Saving extra data
---@field save_extra_data? fun(session_name:string): extra_data:string|nil
---@field restore_extra_data? fun(session_name:string, extra_data:string)
---
---Argument handling
---@field args_allow_single_directory? boolean
---@field args_allow_files_auto_save? boolean|fun(): disable_auto_save:boolean
---
---Misc
---@field log_level? string|integer
---@field root_dir? string
---@field show_auto_restore_notif? boolean
---@field restore_error_handler? fun(error_msg:string): disable_auto_save:boolean
---@field continue_restore_on_error? boolean
---@field lsp_stop_on_restore? boolean|fun()
---@field lazy_support? boolean
---@field legacy_cmds? boolean
---
---@field session_lens? SessionLens
---
---Session Lens Config
---@class SessionLens
---@field picker? "telescope"|"snacks"|"fzf"|"select"
---@field load_on_setup? boolean
---@field picker_opts? table
---@field previewer? 'summary'|'active_buffer'|fun(session_name:string, session_filename:string, session_lines:string[]):lines:string[],filetype:string?
---@field mappings? SessionLensMappings
---@field session_control? SessionControl
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
---Hooks
---@field pre_save_cmds? (string|fun(session_name:string): allow_save:boolean)[] executes before a session is saved, return false to stop auto-saving
---@field post_save_cmds? (string|fun(session_name:string))[] executes after a session is saved
---@field pre_restore_cmds? (string|fun(session_name:string): allow_restore:boolean)[] executes before a session is restored, return false to stop auto-restoring
---@field post_restore_cmds? (string|fun(session_name:string))[] executes after a session is restored
---@field pre_delete_cmds? (string|fun(session_name:string))[] executes before a session is deleted
---@field post_delete_cmds? (string|fun(session_name:string))[] executes after a session is deleted
---@field no_restore_cmds? (string|fun(is_startup:boolean))[] executes when no session is restored when auto-restoring, happens on startup or possibly on cwd/git branch changes
---@field pre_cwd_changed_cmds? (string|fun())[] executes before cwd is changed if cwd_change_handling is true
---@field post_cwd_changed_cmds? (string|fun())[] executes after cwd is changed if cwd_change_handling is true
---@field save_extra_cmds? (string|fun(session_name:string): extra_data:string|table|nil)[] executes to get extra data to save with the session

---@type AutoSession.Config
local defaults = {
  -- Saving / restoring
  enabled = true, -- Enables/disables auto creating, saving and restoring
  auto_save = true, -- Enables/disables auto saving session on exit
  auto_restore = true, -- Enables/disables auto restoring session on start
  auto_create = true, -- Enables/disables auto creating new session files. Can be a function that returns true if a new session file should be allowed
  auto_restore_last_session = false, -- On startup, loads the last saved session if session for cwd does not exist
  cwd_change_handling = false, -- Automatically save/restore sessions when changing directories
  single_session_mode = false, -- Enable single session mode to keep all work in one session regardless of cwd changes. When enabled, prevents creation of separate sessions for different directories and maintains one unified session. Does not work with cwd_change_handling

  -- Filtering
  suppressed_dirs = nil, -- Suppress session restore/create in certain directories
  allowed_dirs = nil, -- Allow session restore/create in certain directories
  bypass_save_filetypes = nil, -- List of filetypes to bypass auto save when the only buffer open is one of the file types listed, useful to ignore dashboards
  close_filetypes_on_save = { "checkhealth" }, -- Buffers with matching filetypes will be closed before saving
  close_unsupported_windows = true, -- Close windows that aren't backed by normal file before autosaving a session
  preserve_buffer_on_restore = nil, -- Function that returns true if a buffer should be preserved when restoring a session

  -- Git / Session naming
  git_use_branch_name = false, -- Include git branch name in session name, can also be a function that takes an optional path and returns the name of the branch
  git_auto_restore_on_branch_change = false, -- Should we auto-restore the session when the git branch changes. Requires git_use_branch_name
  custom_session_tag = nil, -- Function that can return a string to be used as part of the session name

  -- Deleting
  auto_delete_empty_sessions = true, -- Enables/disables deleting the session if there are only unnamed/empty buffers when auto-saving
  purge_after_minutes = nil, -- Sessions older than purge_after_minutes will be deleted asynchronously on startup, e.g. set to 14400 to delete sessions that haven't been accessed for more than 10 days, defaults to off (no purging), requires >= nvim 0.10

  -- Saving extra data
  save_extra_data = nil, -- Function that returns extra data that should be saved with the session. Will be passed to restore_extra_data on restore
  restore_extra_data = nil, -- Function called when there's extra data saved for a session

  -- Argument handling
  args_allow_single_directory = true, -- Follow normal session save/load logic if launched with a single directory as the only argument
  args_allow_files_auto_save = false, -- Allow saving a session even when launched with a file argument (or multiple files/dirs). It does not load any existing session first. Can be true or a function that returns true when saving is allowed. See documentation for more detail

  -- Misc
  log_level = "error", -- Sets the log level of the plugin (debug, info, warn, error).
  root_dir = vim.fn.stdpath("data") .. "/sessions/", -- Root dir where sessions will be stored
  show_auto_restore_notif = false, -- Whether to show a notification when auto-restoring
  restore_error_handler = nil, -- Function called when there's an error restoring. By default, it ignores fold and help errors otherwise it displays the error and returns false to disable auto_save. Default handler is accessible as require('auto-session').default_restore_error_handler
  continue_restore_on_error = true, -- Keep loading the session even if there's an error
  lsp_stop_on_restore = false, -- Should language servers be stopped when restoring a session. Can also be a function that will be called if set. Not called on autorestore from startup
  lazy_support = true, -- Automatically detect if Lazy.nvim is being used and wait until Lazy is done to make sure session is restored correctly. Does nothing if Lazy isn't being used
  legacy_cmds = true, -- Define legacy commands: Session*, Autosession (lowercase s), currently true. Set to false to prevent defining them

  ---@type SessionLens
  session_lens = {
    picker = nil, -- "telescope"|"snacks"|"fzf"|"select"|nil Pickers are detected automatically but you can also set one manually. Falls back to vim.ui.select
    load_on_setup = true, -- Only used for telescope, registers the telescope extension at startup so you can use :Telescope session-lens
    picker_opts = nil, -- Table passed to Telescope / Snacks / Fzf-Lua to configure the picker. See below for more information
    previewer = "summary", -- 'summary'|'active_buffer'|function - How to display session preview. 'summary' shows a summary of the session, 'active_buffer' shows the contents of the active buffer in the session, or a custom function

    ---@type SessionLensMappings
    mappings = {
      -- Mode can be a string or a table, e.g. {"i", "n"} for both insert and normal mode
      delete_session = { "i", "<C-d>" }, -- mode and key for deleting a session from the picker
      alternate_session = { "i", "<C-s>" }, -- mode and key for swapping to alternate session from the picker
      copy_session = { "i", "<C-y>" }, -- mode and key for copying a session from the picker
    },

    ---@type SessionControl
    session_control = {
      control_dir = vim.fn.stdpath("data") .. "/auto_session/", -- Auto session control dir, for control files, like alternating between two sessions with session-lens
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
        ---@diagnostic disable-next-line: undefined-field
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
      ---@diagnostic disable-next-line: undefined-field
      config.session_lens.picker_opts = config.session_lens.theme_conf
      config.session_lens.theme_conf = nil
    end

    ---@diagnostic disable-next-line: undefined-field
    if config.session_lens.shorten_path then
      M.has_old_config = true
      if not config.session_lens.picker_opts then
        config.session_lens.picker_opts = {}
      end
      config.session_lens.picker_opts.path_display = { "shorten" }
      config.session_lens.shorten_path = nil
    end

    ---@diagnostic disable-next-line: undefined-field
    if config.session_lens.path_display then
      M.has_old_config = true
      if not config.session_lens.picker_opts then
        config.session_lens.picker_opts = {}
      end
      ---@diagnostic disable-next-line: undefined-field
      config.session_lens.picker_opts.path_display = config.session_lens.path_display
      config.session_lens.path_display = nil
    end
  end
end

---@param config? AutoSession.Config
function M.setup(config)
  -- Clear the flag in case setup is called again
  M.has_old_config = false

  M.options_without_defaults = config and vim.deepcopy(config) or {}

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
      logger.warn("vim.o.sessionoptions is missing buffers. \nUse `:checkhealth autosession` for more info.")
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
      logger.warn("vim.o.sessionoptions is missing localoptions. \nUse `:checkhealth autosession` for more info.")
    end
    has_issues = true
  end

  if M.purge_after_minutes and vim.fn.has("nvim-0.10") ~= 1 then
    logger.warn("the purge_after_minutes options requires nvim >= 0.10")
    has_issues = true
  end

  if not M.git_use_branch_name and M.git_auto_restore_on_branch_change then
    logger.error("git_auto_restore_on_branch_change requires git_use_branch_name = true")
    has_issues = true
  end

  if M.single_session_mode and M.cwd_change_handling then
    logger.warn("single_session_mode and cwd_change_handling are conflicting options. Disabling single_session_mode.")
    M.single_session_mode = false
    has_issues = true
  end

  if
    M.session_lens
    and M.session_lens.load_on_setup
    and M.session_lens.picker
    and M.session_lens.picker ~= "telescope"
  then
    logger.warn('session_lens.load_on_setup is not used with pickers other than "telescope"')
    M.session_lens.load_on_setup = false
  end

  -- TODO: At some point, we should pop up a warning about old config if
  -- M.has_old_config but let's make sure everything is working well before doing that

  return has_issues
end

return setmetatable(M, {
  __index = function(_, key)
    if M.options == nil then
      M.setup()
      ---@cast M.options {}
    end
    return M.options[key]
  end,
  __newindex = function(_, key, value)
    if M.options == nil then
      M.setup()
      ---@cast M.options {}
    end
    M.options[key] = value
  end,
  __tostring = function(_)
    return vim.inspect(M.options)
  end,
})
