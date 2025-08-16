dofile "scripts/minimal_init.lua"

-- Add current directory to 'runtimepath' to be able to use 'lua' files
vim.cmd [[let &rtp.=','.getcwd()]]

-- Set up 'mini.test'
require("mini.test").setup {
  collect = {
    find_files = function()
      return vim.fn.globpath("tests/mini-tests", "**/test_*.lua", true, true)
    end,
  },
}
