---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("The default config", function()
  local as = require "auto-session"
  as.setup {
    -- log_level = "debug",
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

  it("can restore a session for the cwd", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd "silent %bw"

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    vim.cmd "SessionRestore"

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)

  it("can restore a session for the cwd using a session name", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd "silent %bw"

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    vim.cmd("SessionRestore " .. vim.fn.getcwd())

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)

  it("can save a named session", function()
    vim.cmd("e " .. TL.test_file)

    vim.cmd("SessionSave " .. TL.named_session_name)

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

    vim.cmd("SessionRestore " .. TL.named_session_name)

    assert.equals(1, vim.fn.bufexists(TL.test_file))

    -- FIXME: This currently fails on windows because of Lib.get_file_name(url)
    -- assert.equals(TL.named_session_name, require("auto-session").Lib.current_session_name())
  end)

  it("can restore a named session that already has .vim", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd "silent %bw"

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    vim.cmd("SessionRestore " .. TL.named_session_name .. ".vim")

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)

  it("can complete session names", function()
    local sessions = as.Lib.complete_session_for_dir(TL.session_dir, "")
    -- print(vim.inspect(sessions))

    if vim.fn.has "win32" == 1 then
      --- FIXME: This fails on windows because of the - escaping problem
      ----Modify the data for now, remove it when the bug is fixed
      assert.True(vim.tbl_contains(sessions, (TL.default_session_name:gsub("-", "\\"))))
    else
      assert.True(vim.tbl_contains(sessions, TL.default_session_name))
    end
    assert.True(vim.tbl_contains(sessions, TL.named_session_name))

    print(vim.inspect(sessions))
    -- With my prefix, only named session should be present
    sessions = as.Lib.complete_session_for_dir(TL.session_dir, "my")
    assert.False(vim.tbl_contains(sessions, TL.default_session_name))
    assert.True(vim.tbl_contains(sessions, TL.named_session_name))
  end)

  it("can delete a session for the cwd", function()
    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    vim.cmd "SessionDelete"

    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
  end)

  it("can delete a named session", function()
    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.named_session_path))

    vim.cmd("SessionDelete " .. TL.named_session_name)

    assert.equals(0, vim.fn.filereadable(TL.named_session_path))
  end)

  TL.clearSessionFilesAndBuffers()

  it("can auto save a session for the cwd", function()
    vim.cmd("e " .. TL.test_file)

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

    vim.cmd "SessionRestore"

    assert.equals(1, vim.fn.bufexists(TL.test_file))

    -- FIXME: This currently fails on windows because of the dashes issue
    -- assert.equals("auto-session", require("auto-session.lib").current_session_name())
  end)

  it("can purge old sessions", function()
    -- Create a named session to make sure it doesn't get deleted
    vim.cmd("SessionSave " .. TL.named_session_name)
    assert.equals(1, vim.fn.filereadable(TL.named_session_path))

    local session_name = vim.fn.getcwd():gsub("session$", "session/doesnotexist")

    vim.cmd("SessionSave " .. session_name)
    assert.equals(1, vim.fn.filereadable(TL.makeSessionPath(session_name)))

    as.DisableAutoSave()

    vim.cmd "SessionPurgeOrphaned"
    print(TL.default_session_path)

    -- FIXME: This session gets purged because the encoding can't be reversed
    if vim.fn.has "win32" == 0 then
      assert.equals(1, vim.fn.filereadable(TL.default_session_path))
    end
    assert.equals(1, vim.fn.filereadable(TL.named_session_path))
    assert.equals(0, vim.fn.filereadable(TL.makeSessionPath(session_name)))
  end)
end)
