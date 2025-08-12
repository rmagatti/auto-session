---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("single_session_mode", function()
  local as = require "auto-session"
  local lib = require "auto-session.lib"

  TL.clearSessionFilesAndBuffers()

  it("uses a single session file when enabled", function()
    local original_cwd = vim.fn.getcwd(-1, -1)

    as.setup {
      single_session_mode = true,
    }

    -- Verify no session exists initially
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))

    -- Create a test file and save session
    vim.cmd("e " .. TL.test_file)
    as.SaveSession()

    -- Verify session was created and contains the file
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
    TL.assertSessionHasFile(TL.default_session_path, "test.txt")

    -- Change directory to a subdirectory
    vim.cmd "cd tests"
    local new_cwd = vim.fn.getcwd(-1, -1)
    assert.True(new_cwd ~= original_cwd)

    -- Create another file and save session again
    vim.cmd("e " .. TL.other_file)
    as.SaveSession()

    -- There should NOT be a session file for the new cwd
    local new_cwd_session_path = TL.session_dir .. lib.escape_session_name(new_cwd) .. ".vim"
    assert.equals(0, vim.fn.filereadable(new_cwd_session_path))
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
    -- The session file should contain both files
    TL.assertSessionHasFile(TL.default_session_path, "test.txt")
    TL.assertSessionHasFile(TL.default_session_path, "other.txt")

    vim.cmd("cd " .. original_cwd)
  end)

  TL.clearSessionFilesAndBuffers()

  it("uses current cwd when disabled", function()
    local original_cwd = vim.fn.getcwd()

    as.setup {
      single_session_mode = false,
    }

    -- ensure manually_named_session isn't set
    as.manually_named_session = nil

    -- Verify no session exists initially
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))

    -- Create a test file and save session
    vim.cmd("e " .. TL.test_file)
    as.SaveSession()

    -- Verify session was created and contains the file
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
    TL.assertSessionHasFile(TL.default_session_path, "test.txt")

    -- Change directory to a subdirectory
    vim.cmd "cd tests"
    local new_cwd = vim.fn.getcwd()
    assert.True(new_cwd ~= original_cwd)

    -- Create another file and save session
    vim.cmd("e " .. TL.other_file)
    as.SaveSession()

    -- This time, there SHOULD be a session file for the new cwd
    local new_cwd_session_path = TL.session_dir .. lib.escape_session_name(new_cwd) .. ".vim"
    assert.equals(1, vim.fn.filereadable(new_cwd_session_path))
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
    -- The new session file should contain both files, and the old session
    -- should only contain the first file
    TL.assertSessionHasFile(TL.default_session_path, "test.txt")
    TL.assertSessionDoesNotHaveFile(TL.default_session_path, "other.txt")
    TL.assertSessionHasFile(new_cwd_session_path, "test.txt")
    TL.assertSessionHasFile(new_cwd_session_path, "other.txt")

    vim.fn.delete(new_cwd_session_path)

    vim.cmd("cd " .. original_cwd)
  end)

  it("properly clears manually_named_session when disabled", function()
    local original_cwd = vim.fn.getcwd()

    as.setup {
      single_session_mode = false,
    }

    -- Start with manually_named_session cleared
    as.manually_named_session = nil

    -- Create and save a normal cwd-based session
    vim.cmd("e " .. TL.test_file)
    as.SaveSession()

    -- Verify normal session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
    assert.equals(nil, as.manually_named_session)

    -- Now save a manually named session
    as.SaveSession("manual_session")

    -- Verify manually_named_session is now true
    assert.True(as.manually_named_session)

    -- Restore the normal session (by cwd)
    assert.True(as.RestoreSession(original_cwd))

    -- manually_named_session should now be false since we restored a normal session
    assert.False(as.manually_named_session)

    -- Clean up
    local manual_session_path = TL.session_dir .. lib.escape_session_name("manual_session") .. ".vim"
    vim.fn.delete(manual_session_path)
  end)

  it("maintains single session mode functionality when restoring sessions ", function()
    as.setup {
      single_session_mode = false,
    }
    as.manually_named_session = nil

    local original_cwd = vim.fn.getcwd()

    -- Change to tests directory and create a session there
    vim.cmd "cd tests"
    local tests_cwd = vim.fn.getcwd()

    -- Create a test file and save session
    vim.cmd "e test.txt"
    as.SaveSession()

    -- Verify the session was created
    local tests_session_path = TL.session_dir .. lib.escape_session_name(tests_cwd) .. ".vim"
    assert.equals(1, vim.fn.filereadable(tests_session_path))

    -- Go back to original directory and create another session
    vim.cmd("cd " .. original_cwd)
    vim.cmd "e test.txt"
    as.SaveSession()

    -- Verify the session was created
    local original_session_path = TL.session_dir .. lib.escape_session_name(original_cwd) .. ".vim"
    assert.equals(1, vim.fn.filereadable(original_session_path))

    -- Now enable single_session_mode and setup again
    as.setup {
      single_session_mode = true,
    }

    -- Verify vim.v.this_session is set to original directory session
    local original_session_path = TL.session_dir .. lib.escape_session_name(original_cwd) .. ".vim"
    assert.equals(original_session_path, vim.v.this_session)

    -- Now restore the session from tests directory
    assert.True(as.RestoreSession(tests_cwd))

    -- After restoring the session, vim.v.this_session should be updated
    -- to match the restored session and manually_named_session should be set
    local tests_session_path = TL.session_dir .. lib.escape_session_name(tests_cwd) .. ".vim"
    assert.equals(tests_session_path, vim.v.this_session)
    assert.True(as.manually_named_session)

    vim.cmd("cd " .. original_cwd)
    vim.fn.delete(tests_session_path)
    vim.fn.delete(original_session_path)
  end)

  it("works with manually named sessions", function()
    TL.clearSessionFilesAndBuffers()

    local original_cwd = vim.fn.getcwd(-1, -1)

    as.setup {
      single_session_mode = true,
    }

    -- Create a manually named session
    vim.cmd("e " .. TL.test_file)
    as.SaveSession "my_project"

    -- Verify the named session was created
    local named_session_path = TL.session_dir .. lib.escape_session_name "my_project" .. ".vim"
    assert.equals(1, vim.fn.filereadable(named_session_path))

    -- Verify vim.v.this_session is set to the manually named session
    assert.equals(named_session_path, vim.v.this_session)

    -- Change directory and save again - should still save to the named session
    vim.cmd "cd tests"
    vim.cmd "e test2.txt"
    as.SaveSession()

    -- Should still save to the named session
    assert.equals(1, vim.fn.filereadable(named_session_path))
    TL.assertSessionHasFile(named_session_path, "test.txt")
    TL.assertSessionHasFile(named_session_path, "test2.txt")

    -- Should not create a session for the new cwd
    local new_cwd = vim.fn.getcwd()
    local new_cwd_session_path = TL.session_dir .. lib.escape_session_name(new_cwd) .. ".vim"
    assert.equals(0, vim.fn.filereadable(new_cwd_session_path))

    vim.fn.delete(named_session_path)
    vim.cmd("cd " .. original_cwd)
  end)

  it("gets disabled automatically when cwd_change_handling is also enabled", function()
    TL.clearSessionFilesAndBuffers()
    as.manually_named_session = nil -- Reset manually_named_session
    as.setup {
      single_session_mode = true,
      cwd_change_handling = true, -- Note, this test is last in this file because this config conflict will bleed into other tests
    }

    -- The config validation should have disabled single_session_mode
    local config = require "auto-session.config"
    assert.False(config.single_session_mode)
    assert.True(config.cwd_change_handling)

    -- manually_named_session should still be nil since single_session_mode was disabled
    assert.equals(nil, as.manually_named_session)
  end)

  TL.clearSessionFilesAndBuffers()
end)

