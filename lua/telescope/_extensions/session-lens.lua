local telescope = require "telescope"
local SessionLens = require "auto-session.session-lens"

return telescope.register_extension {
  setup = SessionLens.setup,
  exports = {
    search_session = SessionLens.search_session,
  },
}
