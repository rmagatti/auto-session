local Path = require "plenary.path"

local IS_WIN32 = vim.fn.has "win32" == 1

local function win32_escape(dir)
  dir = dir:gsub("++", ":")
  if not vim.o.shellslash then
    dir = dir:gsub("%%", "\\")
  end

  return dir
end

local function win32_unescape(dir)
  dir = dir:gsub(":", "++")
  if not vim.o.shellslash then
    dir = dir:gsub("\\", "\\%%")
  end

  return dir
end

local function unix_escape_path(dir)
  return dir:gsub("/", "\\%%")
end

local function unix_unescape_path(dir)
  return dir:gsub("%%", "/")
end

function Path:escape()
  if self.escaped then
    return self.filename
  end

  self.escaped = true
  if IS_WIN32 then
    return win32_escape(self.filename)
  else
    return unix_escape_path(self.filename)
  end
end

function Path:unescape()
  if not self.escaped then
    return self.filename
  end

  self.escaped = false
  if IS_WIN32 then
    return win32_unescape(self.filename)
  else
    return unix_unescape_path(self.filename)
  end
end

-- -- v Tests
-- local path = Path:new(vim.fn.getcwd())
-- logger.debug {
--   -- current_session = current_session,
--   -- cwd = cwd,
--   -- normalized_path = path:normalize(),
--   -- relative = path:make_relative(),
--   -- filename = path.filename,
--   escaped_cwd = path:escape(),
--   unescaped_cwd = path:unescape(),
-- }
-- -- ^ Tests

return Path
