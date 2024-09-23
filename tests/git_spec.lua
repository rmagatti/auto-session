---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("The git config", function()
  local as = require "auto-session"
  local Lib = require "auto-session.lib"
  as.setup {
    auto_session_use_git_branch = true,
    -- log_level = "debug",
  }

  TL.clearSessionFilesAndBuffers()

  local git_test_dir = "test_git"
  local git_test_path = TL.tests_base_dir .. "/" .. git_test_dir

  -- clear git test dir
  vim.fn.delete(git_test_path, "rf")
  vim.fn.mkdir(git_test_path)

  -- get a file in that dir
  vim.cmd("e " .. TL.test_file)
  vim.cmd("w! " .. git_test_path .. "/test.txt")
  vim.cmd "%bw"

  -- change to that dir
  vim.cmd("cd " .. git_test_path)

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

    assert.equals(vim.fn.getcwd() .. " (branch: main)", Lib.current_session_name())

    local sessions = Lib.get_session_list(as.get_root_dir())
    assert.equal(1, #sessions)

    assert.equal(TL.session_dir .. sessions[1].file_name, branch_session_path)
    assert.equal(sessions[1].display_name, Lib.current_session_name())
    assert.equal(sessions[1].session_name, vim.fn.getcwd() .. "|main")
  end)

  it("Autorestores a session with the branch name", function()
    vim.cmd "%bw!"
    assert.equals(0, vim.fn.bufexists "test.txt")

    as.AutoRestoreSession()

    assert.equals(1, vim.fn.bufexists "test.txt")

    assert.equals(1, vim.fn.filereadable(branch_session_path))

    assert.equals(vim.fn.getcwd() .. " (branch: main)", Lib.current_session_name())
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

    assert.equals(vim.fn.getcwd() .. " (branch: main)", Lib.current_session_name())
  end)

  it("can get the session name of a git branch with a slash", function()
    runCmdAndPrint "git checkout -b slash/branch"

    as.SaveSession()

    local session_path = TL.session_dir .. TL.escapeSessionName(vim.fn.getcwd() .. "|slash/branch") .. ".vim"
    assert.equals(1, vim.fn.filereadable(session_path))
    assert.equals(vim.fn.getcwd() .. " (branch: slash/branch)", Lib.current_session_name())
    assert.equals(git_test_dir .. " (branch: slash/branch)", Lib.current_session_name(true))
  end)
end)
