describe("The default config", function()
  local as = require "auto-session"
  as.setup {}

  it("can enable autosaving", function()
    as.conf.auto_save_enabled = false

    vim.cmd "SessionEnableAutoSave"

    assert.True(as.conf.auto_save_enabled)
  end)

  it("can disable autosaving", function()
    as.conf.auto_save_enabled = true

    vim.cmd "SessionEnableAutoSave!"

    assert.False(as.conf.auto_save_enabled)
  end)

  it("can toggle autosaving", function()
    assert.False(as.conf.auto_save_enabled)

    vim.cmd "SessionToggleAutoSave"

    assert.True(as.conf.auto_save_enabled)

    vim.cmd "SessionToggleAutoSave"

    assert.False(as.conf.auto_save_enabled)
  end)
end)
