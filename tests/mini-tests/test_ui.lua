---@diagnostic disable: undefined-field, undefined-global
-- Define helper aliases
local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local TL = require("tests/test_lib")

-- Factory function to generate tests with different configs
local function make_tests(picker, autosession_config, other_config)
  -- Create (but not start) child Neovim object
  local child = MiniTest.new_child_neovim()

  other_config = other_config or ""

  local T = new_set({
    hooks = {
      pre_once = function()
        TL.clearSessionFilesAndBuffers()
      end,
      pre_case = function()
        -- Restart child process with custom 'init.lua' script
        child.restart({ "-u", "scripts/minimal_init_mini.lua", "-V9" })
        -- Load tested plugin with passed config
        child.lua(string.format(
          [[
          %s
          M = require('auto-session').setup(%s)
        ]],
          other_config,
          vim.inspect(autosession_config)
        ))
      end,
      post_once = child.stop,
    },
  })

  ---manual timeout function that works with MiniTest
  ---@param timeout integer timeout in ms
  ---@param fun function(): any
  ---@param interval? integer sleep time in ms
  ---@return any # return from fun
  local function sleep_wait(timeout, fun, interval)
    -- time functions don't seem to tick in MiniTest, manually calculate required iterations
    local iterations = math.ceil(timeout / interval)

    for _ = 0, iterations do
      if fun() then
        return true
      end
      vim.loop.sleep(interval)
    end

    return fun()
  end

  T["session lens"] = new_set({})

  T["session lens"]["save a default session"] = function()
    child.cmd("e " .. TL.test_file)
    expect.equality(1, child.fn.bufexists(TL.test_file))
    child.cmd("SessionSave")

    expect.equality(1, child.fn.bufexists(TL.test_file))
    expect.equality(1, vim.fn.filereadable(TL.default_session_path))
  end

  T["session lens"]["save a named session"] = function()
    child.cmd("e " .. TL.test_file)
    expect.equality(1, child.fn.bufexists(TL.test_file))
    child.cmd("SessionSave " .. TL.named_session_name)
    expect.equality(1, vim.fn.filereadable(TL.named_session_path))

    child.cmd("%bw!")

    child.cmd("e " .. TL.other_file)
    child.cmd("SessionSave project_x")
  end

  T["session lens"]["can load a session"] = function()
    expect.equality(0, child.fn.bufexists(TL.other_file))
    child.cmd("SessionSearch")
    vim.loop.sleep(300)
    child.type_keys("project_x")
    -- print(child.get_screenshot())
    vim.loop.sleep(300)
    child.type_keys("<cr>")
    sleep_wait(2000, function()
      return child.fn.bufexists(TL.other_file) == 1
    end, 100)
    -- print(child.get_screenshot())
    expect.equality(1, child.fn.bufexists(TL.other_file))
  end

  if picker == "select" then
    T["session lens"]["can delete a session"] = function()
      expect.equality(1, vim.fn.filereadable(TL.named_session_path))
      child.cmd("Autosession delete")
      vim.loop.sleep(300)
      child.type_keys("mysession")
      -- print(child.get_screenshot())
      vim.loop.sleep(300)
      child.type_keys("<cr>")
      sleep_wait(2000, function()
        return vim.fn.filereadable(TL.named_session_path) == 0
      end, 100)
      expect.equality(0, vim.fn.filereadable(TL.named_session_path))
    end
  else
    T["session lens"]["can copy a session"] = function()
      expect.equality(0, child.fn.bufexists(TL.test_file))
      child.cmd("SessionSearch")
      local session_name = "project_x"
      vim.loop.sleep(300)
      child.type_keys(session_name)
      vim.loop.sleep(100)
      child.type_keys("<C-Y>")
      vim.loop.sleep(100)
      -- print(child.get_screenshot())
      local copy_name = "copy"
      child.type_keys(copy_name .. "<cr>")
      local filepath = TL.makeSessionPath(session_name .. copy_name)
      -- print(child.get_screenshot())
      sleep_wait(2000, function()
        return vim.fn.filereadable(filepath) == 1
      end, 100)
      expect.equality(1, vim.fn.filereadable(filepath))
    end

    T["session lens"]["can delete a session"] = function()
      expect.equality(1, vim.fn.filereadable(TL.named_session_path))
      child.cmd("SessionSearch")
      vim.loop.sleep(300)
      child.type_keys("mysession")
      -- print(child.get_screenshot())
      vim.loop.sleep(300)
      child.type_keys("<c-d>")
      sleep_wait(2000, function()
        return vim.fn.filereadable(TL.named_session_path) == 0
      end, 100)
      expect.equality(0, vim.fn.filereadable(TL.named_session_path))
    end
  end

  return T
end

local combined = new_set({})

local pickers = {
  { "telescope", "require('telescope').setup()" },
  { "snacks", "require('snacks').setup({picker = {enabled = true}})" },

  -- need snacks to hook select otherwise it blocks the tests.
  -- doing this let us test our select code
  { "select", "require('snacks').setup({picker = {enabled = true}})" },
}

if vim.fn.executable("fzf") == 1 then
  table.insert(pickers, { "fzf", "require('fzf-lua').setup()" })
end

for _, picker in ipairs(pickers) do
  combined["tests with picker " .. picker[1]] = make_tests(picker[1], {
    auto_save_enabled = false,
    auto_restore_enabled = false,
    session_lens = {
      picker = picker[1],
    },
  }, picker[2])
end

return combined
