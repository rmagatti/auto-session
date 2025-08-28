local Config = require("auto-session.config")
local Lib = require("auto-session.lib")
local AutoSession = require("auto-session")

local function is_available()
  if vim.fn.exists(":FzfLua") ~= 2 then
    return false
  end

  local ok, fzf = pcall(require, "fzf-lua")
  return ok and fzf
end

---Find the session for the display name
---@param selected table But we only consider the first element
---@return table|nil
local function find_session_by_display_name(selected)
  if not selected or #selected == 0 then
    Lib.logger.error("No session selected?")
    return
  end

  -- no metadata with Fzf, so have to find the session by display_name
  local sessions = Lib.get_session_list(AutoSession.get_root_dir())
  for _, session in ipairs(sessions) do
    if session.display_name == selected[1] then
      return session
    end
  end

  Lib.logger.error("Couldn't find selected session: " .. selected[1])
end

local function on_session_selected(selected)
  local session = find_session_by_display_name(selected)
  if not session then
    return
  end

  vim.defer_fn(function()
    AutoSession.autosave_and_restore(session.session_name)
  end, 50)
end

local function on_session_deleted(selected)
  local session = find_session_by_display_name(selected)
  if not session then
    return
  end

  AutoSession.DeleteSessionFile(session.path, session.display_name)
end

local function on_alternate_session(_)
  vim.schedule(function()
    local alternate_session_name = Lib.get_alternate_session_name(Config.session_lens.session_control)
    if alternate_session_name then
      AutoSession.autosave_and_restore(alternate_session_name)
    end
  end)
end

local function on_copy_session(selected)
  local session = find_session_by_display_name(selected)
  if not session then
    return
  end

  local new_name = vim.fn.input("New session name: ", selected[1])
  if not new_name or new_name == "" or new_name == selected[1] then
    return
  end
  local content = vim.fn.readfile(session.path)
  vim.fn.writefile(content, AutoSession.get_root_dir() .. Lib.escape_session_name(new_name) .. ".vim")
end

---Map Vim-style modifier keys to fzf-lua notation
---@param config_keymap? string|table|nil Mapping from Config.session_lens.mappings
---@return string # keymap suitable for fzf-lua
local function config_to_fzf_key_binding(config_keymap)
  if not config_keymap then
    return ""
  end

  -- only support insert mode keymaps for now
  local key = type(config_keymap) == "table" and config_keymap[2] or config_keymap

  ---@cast key string

  key = key:gsub("<[cC]%-", "ctrl-")
  key = key:gsub("<[sS]%-", "shift-")
  key = key:gsub("<[aA]%-", "alt-")
  key = key:gsub("<[mM]%-", "alt-")

  -- Remove angle brackets
  key = key:gsub("[<>]", "")

  return key
end

local function open_session_picker()
  local fzf_lua = require("fzf-lua")
  local keymaps = Config.session_lens.mappings or {}

  fzf_lua.fzf_exec(function(fzf_cb)
    local sessions = Lib.get_session_list(AutoSession.get_root_dir())
    for _, session in ipairs(sessions) do
      fzf_cb(session.display_name)
    end
    fzf_cb()
  end, {
    fzf_opts = {
      ["--prompt"] = "Sessions> ",
    },
    _headers = { "actions" },
    actions = {
      ["default"] = on_session_selected,
      [config_to_fzf_key_binding(keymaps.delete_session)] = {
        on_session_deleted,
        require("fzf-lua").actions.resume,
        header = "delete",
      },
      [config_to_fzf_key_binding(keymaps.alternate_session)] = {
        on_alternate_session,
        header = "alternate",
      },
      [config_to_fzf_key_binding(keymaps.copy_session)] = {
        on_copy_session,
        require("fzf-lua").actions.resume,
        header = "copy",
      },
    },
    winopts = Config.session_lens.picker_opts,
  })
end

---@type Picker
local M = {
  is_available = is_available,
  open_session_picker = open_session_picker,
}

return M
