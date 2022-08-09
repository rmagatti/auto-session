local AutoSession = require("auto-session")
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")

local SessionLensActions = {}

---Source session action
---Source a selected session after doing proper current session saving and cleanup
---@param prompt_bufnr number the telescope prompt bufnr
SessionLensActions.source_session = function(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  actions.close(prompt_bufnr)

  vim.defer_fn(function()
    if AutoSession.conf.cwd_change_handling then
      vim.fn.chdir(AutoSession.format_file_name(selection.filename))
    else
      AutoSession.AutoSaveSession()
      vim.cmd("%bd!")
      vim.cmd("clearjumps")
      AutoSession.RestoreSession(selection.path)
    end
  end, 50)
end

---Delete session action
---Delete a selected session file
---@param prompt_bufnr number the telescope prompt bufnr
SessionLensActions.delete_session = function(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  current_picker:delete_selection(function(selection)
    AutoSession.DeleteSession(selection.path)
  end)
end

return SessionLensActions

