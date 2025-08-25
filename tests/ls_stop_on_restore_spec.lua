local TL = require("tests/test_lib")

describe("lsp_stop_on_restore", function()
  local as = require("auto-session")
  as.setup({})
  TL.clearSessionFilesAndBuffers()
  vim.cmd("e " .. TL.test_file)
  as.SaveSession()

  it("calls user function on restore", function()
    local stop_called = false
    as.setup({
      lsp_stop_on_restore = function()
        stop_called = true
      end,
    })

    as.RestoreSession()

    assert.True(stop_called)
  end)

  it("doesn't try to stop ls on initial autorestore", function()
    local stop_called = false
    as.setup({
      lsp_stop_on_restore = function()
        stop_called = true
      end,
    })

    as.auto_restore_session_at_vim_enter()

    assert.False(stop_called)
  end)
end)
