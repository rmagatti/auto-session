# Description
Auto Session takes advantage of Neovim's existing session management capabilities to provide seamless automatic session management.  

<img src="https://github.com/ronniemagatti/readme-assets/blob/main/session-example.gif" width="1000" />

# Behaviour
- When starting `nvim` with no arguments, auto-session will try to restore an existing session for the current `cwd` if one exists.
- When starting `nvim .` with some argument, auto-session will do nothing.
- Even after starting `nvim` with an argument, a session can still be manually restored by running `:RestoreSession`.
- Any session saving and restoration takes into consideration the current working directory `cwd`. One can optionally bypass this behaviour by specifying a directory path when calling the commands `SaveSessionOn` and `RestoreSessionFrom`.


# Installation
Any plugin manager should do, I use (Vim Plug)[https://github.com/junegunn/vim-plug]

`Plug 'rmagatti/auto-session'`

# Configuration

### Default
Auto Session by default uses the directory `~/.config/nvim/sessions/` to store sessions.

### Custom
Use `let g:auto_session_root_dir = path/to/my/custom/dir` to set a custom directory for sessions.

:warning: WARNING :warning: the directory must already exist or the plugin will not load and exit with an error.

# Commands
Auto Session exposes two commands that can be used or mapped to any keybindings for manually saving and restoring sessions.
- `:SaveSession` saves or creates a session in the currently set `auto_session_root_dir`.
- `:SaveSession ~/my/custom/path` saves or creates a session in the specified directory path.
- `:RestoreSession` restores a previously saved session based on the `cwd`.
- `:RestoreSession ~/my/custom/path` restores a previously saved session based on the provided path.

Note: the plugin uses these same functions internally for the automatic behaviour wrapping it with only a few extra checks for consistency.
