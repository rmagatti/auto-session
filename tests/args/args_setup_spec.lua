---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"
require("auto-session").setup {
  auto_session_root_dir = TL.session_dir,
  auto_save_enabled = false,
}

describe("The args setup config", function()
  it("can save a session", function()
    vim.cmd(":e " .. TL.test_file)

    vim.cmd ":SessionSave"

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(TL.default_session_path, TL.test_file)
  end)

  it("can restore a session", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd "silent %bw"

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    vim.cmd ":SessionRestore"

    assert.equals(1, vim.fn.bufexists(TL.test_file))

    -- Disable autosaving
  end)
end)
