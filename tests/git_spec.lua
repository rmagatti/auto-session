---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("The git config", function()
  local as = require "auto-session"
  as.setup {
    auto_session_use_git_branch = true,
    -- log_level = "debug",
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
  vim.cmd("e " .. TL.test_file)
  vim.cmd("w! " .. git_test_dir .. "/test.txt")
  vim.cmd "%bw"

  -- change to that dir
  vim.cmd("cd " .. git_test_dir)

  local function runCmdAndPrint(cmd)
    ---@diagnostic disable-next-line: unused-local
    local result = vim.fn.system(cmd)
    -- print("Command output:", result)
    --
    -- local lines = vim.split(result, "\n")
    -- for _, line in ipairs(lines) do
    --   print(line)
    -- end
    --
    -- print("Exit status:", vim.v.shell_error)
  end

  -- init repo and make a commit
  runCmdAndPrint "git init -b main"
  runCmdAndPrint 'git config user.email "test@test.com"'
  runCmdAndPrint 'git config user.name "test"'
  runCmdAndPrint "git add test.txt"
  runCmdAndPrint "git commit -m 'init'"

  -- open a file so we have something to save
  vim.cmd "e test.txt"

  local branch_session_path = TL.session_dir .. TL.escapeSessionName(vim.fn.getcwd() .. "|main") .. ".vim"

  it("saves a session with the branch name", function()
    -- vim.cmd ":SessionSave"

    as.AutoSaveSession()

    assert.equals(1, vim.fn.bufexists "test.txt")

    -- print(session_path)
    assert.equals(1, vim.fn.filereadable(branch_session_path))

    assert.equals(vim.fn.getcwd() .. " (branch: main)", as.Lib.current_session_name())
  end)

  it("Autorestores a session with the branch name", function()
    vim.cmd "%bw!"
    assert.equals(0, vim.fn.bufexists "test.txt")

    as.AutoRestoreSession()

    assert.equals(1, vim.fn.bufexists "test.txt")

    assert.equals(1, vim.fn.filereadable(branch_session_path))

    assert.equals(vim.fn.getcwd() .. " (branch: main)", as.Lib.current_session_name())
  end)

  it("can migrate an old git session", function()
    assert.equals(1, vim.fn.filereadable(branch_session_path))
    local legacy_branch_session_path = TL.session_dir .. TL.legacyEscapeSessionName(vim.fn.getcwd() .. "_main.vim")

    vim.loop.fs_rename(branch_session_path, legacy_branch_session_path)

    assert.equals(1, vim.fn.filereadable(legacy_branch_session_path))
    assert.equals(0, vim.fn.filereadable(branch_session_path))

    vim.cmd "%bw!"
    assert.equals(0, vim.fn.bufexists "test.txt")

    as.AutoRestoreSession()

    assert.equals(1, vim.fn.bufexists "test.txt")

    assert.equals(1, vim.fn.filereadable(branch_session_path))
    assert.equals(0, vim.fn.filereadable(legacy_branch_session_path))

    assert.equals(vim.fn.getcwd() .. " (branch: main)", as.Lib.current_session_name())
  end)
end)
