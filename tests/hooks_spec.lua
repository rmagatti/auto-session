---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")

describe("Hooks", function()
  local as = require("auto-session")
  local pre_save_cmd_called = false
  local post_save_cmd_called = false
  local pre_restore_cmd_called = false
  local post_restore_cmd_called = false
  local pre_delete_cmd_called = false
  local post_delete_cmd_called = false

  as.setup({
    pre_save_cmds = {
      function()
        print("pre_save_cmd")
        pre_save_cmd_called = true
        assert.equals(0, vim.fn.filereadable(TL.default_session_path))
      end,
    },
    post_save_cmds = {
      function()
        print("post_save_cmd")
        post_save_cmd_called = true
        assert.equals(1, vim.fn.filereadable(TL.default_session_path))
      end,
    },
    pre_restore_cmds = {
      function()
        assert.equals(0, vim.fn.bufexists(TL.test_file))
        pre_restore_cmd_called = true
      end,
    },
    post_restore_cmds = {
      function()
        assert.equals(1, vim.fn.bufexists(TL.test_file))
        post_restore_cmd_called = true
      end,
    },
    pre_delete_cmds = {
      function()
        assert.equals(1, vim.fn.filereadable(TL.default_session_path))
        pre_delete_cmd_called = true
      end,
    },
    post_delete_cmds = {
      function()
        assert.equals(0, vim.fn.filereadable(TL.default_session_path))
        post_delete_cmd_called = true
      end,
    },

    -- save_extra is covered by extra_session_commands
    -- no_restore is covered by args tests
  })

  TL.clearSessionFilesAndBuffers()

  it("fire when saving", function()
    vim.cmd("e " .. TL.test_file)

    assert.True(as.AutoSaveSession())
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    assert.True(pre_save_cmd_called)
    assert.True(post_save_cmd_called)
  end)

  it("fire when restoring", function()
    vim.cmd("%bw")

    assert.equals(0, vim.fn.bufexists(TL.test_file))
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    ---@diagnostic disable-next-line: missing-parameter
    assert.True(as.RestoreSession())

    assert.True(pre_restore_cmd_called)
    assert.True(post_restore_cmd_called)
  end)

  it("fire when deleting", function()
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    assert.True(as.DeleteSession())
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))

    assert.True(pre_delete_cmd_called)
    assert.True(post_delete_cmd_called)
  end)
end)
