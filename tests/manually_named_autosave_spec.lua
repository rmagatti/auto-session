---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("Manually named sessions", function()
  require("auto-session").setup {}

  it("can autosave", function()
    TL.clearSessionFilesAndBuffers()
    vim.cmd("e " .. TL.test_file)

    require("auto-session").SaveSession(TL.named_session_name)

    vim.cmd("e " .. TL.other_file)

    require("auto-session").AutoSaveSession()

    -- Make sure the session was not created
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
    assert.equals(1, vim.fn.filereadable(TL.named_session_path))
    TL.assertSessionHasFile(TL.named_session_path, TL.test_file)
    TL.assertSessionHasFile(TL.named_session_path, TL.other_file)
  end)

  it("autosaving doesn't break normal autosaving", function()
    TL.clearSessionFilesAndBuffers()
    vim.cmd("e " .. TL.test_file)

    require("auto-session").SaveSession()

    vim.cmd("e " .. TL.other_file)
    assert.equals(1, vim.fn.bufexists(TL.other_file))

    require("auto-session").AutoSaveSession()

    -- Make sure the session was not created
    assert.equals(0, vim.fn.filereadable(TL.named_session_path))
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
    TL.assertSessionHasFile(TL.default_session_path, TL.test_file)
    TL.assertSessionHasFile(TL.default_session_path, TL.other_file)
  end)
end)
