---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"
local stub = require "luassert.stub"

describe("The args files enabled config", function()
  local no_restore_hook_called = false
  require("auto-session").setup {
    auto_session_root_dir = TL.session_dir,

    args_allow_single_directory = false,
    args_allow_files_auto_save = true,

    -- Disable autosave so we leave our setup autosave for other tests
    auto_save_enabled = false,
    no_restore_cmds = {
      function()
        no_restore_hook_called = true
      end,
    },
  }

  it("doesn't restore a session when run with a single directory", function()
    assert.equals(false, no_restore_hook_called)

    -- Stub
    local s = stub(vim.fn, "argv")
    s.returns { "." }

    -- only exported because we set the unit testing env in TL
    assert.equals(false, require("auto-session").auto_restore_session_at_vim_enter())

    -- Revert the stub
    vim.fn.argv:revert()

    assert.equals(true, no_restore_hook_called)

    assert.equals(0, vim.fn.bufexists(TL.test_file))
  end)

  it("doesn't restore a session when run with a file", function()
    no_restore_hook_called = false
    assert.equals(false, no_restore_hook_called)

    local s = stub(vim.fn, "argv")
    s.returns { TL.other_file }

    -- only exported because we set the unit testing env in TL
    assert.equals(false, require("auto-session").auto_restore_session_at_vim_enter())

    -- Revert the stub
    vim.fn.argv:revert()

    assert.equals(true, no_restore_hook_called)

    assert.equals(0, vim.fn.bufexists(TL.test_file))
  end)

  it("does autosave a session", function()
    vim.cmd(":e " .. TL.other_file)
    assert.equals(1, vim.fn.bufexists(TL.other_file))

    local as = require "auto-session"

    as.conf.auto_save_enabled = true

    assert.equals(true, as.AutoSaveSession())

    as.conf.auto_save_enabled = false

    -- Session should have new file
    TL.assertSessionHasFile(TL.default_session_path, TL.other_file)

    -- Session but not old file
    assert.equals(false, TL.sessionHasFile(TL.default_session_path, TL.test_file))
  end)

  it("doesn't autosave when args_allow_files_auto_save returns false", function()
    M.clearSessionFilesAndBuffers()

    vim.cmd(":e " .. TL.other_file)
    assert.equals(1, vim.fn.bufexists(TL.other_file))

    local as = require "auto-session"

    as.conf.auto_save_enabled = true
    as.conf.args_allow_files_auto_save = function()
      return false
    end

    assert.equals(false, as.AutoSaveSession())

    as.conf.auto_save_enabled = false

    assert.equals(false, TL.sessionHasFile(TL.default_session_path, TL.other_file))
    assert.equals(false, TL.sessionHasFile(TL.default_session_path, TL.test_file))
  end)

  it("does autosave a session when args_allow_files_auto_save returns true", function()
    M.clearSessionFilesAndBuffers()

    vim.cmd(":e " .. TL.other_file)
    assert.equals(1, vim.fn.bufexists(TL.other_file))

    local as = require "auto-session"

    as.conf.auto_save_enabled = true
    as.conf.args_allow_files_auto_save = function()
      return true
    end

    assert.equals(true, as.AutoSaveSession())

    as.conf.auto_save_enabled = false

    -- Session should have new file
    TL.assertSessionHasFile(TL.default_session_path, TL.other_file)

    -- Session but not old file
    assert.equals(false, TL.sessionHasFile(TL.default_session_path, TL.test_file))
  end)
end)
