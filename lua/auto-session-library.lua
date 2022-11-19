local Config = {}
local Lib = {
  logger = {},
  conf = {
    log_level = false,
    last_loaded_session = nil,
  },
  Config = Config,
  _VIM_FALSE = 0,
  _VIM_TRUE = 1,
  ROOT_DIR = nil,
}

function Lib.setup(config)
  Lib.conf = vim.tbl_deep_extend("force", Lib.conf, config or {})
end

function Lib.get_file_name(url)
  return url:match "^.+/(.+)$"
end

function Lib.get_file_extension(url)
  return url:match "^.+(%..+)$"
end

function Lib.current_session_name()
  local fname = Lib.get_file_name(vim.v.this_session)
  local extension = Lib.get_file_extension(fname)
  local fname_without_extension = fname:gsub(extension:gsub("%.", "%%%.") .. "$", "")
  local fname_split = vim.split(fname_without_extension, "%%")
  local session_name = fname_split[#fname_split] or ""
  return session_name
end

function Lib.is_empty_table(t)
  if t == nil then
    return true
  end
  return next(t) == nil
end

function Lib.is_empty(s)
  return s == nil or s == ""
end

function Lib.ends_with(str, ending)
  return ending == "" or str:sub(-#ending) == ending
end

function Lib.append_slash(str)
  if not Lib.is_empty(str) then
    if not Lib.ends_with(str, "/") then
      str = str .. "/"
    end
  end
  return str
end

function Lib.validate_root_dir(root_dir)
  if Lib.is_empty(root_dir) or Lib.expand(root_dir) == Lib.expand(Lib.ROOT_DIR) then
    return Lib.ROOT_DIR
  end

  if not Lib.ends_with(root_dir, "/") then
    root_dir = root_dir .. "/"
  end

  if vim.fn.isdirectory(Lib.expand(root_dir)) == Lib._VIM_FALSE then
    vim.cmd(
      "echoerr 'Invalid g:auto_session_root_dir. "
        .. "Path does not exist or is not a directory. "
        .. string.format("Defaulting to %s.", Lib.ROOT_DIR)
    )
    return Lib.ROOT_DIR
  else
    Lib.logger.debug("Using custom session dir: " .. root_dir)
    return root_dir
  end
end

function Lib.init_dir(dir)
  if vim.fn.isdirectory(Lib.expand(dir)) == Lib._VIM_FALSE then
    vim.fn.mkdir(dir, "p")
  end
end

function Lib.init_file(file_path)
  if not Lib.is_readable(file_path) then
    vim.cmd("!touch " .. file_path)
  end
end

local function win32_escaped_dir(dir)
  dir = dir:gsub("++", ":")
  if not vim.o.shellslash then
    dir = dir:gsub("%%", "\\")
  end

  return dir
end

local function win32_unescaped_dir(dir)
  dir = dir:gsub(":", "++")
  if not vim.o.shellslash then
    dir = dir:gsub("\\", "\\%%")
  end

  return dir
end

local IS_WIN32 = vim.fn.has "win32" == Lib._VIM_TRUE

function Lib.unescape_dir(dir)
  return IS_WIN32 and win32_unescaped_dir(dir) or dir:gsub("%%", "/")
end

function Lib.escape_dir(dir)
  return IS_WIN32 and win32_escaped_dir(dir) or dir:gsub("/", "\\%%")
end

function Lib.escaped_session_name_from_cwd()
  return IS_WIN32 and Lib.unescape_dir(vim.fn.getcwd()) or Lib.escape_dir(vim.fn.getcwd())
end

function Lib.escape_branch_name(branch_name)
  return IS_WIN32 and Lib.unescape_dir(branch_name) or Lib.escape_dir(branch_name)
end

local function get_win32_legacy_cwd(cwd)
  cwd = cwd:gsub(":", "++")
  if not vim.o.shellslash then
    cwd = cwd:gsub("\\", "-")
  end

  return cwd
end

function Lib.legacy_session_name_from_cwd()
  local cwd = vim.fn.getcwd()
  return IS_WIN32 and get_win32_legacy_cwd(cwd) or cwd:gsub("/", "-")
end

function Lib.is_readable(file_path)
  local path, _ = file_path:gsub("\\%%", "%%")
  path = Lib.expand(path)
  local readable = vim.fn.filereadable(path) == Lib._VIM_TRUE

  Lib.logger.debug { path = path, readable = readable }

  return readable
end

function Lib.expand(file_or_dir)
  local saved_wildignore = vim.api.nvim_get_option "wildignore"
  vim.api.nvim_set_option("wildignore", "")
  ---@diagnostic disable-next-line: param-type-mismatch
  local ret = vim.fn.expand(file_or_dir, nil, nil)
  vim.api.nvim_set_option("wildignore", saved_wildignore)
  return ret
end

function Lib.has_open_buffers()
  local result = false
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fn.bufloaded(bufnr) then
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      if bufname ~= "" then
        if vim.fn.bufwinnr(bufnr) ~= -1 then
          if result then
            result = true
            Lib.logger.debug "There are buffer(s) present: "
          end
          Lib.logger.debug { bufname = bufname }
        end
      end
    end
  end
  return result
end

---Function that handles vararg printing, so logs are consistent.
local function to_print(...)
  if #{ ... } == 1 and type(...) == "table" then
    return vim.inspect(...)
  else
    local to_return = ""

    for _, value in ipairs { ... } do
      to_return = vim.fn.join({ to_return, vim.inspect(value) }, " ")
    end

    return to_return
  end
end

function Lib.logger.debug(...)
  if Lib.conf.log_level == "debug" then
    vim.notify(vim.fn.join({ "auto-session-debug:", to_print(...) }, " "), vim.log.levels.DEBUG)
  end
end

function Lib.logger.info(...)
  local valid_values = { "info", "debug" }

  if vim.tbl_contains(valid_values, Lib.conf.log_level) then
    vim.notify(vim.fn.join({ "auto-session-info:", to_print(...) }, " "), vim.log.levels.INFO)
  end
end

function Lib.logger.warn(...)
  local valid_values = { "info", "debug", "warn" }

  if vim.tbl_contains(valid_values, Lib.conf.log_level) then
    vim.notify(vim.fn.join({ "auto-session-warn:", to_print(...) }, " "), vim.log.levels.WARN)
  end
end

function Lib.logger.error(...)
  vim.notify(vim.fn.join({ "auto-session-error:", to_print(...) }, " "), vim.log.levels.ERROR)
end

return Lib
