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

  -- Test glob pattern matching for non-existent directories (issue #509)
  it("saves a session for a glob pattern even when subdirectories don't exist yet", function()
    vim.cmd("cd " .. cwd)
    vim.cmd("e " .. TL.test_file)

    -- Set up a glob pattern for a path that doesn't exist yet
    local test_base = cwd .. "/tests/nonexistent"
    c.allowed_dirs = { test_base .. "/*" }

    -- Create the directory structure
    vim.fn.mkdir(test_base .. "/subdir", "p")
    vim.cmd("cd " .. test_base .. "/subdir")

    local session_path = TL.makeSessionPath(vim.fn.getcwd())
    assert.equals(0, vim.fn.filereadable(session_path))

    as.auto_save_session()

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(session_path))

    -- Cleanup
    vim.fn.delete(test_base, "rf")
  end)

  it("doesn't save for paths that don't match the glob pattern", function()
    vim.cmd("cd " .. cwd)
    vim.cmd("e " .. TL.test_file)

    local test_base = cwd .. "/tests/glob_test"
    c.allowed_dirs = { test_base .. "/allowed/*" }

    -- Create a directory that should NOT match
    vim.fn.mkdir(test_base .. "/not_allowed/subdir", "p")
    vim.cmd("cd " .. test_base .. "/not_allowed/subdir")

    local session_path = TL.makeSessionPath(vim.fn.getcwd())
    as.auto_save_session()

    -- Make sure the session was NOT created
    assert.equals(0, vim.fn.filereadable(session_path))

    -- Cleanup
    vim.fn.delete(test_base, "rf")
  end)

  it("saves for paths that match the glob pattern", function()
    vim.cmd("cd " .. cwd)
    vim.cmd("e " .. TL.test_file)

    local test_base = cwd .. "/tests/glob_test2"
    c.allowed_dirs = { test_base .. "/allowed/*" }

    -- Create a directory that SHOULD match
    vim.fn.mkdir(test_base .. "/allowed/subdir", "p")
    vim.cmd("cd " .. test_base .. "/allowed/subdir")

    local session_path = TL.makeSessionPath(vim.fn.getcwd())
    as.auto_save_session()

    -- Make sure the session WAS created
    assert.equals(1, vim.fn.filereadable(session_path))

    -- Cleanup
    vim.fn.delete(test_base, "rf")
  end)

  it("matches only one directory level with single *", function()
    vim.cmd("cd " .. cwd)
    vim.cmd("e " .. TL.test_file)

    local test_base = cwd .. "/tests/glob_depth"
    c.allowed_dirs = { test_base .. "/*" }

    -- This should match (one level deep)
    vim.fn.mkdir(test_base .. "/level1", "p")
    vim.cmd("cd " .. test_base .. "/level1")
    local session_path1 = TL.makeSessionPath(vim.fn.getcwd())
    as.auto_save_session()
    assert.equals(1, vim.fn.filereadable(session_path1))

    -- This should NOT match (two levels deep)
    vim.fn.mkdir(test_base .. "/level1/level2", "p")
    vim.cmd("cd " .. test_base .. "/level1/level2")
    local session_path2 = TL.makeSessionPath(vim.fn.getcwd())
    as.auto_save_session()
    assert.equals(0, vim.fn.filereadable(session_path2))

    -- Cleanup
    vim.fn.delete(test_base, "rf")
  end)

  it("handles tilde expansion in glob patterns", function()
    vim.cmd("e " .. TL.test_file)

    local home = vim.fn.expand("~")
    local test_dir = home .. "/.auto-session-test-glob"

    c.allowed_dirs = { "~/.auto-session-test-glob/*" }

    vim.fn.mkdir(test_dir .. "/subdir", "p")
    vim.cmd("cd " .. test_dir .. "/subdir")

    local session_path = TL.makeSessionPath(vim.fn.getcwd())
    as.auto_save_session()

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(session_path))

    -- Cleanup
    vim.fn.delete(test_dir, "rf")
  end)
end)
