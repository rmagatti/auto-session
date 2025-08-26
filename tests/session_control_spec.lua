---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")

describe("The default config", function()
  local as = require("auto-session")
  local Lib = require("auto-session.lib")

  as.setup({
    -- log_level = "debug",
  })

  TL.clearSessionFilesAndBuffers()

  it("can save a session control file", function()
    vim.cmd("e " .. TL.test_file)

    ---@diagnostic disable-next-line: missing-parameter
    vim.cmd("AutoSession save")
    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    vim.cmd("%bw!")
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    -- Session control is only written on restore
    vim.cmd("AutoSession restore")

    -- Make sure the restore worked
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    -- Make sure the session control file was written
    assert.equals(1, vim.fn.filereadable(TL.default_session_control_path))
  end)

  it("can save a session control file", function()
    -- Save a new session
    vim.cmd("AutoSession save " .. TL.named_session_name)

    vim.cmd("%bw!")

    assert.equals(0, vim.fn.bufexists(TL.test_file))

    -- Restore the session to set the original one as the alternate
    vim.cmd("AutoSession restore " .. TL.named_session_name)

    -- Make sure session restored
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    -- Make sure the session control file was written
    assert.equals(1, vim.fn.filereadable(TL.default_session_control_path))

    local session_control = Lib.load_session_control_file(TL.default_session_control_path)

    -- Should not be empty
    assert.is_not_nil(next(session_control))

    assert.equals(Lib.expand(TL.named_session_path), session_control.current)
    assert.equals(Lib.expand(TL.default_session_path), session_control.alternate)
  end)

  it("Saving twice doesn't set alternate", function()
    -- Save a session then restore it twice to make sure it's not both current and alternate
    vim.cmd("AutoSession save")

    vim.cmd("AutoSession restore")

    vim.cmd("AutoSession restore ")

    -- Make sure the session control file was written
    assert.equals(1, vim.fn.filereadable(TL.default_session_control_path))

    local session_control = Lib.load_session_control_file(TL.default_session_control_path)

    -- Should not be empty
    assert.is_not_nil(next(session_control))

    assert.equals(Lib.expand(TL.default_session_path), session_control.current)

    -- Should still be mysession from test above
    assert.equals(Lib.expand(TL.named_session_path), session_control.alternate)
  end)

  it("lib function handles edge cases", function()
    -- Don't throw an error on nil
    local session_control = Lib.load_session_control_file(nil)
    assert.equals("table", type(session_control))

    -- Don't throw an error on not a js file
    session_control = Lib.load_session_control_file("tests/session_control_spec.lua")
    assert.equals("table", type(session_control))
  end)
end)
