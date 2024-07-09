M = {}

-- This disables the headless check inside autosession
-- I couldn't find a good way to mock out the calls to make this unnecessary
-- without creating more problems
vim.fn.setenv("AUTOSESSION_ALLOW_HEADLESS_TESTING", 1)

M.test_file = "tests/test_files/test.txt"

M.session_dir = "./tests/test_sessions/"

-- Construct the session name for the current directory
M.default_session_path = M.session_dir .. vim.fn.getcwd():gsub("/", "%%") .. ".vim"

M.session_name = "auto-test"
M.session_path = M.session_dir .. M.session_name .. ".vim"

return M
