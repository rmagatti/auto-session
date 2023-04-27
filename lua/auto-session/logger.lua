local Logger = {}

---Function that handles vararg printing, so logs are consistent.
local function to_print(...)
  local args = { ... }
  if #args == 1 and type(...) == "table" then
    return vim.inspect(...)
  else
    local to_return = ""

    for _, value in ipairs(args) do
      to_return = vim.fn.join({ to_return, vim.inspect(value) }, " ")
    end

    return to_return
  end
end

function Logger:new(obj_and_config)
  obj_and_config = obj_and_config or {}

  self = vim.tbl_deep_extend("force", self, obj_and_config)
  self.__index = function(_, index)
    if type(self[index]) == "function" then
      return function(...)
        -- Make it so any call to logger with "." dot access for a function results in the syntactic sugar of ":" colon access
        self[index](self, ...)
      end
    else
      return self[index]
    end
  end

  setmetatable(obj_and_config, self)

  return obj_and_config
end

function Logger:debug(...)
  if self.log_level == "debug" or self.log_level == vim.log.levels.DEBUG then
    vim.notify(vim.fn.join({ "auto-session DEBUG:", to_print(...) }, " "), vim.log.levels.DEBUG)
  end
end

function Logger:info(...)
  local valid_values = { "info", "debug", vim.log.levels.DEBUG, vim.log.levels.INFO }

  if vim.tbl_contains(valid_values, self.log_level) then
    vim.notify(vim.fn.join({ "auto-session INFO:", to_print(...) }, " "), vim.log.levels.INFO)
  end
end

function Logger:warn(...)
  local valid_values = { "info", "debug", "warn", vim.log.levels.DEBUG, vim.log.levels.INFO, vim.log.levels.WARN }

  if vim.tbl_contains(valid_values, self.log_level) then
    vim.notify(vim.fn.join({ "auto-session WARN:", to_print(...) }, " "), vim.log.levels.WARN)
  end
end

function Logger:error(...)
  vim.notify(vim.fn.join({ "auto-session ERROR:", to_print(...) }, " "), vim.log.levels.ERROR)
end

return Logger
