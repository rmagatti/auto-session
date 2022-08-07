local Lib = require "auto-session-library"

local M = {}

---Setup autocmds for DirChangedPre and DirChanged
---@param config table auto session config
---@param AutoSession table auto session instance
M.setup_autocmds = function(config, AutoSession)
  if vim.tbl_isempty(config.cwd_change_handling) or config.cwd_change_handling == nil then
    return
  end

  local conf = config.cwd_change_handling

  vim.api.nvim_create_autocmd("DirChangedPre", {
    callback = function()
      Lib.logger.debug "DirChangedPre"
      Lib.logger.debug("cwd: " .. vim.fn.getcwd())

      AutoSession.AutoSaveSession()

      -- Clear all buffers and jumps after session save so session doesn't blead over to next session.
      vim.cmd "%bd!"
      vim.cmd "clearjumps"

      if type(conf.pre_cwd_changed_hook) == "function" then
        conf.pre_cwd_changed_hook()
      end
    end,
    pattern = "global",
  })

  if conf.restore_upcoming_session then
    vim.api.nvim_create_autocmd("DirChanged", {
      callback = function()
        Lib.logger.debug "DirChanged"
        Lib.logger.debug("cwd: " .. vim.fn.getcwd())

        -- Deferring to avoid otherwise there are tresitter highlighting issues
        vim.defer_fn(function()
          local success = AutoSession.AutoRestoreSession()

          if not success then
            Lib.logger.info("Could not load session. A session file is likely missing for this cwd." .. vim.fn.getcwd())
          end

          if type(conf.post_cwd_changed_hook) == "function" then
            conf.post_cwd_changed_hook()
          end
        end, 50)
      end,
      pattern = "global",
    })
  end
end

return M
