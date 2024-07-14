---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("Bypass save by filetypes", function()
  local as = require "auto-session"

  as.setup {
    auto_session_root_dir = TL.session_dir,
    bypass_session_save_file_types = { "text" },
  }

  TL.clearSessionFilesAndBuffers()

  it("doesn't save when only filetypes that match exist", function()
    vim.cmd(":e " .. TL.test_file)

    -- generate default session
    assert.False(as.AutoSaveSession())
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))

    -- add another file
    vim.cmd(":e " .. TL.other_file)

    -- generate default session
    assert.False(as.AutoSaveSession())
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
  end)

  TL.clearSessionFilesAndBuffers()

  it("does save when there are other filetypes", function()
    vim.cmd(":e " .. TL.test_file)
    vim.cmd ":e tests/bypass_session_save_file_types.lua"

    -- generate default session
    assert.True(as.AutoSaveSession())
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
  end)
end)
