---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"
local stub = require "luassert.stub"

describe("Setting purge_after_days", function()
  local as = require "auto-session"

  -- old session 10 days ago
  local old_session = 10

  as.setup {
    purge_after_days = 3,
  }

  TL.clearSessionFilesAndBuffers()
  vim.cmd("e " .. TL.test_file)

  -- requires nvim >= 0.10
  if vim.fn.has "nvim-0.10" == 1 then
    it("does purge old sessions while leaving recent ones", function()
      as.SaveSession()
      as.SaveSession(TL.named_session_name)

      assert.equals(1, vim.fn.filereadable(TL.default_session_path))
      assert.equals(1, vim.fn.filereadable(TL.named_session_path))

      -- Make the named session file appear to be 10 days old
      local current_time = os.time()
      local old_time = current_time - (old_session * 24 * 60 * 60) -- 10 days ago in seconds

      -- set the modified and accessed time
      vim.uv.fs_utime(TL.named_session_path, old_time, old_time)

      -- Verify the file's modification time is now old
      local file_time = vim.fn.getftime(TL.named_session_path)
      assert.is_true(file_time < current_time - (old_session * 24 * 60 * 60) + 60) -- Add 60 seconds tolerance

      -- Hook into decode to capture when function finishes
      local json_decode = vim.json.decode
      local purge_finished = false
      stub(vim.json, "decode", function(str)
        -- session control also uses json functions so we're only looking for json returned by
        -- Lib.purge_old_sessions
        if str == '["' .. TL.named_session_name .. '.vim"]' then
          purge_finished = true
        end
        return json_decode(str)
      end)

      -- Now purge old sessions
      as.start()

      vim.wait(1000, function()
        return purge_finished
      end)

      -- Revert the stub
      vim.json.decode:revert()

      -- The named session should be deleted, but the default session should remain
      assert.equals(1, vim.fn.filereadable(TL.default_session_path))
      assert.equals(0, vim.fn.filereadable(TL.named_session_path))
    end)
  end
end)
