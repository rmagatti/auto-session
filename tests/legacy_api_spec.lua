---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")

describe("legacy api functions", function()
  local as = require("auto-session")
  local Lib = require("auto-session.lib")
  local c = require("auto-session.config")
  as.setup({
    legacy_cmds = true,
    -- log_level = "debug",
  })

  TL.clearSessionFilesAndBuffers()

  it("can auto-save a session for the cwd", function()
    assert.False(as.session_exists_for_cwd())
    vim.cmd("e " .. TL.test_file)

    as.AutoSaveSession()

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(TL.default_session_path, TL.test_file)
    assert.True(as.session_exists_for_cwd())

    -- Make sure there isn't an extra commands file by default
    local default_extra_cmds_path = TL.default_session_path:gsub("%.vim$", "x.vim")
    assert.equals(0, vim.fn.filereadable(default_extra_cmds_path))

    local sessions = Lib.get_session_list(as.get_root_dir())
    assert.equal(1, #sessions)

    assert.equal(TL.session_dir .. sessions[1].file_name, TL.default_session_path)
    assert.equal(sessions[1].display_name, Lib.current_session_name())
    assert.equal(sessions[1].session_name, TL.default_session_name)
  end)

  it("can auto-restore a session for the cwd", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd("silent %bw")

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    as.AutoRestoreSession()

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)

  it("can restore a session for the cwd using a session name", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd("silent %bw")

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    as.RestoreSession(vim.fn.getcwd())

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)

  it("can save a named session", function()
    vim.cmd("e " .. TL.test_file)

    as.SaveSession(TL.named_session_name)

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.named_session_path))

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(TL.named_session_path, TL.test_file)
  end)

  it("can restore a named session", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd("silent %bw")

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    as.RestoreSessionFile(TL.named_session_path, TL.named_session_name)

    assert.equals(1, vim.fn.bufexists(TL.test_file))

    assert.equals(TL.named_session_name, require("auto-session.lib").current_session_name())
    assert.equals(TL.named_session_name, require("auto-session.lib").current_session_name(true))
  end)

  it("can delete a session for the cwd", function()
    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    as.DeleteSession()

    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
  end)

  it("can delete a named session", function()
    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.named_session_path))
    assert.True(vim.v.this_session ~= "")

    as.DeleteSessionFile(TL.named_session_path, TL.named_session_name)

    -- Auto save should be disabled when deleting the current session
    assert.False(c.auto_save)

    -- Deleting current session should set vim.v.this_session = ""
    assert.True(vim.v.this_session == "")

    assert.equals(0, vim.fn.filereadable(TL.named_session_path))
  end)
end)
