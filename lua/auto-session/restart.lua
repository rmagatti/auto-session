local M = {}

-- The restart protocol was backported to 0.12.5. Some older 0.13 development
-- builds have :restart but not this protocol, so a version check is insufficient.
function M.is_supported()
  return vim.fn.exists(":restart") == 2 and vim.fn.exists("v:startreason") == 1 and vim.fn.exists("v:exitreason") == 1
end

function M.is_restart(phase)
  -- Both sides must recognize the restart. Older builds only expose exitreason;
  -- skipping their exit save would leave startup restoring a stale session.
  if not M.is_supported() then
    return false
  end
  local name = phase .. "reason"
  if vim.fn.exists("v:" .. name) ~= 1 then
    return false
  end
  local reason = vim.v[name]
  return reason == "restart" or reason == "restart!"
end

local function fail(message)
  vim.notify("AutoSession restart: " .. message, vim.log.levels.ERROR)
  return false
end

local function has_unsaved_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
      return true
    end
  end
  return false
end

local pending_restore

-- Native restart executes its command after UIEnter. If setup is itself delayed
-- until after UIEnter, keep the request until the user's configuration is ready.
function M.on_setup()
  if pending_restore then
    local payload = pending_restore
    pending_restore = nil
    vim.schedule(function()
      M.restore(payload)
    end)
  end
end

---@private
function M.restore(payload)
  if not vim.g.loaded_auto_session then
    pending_restore = payload
    return
  end

  local data = vim.json.decode((payload:gsub("%x%x", function(byte)
    return string.char(tonumber(byte, 16))
  end)))
  local session = require("auto-session")
  session.manually_named_session = data.manually_named
  -- This is a manual restore, so cancellation hooks and automatic settings do
  -- not veto it. Use the saved path rather than recomputing cwd/git/custom tags.
  return session.restore_session_file(data.path)
end

---Save the current session and restore it after a native Neovim restart.
---@return boolean # False if restart was refused or failed
function M.restart()
  if not M.is_supported() then
    return fail("requires Neovim's restart protocol (0.12.5 or newer compatible builds)")
  end
  if #vim.api.nvim_list_uis() == 0 then
    return fail("requires an attached UI to restore the session after restarting")
  end
  if has_unsaved_buffers() then
    return fail("save or discard unsaved buffer changes before restarting")
  end

  local session = require("auto-session")
  local lib = require("auto-session.lib")
  local name = vim.v.this_session ~= "" and lib.escaped_session_path_to_session_name(vim.v.this_session) or nil
  local manually_named = session.manually_named_session or false
  local ok, saved = pcall(session.save_session, name, { show_message = false, stop_on_error = true })
  session.manually_named_session = manually_named
  if not ok or not saved then
    return fail("session save failed" .. (not ok and (": " .. tostring(saved)) or ""))
  end
  if has_unsaved_buffers() then
    return fail("a save hook left unsaved buffer changes; save them before restarting")
  end

  -- Hex keeps session paths (including quotes, bars and newlines) out of the Ex
  -- command syntax. No temporary handoff file or inherited environment is needed.
  local payload = vim.json.encode({ path = vim.v.this_session, manually_named = manually_named })
  payload = payload:gsub(".", function(byte)
    return string.format("%02x", string.byte(byte))
  end)
  local command = "lua require('auto-session.restart').restore('" .. payload .. "')"
  -- Bang suppresses Neovim's own mksession/source cycle, not modified-buffer
  -- checks. Native reason variables suppress our automatic exit/startup work.
  local restarted, err = pcall(vim.api.nvim_cmd, { cmd = "restart", bang = true, args = { command } }, {})
  if not restarted then
    return fail(tostring(err))
  end
  return true
end

return M
