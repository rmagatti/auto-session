---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")
TL.clearSessionFilesAndBuffers()

describe("Config with extra session commands", function()
  local save_extra_cmds_called = false
  local as = require("auto-session")
  local Lib = require("auto-session.lib")
  -- WARN: this test calls setup again later to change save_extra_cmds
  as.setup({
    save_extra_cmds = {
      function()
        save_extra_cmds_called = true
        return [[
        lua vim.g.extraCmdsTest = 1
        lua vim.g.extraCmdsTest2 = 2
        ]]
      end,
    },
    -- log_level = "debug",
  })

  TL.clearSessionFilesAndBuffers()

  local default_extra_cmds_path = TL.default_session_path:gsub("%.vim$", "x.vim")

  it("can save a default session with extra commands", function()
    vim.cmd("e " .. TL.test_file)

    -- generate default session
    assert.True(as.auto_save_session())

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
    assert.equals(1, vim.fn.filereadable(default_extra_cmds_path))

    assert.True(save_extra_cmds_called)

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(TL.default_session_path, TL.test_file)

    -- Make sure extra commands are there
    assert.True(TL.fileHasString(default_extra_cmds_path, "lua vim.g.extraCmdsTest = 1"))
  end)

  it("can restore a default session with extra commands", function()
    vim.g.extraCmdsTest = 0
    vim.g.extraCmdsTest2 = 0

    assert.True(as.restore_session())

    assert.True(vim.g.extraCmdsTest == 1)
    assert.True(vim.g.extraCmdsTest2 == 2)
  end)

  it("can clear x.vim if there are no extra commands", function()
    -- make sure the file is there now
    assert.equals(1, vim.fn.filereadable(default_extra_cmds_path))

    -- remove the handler
    as.setup({
      save_extra_cmds = nil,
    })

    -- generate default session
    assert.True(as.auto_save_session())

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- make sure the extra commands file was removed
    assert.equals(0, vim.fn.filereadable(default_extra_cmds_path))
  end)

  TL.clearSessionFilesAndBuffers()

  it("can save a default session with extra commands in a table", function()
    vim.cmd("e " .. TL.test_file)

    save_extra_cmds_called = false

    as.setup({
      save_extra_cmds = {
        function()
          save_extra_cmds_called = true
          return { "lua vim.g.extraCmdsTest = 1", "lua vim.g.extraCmdsTest2 = 2" }
        end,
      },
    })

    -- generate default session
    assert.True(as.auto_save_session())

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
    assert.equals(1, vim.fn.filereadable(default_extra_cmds_path))

    assert.True(save_extra_cmds_called)

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(TL.default_session_path, TL.test_file)

    -- Make sure extra commands are there
    assert.True(TL.fileHasString(default_extra_cmds_path, "lua vim.g.extraCmdsTest = 1"))
  end)

  it("can restore a default session with extra commands", function()
    vim.g.extraCmdsTest = 0
    vim.g.extraCmdsTest2 = 0

    assert.True(as.restore_session())

    assert.True(vim.g.extraCmdsTest == 1)
    assert.True(vim.g.extraCmdsTest2 == 2)
  end)

  local session_name = "x"
  local session_path = TL.session_dir .. session_name .. ".vim"
  local extra_cmds_path = session_path:gsub("%.vim$", "x.vim")

  it("can save a named session with extra commands", function()
    save_extra_cmds_called = false
    vim.cmd("e " .. TL.test_file)

    -- save a session named "x.vim"
    ---@diagnostic disable-next-line: missing-parameter
    vim.cmd("AutoSession save " .. session_name)

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(session_path))
    assert.equals(1, vim.fn.filereadable(extra_cmds_path))

    assert.True(save_extra_cmds_called)

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(session_path, TL.test_file)

    -- Make sure extra commands are there
    assert.True(TL.fileHasString(extra_cmds_path, "lua vim.g.extraCmdsTest = 1"))
  end)

  it("can correctly differentiate x.vim session and xx.vim custom commands", function()
    assert.True(Lib.is_session_file(TL.session_dir .. TL.default_session_name .. ".vim"))
    assert.False(Lib.is_session_file(TL.session_dir .. TL.default_session_name .. "x.vim"))
    assert.True(Lib.is_session_file(TL.session_dir .. session_name .. ".vim"))
    assert.False(Lib.is_session_file(TL.session_dir .. session_name .. "x.vim"))
  end)

  it("deletes a default session's extra commands when deleting the session", function()
    vim.cmd("AutoSession delete")

    -- Make sure the session was deleted
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
    assert.equals(1, vim.fn.filereadable(session_path))

    -- Make sure the extra commands were deleted too
    assert.equals(0, vim.fn.filereadable(default_extra_cmds_path))
    assert.equals(1, vim.fn.filereadable(extra_cmds_path))
  end)

  it("deletes a named session's extra commands when deleting the session", function()
    vim.cmd("AutoSession delete " .. session_name)

    -- Make sure the session was deleted
    assert.equals(0, vim.fn.filereadable(session_path))

    -- Make sure the extra commands were deleted too
    assert.equals(0, vim.fn.filereadable(extra_cmds_path))
  end)

  it("doesn't delete a session if it is also called x", function()
    ---@diagnostic disable-next-line: missing-parameter
    vim.cmd("AutoSession save " .. session_name)
    vim.cmd("AutoSession save " .. "xx")

    assert.equals(1, vim.fn.filereadable(session_path))

    local double_xx_session_path = session_path:gsub("%.vim", "x.vim")
    assert.equals(1, vim.fn.filereadable(double_xx_session_path))

    vim.cmd("AutoSession delete " .. session_name)

    -- Make sure the session was deleted
    assert.equals(0, vim.fn.filereadable(session_path))

    -- Make sure the session called xx is still there
    assert.equals(1, vim.fn.filereadable(double_xx_session_path))
  end)
end)
