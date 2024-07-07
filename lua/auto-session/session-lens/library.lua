local path = require "plenary.path"
local AutoSessionLib = require "auto-session.lib"

local Config = {}
local Lib = {
  make_entry = {},
  logger = {},
  conf = {
    logLevel = false,
  },
  Config = Config,
  _VIM_FALSE = 0,
  _VIM_TRUE = 1,
  ROOT_DIR = nil,
}

function Lib.setup(config, functions)
  Lib.conf = vim.tbl_deep_extend("force", Lib.conf, config)
  Lib.functions = functions
  Lib.ROOT_DIR = Lib.functions.get_root_dir()
end

function Lib.isEmpty(s)
  return s == nil or s == ""
end

function Lib.appendSlash(str)
  if not Lib.isEmpty(str) then
    if not vim.endswith(str, "/") then
      str = str .. "/"
    end
  end
  return str
end

function Lib.make_entry.gen_from_file(opts)
  local root = Lib.functions.get_root_dir()
  return function(line)
    -- Don't include <session>x.vim files that nvim makes for custom user
    -- commands
    if not AutoSessionLib.is_session_file(root, line) then
      return nil
    end

    return {
      ordinal = line,
      value = line,
      filename = line,
      cwd = root,
      display = function(_)
        local out = AutoSessionLib.unescape_dir(line):match "(.+)%.vim"
        if opts.path_display and vim.tbl_contains(opts.path_display, "shorten") then
          out = path:new(out):shorten()
        end
        if out then
          return out
        end
        return line
      end,
      path = path:new(root, line):absolute(),
    }
  end
end

return Lib
