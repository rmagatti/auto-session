---@diagnostic disable: undefined-field
local TL = require("tests/test_lib")
local as = require("auto-session")
local config = require("auto-session.config")
local restart = require("auto-session.restart")
local lib = require("auto-session.lib")

describe("Native restart", function()
  local original_supported = restart.is_supported
  local original_cmd = vim.api.nvim_cmd
  local original_exists = vim.fn.exists
  local original_v = vim.v
  local original_is_restart = restart.is_restart
  local original_save = as.save_session
  local original_writefile = vim.fn.writefile
  local original_delete = vim.fn.delete
  local original_list_uis = vim.api.nvim_list_uis
  local original_git_branch = lib.get_git_branch_name
  local original_nvim_env = vim.env.NVIM
  local restart_command
  local saves
  local restores
  local no_restores

  before_each(function()
    vim.env.NVIM = nil
    vim.cmd("silent! %bw!")
    TL.clearSessionFilesAndBuffers()
    vim.v.this_session = ""
    as.manually_named_session = false
    saves, restores, no_restores = 0, 0, 0
    restart_command = nil
    vim.api.nvim_list_uis = function()
      return { {} }
    end
    as.setup({
      auto_save = false,
      auto_restore = false,
      save_and_restore_shada = vim.fn.has("nvim-0.11") == 1,
      pre_save_cmds = {
        function()
          return false
        end,
      },
      post_save_cmds = {
        function()
          saves = saves + 1
        end,
      },
      pre_restore_cmds = {
        function()
          return false
        end,
      },
      post_restore_cmds = {
        function()
          restores = restores + 1
        end,
      },
      no_restore_cmds = {
        function()
          no_restores = no_restores + 1
        end,
      },
    })
    restart.is_supported = function()
      return true
    end
    vim.api.nvim_cmd = function(command, opts)
      if command.cmd == "restart" then
        restart_command = command
        return ""
      end
      return original_cmd(command, opts)
    end
    vim.cmd("edit " .. TL.test_file)
  end)

  after_each(function()
    restart.is_supported = original_supported
    restart.is_restart = original_is_restart
    vim.api.nvim_cmd = original_cmd
    vim.fn.exists = original_exists
    vim.v = original_v
    vim.fn.writefile = original_writefile
    vim.fn.delete = original_delete
    vim.api.nvim_list_uis = original_list_uis
    lib.get_git_branch_name = original_git_branch
    as.save_session = original_save
    vim.env.NVIM = original_nvim_env
    vim.cmd("silent! %bw!")
  end)

  local function complete_restart()
    assert.equals("restart", restart_command.cmd)
    assert.True(restart_command.bang)
    vim.cmd("silent %bw")
    vim.v.this_session = ""
    as.manually_named_session = false
    vim.cmd(restart_command.args[1])
  end

  it("runs manual hooks and restores extras and ShaDa with automatic actions disabled", function()
    config.save_extra_cmds = {
      function()
        return "let g:restart_extra = 42"
      end,
    }
    config.save_extra_data = function()
      return "extra restart data"
    end
    local extra_data
    config.restore_extra_data = function(_, data)
      extra_data = data
    end
    vim.fn.setreg("a", "restart register")
    vim.cmd("AutoSession restart")
    assert.equals(1, saves)
    vim.fn.setreg("a", "changed")
    complete_restart()
    assert.equals(1, restores)
    assert.equals(42, vim.g.restart_extra)
    assert.equals("extra restart data", extra_data)
    if config.save_and_restore_shada then
      assert.equals("restart register", vim.fn.getreg("a"))
    end
    assert.equals(TL.default_session_path, vim.v.this_session)
    assert.False(config.auto_save)
    assert.False(config.auto_restore)
    assert.False(as.manually_named_session)
    assert.equals(0, no_restores)
  end)

  it("keeps a manually named session and safely encodes unusual names", function()
    local name = "named ' \" | % space ü"
    assert.True(as.save_session(name))
    local path = vim.v.this_session
    assert.True(restart.restart())
    assert.matches("restore%('[0-9a-f]+'%)$", restart_command.args[1])
    complete_restart()
    assert.equals(path, vim.v.this_session)
    assert.True(as.manually_named_session)
  end)

  it("restores the saved session even if the git branch and custom tag change", function()
    local branch = "original-branch"
    config.git_use_branch_name = true
    lib.get_git_branch_name = function()
      return branch
    end
    config.custom_session_tag = function()
      return "original"
    end
    assert.True(as.save_session())
    local path = vim.v.this_session
    config.custom_session_tag = function()
      return "changed"
    end
    branch = "changed-branch"
    assert.True(restart.restart())
    complete_restart()
    assert.equals(path, vim.v.this_session)
    assert.False(as.manually_named_session)
    assert.equals(0, vim.fn.filereadable(TL.makeSessionPath(TL.default_session_name .. "|changed-branch|changed")))
  end)

  it("refuses hidden modified buffers before running save hooks", function()
    local buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "unsaved" })
    assert.False(restart.restart())
    assert.Nil(restart_command)
    assert.equals(0, saves)
    assert.True(vim.bo[buf].modified)
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
  end)

  it("refuses changes introduced by save hooks", function()
    config.post_save_cmds = {
      function()
        vim.api.nvim_buf_set_lines(0, 0, 0, false, { "hook edit" })
      end,
    }
    assert.False(restart.restart())
    assert.Nil(restart_command)
    assert.True(vim.bo.modified)
  end)

  it("does not restart when saving reports failure", function()
    as.save_session = function()
      return false
    end
    assert.False(restart.restart())
    assert.Nil(restart_command)
  end)

  it("does not restart when a save hook throws", function()
    config.pre_save_cmds = {
      function()
        error("save failed")
      end,
    }
    assert.False(restart.restart())
    assert.Nil(restart_command)
    assert.equals(0, saves)
  end)

  it("does not restart when extra commands cannot be written", function()
    config.save_extra_cmds = {
      function()
        return "let g:restart_extra = 1"
      end,
    }
    vim.fn.writefile = function()
      return -1
    end
    assert.False(restart.restart())
    assert.Nil(restart_command)
  end)

  it("does not restart when stale extra commands cannot be removed", function()
    config.save_extra_cmds = {
      function()
        return "let g:restart_stale = 1"
      end,
    }
    assert.True(as.save_session())
    config.save_extra_cmds = {}
    vim.fn.delete = function()
      return -1
    end
    assert.False(restart.restart())
    assert.Nil(restart_command)
  end)

  it("refuses headless restart before saving", function()
    vim.api.nvim_list_uis = function()
      return {}
    end
    assert.False(restart.restart())
    assert.Nil(restart_command)
    assert.equals(0, saves)
  end)

  it("requires native protocol capabilities rather than a version string", function()
    restart.is_supported = original_supported
    vim.fn.exists = function(name)
      if name == ":restart" then
        return 2
      end
      if name == "v:exitreason" then
        return 1
      end
      if name == "v:startreason" then
        return 0
      end
      return original_exists(name)
    end
    assert.False(restart.restart())
    assert.equals(0, saves)
    assert.Nil(restart_command)
    vim.fn.exists = function(name)
      if name == ":restart" then
        return 2
      end
      if name == "v:startreason" or name == "v:exitreason" then
        return 1
      end
      return original_exists(name)
    end
    assert.True(restart.is_supported())
  end)

  it("preserves automatic behavior on older builds with only exitreason", function()
    restart.is_supported = original_supported
    vim.fn.exists = function(name)
      if name == ":restart" then
        return 2
      end
      if name == "v:exitreason" then
        return 1
      end
      if name == "v:startreason" then
        return 0
      end
      return original_exists(name)
    end
    for _, reason in ipairs({ "restart", "restart!" }) do
      vim.v = { exitreason = reason }
      local skip_exit = restart.is_restart("exit")
      local skip_start = restart.is_restart("start")
      vim.v = original_v
      assert.False(skip_exit)
      assert.False(skip_start)
    end
  end)

  it("skips restart startup and exit hooks but keeps normal startup and exit behavior", function()
    config.auto_save = true
    config.auto_restore = true
    restart.is_restart = function()
      return true
    end
    vim.api.nvim_exec_autocmds("VimEnter", {})
    assert.False(as.auto_restore_session_at_vim_enter())
    vim.api.nvim_exec_autocmds("VimLeavePre", {})
    assert.equals(0, saves)
    assert.equals(0, restores)
    assert.equals(0, no_restores)
    restart.is_restart = function()
      return false
    end
    vim.api.nvim_exec_autocmds("VimEnter", {})
    assert.equals(1, no_restores)
    config.pre_save_cmds = {}
    vim.api.nvim_exec_autocmds("VimLeavePre", {})
    assert.equals(1, saves)
  end)

  it("waits for delayed setup before restoring", function()
    assert.True(restart.restart())
    vim.cmd("silent %bw")
    vim.g.loaded_auto_session = nil
    vim.cmd(restart_command.args[1])
    assert.equals(0, restores)
    as.setup({ post_restore_cmds = {
      function()
        restores = restores + 1
      end,
    } })
    assert.True(vim.wait(1000, function()
      return restores == 1
    end))
    assert.equals(TL.default_session_path, vim.v.this_session)
  end)

  it("rejects unexpected restart arguments", function()
    assert.False(pcall(vim.cmd, "AutoSession restart another_session"))
    assert.Nil(restart_command)
    assert.equals(0, saves)
  end)
end)
