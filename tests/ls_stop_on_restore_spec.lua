local TL = require("tests/test_lib")
local stub = require("luassert.stub")

describe("lsp_stop_on_restore", function()
  local as = require("auto-session")
  as.setup({})
  TL.clearSessionFilesAndBuffers()
  vim.cmd("e " .. TL.test_file)
  as.save_session()

  it("calls user function on restore", function()
    local stop_called = false
    as.setup({
      lsp_stop_on_restore = function()
        stop_called = true
      end,
    })

    as.restore_session()

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

  it("stops each active client via Client:stop on restore", function()
    local stopped = {}
    local get_clients = stub(vim.lsp, "get_clients")
    get_clients.returns({
      {
        stop = function()
          table.insert(stopped, "client-1")
        end,
      },
      {
        stop = function()
          table.insert(stopped, "client-2")
        end,
      },
    })

    as.setup({
      lsp_stop_on_restore = true,
    })

    as.restore_session()

    vim.lsp.get_clients:revert()

    assert.same({ "client-1", "client-2" }, stopped)
  end)
end)
