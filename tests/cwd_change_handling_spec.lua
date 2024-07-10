---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("The cwd_change_handling config", function()
  local pre_cwd_changed_hook_called = false
  local post_cwd_changed_hook_called = false
  require("auto-session").setup {
    -- log_level = "debug",
    auto_session_root_dir = TL.session_dir,
    cwd_change_handling = {
      restore_upcoming_session = true,
      pre_cwd_changed_hook = function()
        pre_cwd_changed_hook_called = true
      end,
      post_cwd_changed_hook = function()
        post_cwd_changed_hook_called = true
      end,
    },
  }

  TL.clearSessionFilesAndBuffers()
  vim.cmd(":e " .. TL.test_file)

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

    vim.cmd "cd tests"

    assert.equals(0, vim.fn.bufexists(TL.test_file))
    assert.equals(true, pre_cwd_changed_hook_called)
    assert.equals(true, post_cwd_changed_hook_called)
  end)

  it("does load the session for the base dir", function()
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    vim.cmd "cd .."

    assert.equals("auto-session", require("auto-session.lib").current_session_name())

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)
end)
