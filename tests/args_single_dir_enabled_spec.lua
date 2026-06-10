---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")
local stub = require("luassert.stub")
local Lib = require("auto-session.lib")

local uv = vim.uv or vim.loop

local function make_symlink_dirs()
  local base = vim.fn.tempname()
  local real_dir = base .. "/real"
  local link_dir = base .. "/link"

  assert.equals(1, vim.fn.mkdir(real_dir, "p"))
  assert.True(uv.fs_symlink(real_dir, link_dir))

  return {
    base = base,
    real = Lib.remove_trailing_separator(vim.fn.resolve(vim.fn.fnamemodify(real_dir, ":p"))),
    link = Lib.remove_trailing_separator(vim.fn.fnamemodify(link_dir, ":p")),
  }
end

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

    -- have to call setup again for auto-session to recapture argv
    as.setup(c.options)

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

    -- have to call setup again for auto-session to recapture argv
    as.setup(c.options)

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

    -- have to call setup again for auto-session to recapture argv
    as.setup(c.options)

    -- only exported because we set the unit testing env in TL
    assert.equals(false, as.auto_restore_session_at_vim_enter())

    -- Revert the stub
    vim.fn.argv:revert()

    assert.equals(true, no_restore_hook_called)

    assert.equals(0, vim.fn.bufexists(TL.test_file))
  end)

  it("does not resolve symlink directory arguments by default", function()
    if vim.fn.has("win32") == 1 then
      return
    end

    no_restore_hook_called = false
    local cwd = vim.fn.getcwd(-1, -1)
    local dirs = make_symlink_dirs()
    c.auto_save = true
    c.resolve_symlinks = false

    vim.cmd("cd " .. vim.fn.fnameescape(dirs.link))

    local s = stub(vim.fn, "argv")
    s.returns({ dirs.link })

    as.setup(c.options)

    assert.False(as.auto_restore_session_at_vim_enter())
    assert.equals(true, no_restore_hook_called)

    -- The symlink argv path and resolved cwd do not match, so autosave stays disabled.
    assert.False(as.auto_save_session())

    vim.fn.argv:revert()
    vim.cmd("cd " .. vim.fn.fnameescape(cwd))
    vim.fn.delete(dirs.base, "rf")
    c.auto_save = false
  end)

  it("keeps autosave enabled for symlink directory arguments when resolving symlinks", function()
    if vim.fn.has("win32") == 1 then
      return
    end

    no_restore_hook_called = false
    local cwd = vim.fn.getcwd(-1, -1)
    local dirs = make_symlink_dirs()
    local test_file = dirs.real .. "/test.txt"
    c.auto_save = true
    c.resolve_symlinks = true

    vim.fn.writefile({ "test" }, test_file)
    vim.cmd("cd " .. vim.fn.fnameescape(dirs.link))
    vim.cmd("e " .. vim.fn.fnameescape(test_file))

    local s = stub(vim.fn, "argv")
    s.returns({ dirs.link })

    as.setup(c.options)

    assert.False(as.auto_restore_session_at_vim_enter())
    assert.equals(true, no_restore_hook_called)
    assert.True(as.auto_save_session())
    assert.equals(1, vim.fn.filereadable(TL.makeSessionPath(dirs.real)))

    vim.fn.argv:revert()
    vim.cmd("cd " .. vim.fn.fnameescape(cwd))
    vim.fn.delete(dirs.base, "rf")
    c.auto_save = false
    c.resolve_symlinks = false
  end)

  it("restores real path sessions with symlink directory arguments when resolving symlinks", function()
    if vim.fn.has("win32") == 1 then
      return
    end

    no_restore_hook_called = false
    local cwd = vim.fn.getcwd(-1, -1)
    local dirs = make_symlink_dirs()
    local test_file = dirs.real .. "/test.txt"
    c.resolve_symlinks = true

    vim.fn.writefile({ "test" }, test_file)
    vim.cmd("cd " .. vim.fn.fnameescape(dirs.real))
    vim.cmd("e " .. vim.fn.fnameescape(test_file))
    assert.True(as.save_session(nil, { show_message = false }))
    vim.cmd("%bw!")
    vim.cmd("cd " .. vim.fn.fnameescape(cwd))

    local s = stub(vim.fn, "argv")
    s.returns({ dirs.link })

    as.setup(c.options)

    assert.True(as.auto_restore_session_at_vim_enter())
    assert.equals(false, no_restore_hook_called)
    assert.equals(1, vim.fn.bufexists(test_file))

    vim.fn.argv:revert()
    vim.cmd("cd " .. vim.fn.fnameescape(cwd))
    vim.fn.delete(dirs.base, "rf")
    c.resolve_symlinks = false
  end)
end)
