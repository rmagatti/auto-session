---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("lock_session_to_startup_cwd", function()
  local as = require "auto-session"
  local lib = require "auto-session.lib"

  TL.clearSessionFilesAndBuffers()

  it("uses startup cwd when enabled", function()
    local original_cwd = vim.fn.getcwd()

    require("auto-session").setup {
      lock_session_to_startup_cwd = true,
      log_level = "debug",
    }

    -- Verify no session exists initially
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))

    -- Create a test file and save session
    vim.cmd("e " .. TL.test_file)
    as.SaveSession()

    -- Verify session was created for the startup cwd
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Change directory to a subdirectory
    vim.cmd "cd tests"
    local new_cwd = vim.fn.getcwd()
    assert.True(new_cwd ~= original_cwd)

    -- Create another file and save session again
    vim.cmd "e other.txt"
    as.SaveSession()

    -- The session should still be saved to the original startup directory,
    -- not the new cwd
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- There should NOT be a session file for the new cwd
    local new_cwd_session_path = TL.session_dir .. lib.escape_session_name(new_cwd) .. ".vim"
    assert.equals(0, vim.fn.filereadable(new_cwd_session_path))

    vim.cmd("cd " .. original_cwd)
  end)

  TL.clearSessionFilesAndBuffers()

  it("uses current cwd when disabled", function()
    local original_cwd = vim.fn.getcwd()

    require("auto-session").setup {
      lock_session_to_startup_cwd = false,
      log_level = "debug",
    }

    -- Verify no session exists initially
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))

    -- Create a test file and save session
    vim.cmd("e " .. TL.test_file)
    as.SaveSession()

    -- Verify session was created for the current cwd
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Change directory to a subdirectory
    vim.cmd "cd tests"
    local new_cwd = vim.fn.getcwd()
    assert.True(new_cwd ~= original_cwd)

    -- Create another file and save session
    vim.cmd "e other.txt"
    as.SaveSession()

    -- This time, there should be a session file for the new cwd
    local new_cwd_session_path = TL.session_dir .. lib.escape_session_name(new_cwd) .. ".vim"
    assert.equals(1, vim.fn.filereadable(new_cwd_session_path))

    vim.fn.delete(new_cwd_session_path)

    vim.cmd("cd " .. original_cwd)
  end)

  it("updates startup_cwd when restoring a legacy session without metadata", function()
    -- First, create a session without the lock_session_to_startup_cwd feature
    -- This simulates a legacy session created before the feature was added

    -- Setup without lock_session_to_startup_cwd first
    require("auto-session").setup {
      lock_session_to_startup_cwd = false,
      log_level = "debug",
    }

    local original_cwd = vim.fn.getcwd()

    -- Change to tests directory and create a "legacy" session there
    vim.cmd "cd tests"
    local tests_cwd = vim.fn.getcwd()

    -- Create a test file and save session (this will be our "legacy" session)
    vim.cmd "e legacy_test.txt"
    as.SaveSession()

    -- Verify the legacy session was created
    local legacy_session_path = TL.session_dir .. lib.escape_session_name(tests_cwd) .. ".vim"
    assert.equals(1, vim.fn.filereadable(legacy_session_path))

    -- Go back to original directory
    vim.cmd("cd " .. original_cwd)

    -- Now enable lock_session_to_startup_cwd and setup again
    require("auto-session").setup {
      lock_session_to_startup_cwd = true,
      log_level = "debug",
    }

    -- Verify startup_cwd is set to original directory
    assert.equals(original_cwd, as.startup_cwd)

    -- Now restore the legacy session from tests directory
    assert.True(as.RestoreSession(tests_cwd))

    -- After restoring the legacy session, startup_cwd should be updated
    -- to match the restored session's directory
    assert.equals(tests_cwd, as.startup_cwd)

    vim.cmd("cd " .. original_cwd)
    vim.fn.delete(legacy_session_path)
  end)

  it("handles git branch sessions correctly when extracting directory", function()
    local original_cwd = vim.fn.getcwd()

    require("auto-session").setup {
      lock_session_to_startup_cwd = true,
      git_use_branch_name = true,
      log_level = "debug",
    }

    -- Create a mock session name with git branch format: "/path/to/dir|main"
    local session_name_with_branch = original_cwd .. "|main"
    local session_path = TL.session_dir .. lib.escape_session_name(session_name_with_branch) .. ".vim"

    -- Create a minimal session file
    vim.fn.writefile({ '" Session file' }, session_path)

    -- Set startup_cwd to something different initially
    as.startup_cwd = "/different/path"

    -- Restore the session with git branch
    assert.True(as.RestoreSession(session_name_with_branch))

    -- startup_cwd should be updated to the directory part (without the git branch)
    assert.equals(original_cwd, as.startup_cwd)

    vim.fn.delete(session_path)
  end)

  it("disables lock_session_to_startup_cwd when cwd_change_handling is also enabled", function()
    local config = require "auto-session.config"

    require("auto-session").setup {
      lock_session_to_startup_cwd = true,
      cwd_change_handling = true,
      log_level = "debug",
    }

    -- The config validation should have disabled lock_session_to_startup_cwd
    assert.False(config.lock_session_to_startup_cwd)
    assert.True(config.cwd_change_handling)

    -- startup_cwd should not be set since lock_session_to_startup_cwd was disabled
    assert.equals(nil, as.startup_cwd)
  end)

  it("saves startup_cwd to extra commands file when enabled", function()
    as.startup_cwd = nil
    local config = require "auto-session.config"
    config.lock_session_to_startup_cwd = nil
    
    local original_cwd = vim.fn.getcwd()
    
    require("auto-session").setup {
      lock_session_to_startup_cwd = true,
      log_level = "debug",
    }

    -- Verify startup_cwd is set
    assert.equals(original_cwd, as.startup_cwd)

    -- Create a test file and save session
    vim.cmd("e " .. TL.test_file)
    as.SaveSession()

    -- Verify session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Check that the extra commands file was created with startup_cwd
    local extra_commands_path = TL.default_session_path:gsub("%.vim$", "x.vim")
    assert.equals(1, vim.fn.filereadable(extra_commands_path))

    -- Read the extra commands file and verify it contains the startup_cwd
    local extra_content = vim.fn.readfile(extra_commands_path)
    local expected_startup_cwd_line = "lua require('auto-session').startup_cwd = '" .. original_cwd .. "'"
    
    -- Check that the expected line is in the extra commands file
    local found_startup_cwd_line = false
    for _, line in ipairs(extra_content) do
      if line == expected_startup_cwd_line then
        found_startup_cwd_line = true
        break
      end
    end
    
    assert.True(found_startup_cwd_line, "Expected startup_cwd line not found in extra commands file")
  end)

  TL.clearSessionFilesAndBuffers()
end)

