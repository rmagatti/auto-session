local Config = require "auto-session.config"
local Lib = require "auto-session.lib"
local Actions = require "auto-session.session-lens.actions"
local AutoSession = require "auto-session"

----------- Setup ----------
local SessionLens = {}

---@private
---Search session
---Triggers the customized telescope picker for switching sessions
---@param custom_opts table
SessionLens.search_session = function(custom_opts)
  local telescope_themes = require "telescope.themes"
  local telescope_actions = require "telescope.actions"
  local telescope_finders = require "telescope.finders"
  local telescope_conf = require("telescope.config").values

  -- use custom_opts if specified and non-empty. Otherwise use the config
  if not custom_opts or vim.tbl_isempty(custom_opts) then
    custom_opts = Config.session_lens
  end
  custom_opts = custom_opts or {}

  -- get the theme defaults, with any overrides in custom_opts.theme_conf
  local theme_opts = telescope_themes.get_dropdown(custom_opts.theme_conf)

  -- path_display could've been in theme_conf but that's not where we put it
  if custom_opts.path_display then
    -- copy over to the theme options
    theme_opts.path_display = custom_opts.path_display
  end

  if theme_opts.path_display then
    -- If there's a path_display setting, we have to force path_display.absolute = true here,
    -- otherwise the session for the cwd will be displayed as just a dot
    theme_opts.path_display.absolute = true
  end

  theme_opts.previewer = custom_opts.previewer

  local session_root_dir = AutoSession.get_root_dir()

  local session_entry_maker = function(session_entry)
    return {

      ordinal = session_entry.session_name,
      value = session_entry.session_name,
      session_name = session_entry.session_name,
      filename = session_entry.file_name,
      path = session_entry.path,
      cwd = session_root_dir,

      -- We can't calculate the vaue of display until the picker is acutally displayed
      -- because telescope.utils.transform_path may depend on the window size,
      -- specifically with the truncate option. So we use a function that will be
      -- called when actually displaying the row
      display = function(_)
        if session_entry.already_set_display_name then
          return session_entry.display_name
        end

        session_entry.already_set_display_name = true

        if not theme_opts or not theme_opts.path_display then
          return session_entry.display_name
        end

        local telescope_utils = require "telescope.utils"

        return telescope_utils.transform_path(theme_opts, session_entry.display_name_component)
          .. session_entry.annotation_component
      end,
    }
  end

  local finder_maker = function()
    return telescope_finders.new_table {
      results = Lib.get_session_list(session_root_dir),
      entry_maker = session_entry_maker,
    }
  end

  local opts = {
    prompt_title = "Sessions",
    attach_mappings = function(prompt_bufnr, map)
      telescope_actions.select_default:replace(Actions.source_session)

      local mappings = Config.session_lens.mappings
      if mappings then
        map(mappings.delete_session[1], mappings.delete_session[2], Actions.delete_session)
        map(mappings.alternate_session[1], mappings.alternate_session[2], Actions.alternate_session)

        Actions.copy_session:enhance {
          post = function()
            local action_state = require "telescope.actions.state"
            local picker = action_state.get_current_picker(prompt_bufnr)
            picker:refresh(finder_maker(), { reset_prompt = true })
          end,
        }

        map(mappings.copy_session[1], mappings.copy_session[2], Actions.copy_session)
      end
      return true
    end,
  }

  -- add the theme options
  opts = vim.tbl_deep_extend("force", opts, theme_opts)

  require("telescope.pickers")
    .new(opts, {
      finder = finder_maker(),
      previewer = telescope_conf.file_previewer(opts),
      sorter = telescope_conf.file_sorter(opts),
    })
    :find()
end

return SessionLens
