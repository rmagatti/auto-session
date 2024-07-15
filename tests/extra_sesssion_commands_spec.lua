---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"
TL.clearSessionFilesAndBuffers()

describe("Config with extra session commands", function()
  local save_extra_cmds_called = false
  require("auto-session").setup {
    auto_session_root_dir = TL.session_dir,
    save_extra_cmds = {
      function()
        save_extra_cmds_called = true
        return [[echo "hello world"]]
      end,
    },
  }

  TL.clearSessionFilesAndBuffers()

  local session_name = "x"
  local session_path = TL.session_dir .. session_name .. ".vim"
  local extra_cmds_path = session_path:gsub("%.vim$", "x.vim")

  it("can save a session with extra commands", function()
    vim.cmd(":e " .. TL.test_file)

    local as = require "auto-session"

    -- generate default session
    assert.True(as.AutoSaveSession())

    -- Save a session named "x.vim"
    ---@diagnostic disable-next-line: missing-parameter
    vim.cmd(":SessionSave " .. session_name)

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
    local as = require "auto-session"

    assert.True(as.Lib.is_session_file(TL.session_dir, TL.default_session_name .. ".vim"))
    assert.True(as.Lib.is_session_file(TL.session_dir, session_name .. ".vim"))
    assert.False(as.Lib.is_session_file(TL.session_dir, session_name .. "x.vim"))
  end)
end)
