---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")

describe("The create_enabled=false config", function()
  require("auto-session").setup({
    auto_session_create_enabled = false,
  })

  TL.clearSessionFilesAndBuffers()

  it("does not create an autosaved session", function()
    vim.cmd("e " .. TL.test_file)

    ---@diagnostic disable-next-line: missing-parameter
    require("auto-session").auto_save_session()

    -- Make sure the session was not created
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
  end)

  it("can save a session", function()
    vim.cmd("e " .. TL.test_file)

    ---@diagnostic disable-next-line: missing-parameter
    vim.cmd("AutoSession save")

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(TL.default_session_path, TL.test_file)
  end)

  it("can restore a session ", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd("silent %bw")

    -- Make sure the buffer is gone
    assert.equals(0, vim.fn.bufexists(TL.test_file))

    vim.cmd("AutoSession restore")

    assert.equals(1, vim.fn.bufexists(TL.test_file))
  end)

  it("can modify a session", function()
    assert.equals(1, vim.fn.bufexists(TL.test_file))

    vim.cmd("e " .. TL.other_file)

    -- Make sure the buffer is gone
    assert.equals(1, vim.fn.bufexists(TL.other_file))

    vim.cmd("AutoSession save")

    vim.cmd("silent %bw")

    assert.equals(0, vim.fn.bufexists(TL.test_file))
    assert.equals(0, vim.fn.bufexists(TL.other_file))

    vim.cmd("AutoSession restore")

    assert.equals(1, vim.fn.bufexists(TL.test_file))
    assert.equals(1, vim.fn.bufexists(TL.other_file))
  end)
end)

describe("The create_enabled=function config", function()
  local allow_create = false
  local callback_called = false

  -- NOTE: This second call to setup reuses the same auto-session object
  -- so it doesn't re-initialize the config to the default values so be
  -- careful of values set up in the first call
  require("auto-session").setup({
    auto_session_create_enabled = function()
      callback_called = true
      return allow_create
    end,
  })

  TL.clearSessionFilesAndBuffers()
  vim.cmd("e " .. TL.other_file)

  it("calls the callback and does not autosave a session", function()
    require("auto-session").auto_save_session()

    assert.equals(true, callback_called)

    -- Make sure the session was not created
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
  end)

  it("calls the callback and autosaves a session", function()
    callback_called = false
    allow_create = true

    require("auto-session").auto_save_session()

    assert.equals(true, callback_called)

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
  end)
end)
