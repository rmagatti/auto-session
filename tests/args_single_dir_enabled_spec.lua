---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")
local stub = require("luassert.stub")

describe("The args single dir enabled config", function()
  local no_restore_hook_called = false
  local as = require("auto-session")
  local c = require("auto-session.config")

  as.setup({
    args_allow_single_directory = true,
    args_allow_files_auto_save = false,

    -- Disable autosave so we leave our setup autosave for other tests
    auto_save_enabled = false,
    no_restore_cmds = {
      function()
        no_restore_hook_called = true
      end,
    },
    -- log_level = "debug",
  })
  TL.clearSessionFilesAndBuffers()

  it("can save a session", function()
    vim.cmd("e " .. TL.test_file)

    vim.cmd("AutoSession save")

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(TL.default_session_path, TL.test_file)

    -- now clear the buffers
    vim.cmd("%bw!")
  end)

  it("does not autosave for cwd if single directory arg does not have a session", function()
    no_restore_hook_called = false
    --enable autosave for this test
    c.auto_save = true

    local s = stub(vim.fn, "argv")
    s.returns({ "tests" })

    -- only exported because we set the unit testing env in TL
    assert.False(as.auto_restore_session_at_vim_enter())
    assert.equals(true, no_restore_hook_called)

    -- we don't want it to save a session since it won't have loaded a session
    assert.False(as.auto_save_session())

    -- Revert the stub
    vim.fn.argv:revert()
    c.auto_save = false
  end)

  it("does restore a session when run with a single directory", function()
    no_restore_hook_called = false

    local cwd = vim.fn.getcwd()

    -- Change out of current directory so we don't load session for it
    vim.cmd("cd tests")

    -- Stub
    local s = stub(vim.fn, "argv")
    s.returns({ cwd })

    -- only exported because we set the unit testing env in TL
    assert.equals(true, as.auto_restore_session_at_vim_enter())

    -- Revert the stub
    vim.fn.argv:revert()

    assert.equals(false, no_restore_hook_called)

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)

  it("doesn't restore a session when run with a file", function()
    vim.cmd("%bw!")
    no_restore_hook_called = false
    assert.equals(false, no_restore_hook_called)

    local s = stub(vim.fn, "argv")
    s.returns({ TL.test_file })

    -- only exported because we set the unit testing env in TL
    assert.equals(false, as.auto_restore_session_at_vim_enter())

    -- Revert the stub
    vim.fn.argv:revert()

    assert.equals(true, no_restore_hook_called)

    assert.equals(0, vim.fn.bufexists(TL.test_file))
  end)
end)
