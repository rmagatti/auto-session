require("plenary")
local TL = require("tests/test_lib")

describe("extra data", function()
  local as = require("auto-session")
  local c = require("auto-session.config")

  as.setup({
    -- log_level = "debug",
  })

  it("can be saved and restored", function()
    vim.cmd("e " .. TL.test_file)

    local test_data = "{ a = 'test', b = { c = 'junx' } }"
    local restore_extra_data_called = false

    c.save_extra_data = function(_)
      return test_data
    end

    c.restore_extra_data = function(_, extra_data)
      restore_extra_data_called = true
      assert.equals(test_data, extra_data)
    end

    assert.True(as.SaveSession())
    assert.True(as.RestoreSession())
    assert.True(restore_extra_data_called)
  end)

  it("escapes correctly", function()
    vim.cmd("e " .. TL.test_file)

    local test_data = "{ a = 'test', b = { c = 'j]]unx' } }"
    local restore_extra_data_called = false

    c.save_extra_data = function(_)
      return test_data
    end

    c.restore_extra_data = function(_, extra_data)
      restore_extra_data_called = true
      assert.equals(test_data, extra_data)
    end

    assert.True(as.SaveSession())
    as.RestoreSession()
    assert.True(restore_extra_data_called)
  end)
end)
