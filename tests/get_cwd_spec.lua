---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("cwd lookup", function()
  local as = require "auto-session"

  require("auto-session").setup {}

  TL.clearSessionFilesAndBuffers()

  it("works when tcd is used", function()
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
    vim.cmd("e " .. TL.test_file)
    vim.cmd "tabnew"
    vim.cmd "tcd tests"

    as.SaveSession()

    vim.cmd "tabclose"

    -- Make sure the session was still created for the global directory
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
  end)

  TL.clearSessionFilesAndBuffers()

  it("works when lcd is used", function()
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
    vim.cmd("e " .. TL.test_file)
    vim.cmd "tabnew"
    vim.cmd "lcd tests"

    as.SaveSession()

    vim.cmd "tabclose"

    -- Make sure the session was still created for the global directory
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
  end)
end)
