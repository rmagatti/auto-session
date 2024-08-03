local asLib = require "auto-session.lib"
M = {}

-- This disables the headless check inside autosession
-- I couldn't find a good way to mock out the calls to make this unnecessary
-- without creating more problems
vim.fn.setenv("AUTOSESSION_UNIT_TESTING", 1)

function M.escapeSessionName(session_name)
  return asLib.percent_encode(session_name)
end

function M.legacyEscapeSessionName(session_name)
  if vim.fn.has "win32" == 1 then
    -- Harcoded implementation from Lib
    local temp = session_name:gsub(":", "++")
    if not vim.o.shellslash then
      temp = temp:gsub("\\", "-")
    end
    return temp:gsub("/", "-")
  else
    return session_name:gsub("/", "%%")
  end
end

function M.makeSessionPath(session_name)
  return M.session_dir .. M.escapeSessionName(session_name) .. ".vim"
end

M.tests_base_dir = "tests"

M.test_file = M.tests_base_dir .. "/test_files/test.txt"
M.other_file = M.tests_base_dir .. "/test_files/other.txt"

-- This is set in minimal.lua to be auto-session/.test/...
M.session_dir = vim.fn.expand(vim.fn.stdpath "data" .. "/sessions/")

M.session_control_dir = vim.fn.stdpath "data" .. "/auto_session/"

-- Construct the session name for the current directory
M.default_session_name = vim.fn.getcwd()

M.default_session_path = M.makeSessionPath(M.default_session_name)
M.default_session_path_legacy = M.session_dir .. M.legacyEscapeSessionName(M.default_session_name) .. ".vim"

M.default_session_control_name = "session_control.json"
M.default_session_control_path = M.session_control_dir .. M.default_session_control_name

M.named_session_name = "mysession"
M.named_session_path = M.session_dir .. M.named_session_name .. ".vim"

function M.fileHasString(file_path, string)
  if vim.fn.has "win32" == 1 then
    return vim.fn
      .system('findstr /c:"' .. string .. '" "' .. (file_path:gsub("/", "\\")) .. '" | find /c /v ""')
      :gsub("%s+", "") ~= "0"
  end
  return vim.fn.system('grep -c "' .. string .. '" "' .. file_path .. '"'):gsub("%s+", "") ~= "0"
end

function M.sessionHasFile(session_path, file)
  if vim.fn.has "win32" == 1 then
    return vim.fn
      .system('findstr badd "' .. (session_path:gsub("/", "\\")) .. '" | findstr /c:"' .. file .. '" | find /c /v ""')
      :gsub("%s+", "") == "1"
  end
  return vim.fn.system('grep badd "' .. session_path .. '" | grep -c "' .. file .. '"'):gsub("%s+", "") == "1"
end

function M.assertSessionHasFile(session_path, file)
  -- requires ripgrep
  ---@diagnostic disable-next-line: undefined-field
  assert.equals(true, M.sessionHasFile(session_path, file))
end

---Clear session directory, session control file, and delete all buffers
function M.clearSessionFilesAndBuffers()
  M.clearSessionFiles(M.session_dir)
  M.clearSessionFiles(M.session_control_dir)
  vim.cmd "silent %bw"
end

---Cross pltform delete all files in directory
function M.clearSessionFiles(dir)
  if vim.fn.has "win32" == 1 then
    pcall(vim.fn.system, "del /Q " .. (dir .. "*.vim .vim"):gsub("/", "\\"))
  else
    pcall(vim.fn.system, "rm -rf " .. dir .. "*.vim .vim")
  end
end

function M.createFile(file_path)
  vim.cmd("ene | w " .. file_path:gsub("%%", "\\%%") .. " | bw")
  assert.True(vim.fn.filereadable(file_path) ~= 0)
end

return M
