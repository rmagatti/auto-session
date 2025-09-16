---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")

describe("Manually named sessions", function()
  require("auto-session").setup({ auto_create = false })

  it("can autosave", function()
    TL.clearSessionFilesAndBuffers()
    vim.cmd("e " .. TL.test_file)

    require("auto-session").save_session(TL.named_session_name)

    vim.cmd("e " .. TL.other_file)

    require("auto-session").auto_save_session()

    -- Make sure the session was not created
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
    assert.equals(1, vim.fn.filereadable(TL.named_session_path))
    TL.assertSessionHasFile(TL.named_session_path, TL.test_file)
    TL.assertSessionHasFile(TL.named_session_path, TL.other_file)
  end)

  it("autosaving doesn't break normal autosaving", function()
    TL.clearSessionFilesAndBuffers()
    vim.cmd("e " .. TL.test_file)
    -- The manually_named_session flag is bleeding into this test from the previous one
    -- This needs to be cleared to simulate the current session not being manually named
    -- Passing nothing to the SaveSession function will use the current manually named
    -- session if the flag is set
    require("auto-session").manually_named_session = false
    require("auto-session").save_session()

    vim.cmd("e " .. TL.other_file)
    assert.equals(1, vim.fn.bufexists(TL.other_file))

    require("auto-session").auto_save_session()

    -- Make sure the session was not created
    assert.equals(0, vim.fn.filereadable(TL.named_session_path))
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
    TL.assertSessionHasFile(TL.default_session_path, TL.test_file)
    TL.assertSessionHasFile(TL.default_session_path, TL.other_file)
  end)

  it("works with single_session_mode enabled", function()
    TL.clearSessionFilesAndBuffers()
    local original_cwd = vim.fn.getcwd()

    require("auto-session").setup({
      single_session_mode = true,
      auto_create = false,
      -- log_level = "debug",
    })

    vim.cmd("e " .. TL.test_file)

    require("auto-session").save_session(TL.named_session_name)

    vim.cmd("cd tests")
    local new_cwd = vim.fn.getcwd()
    assert.True(new_cwd ~= original_cwd)

    vim.cmd("e other_file.txt")
    require("auto-session").auto_save_session()

    -- Should save to the manually named session, not create new session for cwd
    assert.equals(1, vim.fn.filereadable(TL.named_session_path))
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))

    -- Verify both files are in the manually named session
    TL.assertSessionHasFile(TL.named_session_path, "test_files/test.txt")
    TL.assertSessionHasFile(TL.named_session_path, "other_file.txt")

    -- Should not create a session for the new cwd
    local lib = require("auto-session.lib")
    local new_cwd_session_path = TL.session_dir .. lib.escape_session_name(new_cwd) .. ".vim"
    assert.equals(0, vim.fn.filereadable(new_cwd_session_path))

    vim.cmd("cd " .. original_cwd)
  end)
end)
