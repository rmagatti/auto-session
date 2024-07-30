describe("The default config", function()
  local as = require "auto-session"
  as.setup {}

  it("can disable autosave", function()
    as.conf.auto_save_enabled = true

    vim.cmd "SessionDisableAutoSave"

    assert.False(as.conf.auto_save_enabled)
  end)

  it("can enable autosave", function()
    as.conf.auto_save_enabled = false

    vim.cmd "SessionDisableAutoSave!"

    assert.True(as.conf.auto_save_enabled)
  end)

  it("can toggle autosave", function()
    assert.True(as.conf.auto_save_enabled)
    vim.cmd "SessionToggleAutoSave"
    assert.False(as.conf.auto_save_enabled)
    vim.cmd "SessionToggleAutoSave"
    assert.True(as.conf.auto_save_enabled)
  end)
end)
