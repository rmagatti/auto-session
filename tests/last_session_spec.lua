---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("The last loaded session config", function()
  require("auto-session").setup {
    auto_session_enable_last_session = true,
    auto_save_enabled = false,
  }

  TL.clearSessionFilesAndBuffers()

  it("doesn't crash when restoring with no sessions", function()
    vim.cmd "SessionRestore"

    assert.equals(0, vim.fn.bufexists(TL.test_file))
  end)

  it("can save a session for the cwd", function()
    vim.cmd("e " .. TL.test_file)

    vim.cmd "SessionSave"

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(TL.default_session_path, TL.test_file)
  end)

  it("can save a named sessions with another file", function()
    vim.cmd "%bw!"
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    vim.cmd("e " .. TL.other_file)

    -- Sleep for 1.5 seconds since the time comparison is seconds based
    vim.loop.sleep(1500)

    vim.cmd("SessionSave " .. TL.named_session_name)

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.named_session_path))

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(TL.named_session_path, TL.other_file)
  end)

  it("doesn't restore the last session when doing a normal SessionRestore", function()
    -- switch to directory that doesn't have a session
    vim.cmd "%bw!"
    assert.equals(0, vim.fn.bufexists(TL.test_file))
    assert.equals(0, vim.fn.bufexists(TL.other_file))

    -- WARN: this test below also expects to be run from the tests directory
    vim.cmd "cd tests"

    vim.cmd "SessionRestore"

    -- Have file from latest session
    assert.equals(0, vim.fn.bufexists(TL.other_file))

    -- Don't have file from earlier session
    assert.equals(0, vim.fn.bufexists(TL.test_file))
  end)

  it("does restores the last session when doing an auto-restore", function()
    -- switch to directory that doesn't have a session
    vim.cmd "%bw!"
    assert.equals(0, vim.fn.bufexists(TL.test_file))
    assert.equals(0, vim.fn.bufexists(TL.other_file))

    -- WARN: this test depends on the cd state above
    -- we're still in tests/ so don't need to cd again

    assert.True(require("auto-session").AutoRestoreSession())

    -- Have file from latest session
    assert.equals(1, vim.fn.bufexists(TL.other_file))

    -- Don't have file from earlier session
    assert.equals(0, vim.fn.bufexists(TL.test_file))
  end)
end)
