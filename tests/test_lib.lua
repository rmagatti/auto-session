M = {}

-- This disables the headless check inside autosession
-- I couldn't find a good way to mock out the calls to make this unnecessary
-- without creating more problems
vim.fn.setenv("AUTOSESSION_ALLOW_HEADLESS_TESTING", 1)

M.tests_base_dir = "tests"

M.test_file = M.tests_base_dir .. "/test_files/test.txt"
M.other_file = M.tests_base_dir .. "/test_files/other.txt"

-- Use absolute path here for cwd_change_handling
M.session_dir = vim.fn.getcwd() .. "/tests/test_sessions/"

-- Construct the session name for the current directory
M.default_session_path = M.session_dir .. vim.fn.getcwd():gsub("/", "%%") .. ".vim"

M.named_session_name = "auto-test"
M.named_session_path = M.session_dir .. M.named_session_name .. ".vim"

function M.assertSessionHasFile(session_path, file)
  ---@diagnostic disable-next-line: undefined-field
  assert.equals(
    "1",
    vim.fn.system('grep badd "' .. session_path .. '" | grep "' .. file .. '" | wc -l'):gsub("%s+", "")
  )
end

function M.clearSessionFilesAndBuffers()
  pcall(vim.fn.system, "rm -rf " .. M.session_dir .. "/*.vim")
  vim.cmd "silent %bw"
end

return M
