---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("Lib", function()
  local as = require "auto-session"
  as.setup {
    auto_session_root_dir = TL.session_dir,
  }

  local Lib = as.Lib

  it("get_root_dir works", function()
    assert.equals(TL.session_dir, as.get_root_dir())

    assert.equals(TL.session_dir:gsub("/$", ""), as.get_root_dir(false))
  end)

  it("dir_without_trailing_separator works", function()
    assert.equals("/tmp/blah", Lib.dir_without_trailing_separator "/tmp/blah/")

    if vim.fn.has "win32" == 1 then
      assert.equals("c:\\temp\\blah", Lib.dir_without_trailing_separator "c:\\temp\\blah\\")
      assert.equals("c:\\temp\\blah", Lib.dir_without_trailing_separator "c:\\temp\\blah/")
    end
  end)
end)
