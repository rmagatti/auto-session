local AutoSession = require "auto-session"
local Config = require "auto-session.config"
local Lib = require "auto-session.lib"

local uv = vim.uv or vim.loop

local M = {}

M.uv_git_watcher = nil

function M.on_git_watch_event(cwd, current_branch)
  local new_branch = Lib.get_git_branch_name(cwd)

  if new_branch == current_branch then
    return
  end

  Lib.logger.debug "Git: branch changed!"

  -- need to save session for existing branch but can't use normal flow since
  -- the branch name has already changed so we make the session name here and pass it in

  -- NOTE: Generating the session name this way won't work with named sessions but we
  -- don't support named sessions + git branch names together anyway

  if Config.auto_save then
    local session_name = Lib.combine_session_name_with_git_branch(cwd, current_branch)
    AutoSession.SaveSession(session_name)
  end

  if Lib.has_modified_buffers() then
    vim.ui.select({ "Yes", "No" }, {
      prompt = 'Unsaved changes! Really restore session for branch: "' .. new_branch .. '"?',
      format_item = function(item)
        return item
      end,
    }, function(choice)
      if choice == "Yes" then
        AutoSession.AutoRestoreSession()
      else
        AutoSession.DisableAutoSave()
        vim.notify(
          "Session restore cancelled. Auto-save disabled.\nAfter saving your changes, run :SessionRestore\nto load the session for branch: "
            .. new_branch
        )
      end
    end)
  else
    -- No modified buffers, proceed with auto-restore
    AutoSession.AutoRestoreSession()
  end
end

---Watch for git branch changes
---@param cwd string current working directory
---@param towatch string file to watch, should be something like .git/HEAD
function M.start_watcher(cwd, towatch)
  if M.uv_git_watcher then
    M.uv_git_watcher:stop()
    Lib.logger.debug "Git: stopped old watcher so we can start a new one"
  end

  M.uv_git_watcher = assert(uv.new_fs_event())
  local current_branch = Lib.get_git_branch_name(cwd)

  Lib.logger.debug("Git: starting watcher", { cwd, current_branch })

  -- Watch .git/HEAD to detect branch changes
  M.uv_git_watcher:start(towatch, {}, function(err)
    if err then
      vim.schedule(function()
        Lib.logger.err "Error watching for git branch changes"
      end)
      return
    end

    vim.schedule(function()
      M.on_git_watch_event(cwd, current_branch)

      -- git often (always?) replaces .git/HEAD which can change the inode being
      -- watched so we need to stop the current watcher and start another one to
      -- make sure we keep getting future events
      M.start_watcher(cwd, towatch)
    end)
  end)
end

function M.stop_watcher()
  if not M.uv_git_watcher then
    return
  end

  M.uv_git_watcher:stop()
  Lib.logger.debug "Git: stopped watcher"
  M.uv_git_watcher = nil
end

return M
