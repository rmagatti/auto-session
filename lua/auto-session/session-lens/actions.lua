local Lib = require "auto-session.lib"

local M = {
  conf = {},
  functions = {},
}

function M.setup(config, functions)
  M.conf = vim.tbl_deep_extend("force", config, M.conf)
  M.functions = functions
end

local function get_alternate_session()
  local filepath = M.conf.session_control.control_dir .. M.conf.session_control.control_filename

  if vim.fn.filereadable(filepath) == 1 then
    local content = vim.fn.readfile(filepath)[1] or "{}"
    local json = vim.json.decode(content) or {} -- should never hit the or clause since we're defaulting to a string for content

    local sessions = {
      current = json.current,
      alternate = json.alternate,
    }

    Lib.logger.debug("get_alternate_session", { sessions = sessions, content = content })

    if sessions.current ~= sessions.alternate then
      return sessions.alternate
    end

    Lib.logger.info "Current session is the same as alternate!"
  end
end

local function source_session(selection, prompt_bufnr)
  if prompt_bufnr then
    local actions = require "telescope.actions"
    actions.close(prompt_bufnr)
  end

  vim.defer_fn(function()
    if -- type(AutoSession.conf.cwd_change_handling) == "table"
      -- and not vim.tbl_isempty(AutoSession.conf.cwd_change_handling or {})
      -- and AutoSession.conf.cwd_change_handling.restore_upcoming_session
      -- FIXME: Trying to check if cwd_change_handling properties are set, but something is wrong here.
      false
    then
      -- Take advatage of cwd_change_handling behaviour for switching sessions
      Lib.logger.debug "Triggering vim.fn.chdir since cwd_change_handling feature is enabled"
      vim.fn.chdir(M.functions.format_file_name(type(selection) == "table" and selection.filename or selection))
    else
      Lib.logger.debug "Triggering session-lens behaviour since cwd_change_handling feature is disabled"
      M.functions.AutoSaveSession()
      vim.cmd "%bd!"
      vim.cmd "clearjumps"
      M.functions.RestoreSession(type(selection) == "table" and selection.path or selection)
    end
  end, 50)
end

---Source session action
---Source a selected session after doing proper current session saving and cleanup
---@param prompt_bufnr number the telescope prompt bufnr
M.source_session = function(prompt_bufnr)
  local action_state = require "telescope.actions.state"
  local selection = action_state.get_selected_entry()
  source_session(selection, prompt_bufnr)
end

---Delete session action
---Delete a selected session file
---@param prompt_bufnr number the telescope prompt bufnr
M.delete_session = function(prompt_bufnr)
  local action_state = require "telescope.actions.state"
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  current_picker:delete_selection(function(selection)
    M.functions.DeleteSession(selection.path)
  end)
end

M.alternate_session = function(prompt_bufnr)
  local alternate_session = get_alternate_session()

  if not alternate_session then
    Lib.logger.info "There is no alternate session to navigate to, aborting operation"

    if prompt_bufnr then
      actions.close(prompt_bufnr)
    end

    return
  end

  source_session(alternate_session, prompt_bufnr)
end

--TODO: figure out the whole file placeholder parsing, expanding, escaping issue!!
---ex:
---"/Users/ronnieandrewmagatti/.local/share/nvim/sessions//%Users%ronnieandrewmagatti%Projects%dotfiles.vim",
---"/Users/ronnieandrewmagatti/.local/share/nvim/sessions/%Users%ronnieandrewmagatti%Projects%auto-session.vim"
---"/Users/ronnieandrewmagatti/.local/share/nvim/sessions/\\%Users\\%ronnieandrewmagatti\\%Projects\\%auto-session.vim"

return M
