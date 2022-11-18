local AutoSession = require "auto-session"
local action_state = require "telescope.actions.state"
local actions = require "telescope.actions"
local Lib = require "auto-session-library"

local SessionLensActions = {}

-- TODO: Either use this or actually store the latest sessions on load time, then just alternate between them here.
-- local function get_second_to_latest_session_by_last_edited()
--   local dir = Lib.expand(AutoSession.conf.auto_session_root_dir)
--   local sessions = {}

--   for _, filename in ipairs(vim.fn.readdir(dir)) do
--     local session = AutoSession.conf.auto_session_root_dir .. filename
--     local last_edited = vim.fn.getftime(session)

--     -- This is a naive way if checking if the session in question is an "extra" x.vim file.
--     -- This check has a bug with non-extra session file names ending in x, e.g ajax.vim, where the session will never be considered a candidate for alternating.
--     -- TODO: fix this naiveness somehow
--     table.insert(sessions, {
--       session = session,
--       last_edited = last_edited,
--       match = (function()
--         for match in string.gmatch(session, "x.vim") do
--           return match
--         end
--       end)(),
--     })

--     table.sort(sessions, function(a, b)
--       return a.last_edited > b.last_edited
--     end)
--   end

--   local function find_non_extra_vim(start_count)
--     if sessions[start_count].match then
--       return find_non_extra_vim(start_count + 1)
--     end

--     return sessions[start_count]
--   end

--   local latest_and_second_latest = {
--     latest = find_non_extra_vim(1).session,
--     second_latest = find_non_extra_vim(2).session,
--   }

--   -- print(vim.inspect(latest_and_second_latest))
--   -- print(vim.inspect(sessions))

--   return latest_and_second_latest.second_latest
-- end

local function get_second_to_latest_session()
  local filepath = AutoSession.conf.session_control.control_dir .. AutoSession.conf.session_control.control_filename

  if vim.fn.filereadable(filepath) == 1 then
    local content = vim.fn.readfile(filepath)

    local sessions = { this = Lib.expand(vim.v.this_session), alternate = Lib.expand(content[#content]) }

    Lib.logger.debug { sessions = sessions, content = content }

    if sessions.this ~= sessions.alternate then
      return sessions.alternate
    end
  end
end

local function source_session(selection, prompt_bufnr)
  if prompt_bufnr then
    actions.close(prompt_bufnr)
  end

  vim.defer_fn(function()
    if -- type(AutoSession.conf.cwd_change_handling) == "table"
      -- and not vim.tbl_isempty(AutoSession.conf.cwd_change_handling or {})
      -- and AutoSession.conf.cwd_change_handling.restore_upcoming_session
      -- FIXME: Trying to check if cwd_change_handling properties are set, but something is wrong here.
      false
    then
      -- Take advatage of cwd_change_handling behaviour for switching sessions
      Lib.logger.debug "Triggering vim.fn.chdir since cwd_change_handling feature is enabled"
      vim.fn.chdir(AutoSession.format_file_name(type(selection) == "table" and selection.filename or selection))
    else
      Lib.logger.debug "Triggering session-lens behaviour since cwd_change_handling feature is disabled"
      AutoSession.AutoSaveSession()
      vim.cmd "%bd!"
      vim.cmd "clearjumps"
      AutoSession.RestoreSession(type(selection) == "table" and selection.path or selection)
    end
  end, 50)
end

-- TODO: delete this call
-- get_second_to_latest_session()

---Source session action
---Source a selected session after doing proper current session saving and cleanup
---@param prompt_bufnr number the telescope prompt bufnr
SessionLensActions.source_session = function(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  source_session(selection, prompt_bufnr)
end

---Delete session action
---Delete a selected session file
---@param prompt_bufnr number the telescope prompt bufnr
SessionLensActions.delete_session = function(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  current_picker:delete_selection(function(selection)
    AutoSession.DeleteSession(selection.path)
  end)
end

SessionLensActions.alternate_session = function(prompt_bufnr)
  local second_latest = get_second_to_latest_session()

  if not second_latest then
    Lib.logger.info "There is no alternate session to navigate to, aborting operation"

    if prompt_bufnr then
      actions.close(prompt_bufnr)
    end

    return
  end

  source_session(second_latest, prompt_bufnr)
end

return SessionLensActions
