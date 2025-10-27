local Lib = require("auto-session.lib")
local Config = require("auto-session.config")
local AutoSession = require("auto-session")

local M = {}

---Calls lib function for completing session names with session dir
local function complete_session(arg_lead, cmd_line, cursor_pos)
  return Lib.complete_session_for_dir(AutoSession.get_root_dir(), arg_lead, cmd_line, cursor_pos)
end

--- Deletes sessions where the original directory no longer exists
local function purge_orphaned_sessions()
  local orphaned_sessions = {}

  local session_files = Lib.get_session_list(AutoSession.get_root_dir())
  for _, session in ipairs(session_files) do
    if
      not Lib.is_named_session(session.session_name)
      -- don't want any annotations (e.g. git branch)
      and vim.fn.isdirectory(session.display_name_component) == Lib._VIM_FALSE
    then
      Lib.logger.debug("purge: " .. session.session_name)
      table.insert(orphaned_sessions, session.session_name)
    end
  end

  if Lib.is_empty_table(orphaned_sessions) then
    Lib.logger.info("Nothing to purge")
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

local function setup_dirchanged_autocmds()
  if not Config.cwd_change_handling then
    Lib.logger.debug("cwd_change_handling is disabled, skipping setting DirChangedPre and DirChanged autocmd handling")
    return
  end

  vim.api.nvim_create_autocmd("DirChangedPre", {
    callback = function()
      Lib.logger.debug("DirChangedPre")
      Lib.logger.debug({
        cwd = vim.fn.getcwd(-1, -1),
        ---@diagnostic disable-next-line: undefined-field
        target = vim.v.event.directory,
        ["changed window"] = tostring(vim.v.event.changed_window),
        scope = vim.v.event.scope,
      })

      -- Don't want to save session if dir change was triggered
      -- by a window change. This will corrupt the session data,
      -- mixing the two different directory sessions
      if vim.v.event.changed_window then
        return
      end

      if AutoSession.restore_in_progress or vim.g.SessionLoad then
        Lib.logger.debug("DirChangedPre: restore_in_progress/vim.g.SessionLoad is true, ignoring this event")
        -- NOTE: We don't call the cwd_changed_hook here
        -- I think that's probably the right choice because I assume that event is mostly
        -- for preparing sessions for save/restoring but we don't want to do that when we're
        -- already restoring a session
        return
      end

      AutoSession.auto_save_session()
      AutoSession.run_cmds("pre_cwd_changed")

      -- Clear the current session, fixes #399
      vim.v.this_session = ""
    end,
    pattern = "global",
  })

  vim.api.nvim_create_autocmd("DirChanged", {
    callback = function()
      Lib.logger.debug("DirChanged")
      Lib.logger.debug("  cwd: " .. vim.fn.getcwd(-1, -1))
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
        Lib.logger.debug("DirChangedPre: restore_in_progress/vim.g.SessionLoad is true, ignoring this event")
        return
      end

      -- all buffers should've been deleted in `DirChangedPre`, something probably went wrong
      if Lib.has_open_buffers() then
        Lib.logger.debug("Cancelling session restore")
        return
      end

      -- If we're restoring a session with a terminal, we can get an
      -- "Invalid argument: buftype=terminal" error when restoring the
      -- session directly in this callback. To workaround, we schedule
      -- the restore for the next run of the event loop
      vim.schedule(function()
        AutoSession.auto_restore_session()
        AutoSession.run_cmds("post_cwd_changed")
      end)
    end,
    pattern = "global",
  })
end

local user_commands = {
  save = AutoSession.save_session,
  restore = AutoSession.restore_session,
  delete = AutoSession.delete_session,

  disable = AutoSession.disable_auto_save,
  enable = function()
    AutoSession.disable_auto_save(true)
  end,
  toggle = function()
    AutoSession.disable_auto_save(not Config.auto_save)
  end,

  purgeOrphaned = purge_orphaned_sessions,

  search = AutoSession.search,
  deletePicker = AutoSession.delete_picker,
}

local function user_command_completer(arg_lead, cmd_line, cursor_pos)
  -- Parse the command line to get the action
  local parts = vim.split(cmd_line, "%s+")
  local cmd = parts[2] -- First argument after command name

  -- If we're completing the action name itself
  if not cmd or #parts == 2 then
    local actions = {}
    for key, _ in pairs(user_commands) do
      if key:lower():find("^" .. arg_lead:lower()) then
        table.insert(actions, key)
      end
    end
    return actions
  end

  -- If we're completing arguments for specific actions, use old completers
  if cmd == "save" or cmd == "restore" or cmd == "delete" then
    return complete_session(arg_lead, cmd_line, cursor_pos)
  end

  -- No completion for other actions
  return {}
end

local function user_command_handler(args)
  local cmd = user_commands[args.fargs[1]]

  if cmd then
    cmd(args.fargs[2])
  else
    Lib.logger.error("Command not found: " .. args.fargs[1])
  end
end

---@private
---Setup autocmds (VimEnter, VimLeavePre, DirChanged*) and user commands
function M.setup_autocmds()
  -- Check if the auto-session plugin has already been loaded to prevent loading it twice
  if vim.g.loaded_auto_session ~= nil then
    return
  end
  vim.g.in_pager_mode = false

  vim.api.nvim_create_user_command("AutoSession", function(args)
    user_command_handler(args)
  end, {
    complete = user_command_completer,
    nargs = "+",
    desc = "AutoSession command handler",
  })

  if Config.legacy_cmds then
    vim.api.nvim_create_user_command("SessionSave", function(args)
      vim.notify('"SessionSave" is deprecated.\nUse "AutoSession save" instead')
      AutoSession.save_session(args.args)
    end, {
      complete = complete_session,
      bang = true,
      nargs = "?",
      desc = "Save session using current working directory as the session name or an optional session name",
    })

    vim.api.nvim_create_user_command("SessionRestore", function(args)
      vim.notify('"SessionRestore" is deprecated.\nUse "AutoSession restore" instead')
      AutoSession.restore_session(args.args)
    end, {
      complete = complete_session,
      bang = true,
      nargs = "?",
      desc = "Restore session using current working directory as the session name or an optional session name",
    })

    vim.api.nvim_create_user_command("SessionDelete", function(args)
      vim.notify('"SessionDelete" is deprecated.\nUse "AutoSession delete" instead')
      AutoSession.delete_session(args.args)
    end, {
      complete = complete_session,
      bang = true,
      nargs = "*",
      desc = "Delete session using the current working directory as the session name or an optional session name",
    })

    vim.api.nvim_create_user_command("SessionDisableAutoSave", function(args)
      vim.notify('"SessionDisableAutoSave" is deprecated.\nUse "AutoSession disable" instead')
      AutoSession.disable_auto_save(args.bang)
    end, {
      bang = true,
      desc = "Disable autosave. Enable with a !",
    })

    vim.api.nvim_create_user_command("SessionToggleAutoSave", function()
      vim.notify('"SessionToggleAutoSave" is deprecated.\nUse "AutoSession toggle" instead')
      AutoSession.disable_auto_save(not Config.auto_save)
    end, {
      bang = true,
      desc = "Toggle autosave",
    })

    vim.api.nvim_create_user_command("SessionPurgeOrphaned", function()
      vim.notify('"SessionPurgeOrphaned" is deprecated.\nUse "AutoSession purgeOrphaned" instead')
      purge_orphaned_sessions()
    end, { desc = "Remove all orphaned sessions with no directory left" })

    vim.api.nvim_create_user_command("SessionSearch", function()
      vim.notify('"SessionSearch" is deprecated.\nUse "AutoSession search" instead')
      AutoSession.Search()
    end, {
      desc = "Open a session picker",
    })

    vim.api.nvim_create_user_command("Autosession", function(args)
      if args.args:match("search") then
        vim.notify('"Autosession search" (lowercase "s") is deprecated.\nUse "AutoSession search" instead')
        AutoSession.Search()
      elseif args.args:match("delete") then
        vim.notify('"Autosession delete" (lowercase "s") is deprecated.\nUse "AutoSession search" instead')
        AutoSession.DeletePicker()
      end
    end, {
      complete = function(_, _, _)
        return { "search", "delete" }
      end,
      nargs = 1,
    })
  end

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
        Lib.logger.debug("In pager mode, skipping auto restore")
        AutoSession.run_cmds("no_restore")
        return
      end

      if not Config.lazy_support then
        -- If auto_restore_lazy_delay_enabled is false, just restore the session as normal
        AutoSession.start()
        return
      end

      -- Not in pager mode, auto_restore_lazy_delay_enabled is true, check for Lazy
      local ok, lazy_view = pcall(require, "lazy.view")
      if not ok then
        -- No Lazy, load as usual
        AutoSession.start()
        return
      end

      if not lazy_view.visible or not lazy_view.visible() or not lazy_view.view then
        -- Lazy isn't visible, load as usual
        Lib.logger.debug("Lazy is loaded, but not visible, will try to restore session")
        AutoSession.start()
        return
      end

      -- If the Lazy window is visible, hold onto it for later
      lazy_view_win = lazy_view.view.win
      Lib.logger.debug("Lazy window is still visible, waiting for it to close")
    end,
  })

  vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
    group = group,
    pattern = "*",
    callback = function()
      -- If we're in pager mode or we're in a subprocess, don't save on exit
      if not vim.g.in_pager_mode and not vim.env.NVIM then
        AutoSession.auto_save_session()
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
          Lib.logger.debug("A window was closed but it was not Lazy, keep waiting")
          return
        end

        Lib.logger.debug("Lazy window was closed, restore the session!")

        -- Clear lazy_view_win so we stop processing future WinClosed events
        lazy_view_win = nil
        -- Schedule restoration for the next pass in the event loop to time for the window to close
        -- Not doing this could create a blank buffer in the restored session
        vim.schedule(function()
          AutoSession.start()
        end)
      end,
    })
  end

  setup_dirchanged_autocmds()

  if Config.session_lens.load_on_setup then
    -- calling is_available will trigger loading the extension
    require("auto-session.pickers.telescope").is_available()
  end
end

return M
