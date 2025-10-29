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

  -- Defer session loading function to fix issue with Fzf and terminal sessions:
  -- https://github.com/rmagatti/auto-session/issues/391
  vim.defer_fn(function()
    AutoSession.autosave_and_restore(session.session_name)
  end, 50)
end

local function on_session_deleted(selected)
  local session = find_session_by_display_name(selected)
  if not session then
    return
  end

  AutoSession.delete_session_file(session.path, session.display_name)
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
  local keymaps = Config.session_lens.mappings or {}

  local fzf_lua = require("fzf-lua")
  local fzf_path = require("fzf-lua.path")

  local previewer
  local preview

  if Config.session_lens.previewer == "active_buffer" then
    --- NOTE: I don't think fzf lets us set arbitrary file types on the previewer buf
    --- so we special case active_buffer and subclass the builtin buffer_or_file

    -- Subclass default buffer_or_file previewer
    local SessionPreviewer = require("fzf-lua.previewer.builtin").buffer_or_file:extend()

    -- Translate from session display name to session file name for preview
    function SessionPreviewer:entry_to_file(entry_str)
      local session = find_session_by_display_name({ entry_str })

      if not session or not session.path then
        return nil
      end

      local summary = Lib.create_session_summary(session.path)
      if not summary or not summary.current_buffer then
        return nil
      end

      local file_name = Lib.resolve_filename_path(summary.current_buffer, summary.cwd)

      ---@diagnostic disable-next-line: undefined-field
      return fzf_path.entry_to_file(file_name, self.opts)
    end

    previewer = {
      _ctor = function()
        return SessionPreviewer:new()
      end,
    }
  else
    preview = function(items)
      if not items or #items == 0 then
        return ""
      end

      local session = find_session_by_display_name({ items[1] })
      if not session or not session.path then
        return "No session found"
      end

      local preview_lines = Lib.get_session_preview(session.path, Config.session_lens.previewer)
      if not preview_lines then
        return "No preview available"
      end

      return table.concat(preview_lines, "\n")
    end
  end

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
        fn = on_session_deleted,
        header = "delete",
        reload = true,
      },
      [config_to_fzf_key_binding(keymaps.alternate_session)] = {
        fn = on_alternate_session,
        header = "alternate",
      },
      [config_to_fzf_key_binding(keymaps.copy_session)] = {
        fn = on_copy_session,
        header = "copy",
        reload = true,
      },
    },
    winopts = vim.tbl_extend("force", {
      preview = {
        hidden = true,
      },
    }, Config.session_lens.picker_opts or {}),

    -- for previews where we set the lines directly
    preview = preview,

    -- for previews that use a filename
    previewer = previewer,
  })
end

---@type Picker
local M = {
  is_available = is_available,
  open_session_picker = open_session_picker,
}

return M
