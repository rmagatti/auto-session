# Description
Auto Session takes advantage of Neovim's existing session management capabilities to provide seamless automatic session management.  

<img src="https://github.com/rmagatti/readme-assets/blob/main/auto-session-zoomed.gif" width="1000" />

# Behaviour
- When starting `nvim` with no arguments, auto-session will try to restore an existing session for the current `cwd` if one exists.
- When starting `nvim .` with some argument, auto-session will do nothing.
- Even after starting `nvim` with an argument, a session can still be manually restored by running `:RestoreSession`.
- Any session saving and restoration takes into consideration the current working directory `cwd`.


# Installation
Any plugin manager should do, I use [Plug](https://github.com/junegunn/vim-plug).

`Plug 'rmagatti/auto-session'`

# Configuration

### Default
Auto Session by default uses the directory `~/.config/nvim/sessions/` to store sessions.

### Custom
One can set the auto\_session root dir that will be used for auto session saving and restoring.
```viml
let g:auto_session_root_dir = path/to/my/custom/dir
```
:warning: WARNING :warning: the directory must already exist or the plugin will not load and exit with an error.

# Commands
Auto Session exposes two commands that can be used or mapped to any keybindings for manually saving and restoring sessions.
- `:SaveSession` saves or creates a session in the currently set `auto_session_root_dir`.
- `:SaveSession ~/my/custom/path` saves or creates a session in the specified directory path.
- `:RestoreSession` restores a previously saved session based on the `cwd`.
- `:RestoreSession ~/my/custom/path` restores a previously saved session based on the provided path.

## Command Hooks
#### Command hooks are a list of commands that get executed at different stages of the session management lifecycle.

There are 4 command hooks {hook\_name}
- {pre\_save}: executes _before_ a session is saved
- {post\_save}: executes _after_ a session is saved
- {pre\_restore}: executs _before_ a session is restored
- {post\_restore}: executs _after_ a session is restored

Hooks are configured by setting
```viml
let g:auto_session_{hook_name}_cmds = ["{hook_command1}", "{hook_command2}"]
```
`hook_command` is a valid command mode command.
e.g. to close NERDTree before saving the session.
```viml
let g:auto_session_pre_save_cmds = ["tabdo NERDTreeClose"]
```

