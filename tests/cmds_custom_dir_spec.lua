---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("The default config", function()
  local as = require "auto-session"
  as.setup {
    -- log_level = "debug",
  }

  local custom_sessions_dir = vim.fn.getcwd() .. "/tests/custom_sessions/"
  local cwd_session_name = TL.escapeSessionName(vim.fn.getcwd())
  local cwd_session_path = custom_sessions_dir .. cwd_session_name .. ".vim"
  local named_session_path = custom_sessions_dir .. TL.named_session_name .. ".vim"

  TL.clearSessionFilesAndBuffers()
  TL.clearSessionFiles(custom_sessions_dir)

  it("can save a session for the cwd to a custom directory", function()
    vim.cmd("e " .. TL.test_file)

    as.SaveSessionToDir(custom_sessions_dir)

    -- Make sure the session was created
    print(cwd_session_path)
    assert.equals(1, vim.fn.filereadable(cwd_session_path))

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(cwd_session_path, TL.test_file)
  end)

  it("can restore a session for the cwd from a custom directory", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd "silent %bw"

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    as.RestoreSessionFromDir(custom_sessions_dir)

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)

  it("can delete a session for the cwd from a custom directory", function()
    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(cwd_session_path))

    as.DeleteSessionFromDir(custom_sessions_dir)

    assert.equals(0, vim.fn.filereadable(cwd_session_path))
  end)

  it("can save a named session to a custom directory", function()
    vim.cmd("e " .. TL.test_file)

    as.SaveSessionToDir(custom_sessions_dir, TL.named_session_name)

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(named_session_path))

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(named_session_path, TL.test_file)
  end)

  it("can restore a named session from a custom directory", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd "silent %bw"

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    as.RestoreSessionFromDir(custom_sessions_dir, TL.named_session_name)

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)

  it("can delete a named session from a custom directory", function()
    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(named_session_path))

    ---@diagnostic disable-next-line: param-type-mismatch
    as.DeleteSessionFromDir(custom_sessions_dir, TL.named_session_name)

    assert.equals(0, vim.fn.filereadable(named_session_path))
  end)
end)
