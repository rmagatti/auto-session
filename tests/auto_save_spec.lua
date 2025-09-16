---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")

describe("The auto_save_enabled=false config", function()
  require("auto-session").setup({
    auto_save_enabled = false,
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
end)
