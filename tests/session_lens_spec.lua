---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("Session lens", function()
  local as = require "auto-session"
  as.setup {
    -- log_level = "debug",
  }

  it("can get the session files", function()
    as.SaveSession()
    as.SaveSession "project_x"

    -- initialize session_lens
    assert.True(as.setup_session_lens())
    local make_telescope_entry = as.session_lens.make_telescope_callback {}

    local data = make_telescope_entry(TL.escapeSessionName(TL.default_session_name) .. ".vim")
    assert.not_nil(data)

    data = make_telescope_entry "project_x.vim"
    assert.not_nil(data)
    --
  end)
end)
