local telescope = require "telescope"
local SessionLens = require "auto-session.session-lens"

return telescope.register_extension {
  setup = function()
    -- Nothing here for now
  end,
  exports = {
    search_session = SessionLens.search_session,
    ["session-lens"] = SessionLens.search_session,
  },
}
