local Lib = require "auto-session.lib"
local Config = require "auto-session.config"
local SessionLens -- will be initialized later

---@mod auto-session.commands Commands
---@brief [[
---This plugin provides the following commands:
---
---  `:SessionSave` - saves a session based on the `cwd` in `root_dir`
---  `:SessionSave my_session` - saves a session called `my_session` in `root_dir`
---
---  `:SessionRestore` - restores a session based on the `cwd` from `root_dir`
---  `:SessionRestore my_session` - restores `my_session` from `root_dir`
---
---  `:SessionDelete` - deletes a session based on the `cwd` from `root_dir`
---  `:SessionDelete my_session` - deletes `my_sesion` from `root_dir`
---
---  `:SessionDisableAutoSave` - disables autosave
---  `:SessionDisableAutoSave!` - enables autosave (still does all checks in the config)
---  `:SessionToggleAutoSave` - toggles autosave
---
---  `:SessionPurgeOrphaned` - removes all orphaned sessions with no working directory left.
---
---  `:SessionSearch` - open a session picker, uses Telescope if installed, vim.ui.select otherwise
---@brief ]]

local M = {}

---Calls lib function for completeing session names with session dir
local function complete_session(ArgLead, CmdLine, CursorPos)
  return Lib.complete_session_for_dir(M.AutoSession.get_root_dir(), ArgLead, CmdLine, CursorPos)
end

---@private
---@class PickerItem
---@field session_name string
---@field display_name string
---@field path string

---@return PickerItem[]
local function get_session_files()
  local files = {}
  local sessions_dir = M.AutoSession.get_root_dir()

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
      M.AutoSession.autosave_and_restore(choice.session_name)
    end)
  elseif data.args:match "delete" then
    open_picker(files, "Delete a session:", function(choice)
      M.AutoSession.DeleteSessionFile(choice.path, choice.display_name)
    end)
  end
end

--- Deletes sessions where the original directory no longer exists
local function purge_orphaned_sessions()
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
    local session_path = string.format("%s/%s.vim", M.AutoSession.get_root_dir(), escaped_session)
    Lib.logger.debug("purging: " .. session_path)
    vim.fn.delete(Lib.expand(session_path))
  end
end

---@private
---Make sure session_lens is setup. Ok to call multiple times
local function setup_session_lens()
  if SessionLens then
    return true
  end

  local has_telescope, telescope = pcall(require, "telescope")

  if not has_telescope then
    Lib.logger.info "Telescope.nvim is not installed. Session Lens cannot be setup!"
    return false
  end

  SessionLens = require "auto-session.session-lens"
  -- Register session-lens as an extension so :Telescope will complete on session-lens
  telescope.load_extension "session-lens"
  return true
end

local function setup_dirchanged_autocmds(AutoSession)
  if not Config.cwd_change_handling then
    Lib.logger.debug "cwd_change_handling is disabled, skipping setting DirChangedPre and DirChanged autocmd handling"
    return
  end

  vim.api.nvim_create_autocmd("DirChangedPre", {
    callback = function()
      Lib.logger.debug "DirChangedPre"
      Lib.logger.debug {
        cwd = vim.fn.getcwd(),
        target = vim.v.event.directory,
        ["changed window"] = tostring(vim.v.event.changed_window),
        scope = vim.v.event.scope,
      }

      -- Don't want to save session if dir change was triggered
      -- by a window change. This will corrupt the session data,
      -- mixing the two different directory sessions
      if vim.v.event.changed_window then
        return
      end

      if AutoSession.restore_in_progress or vim.g.SessionLoad then
        Lib.logger.debug "DirChangedPre: restore_in_progress/vim.g.SessionLoad is true, ignoring this event"
        -- NOTE: We don't call the cwd_changed_hook here
        -- I think that's probably the right choice because I assume that event is mostly
        -- for preparing sessions for save/restoring but we don't want to do that when we're
        -- already restoring a session
        return
      end

      AutoSession.AutoSaveSession()
      AutoSession.run_cmds "pre_cwd_changed"
    end,
    pattern = "global",
  })

  vim.api.nvim_create_autocmd("DirChanged", {
    callback = function()
      Lib.logger.debug "DirChanged"
      Lib.logger.debug("  cwd: " .. vim.fn.getcwd())
      Lib.logger.debug("  changed window: " .. tostring(vim.v.event.changed_window))
      Lib.logger.debug("  scope: " .. vim.v.event.scope)

      -- see above
      if vim.v.event.changed_window then
        return
      end

      if AutoSession.restore_in_progress or vim.g.SessionLoad then
        -- NOTE: We don't call the cwd_changed_hook here (or in the other case below)
        -- I think that's probably the right choice because I assume that event is mostly
        -- for preparing sessions for save/restoring but we don't want to do that when we're
        -- already restoring a session
        Lib.logger.debug "DirChangedPre: restore_in_progress/vim.g.SessionLoad is true, ignoring this event"
        return
      end

      -- all buffers should've been deleted in `DirChangedPre`, something probably went wrong
      if Lib.has_open_buffers() then
        Lib.logger.debug "Cancelling session restore"
        return
      end

      local success = AutoSession.AutoRestoreSession()

      if not success then
        Lib.logger.info("Could not load session for: " .. vim.fn.getcwd())
        -- Don't return, still dispatch the hook below
      end

      AutoSession.run_cmds "post_cwd_changed"
    end,
    pattern = "global",
  })
end

---@private
---Setup autocmds for DirChangedPre and DirChanged
---@param AutoSession table auto session instance
function M.setup_autocmds(AutoSession)
  -- Check if the auto-session plugin has already been loaded to prevent loading it twice
  if vim.g.loaded_auto_session ~= nil then
    return
  end

  -- Set here to avoid req
  M.AutoSession = AutoSession

  -- Initialize variables
  vim.g.in_pager_mode = false

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
    return AutoSession.DisableAutoSave(not Config.auto_save)
  end, {
    bang = true,
    desc = "Toggle autosave",
  })

  vim.api.nvim_create_user_command("SessionSearch", function()
    -- If Telescope is installed, use that otherwise use vim.ui.select
    if setup_session_lens() and SessionLens then
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
    purge_orphaned_sessions,
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
        Lib.logger.debug "In pager mode, skipping auto restore"
        AutoSession.run_cmds "no_restore"
        return
      end

      if not Config.lazy_support then
        -- If auto_restore_lazy_delay_enabled is false, just restore the session as normal
        AutoSession.auto_restore_session_at_vim_enter()
        return
      end

      -- Not in pager mode, auto_restore_lazy_delay_enabled is true, check for Lazy
      local ok, lazy_view = pcall(require, "lazy.view")
      if not ok then
        -- No Lazy, load as usual
        AutoSession.auto_restore_session_at_vim_enter()
        return
      end

      if not lazy_view.visible() then
        -- Lazy isn't visible, load as usual
        Lib.logger.debug "Lazy is loaded, but not visible, will try to restore session"
        AutoSession.auto_restore_session_at_vim_enter()
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

  if Config.lazy_support then
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
          AutoSession.auto_restore_session_at_vim_enter()
        end)
      end,
    })
  end

  setup_dirchanged_autocmds(AutoSession)

  if Config.session_lens.load_on_setup then
    Lib.logger.debug "Loading session lens"
    setup_session_lens()
  end
end

return M
