---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("Lib / Helper functions", function()
  local as = require "auto-session"
  as.setup {
    auto_session_root_dir = TL.session_dir,
  }

  local Lib = as.Lib

  TL.clearSessionFilesAndBuffers()

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

  it("get_last_session() returns nil when no session", function()
    ---@diagnostic disable-next-line: missing-parameter
    assert.equals(nil, as.Lib.get_latest_session())
    assert.equals(nil, as.Lib.get_latest_session(TL.session_dir))
  end)

  it("session_file_name_to_session_name() works", function()
    assert.equals("mysession", Lib.session_file_name_to_session_name "mysession.vim")
    assert.equals("mysessionavim", Lib.session_file_name_to_session_name "mysessionavim")
    assert.equals("mysession", Lib.session_file_name_to_session_name "mysession")
  end)

  it("is_named_session() works", function()
    assert.True(Lib.is_named_session "mysession")
    assert.True(Lib.is_named_session "mysession.vim")

    if vim.fn.has "win32" == 1 then
      assert.False(Lib.is_named_session "C:\\some\\dir")
      assert.False(Lib.is_named_session "C:/some/dir")
    else
      assert.False(Lib.is_named_session "/some/dir")
    end
  end)

  it("escape_path() works", function()
    if vim.fn.has "win32" == 1 then
      assert.equals("c++-some-dir-", Lib.escape_path "c:\\some\\dir\\")
    else
      assert.equals("%some%dir%", Lib.escape_path "/some/dir/")
    end
  end)

  it("unescape_path() works", function()
    if vim.fn.has "win32" == 1 then
      assert.equals("c:\\some\\dir\\", Lib.unescape_path "c++-some-dir-")
    else
      assert.equals("/some/dir/", Lib.unescape_path "%some%dir%")
    end
  end)

  it("escape_string_for_vim() works", function()
    assert.equals("\\%some\\%dir\\%", Lib.escape_string_for_vim "%some%dir%")
  end)

  it("get_session_name_from_path() works", function()
    assert.equals(
      TL.escapeSessionName(TL.default_session_name .. ".vim"),
      as.Lib.get_session_name_from_path(TL.default_session_path)
    )
    assert.equals(
      TL.escapeSessionName(TL.named_session_name .. ".vim"),
      as.Lib.get_session_name_from_path(TL.named_session_path)
    )
    assert.equals("some string", as.Lib.get_session_name_from_path "some string")
  end)
end)
