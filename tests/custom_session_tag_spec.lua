require("plenary")
local TL = require("tests/test_lib")

describe("custom session tag", function()
  local as = require("auto-session")
  local c = require("auto-session.config")

  as.setup({
    -- log_level = "debug",
  })

  it("can save and restore a session", function()
    TL.clearSessionFilesAndBuffers()
    vim.cmd("e " .. TL.test_file)

    local tag = "mytag"
    c.custom_session_tag = function(_)
      return tag
    end

    local session_path = TL.makeSessionPath(TL.default_session_name .. "||" .. tag)

    assert.True(as.SaveSession())
    assert.equals(1, vim.fn.filereadable(session_path))

    vim.cmd("silent %bw")
    assert.True(as.RestoreSession())
    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)
end)
