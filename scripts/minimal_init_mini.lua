-- Keep all testing data in ./.test
local root = vim.fn.fnamemodify("./.test", ":p")

-- set stdpaths to use .repro
for _, name in ipairs { "config", "data", "state", "cache" } do
  vim.env[("XDG_%s_HOME"):format(name:upper())] = root .. name
end

-- Add current directory to 'runtimepath' to be able to use 'lua' files
vim.cmd [[let &rtp.=','.getcwd()]]

-- Set up 'mini.test' only when calling headless Neovim (like with `make test`)
if #vim.api.nvim_list_uis() ~= 0 then
  return
end

-- Add 'mini.nvim' to 'runtimepath' to be able to use 'mini.test'
-- Assumed that 'mini.nvim' is stored in 'deps/mini.nvim'
vim.opt.rtp:append "./.test/mini.nvim"

-- Add telescope path for session-lens test
vim.opt.rtp:append "./.test/telescope"

-- Need plenary (even with mini.test) for telescope
vim.opt.rtp:append "./.test/plenary"

-- Set up 'mini.test'
require("mini.test").setup {
  collect = {
    find_files = function()
      return vim.fn.globpath("tests/mini-tests", "**/test_*.lua", true, true)
    end,
  },
}
