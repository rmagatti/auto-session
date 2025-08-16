-- NOTE: I tried using lazy here but because plenary can spin up two sessions per
-- spec, it slowed things down quite a bit. I did look at using lazy's busted
-- support but it runs everything in one vim session. While that makes running
-- the tests fast, in introduced a lot of cross test issues. Since a lot of
-- what auto-session does is about startup, it makes sense to stick with
-- plenary to keep the tests clean and not fragile.

-- Keep all testing data in ./.test
local root = vim.fn.fnamemodify("./.test", ":p")
local plugin_root = ".test/plugins/"

-- set stdpaths to use .test
for _, name in ipairs { "config", "data", "state", "cache" } do
  vim.env[("XDG_%s_HOME"):format(name:upper())] = root .. name
end

-- add all plugins to path
local uv = vim.uv or vim.loop
local handle = uv.fs_scandir(vim.fn.expand(plugin_root))
while handle do
  local file, type = uv.fs_scandir_next(handle)
  if not file then
    break
  end

  if type == "directory" then
    vim.opt.rtp:append(plugin_root .. file)
  end
end

-- make sure plenary is loaded
require "plenary"
