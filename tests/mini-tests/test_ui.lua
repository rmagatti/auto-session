---@diagnostic disable: undefined-field
-- Define helper aliases
local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

-- Create (but not start) child Neovim object
local child = MiniTest.new_child_neovim()

-- Define main test set of this file
local T = new_set {
  -- Register hooks
  hooks = {
    -- This will be executed before every (even nested) case
    pre_case = function()
      -- Restart child process with custom 'init.lua' script
      child.restart { "-u", "scripts/minimal_init_mini.lua" }
      -- Load tested plugin
      child.lua [[M = require('auto-session').setup()]]
    end,
    -- This will be executed one after all tests from this set are finished
    post_once = child.stop,
  },
}

local TL = require "tests/test_lib"
TL.clearSessionFilesAndBuffers()

T["session lens"] = new_set {}

T["session lens"]["save a default session"] = function()
  child.cmd("e " .. TL.test_file)
  expect.equality(1, child.fn.bufexists(TL.test_file))
  child.cmd "SessionSave"

  expect.equality(1, child.fn.bufexists(TL.test_file))
  expect.equality(1, vim.fn.filereadable(TL.default_session_path))
end

T["session lens"]["save a named session"] = function()
  child.cmd("e " .. TL.test_file)
  expect.equality(1, child.fn.bufexists(TL.test_file))
  child.cmd("SessionSave " .. TL.named_session_name)
  expect.equality(1, vim.fn.filereadable(TL.named_session_path))

  -- to make sure we can list sessions ending in x (checked in test below)
  child.cmd "SessionSave project_x"
end

T["session lens"]["can load a session"] = function()
  expect.equality(0, child.fn.bufexists(TL.test_file))
  child.cmd "SessionSearch"
  -- give the UI time to come up
  vim.loop.sleep(100)
  child.type_keys "<cr>"
  -- give the session time to load
  vim.loop.sleep(500)
  expect.equality(1, child.fn.bufexists(TL.test_file))
end

T["session lens"]["can delete a session"] = function()
  expect.equality(1, vim.fn.filereadable(TL.named_session_path))
  child.cmd "SessionSearch"
  -- give the UI time to come up
  vim.loop.sleep(100)
  child.type_keys "mysession"
  child.type_keys "<c-d>"
  vim.loop.sleep(100)
  expect.equality(0, vim.fn.filereadable(TL.named_session_path))
end

-- Return test set which will be collected and execute inside `MiniTest.run()`
return T
