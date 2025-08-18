local Config = require "auto-session.config"
local Lib = require "auto-session.lib"
local AutoSession = require "auto-session"

local function is_available()
  local success, snacks_picker_enabled = pcall(function()
    ---@diagnostic disable-next-line: undefined-field
    return Snacks.config.picker.enabled
  end)
  return success and snacks_picker_enabled
end

local function open_session_picker()
  local mappings = Config.session_lens.mappings or {}

  -- If layout is nil or empty, default to select preset
  local layout = Config.session_lens.picker_opts or {}
  if vim.tbl_isempty(layout) then
    layout = { preset = "select" }
  end

  Snacks.picker.pick {
    title = "Sessions",
    finder = function()
      return Lib.get_session_list(AutoSession.get_root_dir())
    end,
    format = "text",
    transform = function(item)
      item.text = item.display_name
      item.file = item.path
    end,
    layout = layout,
    win = {
      input = {
        keys = {
          ["dd"] = "session_delete",
          [mappings.delete_session[2]] = { "session_delete", mode = mappings.delete_session[1] },
          [mappings.alternate_session[2]] = { "session_alternate", mode = mappings.alternate_session[1] },
          [mappings.copy_session[2]] = { "session_copy", mode = mappings.copy_session[1] },
        },
      },
      list = { keys = { ["dd"] = "session_delete" } },
    },
    actions = {
      confirm = function(picker, item)
        picker:close()
        vim.schedule(function()
          AutoSession.autosave_and_restore(item.session_name)
        end)
      end,
      session_delete = function(picker, item)
        vim.schedule(function()
          AutoSession.DeleteSessionFile(item.path, item.display_name)
          picker:find() -- refresh picker
        end)
      end,
      session_alternate = function(picker, _)
        vim.schedule(function()
          local altername_session_name = Lib.get_alternate_session_name(Config.session_lens.session_control)
          if not altername_session_name then
            return
          end
          picker:close()
          vim.defer_fn(function()
          local alternate_session_name = Lib.get_alternate_session_name(Config.session_lens.session_control)
          if not alternate_session_name then
            return
          end
          picker:close()
          vim.defer_fn(function()
            AutoSession.autosave_and_restore(alternate_session_name)
          end, 50)
        end)
      end,
      session_copy = function(picker, item)
        vim.schedule(function()
          local new_name = vim.fn.input("New session name: ", item.text)
          if not new_name or new_name == "" or new_name == item.text then
            return
          end
          local content = vim.fn.readfile(item.path)
          vim.fn.writefile(content, AutoSession.get_root_dir() .. Lib.escape_session_name(new_name) .. ".vim")
          picker:find() -- refresh picker
        end)
      end,
    },
  }
end

---@type Picker
local M = {
  is_available = is_available,
  open_session_picker = open_session_picker,
}

return M
