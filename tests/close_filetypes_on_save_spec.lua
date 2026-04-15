---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")

describe("Close filetypes on save", function()
  local as = require("auto-session")

  as.setup({
    -- use old config name
    ignore_filetypes_on_save = { "text" },
  })

  TL.clearSessionFilesAndBuffers()

  it("closes buffers of matching filetypes before saving", function()
    vim.cmd("e " .. TL.test_file) -- this is a text file
    vim.cmd("e tests/close_filetypes_on_save_spec.lua")

    -- generate default session
    assert.True(as.auto_save_session())
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Check that the text file is not in the session
    assert.False(TL.sessionHasFile(TL.default_session_path, TL.test_file))
    -- Check that the lua file is in the session
    assert.True(TL.sessionHasFile(TL.default_session_path, "tests/close_filetypes_on_save_spec.lua"))
  end)

  TL.clearSessionFilesAndBuffers()

  it("does not close buffers of other filetypes", function()
    vim.cmd("e " .. TL.test_file) -- this is a text file
    vim.cmd("e tests/close_filetypes_on_save_spec.lua")

    as.setup({
      close_filetypes_on_save = { "lua" },
    })

    -- generate default session
    assert.True(as.auto_save_session())
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Check that the text file is in the session
    assert.True(TL.sessionHasFile(TL.default_session_path, TL.test_file))
    -- Check that the lua file is not in the session
    assert.False(TL.sessionHasFile(TL.default_session_path, "tests/close_filetypes_on_save_spec.lua"))
  end)

  TL.clearSessionFilesAndBuffers()

  it("does not save a checkhealth buffer", function()
    vim.cmd("e " .. TL.test_file) -- this is a text file
    vim.cmd("checkhealth auto-session")

    as.setup({
      close_filetypes_on_save = { "checkhealth" }, -- or empty if ignoring checkhealth is the default as suggested above
    })

    -- generate default session
    assert.True(as.auto_save_session())
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    as.restore_session()

    -- Check that the text file is in the session
    assert.True(TL.sessionHasFile(TL.default_session_path, TL.test_file))
    -- Check that the checkhealth file is not in the session
    assert.False(TL.sessionHasFile(TL.default_session_path, "health://"))
  end)

  TL.clearSessionFilesAndBuffers()

  it("gracefully closes snacks_terminal buffers before saving", function()
    local notifications = {}
    local original_notify = vim.notify

    vim.notify = function(msg, level, opts)
      table.insert(notifications, { msg = msg, level = level, opts = opts })
    end

    vim.cmd("enew")
    local terminal_buf = vim.api.nvim_get_current_buf()

    local terminal_closed = false
    vim.api.nvim_create_autocmd("TermClose", {
      buffer = terminal_buf,
      callback = function()
        if type(vim.v.event) == "table" and vim.v.event.status ~= 0 then
          vim.notify("Terminal exited with code " .. vim.v.event.status .. ".\nCheck for any errors.")
          return
        end
        terminal_closed = true
      end,
    })

    vim.fn.termopen({ vim.o.shell, "-c", "while IFS= read -r line; do [ \"$line\" = exit ] && exit 0; done" })
    vim.bo[terminal_buf].filetype = "snacks_terminal"

    as.setup({
      close_filetypes_on_save = { "snacks_terminal" },
    })

    local ok = pcall(as.auto_save_session)

    vim.notify = original_notify

    assert.True(ok)
    vim.wait(1000, function()
      return terminal_closed
    end, 10)
    assert.True(terminal_closed)
    assert.False(vim.api.nvim_buf_is_valid(terminal_buf))

    for _, notification in ipairs(notifications) do
      assert.is_nil(notification.msg:match("Terminal exited with code %-1"))
    end
  end)
end)
