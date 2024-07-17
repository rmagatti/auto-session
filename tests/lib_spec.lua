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

  it("remove_trailing_separator works", function()
    assert.equals("/tmp/blah", Lib.remove_trailing_separator "/tmp/blah/")
    assert.equals("/tmp/blah", Lib.remove_trailing_separator "/tmp/blah")

    if vim.fn.has "win32" == 1 then
      assert.equals("c:\\temp\\blah", Lib.remove_trailing_separator "c:\\temp\\blah\\")
      assert.equals("c:\\temp\\blah", Lib.remove_trailing_separator "c:\\temp\\blah/")
      assert.equals("c:\\temp\\blah", Lib.remove_trailing_separator "c:\\temp\\blah")
    end
  end)

  it("ensure_trailing_separator works", function()
    assert.equals("/test/path/", Lib.ensure_trailing_separator "/test/path/")
    assert.equals("/test/path/", Lib.ensure_trailing_separator "/test/path")

    if vim.fn.has "win32" == 1 then
      -- For the future, if we want to canonicalize paths, we can could call vim.fn.expand
      assert.equals("c:\\test\\path\\", Lib.ensure_trailing_separator "c:\\test\\path\\")
      assert.equals("c:\\test\\path/", Lib.ensure_trailing_separator "c:\\test\\path")
    end
  end)
end)
