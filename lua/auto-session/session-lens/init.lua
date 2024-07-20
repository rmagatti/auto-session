local Actions = require "auto-session.session-lens.actions"
local AutoSession = require "auto-session"
local Lib = AutoSession.Lib

----------- Setup ----------
local SessionLens = {
  conf = {},
}

---Session Lens Config
---@class session_lens_config
---@field shorten_path boolean Deprecated, pass { 'shorten' } to path_display
---@field path_display table An array that specifies how to handle paths. Read :h telescope.defaults.path_display
---@field theme_conf table
---@field buftypes_to_ignore table Deprecated, if you're using this please report your usage on github
---@field previewer boolean
---@field session_control session_control
---@field load_on_setup boolean

---@type session_lens_config
---@diagnostic disable-next-line: missing-fields
local defaultConf = {
  theme_conf = {},
  previewer = false,
  buftypes_to_ignore = {},
}

-- Set default config on plugin load
SessionLens.conf = defaultConf

function SessionLens.setup()
  SessionLens.conf = vim.tbl_deep_extend("force", SessionLens.conf, AutoSession.conf.session_lens)

  if SessionLens.conf.buftypes_to_ignore ~= nil and not vim.tbl_isempty(SessionLens.conf.buftypes_to_ignore) then
    Lib.logger.warn "buftypes_to_ignore is deprecated. If you think you need this option, please file a bug on GitHub. If not, please remove it from your config"
  end
end

local function make_telescope_callback(opts)
  -- We don't want the trailing separator because plenary will add one
  local session_root_dir = AutoSession.get_root_dir(false)
  local path = require "plenary.path"
  return function(file_name)
    -- Don't include <session>x.vim files that nvim makes for custom user
    -- commands
    if not Lib.is_session_file(session_root_dir, file_name) then
      return nil
    end

    -- the name of the session, to be used for restoring/deleting
    local session_name

    -- the name to display, possibly with a shortened path
    local display_name

    -- an annotation about the sesssion, added to display_name after any path processing
    local annotation = ""
    if Lib.is_legacy_file_name(file_name) then
      session_name = (Lib.legacy_unescape_session_name(file_name):gsub("%.vim$", ""))
      display_name = session_name
      annotation = " (legacy)"
    else
      session_name = Lib.escaped_session_name_to_session_name(file_name)
      display_name = session_name
      local name_components = Lib.get_session_display_name_as_table(file_name)
      if #name_components > 1 then
        display_name = name_components[1]
        annotation = " " .. name_components[2]
      end
    end

    if opts.path_display and vim.tbl_contains(opts.path_display, "shorten") then
      display_name = path:new(display_name):shorten()
      if not display_name then
        display_name = session_name
      end
    end
    display_name = display_name .. annotation

    return {
      ordinal = session_name,
      value = session_name,
      filename = file_name,
      cwd = session_root_dir,
      display = display_name,
      path = path:new(session_root_dir, file_name):absolute(),
    }
  end
end

---Search session
---Triggers the customized telescope picker for switching sessions
---@param custom_opts any
SessionLens.search_session = function(custom_opts)
  local themes = require "telescope.themes"
  local telescope_actions = require "telescope.actions"

  custom_opts = (vim.tbl_isempty(custom_opts or {}) or custom_opts == nil) and SessionLens.conf or custom_opts

  -- Use auto_session_root_dir from the Auto Session plugin
  local session_root_dir = AutoSession.get_root_dir()

  if custom_opts.shorten_path ~= nil then
    Lib.logger.warn "`shorten_path` config is deprecated, use the new `path_display` config instead"
    if custom_opts.shorten_path then
      custom_opts.path_display = { "shorten" }
    else
      custom_opts.path_display = nil
    end

    custom_opts.shorten_path = nil
  end

  local theme_opts = themes.get_dropdown(custom_opts.theme_conf)

  -- -- Ignore last session dir on finder if feature is enabled
  -- if AutoSession.conf.auto_session_enable_last_session then
  --   if AutoSession.conf.auto_session_last_session_dir then
  --     local last_session_dir = AutoSession.conf.auto_session_last_session_dir:gsub(cwd, "")
  --     custom_opts["file_ignore_patterns"] = { last_session_dir }
  --   end
  -- end

  -- Use default previewer config by setting the value to nil if some sets previewer to true in the custom config.
  -- Passing in the boolean value errors out in the telescope code with the picker trying to index a boolean instead of a table.
  -- This fixes it but also allows for someone to pass in a table with the actual preview configs if they want to.
  if custom_opts.previewer ~= false and custom_opts.previewer == true then
    custom_opts["previewer"] = nil
  end

  local opts = {
    prompt_title = "Sessions",
    entry_maker = make_telescope_callback(custom_opts),
    cwd = session_root_dir,
    attach_mappings = function(_, map)
      telescope_actions.select_default:replace(Actions.source_session)
      map("i", "<c-d>", Actions.delete_session)
      map("i", "<c-s>", Actions.alternate_session)
      map("i", "<c-a>", Actions.alternate_session)
      return true
    end,
  }
  opts = vim.tbl_deep_extend("force", opts, theme_opts, custom_opts or {})

  local find_command = (function()
    if opts.find_command then
      if type(opts.find_command) == "function" then
        return opts.find_command(opts)
      end
      return opts.find_command
    elseif 1 == vim.fn.executable "rg" then
      return { "rg", "--files", "--color", "never" }
    elseif 1 == vim.fn.executable "fd" then
      return { "fd", "--type", "f", "--color", "never" }
    elseif 1 == vim.fn.executable "fdfind" then
      return { "fdfind", "--type", "f", "--color", "never" }
    elseif 1 == vim.fn.executable "find" and vim.fn.has "win32" == 0 then
      return { "find", ".", "-type", "f" }
    elseif 1 == vim.fn.executable "cmd" and vim.fn.has "win32" == 1 then
      return { "cmd", "/C", "dir", "/b" }
    end
  end)()

  local finders = require "telescope.finders"
  local conf = require("telescope.config").values
  require("telescope.pickers")
    .new(opts, {
      finder = finders.new_oneshot_job(find_command, opts),
      previewer = conf.grep_previewer(opts),
      sorter = conf.file_sorter(opts),
    })
    :find()
end

return SessionLens
