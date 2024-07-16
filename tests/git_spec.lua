---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("The git config", function()
  require("auto-session").setup {
    auto_session_use_git_branch = true,
  }

  TL.clearSessionFilesAndBuffers()

  local git_test_dir = TL.tests_base_dir .. "/test_git"

  -- make test git dir
  if vim.fn.isdirectory(git_test_dir) ~= 1 then
    vim.fn.mkdir(git_test_dir)
  else
    TL.clearSessionFiles(git_test_dir)
  end

  -- get a file in that dir
  vim.cmd(":e " .. TL.test_file)
  vim.cmd(":w! " .. git_test_dir .. "/test.txt")
  vim.cmd "%bw"

  -- change to that dir
  vim.cmd(":cd " .. git_test_dir)

  -- init repo and make a commit
  vim.fn.system "git init -b main"
  vim.fn.system "git add ."
  vim.fn.system "git commit -m 'init'"

  -- open a file so we have something to save
  vim.cmd ":e test.txt"

  it("saves a session with the branch name", function()
    -- vim.cmd ":SessionSave"
    require("auto-session").AutoSaveSession()

    local session_path = TL.session_dir .. TL.escapeSessionName(vim.fn.getcwd() .. "_main.vim")

    assert.equals(1, vim.fn.filereadable(session_path))
  end)
end)
