---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("The default config", function()
  require("auto-session").setup {
    -- log_level = "debug",
  }

  TL.clearSessionFilesAndBuffers()

  it("can save a session for the cwd", function()
    vim.cmd(":e " .. TL.test_file)

    vim.cmd ":SessionSave"

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(TL.default_session_path, TL.test_file)
  end)

  it("can restore a session for the cwd", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd "silent %bw"

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    vim.cmd ":SessionRestore"

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)

  it("can delete a session for the cwd", function()
    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    vim.cmd ":SessionDelete"

    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
  end)

  it("can save a named session", function()
    vim.cmd(":e " .. TL.test_file)

    vim.cmd(":SessionSave " .. TL.named_session_name)

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.named_session_path))

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(TL.named_session_path, TL.test_file)
  end)

  it("can restore a named session", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd "silent %bw"

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    -- TODO: swap
    -- vim.cmd(":SessionRestore " .. TL.named_session_name)
    vim.cmd(":SessionRestore " .. TL.named_session_path)

    assert.equals(1, vim.fn.bufexists(TL.test_file))

    -- FIXME: This currently fails on windows because of Lib.get_file_name(url)
    -- assert.equals(TL.named_session_name, require("auto-session").Lib.current_session_name())
  end)

  it("can restore a session using SessionRestoreFromFile", function()
    -- TODO: Delete this test
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd "silent %bw"

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    vim.cmd(":SessionRestoreFromFile " .. TL.named_session_name)

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)

  it("can delete a named session", function()
    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.named_session_path))

    -- TODO: swap
    -- vim.cmd(":SessionDelete " .. TL.named_session_name)
    vim.cmd(":SessionDelete " .. TL.named_session_path)

    assert.equals(0, vim.fn.filereadable(TL.named_session_path))
  end)

  TL.clearSessionFilesAndBuffers()

  it("can auto save a session for the cwd", function()
    local as = require "auto-session"

    vim.cmd(":e " .. TL.test_file)

    assert.equals(1, vim.fn.bufexists(TL.test_file))

    -- auto_save_enabled will be disabled by delete above
    assert.False(as.conf.auto_save_enabled)

    -- enable it
    as.conf.auto_save_enabled = true

    as.AutoSaveSession()

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(TL.default_session_path, TL.test_file)
  end)

  it("can restore the auto-saved session for the cwd", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd "silent %bw"

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    vim.cmd ":SessionRestore"

    assert.equals(1, vim.fn.bufexists(TL.test_file))

    -- FIXME: This currently fails on windows because of the dashes issue
    -- assert.equals("auto-session", require("auto-session.lib").current_session_name())
  end)

  -- TODO: SessionPurge
end)
