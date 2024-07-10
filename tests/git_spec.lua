---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("The git config", function()
  require("auto-session").setup {
    auto_session_root_dir = TL.session_dir,
    auto_session_use_git_branch = true,
  }

  TL.clearSessionFilesAndBuffers()

  local git_test_dir = TL.tests_base_dir .. "/test_git"

  vim.fn.system("rm -rf " .. git_test_dir)
  vim.fn.system("mkdir " .. git_test_dir)
  vim.fn.system("cp " .. TL.test_file .. " " .. git_test_dir)
  vim.cmd(":cd " .. git_test_dir)
  vim.fn.system "git init -b main"
  vim.fn.system "git add ."
  vim.fn.system "git commit -m 'init'"

  vim.cmd ":e test.txt "

  it("saves a session with the branch name", function()
    -- vim.cmd ":SessionSave"
    require("auto-session").AutoSaveSession()

    local session_path = TL.session_dir .. vim.fn.getcwd():gsub("/", "%%") .. "_main.vim"

    assert.equals(1, vim.fn.filereadable(session_path))
  end)
end)
