require("plenary")
local TL = require("tests/test_lib")

describe("auto_delete", function()
  local as = require("auto-session")

  as.setup({
    -- log_level = "debug",
  })

  it("doesn't delete a session with buffers", function()
    TL.clearSessionFilesAndBuffers()
    vim.cmd("e " .. TL.test_file)

    assert.True(as.auto_save_session())
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
    TL.assertSessionHasFile(TL.default_session_path, TL.test_file)
  end)

  it("doesn't delete session when we never loaded a session", function()
    vim.cmd("%bw!")
    vim.v.this_session = ""

    assert.False(as.auto_save_session())
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))
    TL.assertSessionHasFile(TL.default_session_path, TL.test_file)
  end)

  it("deletes a session when empty", function()
    vim.cmd("e " .. TL.test_file)
    assert.True(as.save_session())

    vim.cmd("%bw!")

    assert.False(as.auto_save_session())

    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
  end)
end)
