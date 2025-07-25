---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("lock_session_to_startup_cwd", function()
  local as = require "auto-session"
  local lib = require "auto-session.lib"

  TL.clearSessionFilesAndBuffers()

  it("uses startup cwd when enabled", function()
    -- Save original cwd
    local original_cwd = vim.fn.getcwd()
    
    -- Setup with lock_session_to_startup_cwd enabled
    require("auto-session").setup {
      lock_session_to_startup_cwd = true,
      log_level = "debug"
    }

    -- Verify no session exists initially
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))

    -- Create a test file and save session
    vim.cmd("e " .. TL.test_file)
    as.SaveSession()

    -- Verify session was created for the startup cwd
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Change directory to a subdirectory
    vim.cmd("cd tests")
    local new_cwd = vim.fn.getcwd()
    assert.True(new_cwd ~= original_cwd)

    -- Create another file and save session again
    vim.cmd("e other.txt")
    as.SaveSession()

    -- The session should still be saved to the original startup directory,
    -- not the new cwd
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
    
    -- There should NOT be a session file for the new cwd
    local new_cwd_session_path = TL.session_dir .. lib.escape_session_name(new_cwd) .. ".vim"
    assert.equals(0, vim.fn.filereadable(new_cwd_session_path))

    -- Restore original cwd
    vim.cmd("cd " .. original_cwd)
  end)

  TL.clearSessionFilesAndBuffers()

  it("uses current cwd when disabled", function()
    -- Save original cwd
    local original_cwd = vim.fn.getcwd()
    
    -- Setup with lock_session_to_startup_cwd disabled (default)
    require("auto-session").setup {
      lock_session_to_startup_cwd = false,
      log_level = "debug"
    }

    -- Verify no session exists initially
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))

    -- Create a test file and save session
    vim.cmd("e " .. TL.test_file)
    as.SaveSession()

    -- Verify session was created for the current cwd
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Change directory to a subdirectory
    vim.cmd("cd tests")
    local new_cwd = vim.fn.getcwd()
    assert.True(new_cwd ~= original_cwd)

    -- Create another file and save session
    vim.cmd("e other.txt")
    as.SaveSession()

    -- This time, there should be a session file for the new cwd
    local new_cwd_session_path = TL.session_dir .. lib.escape_session_name(new_cwd) .. ".vim"
    assert.equals(1, vim.fn.filereadable(new_cwd_session_path))

    -- Clean up the new session file
    vim.fn.delete(new_cwd_session_path)

    -- Restore original cwd
    vim.cmd("cd " .. original_cwd)
  end)

  TL.clearSessionFilesAndBuffers()
end)