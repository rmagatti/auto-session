---@diagnostic disable: undefined-field
local session_dir = "./tests/test_sessions/"

vim.fn.setenv("AUTOSESSION_ALLOW_HEADLESS_TESTING", 1)

describe("The default config", function()
  require("auto-session").setup {
    auto_session_root_dir = session_dir,
    close_unsupported_windows = false,
  }

  local test_file = "tests/test_files/test.txt"
  local session_name = "auto-test"
  local session_path = session_dir .. session_name .. ".vim"

  pcall(vim.fn.system, "rm -rf tests/test_sessions")

  it("can create a session", function()
    vim.cmd(":e " .. test_file)
    vim.cmd ":w"

    ---@diagnostic disable-next-line: missing-parameter
    require("auto-session").AutoSaveSession(session_name)

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(session_path))

    -- Make sure the session has our buffer
    assert.equals("1", vim.fn.system("grep 'badd' " .. session_path .. " | grep 'test.txt' | wc -l"):gsub("%s+", ""))
  end)

  it("can restore a session", function()
    assert.equals(1, vim.fn.bufexists(test_file))

    vim.cmd "%bw"

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(test_file))

    require("auto-session").RestoreSession(session_path)

    assert.equals(1, vim.fn.bufexists(test_file))
  end)
end)
