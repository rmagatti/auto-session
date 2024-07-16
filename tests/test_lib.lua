M = {}

-- This disables the headless check inside autosession
-- I couldn't find a good way to mock out the calls to make this unnecessary
-- without creating more problems
vim.fn.setenv("AUTOSESSION_UNIT_TESTING", 1)

function M.escapeSessionName(name)
  if vim.fn.has "win32" == 1 then
    -- Harcoded implementation from Lib
    local temp = name:gsub(":", "++")
    if not vim.o.shellslash then
      return temp:gsub("\\", "-"):gsub("/", "-")
    end
  else
    return name:gsub("/", "%%")
  end
end

M.tests_base_dir = "tests"

M.test_file = M.tests_base_dir .. "/test_files/test.txt"
M.other_file = M.tests_base_dir .. "/test_files/other.txt"

-- This is set in minimal.lua to be auto-session/.test/...
M.session_dir = vim.fn.stdpath "data" .. "/sessions/"

-- Construct the session name for the current directory
M.default_session_name = M.escapeSessionName(vim.fn.getcwd())

M.default_session_path = M.session_dir .. M.default_session_name .. ".vim"

M.named_session_name = "mysession"
M.named_session_path = M.session_dir .. M.named_session_name .. ".vim"

function M.fileHasString(file_path, string)
  return vim.fn.system('rg -c "' .. string .. '" "' .. file_path .. '"'):gsub("%s+", "") ~= ""
end

function M.sessionHasFile(session_path, file)
  return vim.fn.system('rg badd "' .. session_path .. '" | rg -c "' .. file .. '"'):gsub("%s+", "") == "1"
end

function M.assertSessionHasFile(session_path, file)
  -- requires ripgrep
  ---@diagnostic disable-next-line: undefined-field
  assert.equals(true, M.sessionHasFile(session_path, file))
end

function M.clearSessionFilesAndBuffers()
  M.clearSessionFiles(M.session_dir)
  vim.cmd "silent %bw"
end

function M.clearSessionFiles(dir)
  if vim.fn.has "win32" == 1 then
    pcall(vim.fn.system, "del /Q " .. (dir .. "*.vim"):gsub("/", "\\"))
  else
    pcall(vim.fn.system, "rm -rf " .. dir .. "*.vim")
  end
end

return M
