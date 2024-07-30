---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"
TL.clearSessionFilesAndBuffers()

describe("Config with extra session commands", function()
  local save_extra_cmds_called = false
  local as = require "auto-session"
  as.setup {
    save_extra_cmds = {
      function()
        save_extra_cmds_called = true
        return [[echo "hello world"]]
      end,
    },
    -- log_level = "debug",
  }

  TL.clearSessionFilesAndBuffers()

  local default_extra_cmds_path = TL.default_session_path:gsub("%.vim$", "x.vim")

  it("can save a default session with extra commands", function()
    vim.cmd("e " .. TL.test_file)

    -- generate default session
    assert.True(as.AutoSaveSession())

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
    assert.equals(1, vim.fn.filereadable(default_extra_cmds_path))

    assert.True(save_extra_cmds_called)

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(TL.default_session_path, TL.test_file)

    -- Make sure extra commands are there
    assert.True(TL.fileHasString(default_extra_cmds_path, 'echo \\"hello world\\"'))
  end)

  local session_name = "x"
  local session_path = TL.session_dir .. session_name .. ".vim"
  local extra_cmds_path = session_path:gsub("%.vim$", "x.vim")

  it("can save a named session with extra commands", function()
    save_extra_cmds_called = false
    vim.cmd("e " .. TL.test_file)

    -- save a session named "x.vim"
    ---@diagnostic disable-next-line: missing-parameter
    vim.cmd("SessionSave " .. session_name)

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(session_path))
    assert.equals(1, vim.fn.filereadable(extra_cmds_path))

    assert.True(save_extra_cmds_called)

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(session_path, TL.test_file)

    -- Make sure extra commands are there
    assert.True(TL.fileHasString(extra_cmds_path, 'echo \\"hello world\\"'))
  end)

  it("can correctly differentiate x.vim session and xx.vim custom commands", function()
    assert.True(as.Lib.is_session_file(TL.session_dir .. TL.default_session_name .. ".vim"))
    assert.False(as.Lib.is_session_file(TL.session_dir .. TL.default_session_name .. "x.vim"))
    assert.True(as.Lib.is_session_file(TL.session_dir .. session_name .. ".vim"))
    assert.False(as.Lib.is_session_file(TL.session_dir .. session_name .. "x.vim"))
  end)

  it("deletes a default session's extra commands when deleting the session", function()
    vim.cmd "SessionDelete"

    -- Make sure the session was deleted
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
    assert.equals(1, vim.fn.filereadable(session_path))

    -- Make sure the extra commands were deleted too
    assert.equals(0, vim.fn.filereadable(default_extra_cmds_path))
    assert.equals(1, vim.fn.filereadable(extra_cmds_path))
  end)

  it("deletes a named session's extra commands when deleting the session", function()
    vim.cmd("SessionDelete " .. session_name)

    -- Make sure the session was deleted
    assert.equals(0, vim.fn.filereadable(session_path))

    -- Make sure the extra commands were deleted too
    assert.equals(0, vim.fn.filereadable(extra_cmds_path))
  end)

  it("doesn't delete a session if it is also called x", function()
    ---@diagnostic disable-next-line: missing-parameter
    vim.cmd("SessionSave " .. session_name)
    vim.cmd("SessionSave " .. "xx")

    assert.equals(1, vim.fn.filereadable(session_path))

    local double_xx_session_path = session_path:gsub("%.vim", "x.vim")
    assert.equals(1, vim.fn.filereadable(double_xx_session_path))

    vim.cmd("SessionDelete " .. session_name)

    -- Make sure the session was deleted
    assert.equals(0, vim.fn.filereadable(session_path))

    -- Make sure the session called xx is still there
    assert.equals(1, vim.fn.filereadable(double_xx_session_path))
  end)
end)
