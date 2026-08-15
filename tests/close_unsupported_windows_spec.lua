---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")

describe("Close unsupported windows", function()
  local as = require("auto-session")

  local function has_open_window_with_buftype(target_buftype)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
      if buftype == target_buftype then
        return true
      end
    end

    return false
  end

  local function open_quickfix()
    vim.fn.setqflist({
      {
        filename = TL.test_file,
        lnum = 1,
        col = 1,
        text = "quickfix entry",
      },
    }, "r")
    vim.cmd("copen")
  end

  local function open_nofile_window()
    vim.cmd("vnew")
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = 0 })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = 0 })
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "scratch buffer" })
  end

  before_each(function()
    TL.clearSessionFilesAndBuffers()
    vim.fn.setqflist({}, "r")
    vim.g.close_unsupported_windows_qf_open = nil
    vim.g.close_unsupported_windows_nofile_open = nil
  end)

  it("closes unsupported windows by default", function()
    as.setup({
      close_unsupported_windows = true,
      save_extra_cmds = {
        function()
          vim.g.close_unsupported_windows_qf_open = vim.fn.getqflist({ winid = 1 }).winid ~= 0
          vim.g.close_unsupported_windows_nofile_open = has_open_window_with_buftype("nofile")
          return nil
        end,
      },
    })

    vim.cmd("e " .. TL.test_file)
    open_quickfix()
    open_nofile_window()

    assert.True(as.auto_save_session())
    assert.False(vim.g.close_unsupported_windows_qf_open)
    assert.False(vim.g.close_unsupported_windows_nofile_open)
  end)

  it("preserves configured unsupported windows for save_extra_cmds", function()
    as.setup({
      close_unsupported_windows = {
        preserve_buftypes = { "quickfix" },
      },
      save_extra_cmds = {
        function()
          vim.g.close_unsupported_windows_qf_open = vim.fn.getqflist({ winid = 1 }).winid ~= 0
          vim.g.close_unsupported_windows_nofile_open = has_open_window_with_buftype("nofile")
          return nil
        end,
      },
    })

    vim.cmd("e " .. TL.test_file)
    open_quickfix()
    open_nofile_window()

    assert.True(as.auto_save_session())
    assert.True(vim.g.close_unsupported_windows_qf_open)
    assert.False(vim.g.close_unsupported_windows_nofile_open)
  end)
end)
