---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")

-- Cross platform delete of leftover shada files from the shada describe blocks
local function clear_shada_files()
  for _, file in ipairs(vim.fn.glob(TL.session_dir .. "*.shada", false, true)) do
    vim.fn.delete(file)
  end
end

-- wshada/rshada with an explicit file silently no-op when shadafile is NONE on
-- nvim < 0.11 (fixed in https://github.com/neovim/neovim/pull/32538), so the
-- feature is only enabled on nvim >= 0.11
if vim.fn.has("nvim-0.11") == 1 then
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

    it("sets shadafile to NONE so the global shada isn't loaded", function()
      assert.equals("NONE", vim.o.shadafile)
    end)

    it("deletes the .shada file when deleting a session", function()
      vim.cmd("e " .. TL.test_file)
      ---@diagnostic disable-next-line: missing-parameter
      require("auto-session").save_session("noshada")

      assert.equals(1, vim.fn.filereadable(TL.makeSessionPath("noshada") .. ".shada"))

      ---@diagnostic disable-next-line: missing-parameter
      require("auto-session").delete_session("noshada")

      assert.equals(0, vim.fn.filereadable(TL.makeSessionPath("noshada") .. ".shada"))
    end)
  end)
end

describe("The default config", function()
  require("auto-session").setup({})

  TL.clearSessionFilesAndBuffers()
  clear_shada_files()

  it("does not save a .shada file for the session when disabled", function()
    vim.cmd("e " .. TL.test_file)

    ---@diagnostic disable-next-line: missing-parameter
    require("auto-session").save_session()

    local shada_path = TL.default_session_path .. ".shada"
    assert.equals(0, vim.fn.filereadable(shada_path))
  end)

  it("does not change shadafile when disabled", function()
    vim.o.shadafile = "main.shada"
    require("auto-session").setup({
      save_and_restore_shada = false,
    })
    assert.equals("main.shada", vim.o.shadafile)

    -- Avoid nvim writing a shada to the repo root on exit
    vim.o.shadafile = "NONE"
    vim.fn.delete("main.shada")
  end)
end)
