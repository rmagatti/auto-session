---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("Ignore filetypes on save", function()
  local as = require "auto-session"

  as.setup {
    ignore_filetypes_on_save = { "text" },
  }

  TL.clearSessionFilesAndBuffers()

  it("closes buffers of ignored filetypes before saving", function()
    vim.cmd("e " .. TL.test_file) -- this is a text file
    vim.cmd "e tests/ignore_filetypes_on_save_spec.lua"

    -- generate default session
    assert.True(as.AutoSaveSession())
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Check that the text file is not in the session
    assert.False(TL.sessionHasFile(TL.default_session_path, TL.test_file))
    -- Check that the lua file is in the session
    assert.True(TL.sessionHasFile(TL.default_session_path, "tests/ignore_filetypes_on_save_spec.lua"))
  end)

  TL.clearSessionFilesAndBuffers()

  it("does not close buffers of other filetypes", function()
    vim.cmd("e " .. TL.test_file) -- this is a text file
    vim.cmd "e tests/ignore_filetypes_on_save_spec.lua"

    as.setup {
      ignore_filetypes_on_save = { "lua" },
    }

    -- generate default session
    assert.True(as.AutoSaveSession())
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Check that the text file is in the session
    assert.True(TL.sessionHasFile(TL.default_session_path, TL.test_file))
    -- Check that the lua file is not in the session
    assert.False(TL.sessionHasFile(TL.default_session_path, "tests/ignore_filetypes_on_save_spec.lua"))
  end)

  TL.clearSessionFilesAndBuffers()

  it("does not save a checkhealth buffer", function()
    vim.cmd("e " .. TL.test_file) -- this is a text file
    vim.cmd "checkhealth auto-session"

    as.setup {
      close_filetypes_on_save = { "checkhealth" }, -- or empty if ignoring checkhealth is the default as suggested above
    }

    -- generate default session
    assert.True(as.AutoSaveSession())
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    as.RestoreSession()

    -- Check that the text file is in the session
    assert.True(TL.sessionHasFile(TL.default_session_path, TL.test_file))
    -- Check that the checkhealth file is not in the session
    assert.False(TL.sessionHasFile(TL.default_session_path, "health://"))
  end)
end)
