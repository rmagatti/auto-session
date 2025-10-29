local config = require("auto-session.config")
local Lib = require("auto-session.lib")

-- Ensure config.options.session_lens and session_control are initialized for helpers
config.setup({ session_lens = { session_control = { control_dir = "/tmp/auto-session-test/" } } })

local function stub_session_file(name, content)
  local path = config.options.session_lens.session_control.control_dir .. name .. ".vim"
  vim.fn.mkdir(config.options.session_lens.session_control.control_dir, "p")
  vim.fn.writefile(content, path)
  return path
end

local function stub_buffer_file(name, content)
  local path = config.options.session_lens.session_control.control_dir .. name .. ".lua"
  vim.fn.mkdir(config.options.session_lens.session_control.control_dir, "p")
  vim.fn.writefile(content, path)
  return path
end

describe("SessionLens previewer config", function()
  local session_name = "testsession"
  local session_file_content = {
    "tabpage 1",
    "buffer 1",
    "buffer 2",
    "filetype lua",
  }
  local session_file_path
  local buffer_file_path
  local buffer_file_content = {
    'print("hello world")',
    "return 42",
  }

  before_each(function()
    session_file_path = stub_session_file(session_name, session_file_content)
    buffer_file_path = stub_buffer_file("testbuffer", buffer_file_content)
  end)

  after_each(function()
    vim.fn.delete(session_file_path)
    vim.fn.delete(buffer_file_path)
  end)

  it("defaults to summary", function()
    config.setup({ session_lens = { previewer = nil } })
    local lines, filetype = Lib.get_session_preview(session_file_path, nil)
    assert.is_true(type(lines) == "table")
    assert.is_true(#lines > 0)
    assert.is_true(type(lines[1]) == "string")
    assert.are.same(nil, filetype)
  end)

  it("uses summary when set", function()
    config.setup({ session_lens = { previewer = "summary" } })
    local lines, filetype = Lib.get_session_preview(session_file_path, "summary")
    assert.is_true(type(lines) == "table")
    assert.is_true(#lines > 0)
    assert.is_true(type(lines[1]) == "string")
    assert.are.same(nil, filetype)
  end)

  it("uses active_buffer when set", function()
    -- Patch create_session_summary to simulate current_buffer
    local orig_create_session_summary = Lib.create_session_summary
    Lib.create_session_summary = function(_)
      return {
        current_buffer = buffer_file_path,
      }
    end
    config.setup({ session_lens = { previewer = "active_buffer" } })
    local lines, filetype = Lib.get_session_preview(session_file_path, "active_buffer")
    assert.are.same("lua", filetype)
    assert.are.same(buffer_file_content, lines)
    Lib.create_session_summary = orig_create_session_summary
  end)

  it("uses custom function when set", function()
    local custom_preview = function(session_name, session_filename, session_lines)
      return { "CUSTOM:" .. session_name, "LINES:" .. #session_lines }, "customft"
    end
    config.setup({ session_lens = { previewer = custom_preview } })
    local lines, filetype = Lib.get_session_preview(session_file_path, custom_preview)
    assert.are.same({ "CUSTOM:" .. session_name, "LINES:" .. #session_file_content }, lines)
    assert.are.same("customft", filetype)
  end)

  it("handles invalid value gracefully", function()
    config.setup({ session_lens = { previewer = "invalid_value" } })
    local lines, filetype = Lib.get_session_preview(session_file_path, "invalid_value")
    assert.is_true(type(lines) == "nil" or type(lines) == "table")
    assert.are.same(nil, filetype)
  end)
end)
