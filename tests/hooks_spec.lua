---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")

describe("Hooks", function()
  local as = require("auto-session")
  local c = require("auto-session.config")
  local pre_save_cmd_called = false
  local pre_save_session_name
  local post_save_cmd_called = false
  local pre_restore_cmd_called = false
  local pre_restore_session_name
  local post_restore_cmd_called = false
  local pre_delete_cmd_called = false
  local post_delete_cmd_called = false

  as.setup({
    pre_save_cmds = {
      function(session_name)
        -- print("pre_save_cmd")
        pre_save_cmd_called = true
        pre_save_session_name = session_name
      end,
    },
    post_save_cmds = {
      function()
        -- print("post_save_cmd")
        post_save_cmd_called = true
      end,
    },
    pre_restore_cmds = {
      function(session_name)
        pre_restore_cmd_called = true
        pre_restore_session_name = session_name
      end,
    },
    post_restore_cmds = {
      function()
        post_restore_cmd_called = true
      end,
    },
    pre_delete_cmds = {
      function()
        pre_delete_cmd_called = true
      end,
    },
    post_delete_cmds = {
      function()
        post_delete_cmd_called = true
      end,
    },

    -- save_extra is covered by extra_session_commands
    -- no_restore is covered by args tests
  })

  TL.clearSessionFilesAndBuffers()

  it("fire when saving", function()
    vim.cmd("e " .. TL.test_file)

    assert.True(as.save_session())
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    assert.True(pre_save_cmd_called)
    assert.True(post_save_cmd_called)
    assert.equals(TL.default_session_name, pre_save_session_name)
  end)

  it("fire when restoring", function()
    vim.cmd("%bw")

    assert.equals(0, vim.fn.bufexists(TL.test_file))
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    ---@diagnostic disable-next-line: missing-parameter
    assert.True(as.restore_session())

    assert.True(pre_restore_cmd_called)
    assert.True(post_restore_cmd_called)
    assert.equals(TL.default_session_name, pre_restore_session_name)
  end)

  it("fire when deleting", function()
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    assert.True(as.delete_session())
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))

    assert.True(pre_delete_cmd_called)
    assert.True(post_delete_cmd_called)
  end)

  it("pre_save returning false stops auto-save but not save", function()
    TL.clearSessionFilesAndBuffers()
    vim.cmd("e " .. TL.test_file)

    -- re-enable auto-save because test above deletes the current session
    -- which disables auto-save
    c.auto_save = true
    c.pre_save_cmds = {
      function()
        pre_save_cmd_called = true
        print("returning false in pre_save_cmds")
        return false
      end,
    }

    pre_save_cmd_called = false
    post_save_cmd_called = false

    assert.False(as.auto_save_session())

    assert.equals(0, vim.fn.filereadable(TL.default_session_path))

    assert.True(pre_save_cmd_called)
    assert.False(post_save_cmd_called)

    -- now make sure non-auto save works

    pre_save_cmd_called = false
    post_save_cmd_called = false

    assert.True(as.save_session())

    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    assert.True(pre_save_cmd_called)
    assert.True(post_save_cmd_called)
  end)

  it("pre_restore returning false stops auto-restore but not restore", function()
    vim.cmd("%bw")

    assert.equals(0, vim.fn.bufexists(TL.test_file))
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    c.pre_restore_cmds = {
      function()
        pre_restore_cmd_called = true
        print("returning false in pre_restore_cmds")
        return false
      end,
    }

    -- make sure auto-restore can be stopped

    pre_restore_cmd_called = false
    post_restore_cmd_called = false

    assert.False(as.auto_restore_session(nil, true))

    assert.True(pre_restore_cmd_called)
    assert.False(post_restore_cmd_called)
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    -- now make sure non-auto restore works

    pre_restore_cmd_called = false
    post_restore_cmd_called = false

    assert.True(as.restore_session())

    assert.True(pre_restore_cmd_called)
    assert.True(post_restore_cmd_called)
    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)
end)
