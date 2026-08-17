---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")

describe("The save_and_restore_shada config", function()
  require("auto-session").setup({
    save_and_restore_shada = true,
  })

  TL.clearSessionFilesAndBuffers()

  it("saves a .shada file for the session when enabled", function()
    vim.cmd("e " .. TL.test_file)
    vim.fn.setreg("a", "hello")

    ---@diagnostic disable-next-line: missing-parameter
    require("auto-session").save_session()

    local shada_path = TL.default_session_path .. ".shada"
    assert.equals(1, vim.fn.filereadable(shada_path))
  end)

  it("restores the register from the session .shada file", function()
    ---@diagnostic disable-next-line: missing-parameter
    require("auto-session").restore_session()

    assert.equals("hello", vim.fn.getreg("a"))
  end)

  it("does not load the global shada when a session has no shada file", function()
    ---@diagnostic disable-next-line: missing-parameter
    require("auto-session").save_session("noshada")

    -- Remove the shada file so the session has none
    vim.fn.delete(TL.makeSessionPath("noshada") .. ".shada")

    ---@diagnostic disable-next-line: missing-parameter
    require("auto-session").restore_session("noshada")

    assert.equals("NONE", vim.o.shadafile)
  end)

  it("deletes the .shada file when deleting a session", function()
    ---@diagnostic disable-next-line: missing-parameter
    require("auto-session").delete_session("noshada")

    assert.equals(0, vim.fn.filereadable(TL.makeSessionPath("noshada") .. ".shada"))
  end)
end)

describe("The default config", function()
  require("auto-session").setup({})

  TL.clearSessionFilesAndBuffers()
  -- Clear leftover shada files from the first describe
  vim.fn.system("rm -rf " .. TL.session_dir .. "*.shada")

  it("does not save a .shada file for the session when disabled", function()
    vim.cmd("e " .. TL.test_file)

    ---@diagnostic disable-next-line: missing-parameter
    require("auto-session").save_session()

    local shada_path = TL.default_session_path .. ".shada"
    assert.equals(0, vim.fn.filereadable(shada_path))
  end)
end)
