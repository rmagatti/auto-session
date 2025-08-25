---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")

describe("preserve_buffer_on_restore", function()
  local as = require("auto-session")

  as.setup({
    preserve_buffer_on_restore = function(buf_nr)
      return string.find(vim.api.nvim_buf_get_name(buf_nr):gsub("\\", "/"), TL.other_file, 1, true) ~= nil
    end,
  })

  TL.clearSessionFilesAndBuffers()

  it("preserves matching buffers when restoring", function()
    vim.cmd("e " .. TL.test_file)

    -- generate default session
    assert.True(as.AutoSaveSession())
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    vim.cmd("silent %bw!")

    -- open another buffer to test preserving
    vim.cmd("e " .. TL.other_file)

    assert.True(as.RestoreSession())

    -- make sure both buffers are there after restoring
    assert.equals(1, vim.fn.bufexists(TL.test_file))
    assert.equals(1, vim.fn.bufexists(TL.other_file))
  end)

  TL.clearSessionFilesAndBuffers()
end)
