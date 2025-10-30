# 🗒️ AutoSession

<!-- panvimdoc-ignore-start -->

Automatically reopen the files and windows you had open. It's like you never left!

<img alt="demo" src="https://github.com/user-attachments/assets/8a779b99-d556-48a4-bd9f-dc88fb080a8e" width="800">
  
[<img alt="GitHub Actions Workflow Status" src="https://img.shields.io/github/actions/workflow/status/rmagatti/auto-session/tests.yml?style=for-the-badge&label=tests">](https://github.com/rmagatti/auto-session/actions/workflows/tests.yml)

<!-- panvimdoc-ignore-end -->

## ⭐ Features

- 💾 Automatically save and restore sessions, with customizable filters
- 🎯 [Session picker](#-session-picker), with support for Telescope, Snacks, Fzf-Lua, and `vim.ui.select`
- 📁 Track directory changes
- 🌿 Separate sessions per git branch
- 🪝 Customizable with [Hooks](#-command-hooks)
- 🗃️ Save custom data along with your session

## 💡 How it works

When you start `nvim`, AutoSession will try to restore a session for the current working directory (`cwd`) if it exists. If it does, it'll reopen all of your buffers and windows. If not, nothing happens. When you quit `nvim`, AutoSession will automatically save a session for `cwd` so you can pick up where you left off.

## 📦 Installation

[Lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  "rmagatti/auto-session",
  lazy = false,

  ---enables autocomplete for opts
  ---@module "auto-session"
  ---@type AutoSession.Config
  opts = {
    suppressed_dirs = { "~/", "~/Projects", "~/Downloads", "/" },
    -- log_level = 'debug',
  },
}
```

Note: For other plugin managers, make sure setup is called somewhere, e.g.:

```lua
require("auto-session").setup({})
```

## ⚙️ Configuration

Default settings (you don't have to copy these into your config):

<!-- config:start -->

```lua
local defaults = {
  -- Saving / restoring
  enabled = true, -- Enables/disables auto creating, saving and restoring
  auto_save = true, -- Enables/disables auto saving session on exit
  auto_restore = true, -- Enables/disables auto restoring session on start
  auto_create = true, -- Enables/disables auto creating new session files. Can be a function that returns true if a new session file should be allowed
  auto_restore_last_session = false, -- On startup, loads the last saved session if session for cwd does not exist
  cwd_change_handling = false, -- Automatically save/restore sessions when changing directories
  single_session_mode = false, -- Enable single session mode to keep all work in one session regardless of cwd changes. When enabled, prevents creation of separate sessions for different directories and maintains one unified session. Does not work with cwd_change_handling

  -- Filtering
  suppressed_dirs = nil, -- Suppress session restore/create in certain directories
  allowed_dirs = nil, -- Allow session restore/create in certain directories
  bypass_save_filetypes = nil, -- List of filetypes to bypass auto save when the only buffer open is one of the file types listed, useful to ignore dashboards
  close_filetypes_on_save = { "checkhealth" }, -- Buffers with matching filetypes will be closed before saving
  close_unsupported_windows = true, -- Close windows that aren't backed by normal file before autosaving a session
  preserve_buffer_on_restore = nil, -- Function that returns true if a buffer should be preserved when restoring a session

  -- Git / Session naming
  git_use_branch_name = false, -- Include git branch name in session name, can also be a function that takes an optional path and returns the name of the branch
  git_auto_restore_on_branch_change = false, -- Should we auto-restore the session when the git branch changes. Requires git_use_branch_name
  custom_session_tag = nil, -- Function that can return a string to be used as part of the session name

  -- Deleting
  auto_delete_empty_sessions = true, -- Enables/disables deleting the session if there are only unnamed/empty buffers when auto-saving
  purge_after_minutes = nil, -- Sessions older than purge_after_minutes will be deleted asynchronously on startup, e.g. set to 14400 to delete sessions that haven't been accessed for more than 10 days, defaults to off (no purging), requires >= nvim 0.10

  -- Saving extra data
  save_extra_data = nil, -- Function that returns extra data that should be saved with the session. Will be passed to restore_extra_data on restore
  restore_extra_data = nil, -- Function called when there's extra data saved for a session

  -- Argument handling
  args_allow_single_directory = true, -- Follow normal session save/load logic if launched with a single directory as the only argument
  args_allow_files_auto_save = false, -- Allow saving a session even when launched with a file argument (or multiple files/dirs). It does not load any existing session first. Can be true or a function that returns true when saving is allowed. See documentation for more detail

  -- Misc
  log_level = "error", -- Sets the log level of the plugin (debug, info, warn, error).
  root_dir = vim.fn.stdpath("data") .. "/sessions/", -- Root dir where sessions will be stored
  show_auto_restore_notif = false, -- Whether to show a notification when auto-restoring
  restore_error_handler = nil, -- Function called when there's an error restoring. By default, it ignores fold and help errors otherwise it displays the error and returns false to disable auto_save. Default handler is accessible as require('auto-session').default_restore_error_handler
  continue_restore_on_error = true, -- Keep loading the session even if there's an error
  lsp_stop_on_restore = false, -- Should language servers be stopped when restoring a session. Can also be a function that will be called if set. Not called on autorestore from startup
  lazy_support = true, -- Automatically detect if Lazy.nvim is being used and wait until Lazy is done to make sure session is restored correctly. Does nothing if Lazy isn't being used
  legacy_cmds = true, -- Define legacy commands: Session*, Autosession (lowercase s), currently true. Set to false to prevent defining them

  ---@type SessionLens
  session_lens = {
    picker = nil, -- "telescope"|"snacks"|"fzf"|"select"|nil Pickers are detected automatically but you can also set one manually. Falls back to vim.ui.select
    load_on_setup = true, -- Only used for telescope, registers the telescope extension at startup so you can use :Telescope session-lens
    picker_opts = nil, -- Table passed to Telescope / Snacks / Fzf-Lua to configure the picker. See below for more information
    previewer = "summary", -- 'summary'|'active_buffer'|function - How to display session preview. 'summary' shows a summary of the session, 'active_buffer' shows the contents of the active buffer in the session, or a custom function

    ---@type SessionLensMappings
    mappings = {
      -- Mode can be a string or a table, e.g. {"i", "n"} for both insert and normal mode
      delete_session = { "i", "<C-d>" }, -- mode and key for deleting a session from the picker
      alternate_session = { "i", "<C-s>" }, -- mode and key for swapping to alternate session from the picker
      copy_session = { "i", "<C-y>" }, -- mode and key for copying a session from the picker
    },

    ---@type SessionControl
    session_control = {
      control_dir = vim.fn.stdpath("data") .. "/auto_session/", -- Auto session control dir, for control files, like alternating between two sessions with session-lens
      control_filename = "session_control.json", -- File name of the session control file
    },
  },
}
```

<!-- config:end -->

<details><summary>Types</summary>

<!-- types:start -->

```lua
---@class AutoSession.Config
---
---Saving / restoring
---@field enabled? boolean
---@field auto_save? boolean
---@field auto_restore? boolean
---@field auto_create? boolean|fun(): should_create_session:boolean
---@field auto_restore_last_session? boolean
---@field cwd_change_handling? boolean
---@field single_session_mode? boolean
---
---Filtering
---@field suppressed_dirs? table
---@field allowed_dirs? table
---@field bypass_save_filetypes? table
---@field close_filetypes_on_save? table
---@field close_unsupported_windows? boolean
---@field preserve_buffer_on_restore? fun(bufnr:number): preserve_buffer:boolean
---
---Git / Session naming
---@field git_use_branch_name? boolean|fun(path:string?): branch_name:string|nil
---@field git_auto_restore_on_branch_change? boolean
---@field custom_session_tag? fun(session_name:string): tag:string
---
---Deleting
---@field auto_delete_empty_sessions? boolean
---@field purge_after_minutes? number
---
---Saving extra data
---@field save_extra_data? fun(session_name:string): extra_data:string|nil
---@field restore_extra_data? fun(session_name:string, extra_data:string)
---
---Argument handling
---@field args_allow_single_directory? boolean
---@field args_allow_files_auto_save? boolean|fun(): disable_auto_save:boolean
---
---Misc
---@field log_level? string|integer
---@field root_dir? string
---@field show_auto_restore_notif? boolean
---@field restore_error_handler? fun(error_msg:string): disable_auto_save:boolean
---@field continue_restore_on_error? boolean
---@field lsp_stop_on_restore? boolean|fun()
---@field lazy_support? boolean
---@field legacy_cmds? boolean
---
---@field session_lens? SessionLens
---
---Session Lens Config
---@class SessionLens
---@field picker? "telescope"|"snacks"|"fzf"|"select"
---@field load_on_setup? boolean
---@field picker_opts? table
---@field previewer? 'summary'|'active_buffer'|fun(session_name:string, session_filename:string, session_lines:string[]):lines:string[],filetype:string?
---@field mappings? SessionLensMappings
---@field session_control? SessionControl
---
---@class SessionLensMappings
---@field delete_session? table
---@field alternate_session? table
---@field copy_session? table
---
---@class SessionControl
---@field control_dir? string
---@field control_filename? string
---
---Hooks
---@field pre_save_cmds? (string|fun(session_name:string): boolean)[] executes before a session is saved, return false to stop auto-saving
---@field post_save_cmds? (string|fun(session_name:string))[] executes after a session is saved
---@field pre_restore_cmds? (string|fun(session_name:string): boolean)[] executes before a session is restored, return false to stop auto-restoring
---@field post_restore_cmds? (string|fun(session_name:string))[] executes after a session is restored
---@field pre_delete_cmds? (string|fun(session_name:string))[] executes before a session is deleted
---@field post_delete_cmds? (string|fun(session_name:string))[] executes after a session is deleted
---@field no_restore_cmds? (string|fun(is_startup:boolean))[] executes when no session is restored when auto-restoring, happens on startup or possibly on cwd/git branch changes
---@field pre_cwd_changed_cmds? (string|fun())[] executes before cwd is changed if cwd_change_handling is true
---@field post_cwd_changed_cmds? (string|fun())[] executes after cwd is changed if cwd_change_handling is true
---@field save_extra_cmds? (string|fun(session_name:string): string|table|nil)[] executes to get extra data to save with the session
```

<!-- types:end -->

</details>

#### Recommended sessionoptions config

For the best experience, set `sessionoptions` to:

**Lua**

```lua
vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
```

**VimL**

```viml
set sessionoptions+=winpos,terminal,folds
```

## 📢 Commands

```viml
:AutoSession save " saves a session based on the `cwd` in `root_dir`
:AutoSession save my_session " saves a session called `my_session` in `root_dir`

:AutoSession restore " restores a session based on the `cwd` from `root_dir`
:AutoSession restore my_session " restores `my_session` from `root_dir`

:AutoSession delete " deletes a session based on the `cwd` from `root_dir`
:AutoSession delete my_session " deletes `my_session` from `root_dir`

:AutoSession disable " disables autosave
:AutoSession enable " enables autosave (still does all checks in the config)
:AutoSession toggle" toggles autosave

:AutoSession purgeOrphaned " removes all orphaned sessions with no working directory left.

:AutoSession search " opens a session picker, see Config.session_lens.picker
:AutoSession deletePicker " opens a vim.ui.select picker to choose a session to delete.
```

## 📖 Details

Starting `nvim`

- When starting `nvim` with no arguments, AutoSession will try to restore the session for `cwd` if one exists.
- When starting `nvim .` (or another directory), AutoSession will try to restore the session for that directory. See [argument handling](https://github.com/rmagatti/auto-session/wiki/Argument-Handling) for more details.
- When starting `nvim some_file.txt` (or multiple files), by default, AutoSession won't do anything. See [argument handling](https://github.com/rmagatti/auto-session/wiki/Argument-Handling) for more details.
- Even after starting `nvim` with a file argument, a session for `cwd` can still be manually restored by running `:AutoSession restore`.
- When piping to `nvim`, e.g: `cat myfile | nvim`, AutoSession disables itself.

:warning: Please note that if there are errors in your config, restoring the session might fail, if that happens, auto session will then disable auto saving for the current session.

Exiting `nvim`

- When you exit, AutoSession will try to automatically save a session for `cwd`
- If autosaving is enabled (`auto_save = true`) and
- If there are non-empty buffers and
- If `cwd` isn't in `suppressed_dirs` or, if set, it is in `allowed_dirs` and
- If the session doesn't exist and `auto_create = true`
- Then it will save a session for `cwd`

Session naming:

- By default, sessions are named for `cwd`
- You can manually name a session with `:AutoSession save my_session`. Manually named sessions can't be auto-restored but once restored they will be used for autosaving.
- The current git branch can optionally be included in the session name.
- You can also set a custom function that returns a string to include in the session name so you have different sessions for `cwd` per tmux session, window, etc.

## 🔭 Session Picker

You can use [Telescope](https://github.com/nvim-telescope/telescope.nvim), [snacks.nvim](https://github.com/folke/snacks.nvim), [Fzf-Lua](https://github.com/ibhagwan/fzf-lua) to see, load, and delete your sessions. The configuration options are in the `session_lens` section:

```lua
return {
  "rmagatti/auto-session",
  lazy = false,
  keys = {
    -- Will use Telescope if installed or a vim.ui.select picker otherwise
    { "<leader>wr", "<cmd>AutoSession search<CR>", desc = "Session search" },
    { "<leader>ws", "<cmd>AutoSession save<CR>", desc = "Save session" },
    { "<leader>wa", "<cmd>AutoSession toggle<CR>", desc = "Toggle autosave" },
  },

  ---enables autocomplete for opts
  ---@module "auto-session"
  ---@type AutoSession.Config
  opts = {
    -- The following are already the default values, no need to provide them if these are already the settings you want.
    session_lens = {
      picker = nil, -- "telescope"|"snacks"|"fzf"|"select"|nil Pickers are detected automatically but you can also manually choose one. Falls back to vim.ui.select
      mappings = {
        -- Mode can be a string or a table, e.g. {"i", "n"} for both insert and normal mode
        delete_session = { "i", "<C-d>" },
        alternate_session = { "i", "<C-s>" },
        copy_session = { "i", "<C-y>" },
      },

      picker_opts = {
        -- For Telescope, you can set theme options here, see:
        -- https://github.com/nvim-telescope/telescope.nvim/blob/master/doc/telescope.txt#L112
        -- https://github.com/nvim-telescope/telescope.nvim/blob/master/lua/telescope/themes.lua
        --
        -- border = true,
        -- layout_config = {
        --   width = 0.8, -- Can set width and height as percent of window
        --   height = 0.5,
        -- },

        -- For Snacks, you can set layout options here, see:
        -- https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#%EF%B8%8F-layouts
        --
        -- preset = "dropdown",
        -- preview = false,
        -- layout = {
        --   width = 0.4,
        --   height = 0.4,
        -- },

        -- For Fzf-Lua, picker_opts just turns into winopts, see:
        -- https://github.com/ibhagwan/fzf-lua#customization
        --
        --  height = 0.8,
        --  width = 0.50,
      },

      -- Telescope only: If load_on_setup is false, make sure you use `:AutoSession search` to open the picker as it will initialize everything first
      load_on_setup = true,
    },
  },
}
```

Use `:AutoSession search` to launch the session picker. It will automatically look for Telescope, Snacks, and Fzf-Lua and use the first one it finds. If you have multiple pickers installed, you can set `session-lens.picker` to manually pick your picker. If no pickers are installed, it'll fall back to `vim.ui.select`

If you're using Telescope and want to launch the picker via `:Telescope session-lens`, set `session-lens.load_on_setup = true` or make sure you've called `:AutoSession search` first.

The following default keymaps are available when the session-lens picker is open:

- `<CR>` loads the currently highlighted session.
- `<C-s>` swaps to the previously opened session. This can give you a nice flow if you're constantly switching between two projects.
- `<C-d>` will delete the currently highlighted session. This makes it easy to keep the session list clean.
- `<C-y>` will let you make a copy of the highlighted session.

When using Telescope, Snacks, or Fzf-Lua, you can customize the picker using `picker_opts`. Refer to the links above for the specific picker configuration options.

<img alt ="picker" src="https://github.com/user-attachments/assets/440fc85d-c56c-4c2b-81f5-1bdeac35e8af" width="800">

## 📁 Directories

There are two config options, `allowed_dirs` and `suppressed_dirs`, that control which directories AutoSession will auto-save a session for. If `allowed_dirs` is set, sessions will only be auto-saved in matching directories. If `suppressed_dirs` is set, then a session won't be auto-saved for a matching directory. If both are set, a session will only be auto-saved if it matches an allowed dir and does not match a suppressed dir.

Both options are a table of directories, with support for globs:

```lua
opts = {
  allowed_dirs = { "/some/dir/", "/projects/*" },
  suppressed_dirs = { "/projects/secret" },
}
```

With those options, sessions would only be auto-saved for `/some/dir` and any direct child of `/projects` (e.g. `/projects/myproject` but not `/projects/myproject/submodule`) except `/projects/secret`

If you want even more fine-grained control, you can instead set `auto_create` to a function to [conditionally create a session](https://github.com/rmagatti/auto-session/wiki/Auto%E2%80%90creation-customization).

## 🚶 Directory changes

AutoSession can track `cwd` changes!

It's disabled by default, but when enabled it works as follows:

- DirChangedPre (before the cwd actually changes):
  - Save the current session
  - Clear all buffers `%bw!`. This guarantees buffers don't bleed to the
    next session.
  - Clear jumps. Also done so there is no bleeding between sessions.
  - Run the `pre_cwd_changed` hook
- DirChanged (after the cwd has changed):
  - Restore session using new cwd
  - Run the `post_cwd_changed` hook

Now when you changes the cwd with `:cd some/new/dir` AutoSession handles it gracefully, saving the current session so there aren't losses and loading the session for the upcoming cwd if it exists.

Hooks are available for custom actions _before_ and _after_ the `cwd` is changed. Here's the config for tracking cwd and a hook example:

```lua
opts = {
  cwd_change_handling = true,

  pre_cwd_changed_cmds = {
    "tabdo NERDTreeClose", -- Close NERDTree before saving session
  },

  post_cwd_changed_cmds = {
    function()
      require("lualine").refresh() -- example refreshing the lualine status line _after_ the cwd changes
    end,
  },
}
```

## 🌿 Git

To include the current git branch in the session name, set `git_use_branch_name = true,` in your config

AutoSession can also optionally auto-restore sessions when switching branches. Set `git_auto_restore_on_branch_change = true,` to enable that. Note, if you have modified files open when the branch is switched, AutoSession will ask if you want to close those files and restore the session or cancel restoring the session. If you cancel restoring the session, auto-saving will be disabled.

```lua
opts = {
  git_use_branch_name = true,
  git_auto_restore_on_branch_change = true,
}
```

## 🖥️ Dashboards

If you use a dashboard, you probably don't want to try and save a session when just the dashboard is open. To avoid that, add your dashboard filetype to the bypass list as follows:

```lua
opts = {
  bypass_save_filetypes = { "alpha", "dashboard", "snacks_dashboard" }, -- or whatever dashboard you use
}
```

## ➖ Statusline

You can show the current session name in the statusline by using the function `current_session_name()`. With no arguments, it will return the full session name. For automatically created sessions that will be the path where the session was saved. If you only want the last directory in the path, you can call `current_session_name(true)`.

Here's an example using [Lualine](https://github.com/nvim-lualine/lualine.nvim):

```lua
require("lualine").setup({
  options = {
    theme = "tokyonight",
  },
  sections = {
    lualine_x = {
      function()
        return require("auto-session.lib").current_session_name(true)
      end,
    },
  },
})
```

<img width="800" height="676" alt="Screenshot 2025-08-21 at 12 10 10" src="https://github.com/user-attachments/assets/49b0357e-9002-4d18-8dbb-3eed4422c5f9" />

## 🪝 Command Hooks

#### Command hooks are a list of commands or functions that get executed at different stages of the session management lifecycle.

Command hooks exist in the format: {hook_name}

- `{pre_save}`: executes _before_ a session is saved, return false to stop auto-save
- `{post_save}`: executes _after_ a session is saved
- `{pre_restore}`: executes _before_ a session is restored, return false to stop auto-restore
- `{post_restore}`: executes _after_ a session is restored
- `{pre_delete}`: executes _before_ a session is deleted
- `{post_delete}`: executes _after_ a session is deleted
- `{no_restore}`: executes when no session is auto-restored, happens _after_ `VimEnter` (and possibly on cwd/git branch change, if enabled)
- `{pre_cwd_changed}`: executes _before_ a directory is changed (if `cwd_change_handling` is enabled)
- `{post_cwd_changed}`: executes _after_ a directory is changed (if `cwd_change_handling` is enabled)
- `{save_extra}`: executes _after_ a session is saved, saves returned string or table to `*x.vim`, reference `:help mks`

Each hook is a table of vim commands or lua functions (or a mix of both). Here are some examples of what you can do:

```lua
opts = {
  -- {hook_name}_cmds = {"{hook_command1}", "{hook_command2}"}

  pre_save_cmds = {
    "tabdo NERDTreeClose", -- Close NERDTree before saving session
    function(session_name)
      if some_test() then -- don't auto-save if some_test() is true
        return false
      end
    end,
  },

  pre_restore_cmds = {
    function(session_name)
      if some_test() then -- don't auto-restore if some_test() is true
        return false
      end
    end,
  },

  post_restore_cmds = {
    "someOtherVimCommand",
    function()
      -- Restore nvim-tree after a session is restored
      local nvim_tree_api = require("nvim-tree.api")
      nvim_tree_api.tree.open()
      nvim_tree_api.tree.change_root(vim.fn.getcwd())
      nvim_tree_api.tree.reload()
    end,
  },

  -- Save quickfix list and open it when restoring the session
  save_extra_cmds = {
    function()
      local qflist = vim.fn.getqflist()
      -- return nil to clear any old qflist
      if #qflist == 0 then
        return nil
      end
      local qfinfo = vim.fn.getqflist({ title = 1 })

      for _, entry in ipairs(qflist) do
        -- use filename instead of bufnr so it can be reloaded
        entry.filename = vim.api.nvim_buf_get_name(entry.bufnr)
        entry.bufnr = nil
      end

      local setqflist = "call setqflist(" .. vim.fn.string(qflist) .. ")"
      local setqfinfo = 'call setqflist([], "a", ' .. vim.fn.string(qfinfo) .. ")"
      return { setqflist, setqfinfo, "copen" }
    end,
  },
}
```

## 🗃️ Saving custom data

You can use the config functions `save_extra_data` and `restore_extra_data` to save arbitrary data as part of your session.

As an example, here's how you could save DAP breakpoints with your session:

```lua
---@module "auto-session"
---@type AutoSession.Config
local opts = {

  save_extra_data = function(_)
    local ok, breakpoints = pcall(require, "dap.breakpoints")
    if not ok or not breakpoints then
      return
    end

    local bps = {}
    local breakpoints_by_buf = breakpoints.get()
    for buf, buf_bps in pairs(breakpoints_by_buf) do
      bps[vim.api.nvim_buf_get_name(buf)] = buf_bps
    end
    if vim.tbl_isempty(bps) then
      return
    end
    local extra_data = {
      breakpoints = bps,
    }
    return vim.fn.json_encode(extra_data)
  end,

  restore_extra_data = function(_, extra_data)
    local json = vim.fn.json_decode(extra_data)

    if json.breakpoints then
      local ok, breakpoints = pcall(require, "dap.breakpoints")

      if not ok or not breakpoints then
        return
      end
      vim.notify("restoring breakpoints")
      for buf_name, buf_bps in pairs(json.breakpoints) do
        for _, bp in pairs(buf_bps) do
          local line = bp.line
          local opts = {
            condition = bp.condition,
            log_message = bp.logMessage,
            hit_condition = bp.hitCondition,
          }
          breakpoints.set(opts, vim.fn.bufnr(buf_name), line)
        end
      end
    end
  end,
}
```

## 📚 Wiki

See [the wiki](https://github.com/rmagatti/auto-session/wiki/) for more advanced ways to use AutoSession. And feel free to share new and interesting ways you're using AutoSession!

## 🚫 Disabling the plugin

You might run into issues with Firenvim or another plugin and want to disable AutoSession altogether based on some condition.
For example, this will disable AutoSession when started under Firenvim:

```lua
return {
  "rmagatti/auto-session",
  lazy = false,
  cond = not vim.g.started_by_firenvim and not vim.g.vscode,
}
```

Or in VimScript:

```viml
if exists('g:started_by_firenvim')
  let g:auto_session_enabled = v:false
endif
```

You can also disable the plugin by setting the `auto_session_enabled` option to false at startup:

```sh
nvim --cmd "let g:auto_session_enabled = v:false"
```

## 🚧 Troubleshooting

First run `:checkhealth auto-session` to see if it detects any problems.

If that doesn't help, you can:

- refer to the [wiki page](https://github.com/rmagatti/auto-session/wiki/Troubleshooting).
- check the [Discussions](https://github.com/rmagatti/auto-session/discussions)
- or file an [Issue](https://github.com/rmagatti/auto-session/issues)

## Compatibility

Neovim >= 0.10

For support < 0.10, use tag pre-nvim-0.10

Tested with:

```
v0.10.3 - nightly
```
