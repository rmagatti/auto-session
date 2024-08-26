describe("The default config", function()
  local as = require "auto-session"
  local c = require "auto-session.config"
  as.setup {}

  it("can disable autosave", function()
    c.auto_save = true

    vim.cmd "SessionDisableAutoSave"

    assert.False(c.auto_save)
  end)

  it("can enable autosave", function()
    c.auto_save = false

    vim.cmd "SessionDisableAutoSave!"

    assert.True(c.auto_save)
  end)

  it("can toggle autosave", function()
    assert.True(c.auto_save)
    vim.cmd "SessionToggleAutoSave"
    assert.False(c.auto_save)
    vim.cmd "SessionToggleAutoSave"
    assert.True(c.auto_save)
  end)
end)
