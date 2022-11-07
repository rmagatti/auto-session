local Lib = require "auto-session-library"

local M = {}

-- don't autorestore if there are open buffers (indicating auto save session failed)
local function has_open_buffers()
  local result = false
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fn.bufloaded(bufnr) then
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      if bufname ~= "" then
        if vim.fn.bufwinnr(bufnr) ~= -1 then
          if result then
            result = true
            Lib.logger.debug("There are buffer(s) present: ")
          end
          Lib.logger.debug("  " .. bufname)
        end
      end
    end
  end
  return result
end

---Setup autocmds for DirChangedPre and DirChanged
---@param config table auto session config
---@param AutoSession table auto session instance
M.setup_autocmds = function(config, AutoSession)
  if not config.cwd_change_handling or vim.tbl_isempty(config.cwd_change_handling or {}) then
    Lib.logger.debug "cwd_change_handling is disabled, skipping setting DirChangedPre and DirChanged autocmd handling"
    return
  end

  local conf = config.cwd_change_handling
  local scopes = { "global", "tabpage"}

  for _, pattern in ipairs(scopes) do
    vim.api.nvim_create_autocmd("DirChangedPre", {
      callback = function()
        Lib.logger.debug "DirChangedPre"
        Lib.logger.debug("  cwd: " .. vim.fn.getcwd())
        Lib.logger.debug("  target: " .. vim.v.event.directory)
        Lib.logger.debug("  changed window: " .. tostring(vim.v.event.changed_window))
        Lib.logger.debug("  scope: " .. vim.v.event.scope)

        -- Don't want to save session if dir change was triggered
        -- by a window change. This will corrupt the session data,
        -- mixing the two different directory sessions
        if vim.v.event.changed_window then
          return
        end

        AutoSession.AutoSaveSession()

        -- Clear all buffers and jumps after session save so session doesn't blead over to next session.
        vim.cmd "%bd!"
        vim.cmd "clearjumps"

        if type(conf.pre_cwd_changed_hook) == "function" then
          conf.pre_cwd_changed_hook()
        end
      end,
      pattern = pattern,
    })

    if conf.restore_upcoming_session then
        vim.api.nvim_create_autocmd("DirChanged", {
          callback = function()
            Lib.logger.debug "DirChanged"
            Lib.logger.debug("  cwd: " .. vim.fn.getcwd() )
            Lib.logger.debug("  changed window: " .. tostring(vim.v.event.changed_window))
            Lib.logger.debug("  scope: " .. vim.v.event.scope)

            -- see above
            if vim.v.event.changed_window then
              return
            end

            -- all buffers should've been deleted in `DirChangedPre`, something probably went wrong
            if has_open_buffers() then
              Lib.logger.debug("Cancelling session restore")
              return
            end

            local success = AutoSession.AutoRestoreSession()

            if not success then
              Lib.logger.info("Could not load session. A session file is likely missing for this cwd." .. vim.fn.getcwd())
              return
            end

            if type(conf.post_cwd_changed_hook) == "function" then
              conf.post_cwd_changed_hook()
            end
          end,
          pattern = pattern,
        })
    end
  end
end

return M
