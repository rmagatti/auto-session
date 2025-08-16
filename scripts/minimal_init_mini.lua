dofile "scripts/minimal_init.lua"

-- Set up 'mini.test'
require("mini.test").setup {
  collect = {
    find_files = function()
      return vim.fn.globpath("tests/mini-tests", "**/test_*.lua", true, true)
    end,
  },
}
