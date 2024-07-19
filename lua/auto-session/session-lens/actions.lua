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
    local json = Lib.load_session_control_file(filepath)

    local sessions = {
      current = json.current,
      alternate = json.alternate,
    }

    Lib.logger.debug("get_alternate_session", { sessions = sessions, json = json })

    if sessions.current ~= sessions.alternate then
      return sessions.alternate
    end

    Lib.logger.info "Current session is the same as alternate!"
  end
end

local function source_session(path, prompt_bufnr)
  if prompt_bufnr then
    local actions = require "telescope.actions"
    actions.close(prompt_bufnr)
  end

  vim.defer_fn(function()
    M.functions.autosave_and_restore(path)
  end, 50)
end

---Source session action
---Source a selected session after doing proper current session saving and cleanup
---@param prompt_bufnr number the telescope prompt bufnr
M.source_session = function(prompt_bufnr)
  local action_state = require "telescope.actions.state"
  local selection = action_state.get_selected_entry()
  source_session(Lib.unescape_path(selection.filename), prompt_bufnr)
end

---Delete session action
---Delete a selected session file
---@param prompt_bufnr number the telescope prompt bufnr
M.delete_session = function(prompt_bufnr)
  local action_state = require "telescope.actions.state"
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  current_picker:delete_selection(function(selection)
    M.functions.DeleteSession(Lib.unescape_path(selection.filename), prompt_bufnr)
  end)
end

M.alternate_session = function(prompt_bufnr)
  local alternate_session = get_alternate_session()

  if not alternate_session then
    vim.notify "There is no alternate session"
    -- Keep the picker open in case they want to select a session to load
    return
  end

  source_session(M.functions.Lib.get_session_name_from_path(alternate_session), prompt_bufnr)
end

return M
