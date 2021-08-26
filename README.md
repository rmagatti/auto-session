# Description
Auto Session takes advantage of Neovim's existing session management capabilities to provide seamless automatic session management.

<img src="https://github.com/rmagatti/readme-assets/blob/main/auto-session-zoomed.gif" width="1000" />

# Behaviour
1. When starting `nvim` with no arguments, auto-session will try to restore an existing session for the current `cwd` if one exists.
2. When starting `nvim .` with some argument, auto-session will do nothing.
3. Even after starting `nvim` with an argument, a session can still be manually restored by running `:RestoreSession`.
4. Any session saving and restoration takes into consideration the current working directory `cwd`.
5. When piping to `nvim`, e.g: `cat myfile | nvim`, auto-session behaves like #2.

:warning: Please note that if there are errors in your config, restoring the session might fail, if that happens, auto session will then disable auto saving for the current session.
Manually saving a session can still be done by calling `:SaveSession`.

# Installation
Any plugin manager should do, I use [Plug](https://github.com/junegunn/vim-plug).

`Plug 'rmagatti/auto-session'`

# Configuration

### Default
Auto Session by default stores sessions in `vim.fn.stdpath('config').."/sessions/"`.  

### Custom
One can set the auto\_session root dir that will be used for auto session saving and restoring.
```viml
let g:auto_session_root_dir = path/to/my/custom/dir

" or use lua
lua << EOF
local opts = {
  log_level = 'info',
  auto_session_enable_last_session = false,
  auto_session_root_dir = vim.fn.stdpath('data').."/sessions/",
  auto_session_enabled = true,
  auto_save_enabled = nil,
  auto_restore_enabled = nil,
  auto_session_suppress_dirs = nil
}

require('auto-session').setup(opts)
EOF
```
### Options
| Config                            | Options                   | Default                               | Description                                                     |
| --------------------------------- | ------------------------- | ------------------------------------- | ----------------------------------------------------------------|
| log_level                         | 'debug', 'info', 'error'  | 'info'                                | Sets the log level of the plugin                                |
| auto_session_enable_last_session  | false, true               | false                                 | Loads the last loaded session if session for cwd does not exist |
| auto_session_root_dir             | "/some/path/you/want"     | vim.fn.stdpath('data').."/sessions/"  | Changes the root dir for sessions                               |
| auto_session_enabled              | false, true               | true                                  | Enables/disables the plugin's auto save _and_ restore features  |
| auto_save_enabled                 | false, true, nil          | nil                                   | Enables/disables auto saving                                    |
| auto_restore_enabled              | false, true, nil          | nil                                   | Enables/disables auto restoring                                 |
| auto_session_suppress_dirs        | ["list", "of paths"]      | nil                                   | Suppress session create/restore if in one of the list of dirs   |
| auto_session_allowed_dirs         | ["list", "of paths"]      | nil                                   | Allow session create/restore if in one of the list of dirs      |

#### Recommended sessionoptions config
For a better experience with the plugin overall using this config for `sessionoptions` is recommended.

**Lua**
```lua
vim.o.sessionoptions="blank,buffers,curdir,folds,help,options,tabpages,winsize,resize,winpos,terminal"
```

**VimL**
```viml
set sessionoptions+=options,resize,winpos,terminal
```

### Last Session
This optional feature enables the keeping track and loading of the last session.
This loading of a last session happens only when a `RestoreSession` could not find a session for the current dir.
This feature can come in handy when starting Neovim from a GUI for example.
:warning: This feature is still experimental and as of right now it interferes with the plugin's ability to auto create new sessions when opening Neovim in a new directory.
```lua
require('auto-session').setup {
    auto_session_enable_last_session=true,
}
```

:warning: WARNING :warning: If the directory does not exist, default directory will be used and an error message will be printed.

# Commands
Auto Session exposes two commands that can be used or mapped to any keybindings for manually saving and restoring sessions.
```viml
:SaveSession " saves or creates a session in the currently set `auto_session_root_dir`.
:SaveSession ~/my/custom/path " saves or creates a session in the specified directory path.
:RestoreSession " restores a previously saved session based on the `cwd`.
:RestoreSession ~/my/custom/path " restores a previously saved session based on the provided path.
:DeleteSession " deletes a session in the currently set `auto_session_root_dir`.
:DeleteSession ~/my/custom/path " deleetes a session based on the provided path.
```

## Command Hooks
#### Command hooks are a list of commands that get executed at different stages of the session management lifecycle.

Command hooks exist in the format: {hook\_name}
- {pre\_save}: executes _before_ a session is saved
- {post\_save}: executes _after_ a session is saved
- {pre\_restore}: executs _before_ a session is restored
- {post\_restore}: executs _after_ a session is restored
- {pre\_delete}: executs _before_ a session is deleted
- {post\_delete}: executs _after_ a session is deleted

Hooks are configured by setting
```viml
let g:auto_session_{hook_name}_cmds = ["{hook_command1}", "{hook_command2}"]

" or use lua
lua << EOF
require('auto-session').setup {
    {hook_name}_cmds = {"{hook_command1}", "{hook_command2}"}
}
EOF
```
`hook_command` is a valid command mode command.
e.g. to close NERDTree before saving the session.
```viml
let g:auto_session_pre_save_cmds = ["tabdo NERDTreeClose"]
```
## Session Lens
[Session Lens](https://github.com/rmagatti/session-lens) is a companion plugin to auto-session built on top of [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for easy switching between existing sessions.

See installation and usage instructions in the plugin's page.

### Preview
<img src="https://github.com/rmagatti/readme-assets/blob/main/session-lens.gif" width=1000 />

# Compatibility
Neovim > 0.5

Tested with:
```
NVIM v0.5.0-dev+a1ec36f
Build type: Release
LuaJIT 2.1.0-beta3
```
