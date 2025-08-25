local telescope = require("telescope")
local Picker = require("auto-session.pickers.telescope")

return telescope.register_extension({
  setup = function()
    -- Nothing here for now
  end,
  exports = {
    search_session = Picker.extension_search_session,
    ["session-lens"] = Picker.extension_search_session,
  },
})
