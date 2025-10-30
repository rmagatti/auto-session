local AutoSession = require("auto-session")
local Config = require("auto-session.config")
local Lib = require("auto-session.lib")
local transform_mod = require("telescope.actions.mt").transform_mod

local M = {}

local function source_session(session_name, prompt_bufnr)
  if prompt_bufnr then
    local actions = require("telescope.actions")
    actions.close(prompt_bufnr)
  end

  vim.defer_fn(function()
    AutoSession.autosave_and_restore(session_name)
  end, 50)
end

---@private
---Source session action
---Source a selected session after doing proper current session saving and cleanup
---@param prompt_bufnr number the telescope prompt bufnr
M.source_session = function(prompt_bufnr)
  local action_state = require("telescope.actions.state")
  local selection = action_state.get_selected_entry()
  if selection then
    source_session(selection.value, prompt_bufnr)
  end
end

---@private
---Delete session action
---Delete a selected session file
---@param prompt_bufnr number the telescope prompt bufnr
M.delete_session = function(prompt_bufnr)
  local action_state = require("telescope.actions.state")
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  current_picker:delete_selection(function(selection)
    if selection then
      AutoSession.delete_session_file(selection.path, selection.display())
    end
  end)
end

---@private
M.alternate_session = function(prompt_bufnr)
  local alternate_session_name = Lib.get_alternate_session_name(Config.session_lens.session_control)
  if not alternate_session_name then
    vim.notify("There is no alternate session")
    -- Keep the picker open in case they want to select a session to load
    return
  end

  source_session(alternate_session_name, prompt_bufnr)
end

---@private
---Copy session action
---Ask user for the new name and then copy the session to that name
M.copy_session = function(_)
  local action_state = require("telescope.actions.state")
  local selection = action_state.get_selected_entry()

  local new_name = vim.fn.input("New session name: ", selection.session_name)

  if not new_name or new_name == "" then
    return
  end

  local content = vim.fn.readfile(selection.path)
  vim.fn.writefile(content, AutoSession.get_root_dir() .. Lib.escape_session_name(new_name) .. ".vim")
end

return transform_mod(M)
