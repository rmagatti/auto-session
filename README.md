# Description
Auto Session takes advantage of Neovim's existing session management capabilities to provide seamless automatic session management.

# Installation
Any plugin manager should do, I use https://github.com/junegunn/vim-plug

`Plug 'ronniemagatti/auto-session'`

# Configuration

### Default
Auto Session by default uses the directory `~/.config/nvim/sessions/` to store sessions.

### Custom
Use `let g:auto_session_root_dir = path/to/my/custom/dir` to set a custom directory for sessions.

:warning: WARNING :warning: the directory must already exist or the plugin will not load and exit with an error.

# Commands
Auto Session exposes two commands that can be used or mapped to any keybindings for manually saving and restoring sessions.
```vimscript
:SaveSession " saves or creates a session in the currently set `auto_session_root_dir`.
:RestoreSession " restores a previously saved session based on the `cwd`.
```

Note: the plugin uses these same functions internally for the automatic behaviour wrapping it with only a few extra checks for consistency.
