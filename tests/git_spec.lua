---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"
local stub = require "luassert.stub"

describe("The git config", function()
  local as = require "auto-session"
  local Lib = require "auto-session.lib"
  local c = require "auto-session.config"
  -- NOTE: need to load the git module here because we change the directory later which
  -- I tihnk messes up the relative module load path. a bit of a hack but oh well
  ---@diagnostic disable-next-line: unused-local
  local g = require "auto-session.git"

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
  vim.cmd("w! " .. git_test_path .. "/other.txt")
  vim.cmd "silent %bw"

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
    vim.cmd "silent %bw!"
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

    vim.cmd "silent %bw!"
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

  it("load a session named with git branch from . directory", function()
    c.args_allow_single_directory = true
    c.log_level = "debug"

    -- delete all buffers
    vim.cmd "silent %bw"

    local s = stub(vim.fn, "argv")
    s.returns { "." }

    -- only exported because we set the unit testing env in TL
    assert.True(as.auto_restore_session_at_vim_enter())

    assert.equals(1, vim.fn.bufexists "test.txt")

    -- Revert the stub
    vim.fn.argv:revert()
    c.auto_save = false

    vim.fn.system "git switch main"
  end)

  it("load a session named with git branch from directory argument", function()
    c.args_allow_single_directory = true
    c.cwd_change_handling = false

    -- delete all buffers
    vim.cmd "silent %bw"

    -- change to parent directory
    vim.cmd "cd .."

    local s = stub(vim.fn, "argv")
    s.returns { git_test_dir }

    -- only exported because we set the unit testing env in TL
    assert.True(as.auto_restore_session_at_vim_enter())

    assert.equals(1, vim.fn.bufexists "test.txt")

    -- Revert the stub
    vim.fn.argv:revert()
    c.auto_save = false
  end)

  it("auto-restores after a branch change", function()
    c.auto_save = true
    c.git_auto_restore_on_branch_change = true

    -- make sure we're on the main branch
    vim.fn.system "git switch -c main"

    -- delete all buffers
    vim.cmd "silent %bw"

    -- branch change monitoring is only turned on when we've loaded a session
    as.RestoreSession()
    assert.equals("test_git (branch: main)", Lib.current_session_name(true))

    -- save main branch session
    assert.equals(1, vim.fn.bufexists "test.txt")
    as.SaveSession()

    -- stub out on_git_watch_event so we know when the watcher is triggered
    -- we can't use post_restore_cmds because there's no session restored
    -- for other-branch the first time
    local git_watch_triggered = false
    local on_git_watch_event = g.on_git_watch_event
    stub(g, "on_git_watch_event", function(cwd, current_branch)
      on_git_watch_event(cwd, current_branch)
      git_watch_triggered = true
    end)

    -- switch to other-branch just to set it up
    vim.fn.system "git switch -c other-branch"
    vim.wait(1000, function()
      return git_watch_triggered
    end)

    vim.cmd "silent %bw"
    vim.cmd "e other.txt"

    assert.equals(0, vim.fn.bufexists "test.txt")
    assert.equals(1, vim.fn.bufexists "other.txt")

    git_watch_triggered = false
    vim.fn.system "git switch main"
    vim.wait(1000, function()
      return git_watch_triggered
    end)

    assert.equals("test_git (branch: main)", Lib.current_session_name(true))
    -- other branch should now exist but the main branch is our current session

    assert.equals(1, vim.fn.bufexists "test.txt")
    assert.equals(0, vim.fn.bufexists "other.txt")

    git_watch_triggered = false
    vim.fn.system "git switch other-branch"
    vim.wait(1000, function()
      return git_watch_triggered
    end)

    assert.equals("test_git (branch: other-branch)", Lib.current_session_name(true))
    assert.equals(0, vim.fn.bufexists "test.txt")
    assert.equals(1, vim.fn.bufexists "other.txt")

    c.auto_save = false
    g.on_git_watch_event:revert()
  end)
end)
