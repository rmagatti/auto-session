---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")
TL.clearSessionFilesAndBuffers()

describe("The allowed dirs config", function()
  local original_cwd
  local uv = vim.uv or vim.loop

  before_each(function()
    TL.clearSessionFilesAndBuffers()
    original_cwd = uv.cwd()
  end)

  after_each(function()
    uv.chdir(original_cwd)
  end)

  local as = require("auto-session")
  local c = require("auto-session.config")
  as.setup({
    auto_session_allowed_dirs = { "/dummy" },
    -- log_level = "debug",
  })
  local cwd = vim.fn.getcwd()

  it("doesn't save a session for a non-allowed dir", function()
    vim.cmd("e " .. TL.test_file)
    as.auto_save_session()

    -- Make sure the session was not created
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
  end)

  it("saves a session for an allowed dir", function()
    vim.cmd("e " .. TL.test_file)
    c.allowed_dirs = { vim.fn.getcwd() }
    as.auto_save_session()

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(TL.default_session_path, TL.test_file)
  end)

  it("saves a session for an allowed dir with a glob", function()
    vim.cmd("e " .. TL.test_file)
    c.allowed_dirs = { vim.fn.getcwd() .. "/tests/*" }

    -- Change to a sub directory to see if it's allowed
    vim.cmd("cd tests/test_files")

    local session_path = TL.makeSessionPath(vim.fn.getcwd())
    assert.equals(0, vim.fn.filereadable(session_path))

    as.auto_save_session()

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(session_path))
  end)

  if vim.fn.has("win32") == 0 then
    it("saves a session for an allowed dir with a symlink", function()
      vim.cmd("cd " .. cwd)

      vim.cmd("e " .. TL.test_file)
      c.allowed_dirs = { vim.fn.getcwd() .. "/tests/symlink-test" }

      vim.fn.system("ln -snf test_files tests/symlink-test")
      vim.cmd("cd tests/symlink-test")

      local session_path = TL.makeSessionPath(vim.fn.getcwd())
      assert.equals(0, vim.fn.filereadable(session_path))

      assert.True(as.auto_save_session())

      -- Make sure the session was created
      assert.equals(1, vim.fn.filereadable(session_path))
    end)
  end
end)
