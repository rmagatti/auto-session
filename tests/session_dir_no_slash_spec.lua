---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("A session directory with no trailing slash", function()
  require("auto-session").setup {
    -- Remove trailing slash
    auto_session_root_dir = TL.session_dir:gsub("/$", ""),
  }

  TL.clearSessionFilesAndBuffers()

  vim.cmd(":e " .. TL.test_file)

  it("saves a session to the directory", function()
    vim.cmd ":SessionSave"

    assert.equals(1, vim.fn.bufexists(TL.test_file))

    -- Make sure it is the same as if it had the trailing slash
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
  end)

  it("loads a session from the directory", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd "silent %bw"

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    vim.cmd ":SessionRestore"

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)
end)
