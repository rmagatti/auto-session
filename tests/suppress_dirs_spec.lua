---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("The suppress dirs config", function()
  local as = require "auto-session"

  as.setup {
    auto_session_root_dir = TL.session_dir,
    auto_session_suppress_dirs = { vim.fn.getcwd() },
  }

  TL.clearSessionFilesAndBuffers()
  vim.cmd("e " .. TL.test_file)

  it("doesn't save a session for a suppressed dir", function()
    ---@diagnostic disable-next-line: missing-parameter
    as.AutoSaveSession()

    -- Make sure the session was not created
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
  end)

  it("saves a session for a non-suppressed dir", function()
    as.setup {
      auto_session_root_dir = TL.session_dir,
      auto_session_suppress_dirs = { "/dummy" },
    }
    ---@diagnostic disable-next-line: missing-parameter
    as.AutoSaveSession()

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(TL.default_session_path, TL.test_file)
  end)

  it("doesn't save a session for an allowed dir with a glob", function()
    TL.clearSessionFilesAndBuffers()
    vim.cmd("e " .. TL.test_file)
    as.conf.auto_session_suppress_dirs = { vim.fn.getcwd() .. "/tests/*" }

    -- Change to a sub directory to see if it's allowed
    vim.cmd "cd tests/test_files"

    local session_path = TL.makeSessionPath(vim.fn.getcwd())
    assert.equals(0, vim.fn.filereadable(session_path))

    as.AutoSaveSession()

    -- Make sure the session was not created
    assert.equals(0, vim.fn.filereadable(session_path))
  end)

  TL.clearSessionFilesAndBuffers()

  it("doesn't save a session for a suppressed dir even if also an allowed dir", function()
    vim.cmd("e " .. TL.test_file)
    as.setup {
      auto_session_root_dir = TL.session_dir,
      auto_session_suppress_dirs = { vim.fn.getcwd() },
      auto_session_allowed_dirs = { vim.fn.getcwd() },
    }
    ---@diagnostic disable-next-line: missing-parameter
    as.AutoSaveSession()

    -- Make sure the session was not created
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
  end)
end)
