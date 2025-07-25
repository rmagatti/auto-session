require "plenary"
local TL = require "tests/test_lib"

describe("restore_error_handler", function()
  local as = require "auto-session"
  local should_return
  local was_called = false

  as.setup()

  it("works when nil", function()
    TL.clearSessionFilesAndBuffers()
    vim.cmd("e " .. TL.test_file)
    as.SaveSession()

    -- add an error to the session file
    local uv = vim.loop
    local fd = assert(uv.fs_open(TL.default_session_path, "a", 438))
    uv.fs_write(fd, "error string\n", -1)
    uv.fs_close(fd)

    assert.False(as.RestoreSession())
  end)

  as.setup {
    ---@type restore_error_fn
    restore_error_handler = function()
      was_called = true
      return should_return
    end,
  }

  it("can suppress errors", function()
    TL.clearSessionFilesAndBuffers()
    vim.cmd("e " .. TL.test_file)
    as.SaveSession()

    -- add an error to the session file
    local uv = vim.loop
    local fd = assert(uv.fs_open(TL.default_session_path, "a", 438))
    uv.fs_write(fd, "error string\n", -1)
    uv.fs_close(fd)

    was_called = false
    should_return = true

    assert.True(as.RestoreSession())
    assert.True(was_called)
  end)

  it("can report errors", function()
    TL.clearSessionFilesAndBuffers()
    vim.cmd("e " .. TL.test_file)
    as.SaveSession()

    -- add an error to the session file
    local uv = vim.loop
    local fd = assert(uv.fs_open(TL.default_session_path, "a", 438))
    uv.fs_write(fd, "error string\n", -1)
    uv.fs_close(fd)

    was_called = false
    should_return = false

    assert.False(as.RestoreSession())
    assert.True(was_called)
  end)

  -- Test for the default error handler ignoring fold errors
  as.setup()

  it("ignores E16 Invalid range fold errors", function()
    TL.clearSessionFilesAndBuffers()
    vim.cmd("e " .. TL.test_file)
    as.SaveSession()

    -- add an E16 fold error to the session file
    local uv = vim.loop
    local fd = assert(uv.fs_open(TL.default_session_path, "a", 438))
    uv.fs_write(fd, "100,200fold\n", -1)  -- This will cause E16: Invalid range
    uv.fs_close(fd)

    -- This should succeed (return true) because E16 errors are ignored
    assert.True(as.RestoreSession())
  end)

  it("ignores E490 No fold found errors", function()
    TL.clearSessionFilesAndBuffers()
    vim.cmd("e " .. TL.test_file)
    as.SaveSession()

    -- add an E490 fold error to the session file
    local uv = vim.loop
    local fd = assert(uv.fs_open(TL.default_session_path, "a", 438))
    uv.fs_write(fd, "foldopen\n", -1)  -- This will cause E490: No fold found
    uv.fs_close(fd)

    -- This should succeed (return true) because E490 errors are ignored
    assert.True(as.RestoreSession())
  end)
end)
