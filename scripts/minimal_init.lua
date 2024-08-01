-- Keep all testing data in ./.test
local root = vim.fn.fnamemodify("./.test", ":p")

-- set stdpaths to use .repro
for _, name in ipairs { "config", "data", "state", "cache" } do
  vim.env[("XDG_%s_HOME"):format(name:upper())] = root .. name
end

-- Add plenary, so we can run it
vim.opt.rtp:append "./.test/plenary"

-- Add telescope path for session-lens test
vim.opt.rtp:append "./.test/telescope"

require "plenary"
