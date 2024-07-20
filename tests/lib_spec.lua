---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("Lib / Helper functions", function()
  local as = require "auto-session"
  as.setup {}

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

  it("can urlencode/urldecode", function()
    assert.equals("%2Fsome%2Fdir%2Fwith%20spaces%2Fand-dashes", Lib.urlencode "/some/dir/with spaces/and-dashes")
    assert.equals("/some/dir/with spaces/and-dashes", Lib.urldecode(Lib.urlencode "/some/dir/with spaces/and-dashes"))

    assert.equals(
      "c%3A%5Csome%5Cdir%5Cwith%20space%5Cand-dashes%5C",
      Lib.urlencode "c:\\some\\dir\\with space\\and-dashes\\"
    )
    assert.equals(
      "c:\\some\\dir\\with space\\and-dashes\\",
      Lib.urldecode(Lib.urlencode "c:\\some\\dir\\with space\\and-dashes\\")
    )

    -- round trip should be stable
    assert.equals(TL.default_session_name, Lib.urldecode(Lib.urlencode(TL.default_session_name)))
    assert.equals(TL.named_session_name, Lib.urldecode(Lib.urlencode(TL.named_session_name)))

    -- Should not encode anything
    assert.equals(TL.named_session_name, Lib.urldecode(TL.named_session_name))
    assert.equals(TL.named_session_name, Lib.urlencode(TL.named_session_name))
  end)

  it("session_file_name_to_session_name() works", function()
    assert.equals("mysession", Lib.escaped_session_name_to_session_name "mysession.vim")
    assert.equals("mysessionavim", Lib.escaped_session_name_to_session_name "mysessionavim")
    assert.equals("mysession", Lib.escaped_session_name_to_session_name "mysession")
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

  it("escape_session_name() works", function()
    assert.equals(
      "%2Fsome%2Fdir%2Fwith%20spaces%2Fand-dashes",
      Lib.escape_session_name "/some/dir/with spaces/and-dashes"
    )

    assert.equals(
      "c%3A%5Csome%5Cdir%5Cwith%20space%5Cand-dashes%5C",
      Lib.escape_session_name "c:\\some\\dir\\with space\\and-dashes\\"
    )
  end)

  it("legacy_escape_session_name() works", function()
    if vim.fn.has "win32" == 1 then
      assert.equals("c++-some-dir-", Lib.legacy_escape_session_name "c:\\some\\dir\\")
    else
      assert.equals("%some%dir%", Lib.legacy_escape_session_name "/some/dir/")
    end
  end)

  it("legacy_escape_session_name() works", function()
    if vim.fn.has "win32" == 1 then
      assert.equals("c:\\some\\dir\\", Lib.legacy_unescape_session_name "c++-some-dir-")
    else
      assert.equals("/some/dir/", Lib.legacy_unescape_session_name "%some%dir%")
    end
  end)

  it("escape_string_for_vim() works", function()
    assert.equals("\\%some\\%dir\\%", Lib.escape_string_for_vim "%some%dir%")
  end)

  it("can identify new and old sessions", function()
    assert.False(Lib.is_legacy_file_name(Lib.urlencode "mysession" .. ".vim"))
    assert.False(Lib.is_legacy_file_name(Lib.urlencode "/some/dir/" .. ".vim"))
    assert.False(Lib.is_legacy_file_name(Lib.urlencode "/some/dir/with spaces/and-dashes" .. ".vim"))
    assert.False(Lib.is_legacy_file_name(Lib.urlencode "c:\\some\\dir\\with spaces\\and-dashes" .. ".vim"))
    assert.False(Lib.is_legacy_file_name(Lib.urlencode "c:\\some\\dir\\with spaces\\and-dashes\\" .. ".vim"))

    assert.True(Lib.is_legacy_file_name(TL.legacyEscapeSessionName "/some/dir" .. ".vim"))
    assert.False(Lib.is_legacy_file_name(TL.legacyEscapeSessionName "mysession" .. ".vim"))

    if vim.fn.has "win32" == 1 then
      assert.True(Lib.is_legacy_file_name(TL.legacyEscapeSessionName "c:\\some\\dir" .. ".vim"))
      assert.True(Lib.is_legacy_file_name(TL.legacyEscapeSessionName "c:\\some\\other\\dir" .. ".vim"))
      assert.True(Lib.is_legacy_file_name(TL.legacyEscapeSessionName "c:\\some\\dir-with-dashes" .. ".vim"))
      assert.True(Lib.is_legacy_file_name(TL.legacyEscapeSessionName "c:/some/dir-with-dashes" .. ".vim"))
    end
  end)

  it("can get display name", function()
    local splits = Lib.get_session_display_name_as_table "%2FUsers%2Fcam%2FDev%2Fneovim-dev%2Fauto-session.vim"

    assert.equals(1, #splits)
    assert.equals("/Users/cam/Dev/neovim-dev/auto-session", splits[1])

    assert.equals(
      "/Users/cam/tmp/a (branch: main)",
      (Lib.get_session_display_name "%2FUsers%2Fcam%2Ftmp%2Fa%7Cmain.vim")
    )

    splits = Lib.get_session_display_name_as_table "%2FUsers%2Fcam%2Ftmp%2Fa%7Cmain.vim"

    assert.equals(2, #splits)
    assert.equals("/Users/cam/tmp/a", splits[1])
    assert.equals("(branch: main)", splits[2])

    assert.equals(
      "/Users/cam/tmp/a (branch: main)",
      (Lib.get_session_display_name "%2FUsers%2Fcam%2Ftmp%2Fa%7Cmain.vim")
    )
  end)
end)
