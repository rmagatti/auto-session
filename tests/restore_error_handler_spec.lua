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
end)
