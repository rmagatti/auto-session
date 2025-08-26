---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")

describe("legacy_cmds=true", function()
  local as = require("auto-session")
  local Lib = require("auto-session.lib")
  local c = require("auto-session.config")
  as.setup({
    legacy_cmds = true,
    -- log_level = "debug",
  })

  TL.clearSessionFilesAndBuffers()

  it("can save a session for the cwd", function()
    assert.False(as.session_exists_for_cwd())
    vim.cmd("e " .. TL.test_file)

    vim.cmd("SessionSave")

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

  it("can restore a session for the cwd", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd("silent %bw")

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    vim.cmd("SessionRestore")

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)

  it("can restore a session for the cwd using a session name", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd("silent %bw")

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

    vim.cmd("silent %bw")

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    vim.cmd("SessionRestore " .. TL.named_session_name)

    assert.equals(1, vim.fn.bufexists(TL.test_file))

    assert.equals(TL.named_session_name, require("auto-session.lib").current_session_name())
    assert.equals(TL.named_session_name, require("auto-session.lib").current_session_name(true))
  end)

  it("can complete session names", function()
    local sessions = Lib.complete_session_for_dir(TL.session_dir, "")
    -- print(vim.inspect(sessions))

    assert.True(vim.tbl_contains(sessions, TL.default_session_name))
    assert.True(vim.tbl_contains(sessions, TL.named_session_name))

    -- print(vim.inspect(sessions))
    -- With my prefix, only named session should be present
    sessions = Lib.complete_session_for_dir(TL.session_dir, "my")
    assert.False(vim.tbl_contains(sessions, TL.default_session_name))
    assert.True(vim.tbl_contains(sessions, TL.named_session_name))
  end)

  it("can delete a session for the cwd", function()
    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    vim.cmd("SessionDelete")

    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
  end)

  it("can delete a named session", function()
    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.named_session_path))
    assert.True(vim.v.this_session ~= "")

    vim.cmd("SessionDelete " .. TL.named_session_name)

    -- Auto save should be disabled when deleting the current session
    assert.False(c.auto_save)

    -- Deleting current session should set vim.v.this_session = ""
    assert.True(vim.v.this_session == "")

    assert.equals(0, vim.fn.filereadable(TL.named_session_path))
  end)

  TL.clearSessionFilesAndBuffers()

  it("can purge old sessions", function()
    -- Save default session
    as.SaveSession()

    -- Create a named session to make sure it doesn't get deleted
    vim.cmd("SessionSave " .. TL.named_session_name)
    assert.equals(1, vim.fn.filereadable(TL.named_session_path))

    local session_name = vim.fn.getcwd():gsub("session$", "session/doesnotexist")

    vim.cmd("SessionSave " .. session_name)
    assert.equals(1, vim.fn.filereadable(TL.makeSessionPath(session_name)))

    as.DisableAutoSave()

    vim.cmd("SessionPurgeOrphaned")
    -- print(TL.default_session_path)

    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
    assert.equals(1, vim.fn.filereadable(TL.named_session_path))
    assert.equals(0, vim.fn.filereadable(TL.makeSessionPath(session_name)))
  end)

  it("can disable autosave", function()
    c.auto_save = true

    vim.cmd("SessionDisableAutoSave")

    assert.False(c.auto_save)
  end)

  it("can enable autosave", function()
    c.auto_save = false

    vim.cmd("SessionDisableAutoSave!")

    assert.True(c.auto_save)
  end)

  it("can toggle autosave", function()
    assert.True(c.auto_save)
    vim.cmd("SessionToggleAutoSave")
    assert.False(c.auto_save)
    vim.cmd("SessionToggleAutoSave")
    assert.True(c.auto_save)
  end)
end)
