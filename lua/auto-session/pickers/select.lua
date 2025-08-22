local Lib = require "auto-session.lib"
local AutoSession = require "auto-session"

local function is_available()
  return true
end

---@private
---@class PickerItem
---@field session_name string
---@field display_name string
---@field path string

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

---Opens a vim.ui.select picker for loading sessions
local function open_session_picker()
  local files = Lib.get_session_list(AutoSession.get_root_dir())
  open_picker(files, "Select a session:", function(choice)
    -- Defer session loading function to fix issue with Fzf and terminal sessions:
    -- https://github.com/rmagatti/auto-session/issues/391
    vim.defer_fn(function()
      AutoSession.autosave_and_restore(choice.session_name)
    end, 50)
  end)
end

---Opens a vim.ui.select picker for deleting sessions
local function open_delete_picker()
  local files = Lib.get_session_list(AutoSession.get_root_dir())
  open_picker(files, "Delete a session:", function(choice)
    AutoSession.DeleteSessionFile(choice.path, choice.display_name)
  end)
end

---@type Picker
local M = {
  is_available = is_available,
  open_session_picker = open_session_picker,
  open_delete_picker = open_delete_picker,
}

return M
