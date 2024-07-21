---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("Legacy file name support", function()
  local as = require "auto-session"
  as.setup {
    -- log_level = "debug",
  }

  it("can convert a session to the new format during a restore", function()
    TL.clearSessionFilesAndBuffers()

    vim.cmd("e " .. TL.test_file)

    assert.equals(1, vim.fn.bufexists(TL.test_file))

    -- save a default session in new format
    as.SaveSession()
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    vim.loop.fs_rename(TL.default_session_path, TL.default_session_path_legacy)

    print(TL.default_session_path_legacy)
    assert.equals(1, vim.fn.filereadable(TL.default_session_path_legacy))
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))

    vim.cmd "%bw!"

    assert.equals(0, vim.fn.bufexists(TL.test_file))

    as.RestoreSession()

    -- did we successfully restore the session?
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    -- did we now have a new filename?
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- and no old file name?
    assert.equals(0, vim.fn.filereadable(TL.default_session_path_legacy))
  end)

  it("can convert a session to the new format during a delete", function()
    TL.clearSessionFilesAndBuffers()

    vim.cmd("e " .. TL.test_file)

    assert.equals(1, vim.fn.bufexists(TL.test_file))

    -- save a default session in new format
    as.SaveSession()
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    vim.loop.fs_rename(TL.default_session_path, TL.default_session_path_legacy)

    print(TL.default_session_path_legacy)
    assert.equals(1, vim.fn.filereadable(TL.default_session_path_legacy))
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))

    vim.cmd "%bw!"

    assert.equals(0, vim.fn.bufexists(TL.test_file))

    as.DeleteSession()

    -- file should be gone
    assert.equals(0, vim.fn.filereadable(TL.default_session_path_legacy))
  end)
end)
