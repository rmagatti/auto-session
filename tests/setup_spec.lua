---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("The default config", function()
  require("auto-session").setup {
    auto_session_root_dir = TL.session_dir,
  }

  TL.clearSessionFilesAndBuffers()

  it("can save a session", function()
    vim.cmd(":e " .. TL.test_file)

    ---@diagnostic disable-next-line: missing-parameter
    require("auto-session").AutoSaveSession()

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
  end)

  it("can delete a session", function()
    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    ---@diagnostic disable-next-line: param-type-mismatch
    vim.cmd ":SessionDelete"

    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
  end)

  -- pcall(vim.fn.system, "rm -rf tests/test_sessions")

  it("can save a session with a file path", function()
    vim.cmd(":e " .. TL.test_file)

    ---@diagnostic disable-next-line: missing-parameter
    require("auto-session").SaveSession(TL.named_session_name)

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.named_session_path))

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(TL.named_session_path, TL.test_file)
  end)

  it("can restore a session from a file path", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd "silent %bw"

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    vim.cmd(":SessionRestore " .. TL.named_session_path)

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)

  it("can restore a session using SessionRestoreFromFile", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd "silent %bw"

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    vim.cmd(":SessionRestoreFromFile " .. TL.named_session_name)

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)

  it("can delete a session with a file path", function()
    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.named_session_path))

    ---@diagnostic disable-next-line: param-type-mismatch
    vim.cmd(":SessionDelete " .. TL.named_session_path)

    assert.equals(0, vim.fn.filereadable(TL.named_session_path))
  end)
end)
