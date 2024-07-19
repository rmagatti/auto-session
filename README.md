# 🗒️ AutoSession

AutoSession takes advantage of Neovim's existing session management capabilities to provide seamless automatic session management.

<img src="https://github.com/rmagatti/readme-assets/blob/main/auto-session-new-example.gif" width="800" />

[<img alt="GitHub Actions Workflow Status" src="https://img.shields.io/github/actions/workflow/status/rmagatti/auto-session/tests.yml?style=for-the-badge&label=tests">](https://github.com/rmagatti/auto-session/actions/workflows/tests.yml)

# 💡 Behaviour

1. When starting `nvim` with no arguments, AutoSession will try to restore an existing session for the current `cwd` if one exists.
2. When starting `nvim .` (or another directory), AutoSession will try to restore the session for that directory.
3. When starting `nvim some_file.txt` (or multiple files), by default, AutoSession won't do anything. See [argument handling](#argument-handling) for more details.
4. Even after starting `nvim` with a file argument, a session can still be manually restored by running `:SessionRestore`.
5. Any session saving and restoration takes into consideration the current working directory `cwd`.
6. When piping to `nvim`, e.g: `cat myfile | nvim`, AutoSession won't do anything.

:warning: Please note that if there are errors in your config, restoring the session might fail, if that happens, auto session will then disable auto saving for the current session.
Manually saving a session can still be done by calling `:SessionSave`.

AutoSession can now track `cwd` changes!
By default, `cwd` handling is disabled but when enabled, it works as follows:

- DirChangedPre (before the cwd actually changes):
  - Save the current session
  - Clear all buffers `%bd!`. This guarantees buffers don't bleed to the
    next session.
  - Clear jumps. Also done so there is no bleeding between sessions.
  - Run the `pre_cwd_changed_hook`/
- DirChanged (after the cwd has changed):
  - Restore session using new cwd
  - Run the `post_cwd_changed_hook`

Now when the user changes the cwd with `:cd some/new/dir` AutoSession handles it gracefully, saving the current session so there aren't losses and loading the session for the upcoming cwd if it exists.

Hooks are available for custom actions _before_ and _after_ the `cwd` is changed. These hooks can be configured through the `cwd_change_handling` key as follows:

```lua
require("auto-session").setup {
  log_level = "error",

  cwd_change_handling = {
    restore_upcoming_session = true, -- Disabled by default, set to true to enable
    pre_cwd_changed_hook = nil, -- already the default, no need to specify like this, only here as an example
    post_cwd_changed_hook = function() -- example refreshing the lualine status line _after_ the cwd changes
      require("lualine").refresh() -- refresh lualine so the new session name is displayed in the status bar
    end,
  },
}

```

# 📦 Installation

[Lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  {
    'rmagatti/auto-session',
    dependencies = {
      'nvim-telescope/telescope.nvim', -- Only needed if you want to use sesssion lens
    },
    config = function()
      require('auto-session').setup({
        auto_session_suppress_dirs = { '~/', '~/Projects', '~/Downloads', '/' },
      })
    end,
  },
}
```

[Packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'rmagatti/auto-session',
  config = function()
    require("auto-session").setup {
      auto_session_suppress_dirs = { "~/", "~/Projects", "~/Downloads", "/"},
    }
  end
}
```

# ⚙️ Configuration

### Default

AutoSession by default stores sessions in `vim.fn.stdpath('data').."/sessions/"`.

### Custom

One can set the auto_session root dir that will be used for auto session saving and restoring.

```viml
let g:auto_session_root_dir = path/to/my/custom/dir

" or use Lua
lua << EOF
local opts = {
  log_level = 'info',
  auto_session_enable_last_session = false,
  auto_session_root_dir = vim.fn.stdpath('data').."/sessions/",
  auto_session_enabled = true,
  auto_save_enabled = nil,
  auto_restore_enabled = nil,
  auto_session_suppress_dirs = nil,
  auto_session_use_git_branch = nil,
  -- the configs below are lua only
  bypass_session_save_file_types = nil
}

require('auto-session').setup(opts)
EOF
```

### Options

| Config                           | Options                  | Default                              | Description                                                                                                                                          |
| -------------------------------- | ------------------------ | ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| log_level                        | 'debug', 'info', 'error' | 'info'                               | Sets the log level of the plugin                                                                                                                     |
| auto_session_enable_last_session | false, true              | false                                | On startup, loads the last loaded session if session for cwd does not exist                                                                          |
| auto_session_root_dir            | "/some/path/you/want"    | vim.fn.stdpath('data').."/sessions/" | Changes the root dir for sessions                                                                                                                    |
| auto_session_enabled             | false, true              | true                                 | Enables/disables the plugin's auto save _and_ restore features                                                                                       |
| auto_session_create_enabled      | false, true, function    | true                                 | Enables/disables the plugin's session auto creation. Can also be a Lua function that returns true if a session should be created and false otherwise |
| auto_save_enabled                | false, true, nil         | nil                                  | Enables/disables auto saving                                                                                                                         |
| auto_restore_enabled             | false, true, nil         | nil                                  | Enables/disables auto restoring                                                                                                                      |
| auto_restore_lazy_delay_enabled  | false, true, nil         | true                                 | Enables/disables delaying auto-restore if Lazy.nvim is used                                                                                          |
| auto_session_suppress_dirs       | ["list", "of paths"]     | nil                                  | Suppress session create/restore if in one of the list of dirs                                                                                        |
| auto_session_allowed_dirs        | ["list", "of paths"]     | nil                                  | Allow session create/restore if in one of the list of dirs                                                                                           |
| auto_session_use_git_branch      | false, true, nil         | nil                                  | Use the git branch to differentiate the session name                                                                                                 |

#### Notes

`auto_session_suppress_dirs` and `auto_session_allowed_dirs` support base paths with `*` wildcard (e.g.: `/my/base/path/*`)

### Lua Only Options

```lua
require("auto-session").setup {
  bypass_session_save_file_types = nil, -- table: Bypass auto save when only buffer open is one of these file types
  close_unsupported_windows = true, -- boolean: Close windows that aren't backed by normal file
  cwd_change_handling = { -- table: Config for handling the DirChangePre and DirChanged autocmds, can be set to nil to disable altogether
    restore_upcoming_session = false, -- boolean: restore session for upcoming cwd on cwd change
    pre_cwd_changed_hook = nil, -- function: This is called after auto_session code runs for the `DirChangedPre` autocmd
    post_cwd_changed_hook = nil, -- function: This is called after auto_session code runs for the `DirChanged` autocmd
  },
  args_allow_single_directory = true, -- boolean Follow normal sesion save/load logic if launched with a single directory as the only argument
  args_allow_files_auto_save = false, -- boolean|function Allow saving a session even when launched with a file argument (or multiple files/dirs). It does not load any existing session first. While you can just set this to true, you probably want to set it to a function that decides when to save a session when launched with file args. See documentation for more detail
}
```

#### Recommended sessionoptions config

For a better experience with the plugin overall using this config for `sessionoptions` is recommended.

**Lua**

```lua
vim.o.sessionoptions="blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
```

**VimL**

```viml
set sessionoptions+=winpos,terminal,folds
```

:warning: if you use [packer.nvim](https://github.com/wbthomason/packer.nvim)'s lazy loading feature, and you have the `options` value in your `sessionoptions` beware it might lead to weird behaviour with the lazy loading, especially around key-based lazy loading where keymaps are kept and thus the lazy loading mapping packer creates never gets set again.

### Last Session

This optional feature enables the keeping track and loading of the last session.
The last session is only loaded at startup if there isn't already a session for the current working directory.
This feature can come in handy when starting Neovim from a GUI for example.

:warning: If the directory does not exist, default directory will be used and an error message will be printed.  
:warning: This feature is still experimental and as of right now it interferes with the plugin's ability to auto create new sessions when opening Neovim in a new directory.

```lua
require('auto-session').setup {
    auto_session_enable_last_session = true,
}
```

A quick workaround for inability to auto create new sessions is to conditionally enable last session.

```lua
require('auto-session').setup {
    auto_session_enable_last_session = vim.loop.cwd() == vim.loop.os_homedir(),
}
```

Now last session will be restored only when Neovim is launched in the home directory, which is usually right after launching the terminal or Neovim GUI clients.

# 📢 Commands

AutoSession exposes the following commands that can be used or mapped to any keybindings for manually saving and restoring sessions.

```viml
:SessionSave " saves a session based on the `cwd` in `auto_session_root_dir`
:SessionSave my_session " saves a session called `my_session` in `auto_session_root_dir`

:SessionRestore " restores a session based on the `cwd` from `auto_session_root_dir`
:SessionRestore my_session " restores `my_session` from `auto_session_root_dir`

:SessionDelete " deletes a session based on the `cwd` from `auto_session_root_dir`
:SessionDelete my_session " deletes `my_sesion` from `auto_session_root_dir`

:SesssionEnableAutoSave "enables autosave on exit, subject to all of the normal filters in the config
:SesssionEnableAutoSave! "disables autosave on exit
:SesssionToggleAutoSave "toggles autosave

:SessionPurgeOrphaned " removes all orphaned sessions with no working directory left.

:SessionSearch " open a session picker, uses Telescope if installed, vim.ui.select otherwise

:Autosession search " open a vim.ui.select picker to choose a session to load.
:Autosession delete " open a vim.ui.select picker to choose a session to delete.
```

There are also versions of Save/Restore/Delete that take a session directory and an optional session name:

```viml
:SessionSaveToDir /some/dir " saves a session based on the `cwd` to `/some/dir`
:SessionSaveToDir /some/dir my_session " saves `my_session` to `/some/dir`

:SessionRestoreFromDir /some/dir " restores a session based on the `cwd` from `/some/dir`
:SessionRestoreFromDir /some/dir my_session " restores `my_session` from `/some/dir`

:SessionDeleteFromDir /some/dir " deletes a session based on the `cwd` from `/some/dir`
:SessionDeleteFromDir /some/dir my_session " deletes `my_session` from `/some/dir`
```

## 🪝 Command Hooks

#### Command hooks are a list of commands that get executed at different stages of the session management lifecycle.

Command hooks exist in the format: {hook_name}

- `{pre_save}`: executes _before_ a session is saved
- `{save_extra}`: executes _after_ a session is saved, return string will save to `*x.vim`, reference `:help mks`
- `{post_save}`: executes _after_ a session is saved
- `{pre_restore}`: executes _before_ a session is restored
- `{post_restore}`: executes _after_ a session is restored
- `{pre_delete}`: executes _before_ a session is deleted
- `{post_delete}`: executes _after_ a session is deleted
- `{no_restore}`: executes _at_ `VimEnter` _when_ no session is restored

Hooks are configured by setting

```viml
let g:auto_session_{hook_name}_cmds = ["{hook_command1}", "{hook_command2}"]

" or use Lua
lua << EOF
require('auto-session').setup {
    {hook_name}_cmds = {"{hook_command1}", "{hook_command2}"}
    save_extra_cmds = {
        function()
            return [[echo "hello world"]]
        end
    }
}
EOF
```

`hook_command` is a valid command mode command.
e.g. to close NERDTree before saving the session.

```viml
let g:auto_session_pre_save_cmds = ["tabdo NERDTreeClose"]
```

Hooks can also be lua functions
For example to update the directory of the session in nvim-tree:

```lua
local function restore_nvim_tree()
    local nvim_tree = require('nvim-tree')
    nvim_tree.change_dir(vim.fn.getcwd())
    nvim_tree.refresh()
end

require('auto-session').setup {
    {hook_name}_cmds = {"{vim_cmd_1}", restore_nvim_tree, "{vim_cmd_2}"}
}
```

## Conditionally creating a session

`auto_session_create_enabled` can take a function that returns if a session should be created or not as part of auto saving. As one example, you could
use this to only create sessions for git projects:

```lua

  config = function()
    require('auto-session').setup({
      auto_save_enabled = true,
      auto_restore_enabled = true,

      auto_session_create_enabled = function()
        local cmd = 'git rev-parse --is-inside-work-tree'
        return vim.fn.system(cmd) == 'true\n'
      end,
    })
  end

```

## Argument Handling

By default, when `nvim` is run with a single directory argument, AutoSession will try to restore the session for that directory. If `nvim` is run with multiple directories or any file arguments, AutoSession won't try to restore a session and won't auto-save a session on exit (if enabled). Those behaviors can be changed with these config parameters:

```lua
  args_allow_single_directory = true, -- boolean Follow normal sesion save/load logic if launched with a single directory as the only argument
  args_allow_files_auto_save = false, -- boolean|function Allow saving a session even when launched with a file argument (or multiple files/dirs). It does not load any existing session first. While you can just set this to true, you probably want to set it to a function that decides when to save a session when launched with file args. See documentation for more detail
```

For `args_allow_single_directory`, if you frequently use `netrw` to look at directories, you might want to add it to `bypass_session_save_file_types` if you don't want to create a session for each directory you look at:

```lua
      bypass_session_save_file_types = { 'netrw' }
```

If `args_allow_files_auto_save` is true, AutoSession won't load any session when `nvim` is launched with file argument(s) but it will save on exit. What's probably more useful is to set `args_allow_files_auto_save` to a function that returns true if a session should be saved and false otherwise. AutoSession will call that function on auto save when run with arguments. Here's one example config where it will save the session if at least two buffers are open after being launched with arguments:

```lua
return {
  'rmagatti/auto-session',
  config = function()
    require('auto-session').setup({
      auto_restore_enabled = true,
      auto_save_enabled = true,

      args_allow_files_auto_save = function()
        local supported = 0

        local buffers = vim.api.nvim_list_bufs()
        for _, buf in ipairs(buffers) do
          -- Check if the buffer is valid and loaded
          if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
            local path = vim.api.nvim_buf_get_name(buf)
            if vim.fn.filereadable(path) ~= 0 then supported = supported + 1 end
          end
        end

        -- If we have more 2 or more supported buffers, save the session
        return supported >= 2
      end,
    })
  end,
}

```

Another possibility is to only save the session if there are at least two windows with buffers backed by normal files:

```lua
      args_allow_files_auto_save = function()
        local supported = 0

        local tabpages = vim.api.nvim_list_tabpages()
        for _, tabpage in ipairs(tabpages) do
          local windows = vim.api.nvim_tabpage_list_wins(tabpage)
          for _, window in ipairs(windows) do
            local buffer = vim.api.nvim_win_get_buf(window)
            local file_name = vim.api.nvim_buf_get_name(buffer)
            if vim.fn.filereadable(file_name) ~= 0 then supported = supported + 1 end
          end
        end

        -- If we have 2 or more windows with supported buffers, save the session
        return supported >= 2
      end,

```

## Disabling the plugin

One might run into issues with Firenvim or another plugin and want to disable `auto_session` altogether based on some condition.
For this example, as to not try and save sessions for Firenvim, we disable the plugin if the `started_by_firenvim` variable is set.

```viml
if exists('g:started_by_firenvim')
  let g:auto_session_enabled = v:false
endif
```

One can also disable the plugin by setting the `auto_session_enabled` option to false at startup.

```sh
nvim "+let g:auto_session_enabled = v:false"
```

## 🚧 Troubleshooting

For troubleshooting refer to the [wiki page](https://github.com/rmagatti/auto-session/wiki/Troubleshooting).

## 🔭 Session Lens

Session Lens has been merged into AutoSession so now you can see, load, and delete your sessions using Telescope! It's enabled by
default if you have Telescope, but here's the Lazy config that shows the configuration options:

```lua

return {
  {
    'rmagatti/auto-session',
    dependencies = {
      'nvim-telescope/telescope.nvim',
    },
    config = function()
      require('auto-session').setup({
        log_level = 'error',
        auto_session_suppress_dirs = { '~/', '~/Projects', '~/Downloads', '/' },

        -- ⚠️ This will only work if Telescope.nvim is installed
        -- The following are already the default values, no need to provide them if these are already the settings you want.
        session_lens = {
          -- If load_on_setup is set to false, one needs to eventually call `require("auto-session").setup_session_lens()` if they want to use session-lens.
          load_on_setup = true,
          theme_conf = { border = true },
          previewer = false,
          buftypes_to_ignore = {}, -- list of buffer types that should not be deleted from current session when a new one is loaded
        },
      })
    end,
  },
}

-- Set mapping for searching a session.
-- ⚠️ This will only work if Telescope.nvim is installed
vim.keymap.set("n", "<C-s>", require("auto-session.session-lens").search_session, {
  noremap = true,
})
```

You can also use `:Telescope session-lens` to launch the session picker.

The following shortcuts are available when the session-lens picker is open

- `<c-s>` restores the previously opened session. This can give you a nice flow if you're constantly switching between two projects.
- `<c-d>` will delete the currently highlighted session. This makes it easy to keep the session list clean.

NOTE: If you previously installed `rmagatti/session-lens`, you should remove it from your config as it is no longer necessary.

AutoSession provides its own `:Autosession search` and `:Autosession delete` commands, but session-lens is a more complete version of those commands that is specifically built to be used with `telescope.nvim`. These commands make use of `vim.ui.select` which can itself be implemented by other plugins other than telescope.

### Preview

<img src="https://github.com/rmagatti/readme-assets/blob/main/session-lens.gif" width=800 />

### Statusline

One can show the current session name in the statusline by using an AutoSession helper function.

Lualine example config and how it looks

```lua
require('lualine').setup{
  options = {
    theme = 'tokyonight',
  },
  sections = {lualine_c = {require('auto-session.lib').current_session_name}}
}
```

<img width="1904" alt="Screen Shot 2021-10-30 at 3 58 57 PM" src="https://user-images.githubusercontent.com/2881382/139559478-8edefdb8-8254-42e7-a0f3-babd3dfd6ff2.png">

# Compatibility

Neovim > 0.7

Tested with:

```
NVIM v0.7.0 - NVIM 0.10.0
```
