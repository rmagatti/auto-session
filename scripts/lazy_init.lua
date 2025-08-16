-- Script just for installing the plugins we need for testing
-- See minimal_init.lua for more info

vim.env.LAZY_STDPATH = ".test"
load(vim.fn.system "curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua")()

-- Setup lazy.nvim
require("lazy.minit").setup {
  root = "./.test/plugins",
  spec = {
    --  FIXME: Using my fork of plenary just for https://github.com/nvim-lua/plenary.nvim/pull/611
    "cameronr/plenary.nvim",

    { "echasnovski/mini.nvim", version = "v0.16.0" },

    -- for session lens tests
    { "nvim-telescope/telescope.nvim", version = "0.1.8" },
  },
}

-- quit when done
vim.cmd "qa!"
