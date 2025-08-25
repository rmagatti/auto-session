---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")

describe("The cwd_change_handling config", function()
  local pre_cwd_changed_hook_called = false
  local post_cwd_changed_hook_called = false
  require("auto-session").setup({
    -- log_level = "debug",
    cwd_change_handling = {
      restore_upcoming_session = true,
      pre_cwd_changed_hook = function()
        pre_cwd_changed_hook_called = true
      end,
      post_cwd_changed_hook = function()
        post_cwd_changed_hook_called = true
      end,
    },
  })

  TL.clearSessionFilesAndBuffers()
  vim.cmd("e " .. TL.test_file)

  it("can save a session for the current directory (to use later)", function()
    ---@diagnostic disable-next-line: missing-parameter
    require("auto-session").AutoSaveSession()

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(TL.default_session_path, TL.test_file)
    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)

  it("doesn't load a session for tests dir but still dispatches hooks correctly", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))
    assert.equals(false, pre_cwd_changed_hook_called)
    assert.equals(false, post_cwd_changed_hook_called)

    assert.True(vim.v.this_session ~= "")

    vim.cmd("cd tests")
    vim.wait(0)

    assert.equals(0, vim.fn.bufexists(TL.test_file))
    assert.equals(true, pre_cwd_changed_hook_called)
    assert.equals(true, post_cwd_changed_hook_called)

    -- Changing to a directory without a session should clear this_session
    assert.True(vim.v.this_session == "")
  end)

  it("does load the session for the base dir", function()
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    vim.cmd("cd ..")
    vim.wait(0)

    assert.equals(vim.fn.getcwd(), require("auto-session.lib").current_session_name())

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)

  it("does not double load a session when using SessionRestore", function()
    -- Move to different directory
    vim.cmd("cd tests")
    vim.wait(0)

    pre_cwd_changed_hook_called = false
    post_cwd_changed_hook_called = false
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    -- Calling session restore will result in a cd to the main directory
    -- which will also try to restore the session which will throw an error
    -- if this case isn't working
    vim.cmd("SessionRestore " .. TL.default_session_name)

    assert.equals(1, vim.fn.bufexists(TL.test_file))

    -- Currently, the code doesn't dispatch the *_cwd_changed_hooks if a session
    -- is already being loaded
    assert.equals(false, pre_cwd_changed_hook_called)
    assert.equals(false, post_cwd_changed_hook_called)
  end)
end)
