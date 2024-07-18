---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

local custom_session_dir = "/tests/custom_sessions/"

TL.clearSessionFilesAndBuffers()
TL.clearSessionFiles(custom_session_dir)

describe("A custom session dir config", function()
  require("auto-session").setup {
    -- Remove trailing slash
    auto_session_root_dir = vim.fn.getcwd() .. custom_session_dir,
    -- log_level = "debug",
  }

  TL.clearSessionFilesAndBuffers()

  vim.cmd("e " .. TL.test_file)

  it("can save default session to the directory", function()
    vim.cmd "SessionSave"

    assert.equals(1, vim.fn.bufexists(TL.test_file))

    local session_path = vim.fn.getcwd() .. custom_session_dir .. TL.default_session_name .. ".vim"

    -- Make sure it is the same as if it had the trailing slash
    print(session_path)
    assert.equals(1, vim.fn.filereadable(session_path))

    -- Make sure default session isn't there
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
  end)

  it("can load default session from the directory", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd "silent %bw"

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    vim.cmd "SessionRestore"

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)

  local named_session = "mysession"

  it("can save a named session to the directory", function()
    vim.cmd("SessionSave " .. named_session)

    assert.equals(1, vim.fn.bufexists(TL.test_file))

    local session_path = vim.fn.getcwd() .. custom_session_dir .. named_session .. ".vim"

    -- Make sure it is the same as if it had the trailing slash
    assert.equals(1, vim.fn.filereadable(session_path))

    -- Make sure default session isn't there
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
  end)

  it("can load a named session from the directory", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd "silent %bw"

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    local session_path = vim.fn.getcwd() .. custom_session_dir .. named_session .. ".vim"

    vim.cmd("SessionRestore " .. session_path)

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)
end)
