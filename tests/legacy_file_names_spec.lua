---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("Legacy file name support", function()
  local as = require "auto-session"
  as.setup {
    -- log_level = "debug",
  }

  local Lib = as.Lib

  it("can convert old session file names to new format", function()
    TL.clearSessionFilesAndBuffers()

    -- save a default session
    as.SaveSession()
    as.SaveSession(TL.named_session_name)

    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
    assert.equals(1, vim.fn.filereadable(TL.named_session_path))

    local old_sessions = {
      "%Users%home%a.vim",
      "%Users%home%b.vim",
      "%Users%home%c.vim",
      "%Users%home%123.vim",
      "%Users%homw%dash-tiest.vim",
      "%Users%home%123%otherdir.vim",
      "%Users%home%dash-test%otherdir.vim",
    }

    for _, file_name in ipairs(old_sessions) do
      TL.createFile(TL.session_dir .. file_name)
      assert.equals(1, vim.fn.filereadable(TL.session_dir .. file_name))
    end

    Lib.convert_session_dir(TL.session_dir)

    for _, old_file_name in ipairs(old_sessions) do
      assert.equals(0, vim.fn.filereadable(TL.session_dir .. old_file_name))
    end

    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
    assert.equals(1, vim.fn.filereadable(TL.named_session_path))
  end)

  it("can convert a session to the new format during a restore", function()
    TL.clearSessionFilesAndBuffers()

    vim.cmd("e " .. TL.test_file)

    assert.equals(1, vim.fn.bufexists(TL.test_file))

    -- save a default session in new format
    as.SaveSession()
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    vim.loop.fs_rename(TL.default_session_path, TL.default_session_path_legacy)

    assert.equals(1, vim.fn.filereadable(TL.default_session_path_legacy))
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))

    vim.cmd "%bw!"

    assert.equals(0, vim.fn.bufexists(TL.test_file))

    as.RestoreSession()

    -- did we successfully restore the session?
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    -- did we know have a new filename?
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- and no old file name?
    assert.equals(0, vim.fn.filereadable(TL.default_session_path_legacy))
  end)
end)
