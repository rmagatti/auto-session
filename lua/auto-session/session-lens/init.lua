local Lib = require "auto-session.session-lens.library"
local Actions = require "auto-session.session-lens.actions"

local logger = require("auto-session.logger"):new {
  log_level = vim.log.levels.INFO,
}

----------- Setup ----------
local SessionLens = {
  conf = {},
}

---Session Lens Config
---@class session_lens_config
---@field shorten_path boolean
---@field theme_conf table
---@field buftypes_to_ignore table
---@field previewer boolean
---@field session_control session_control
---@field load_on_setup boolean

---@type session_lens_config
local defaultConf = {
  theme_conf = { winblend = 10, border = true },
  previewer = false,
  buftypes_to_ignore = {},
}

-- Set default config on plugin load
SessionLens.conf = defaultConf

function SessionLens.setup(auto_session)
  SessionLens.conf = vim.tbl_deep_extend("force", SessionLens.conf, auto_session.conf.session_lens)
  SessionLens.conf.functions = auto_session

  Lib.setup(SessionLens.conf, auto_session)
  Actions.setup(SessionLens.conf, auto_session)
  logger.log_level = auto_session.conf.log_level
end

---Search session
---Triggers the customized telescope picker for switching sessions
---@param custom_opts any
SessionLens.search_session = function(custom_opts)
  local themes = require "telescope.themes"
  local telescope_actions = require "telescope.actions"

  custom_opts = (vim.tbl_isempty(custom_opts or {}) or custom_opts == nil) and SessionLens.conf or custom_opts

  -- Use auto_session_root_dir from the Auto Session plugin
  local cwd = SessionLens.conf.functions.get_root_dir()

  if custom_opts.shorten_path ~= nil then
    logger.warn "`shorten_path` config is deprecated, use the new `path_display` config instead"
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
    entry_maker = Lib.make_entry.gen_from_file(custom_opts),
    cwd = cwd,
    -- TOOD: support custom mappings?
    attach_mappings = function(_, map)
      telescope_actions.select_default:replace(Actions.source_session)
      map("i", "<c-d>", Actions.delete_session)
      map("i", "<c-s>", Actions.alternate_session)
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
    elseif 1 == vim.fn.executable "where" then
      return { "where", "/r", ".", "*" }
    end
  end)()

  local finders = require "telescope.finders"
  local conf = require("telescope.config").values
  require("telescope.pickers").new(opts, {
    finder = finders.new_oneshot_job(find_command, opts),
    previewer = conf.grep_previewer(opts),
    sorter = conf.file_sorter(opts),
  }):find()
end

return SessionLens
