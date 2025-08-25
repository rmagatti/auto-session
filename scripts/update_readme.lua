local uv = vim.uv or vim.loop

local readme_path = "README.md"
local config_path = "lua/auto-session/config.lua"

local function read_file(path)
  local fd = assert(uv.fs_open(path, "r", 438)) -- 438 = 0666 in octal
  local stat = assert(uv.fs_fstat(fd))
  local data = assert(uv.fs_read(fd, stat.size, 0))
  uv.fs_close(fd)
  return data
end

local function write_file(path, data)
  local fd = assert(uv.fs_open(path, "w", 438))
  assert(uv.fs_write(fd, data, 0))
  uv.fs_close(fd)
end

local function escape_for_pattern(s)
  return s:gsub("(%W)", "%%%1")
end

local function replace_section(text, start_marker, end_marker, replacement)
  local pattern = escape_for_pattern(start_marker) .. "(.-)" .. escape_for_pattern(end_marker)
  return text:gsub(pattern, start_marker .. "\n\n```lua\n" .. replacement .. "\n```\n\n" .. end_marker)
end

local function find_matching_brace(text, open_pos)
  local level = 0
  for i = open_pos, #text do
    local c = text:sub(i, i)
    if c == "{" then
      level = level + 1
    elseif c == "}" then
      level = level - 1
      if level == 0 then
        return i
      end
    end
  end
  return nil
end

local function update_readme()
  local config_text = read_file(config_path)
  local readme_text = read_file(readme_path)

  -- Extract types section: from ---@class AutoSession.Config to next empty line
  local types_section = config_text:match("(---@class%s+AutoSession%.Config.-)\n\n")
  if not types_section then
    error("Types section not found")
  end

  -- Extract config section: from 'local defaults = {' to matching closing '}'
  local start_pos, end_pos = config_text:find("local%s+defaults%s*=%s*{")
  if not start_pos then
    error("Config section start not found")
  end

  local close_pos = find_matching_brace(config_text, end_pos)
  if not close_pos then
    error("Config section closing brace not found")
  end

  local config_section = config_text:sub(start_pos, close_pos)

  -- Replace markers with extracted content
  readme_text = replace_section(readme_text, "<!-- types:start -->", "<!-- types:end -->", types_section)
  readme_text = replace_section(readme_text, "<!-- config:start -->", "<!-- config:end -->", config_section)

  write_file(readme_path, readme_text)
  print("README.md updated successfully")
end

update_readme()
