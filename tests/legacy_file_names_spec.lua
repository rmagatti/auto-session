---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")

describe("Legacy file name support", function()
  local as = require("auto-session")
  local save_extra_cmds_called = false
  as.setup({
    -- log_level = "debug",
    save_extra_cmds = {
      function()
        save_extra_cmds_called = true
        return [[echo "hello world"]]
      end,
    },
  })
  local default_extra_cmds_path = TL.default_session_path:gsub("%.vim$", "x.vim")
  local legacy_extra_cmds_path = TL.default_session_path_legacy:gsub("%.vim$", "x.vim")

  it("can convert a session to the new format during a restore, including extra cmds", function()
    TL.clearSessionFilesAndBuffers()

    vim.cmd("e " .. TL.test_file)

    assert.equals(1, vim.fn.bufexists(TL.test_file))

    -- save a default session in new format
    as.SaveSession()

    assert.True(as.session_exists_for_cwd())
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
    assert.equals(1, vim.fn.filereadable(default_extra_cmds_path))

    vim.loop.fs_rename(TL.default_session_path, TL.default_session_path_legacy)
    vim.loop.fs_rename(default_extra_cmds_path, legacy_extra_cmds_path)

    print(TL.default_session_path_legacy)
    assert.True(as.session_exists_for_cwd())
    assert.equals(1, vim.fn.filereadable(TL.default_session_path_legacy))
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
    assert.equals(1, vim.fn.filereadable(legacy_extra_cmds_path))
    assert.equals(0, vim.fn.filereadable(default_extra_cmds_path))

    vim.cmd("%bw!")

    assert.equals(0, vim.fn.bufexists(TL.test_file))

    as.RestoreSession()

    -- did we successfully restore the session?
    assert.equals(1, vim.fn.bufexists(TL.test_file))
    assert.True(save_extra_cmds_called)

    -- did we now have a new filename?
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
    assert.equals(1, vim.fn.filereadable(default_extra_cmds_path))

    -- and no old file name?
    assert.equals(0, vim.fn.filereadable(TL.default_session_path_legacy))
    assert.equals(0, vim.fn.filereadable(legacy_extra_cmds_path))

    assert.True(as.session_exists_for_cwd())
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

    vim.cmd("%bw!")

    assert.equals(0, vim.fn.bufexists(TL.test_file))

    as.DeleteSession()

    -- file should be gone
    assert.equals(0, vim.fn.filereadable(TL.default_session_path_legacy))
  end)
end)
