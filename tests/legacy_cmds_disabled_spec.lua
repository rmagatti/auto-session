---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")

describe("legacy_cmds=false", function()
  local as = require("auto-session")
  as.setup({
    legacy_cmds = false,
  })

  it("legacy commands aren't defined", function()
    assert.Equal(2, vim.fn.exists(":AutoSession"))
    assert.Equal(0, vim.fn.exists(":SessionSave"))
    assert.Equal(0, vim.fn.exists(":SessionRestore"))
    assert.Equal(0, vim.fn.exists(":SessionDelete"))
    assert.Equal(0, vim.fn.exists(":SessionDisableAutoSave"))
    assert.Equal(0, vim.fn.exists(":SessionToggleAutoSave"))
    assert.Equal(0, vim.fn.exists(":SessionSearch"))
    assert.Equal(0, vim.fn.exists(":Autosession"))
  end)
end)
