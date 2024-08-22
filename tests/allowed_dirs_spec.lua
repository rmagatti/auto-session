---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"
TL.clearSessionFilesAndBuffers()

describe("The allowed dirs config", function()
  local as = require "auto-session"
  local c = require "auto-session.config"
  as.setup {
    auto_session_allowed_dirs = { "/dummy" },
  }

  TL.clearSessionFilesAndBuffers()
  vim.cmd("e " .. TL.test_file)

  it("doesn't save a session for a non-allowed dir", function()
    as.AutoSaveSession()

    -- Make sure the session was not created
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
  end)

  it("saves a session for an allowed dir", function()
    c.allowed_dirs = { vim.fn.getcwd() }
    as.AutoSaveSession()

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(TL.default_session_path, TL.test_file)
  end)

  it("saves a session for an allowed dir with a glob", function()
    TL.clearSessionFilesAndBuffers()
    vim.cmd("e " .. TL.test_file)
    c.allowed_dirs = { vim.fn.getcwd() .. "/tests/*" }

    -- Change to a sub directory to see if it's allowed
    vim.cmd "cd tests/test_files"

    local session_path = TL.makeSessionPath(vim.fn.getcwd())
    assert.equals(0, vim.fn.filereadable(session_path))

    as.AutoSaveSession()

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(session_path))
  end)
end)
