---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("The default config", function()
  local as = require "auto-session"
  as.setup {
    -- log_level = "debug",
  }

  TL.clearSessionFilesAndBuffers()

  local dotvim_session_name = "test.vim"
  local dotvim_seesion_path = TL.session_dir .. TL.escapeSessionName(dotvim_session_name) .. ".vim"

  it("can save a session name with .vim", function()
    vim.cmd("e " .. TL.test_file)

    vim.cmd("SessionSave " .. dotvim_session_name)

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(dotvim_seesion_path))
  end)

  it("can restore a session name with .vim", function()
    vim.cmd "%bw!"

    assert.equals(0, vim.fn.bufexists(TL.test_file))

    vim.cmd("SessionRestore " .. dotvim_session_name)

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)
end)
