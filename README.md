# :floppy_disk: Auto Session

Auto Session takes advantage of Neovim’s existing session management
capabilities to provide seamless automatic session management.

![zoomgif](https://github.com/rmagatti/readme-assets/blob/main/auto-session-zoomed.gif)

## :bulb: How it works?

1.  When starting `nvim` with no arguments, auto-session will try to
    restore an existing session for the current `cwd` if one exists.
2.  When starting `nvim .` with some argument, auto-session will do
    nothing.
3.  Even after starting `nvim` with an argument, a session can still be
    manually restored by running `:RestoreSession`.
4.  Any session saving and restoration takes into consideration the
    current working directory `cwd`.
5.  When piping to `nvim`, e.g: `cat myfile | nvim`, auto-session
    behaves like #2.

:warning: Please note that if there are errors in your config, restoring
the session might fail, if that happens, auto session will then disable
auto saving for the current session. Manually saving a session can still
be done by calling `:SaveSession`.

## Table of Contents

<!--ts-->

- [Installation](#package-installation)
  - [Plug](#plug)
  - [Packer](#packer)
- [Configuration](#gear-configuration)
  - [Default Settings](#default-settings)
  - [Description](#description)
- [Usage](#electric_plug-usage)
  - [Commands](#loudspeaker-commands)
  - [Command Hooks](#-command-hooks)
    - [Hooks available](#hooks-available)
    - [Setting up hooks](#setting-up-hooks)
    - [Examples](#examples)
      - [Closing file managers before saving a
        session](#closing-file-managers-before-saving-a-session)
      - [Usage of lua functions](#usage-of-lua-functions)
  - [Last Session (Experimental)](#computer-last-session-experimental)
- [Recommendations](#page_with_curl-recommendations)
  - [Vim Settings](#heavy_check_mark-vim-settings)
  - [Lazy Loading](#loop-lazy-loading)
  - [Silent Mode](#mute-silent-mode)
  - [Session Lens](#-session-lens)
- [Compatibility](#link-compatibility)

<!--te-->

## :package: Installation

Any plugin manager should be able to install it. For example:

### [Plug](https://github.com/junegunn/vim-plug)

``` vim
Plug "rmagatti/auto-session"
```

### [Packer](https://github.com/wbthomason/packer.nvim)

``` lua
use("rmagatti/auto-session")
```

## :gear: Configuration

### Default Settings

``` lua
require('auto-session').setup({
  log_level = 'info', -- debug | info | error
  root_dir = vim.fn.stdpath('data').."/sessions/",
  auto_session = true,
  auto_restore = false,
  auto_save = false,
  last_session = false, -- experimental
  suppress_dirs = false,
  silent_mode = false,
  allowed_dirs = {}
})
```

<details>
<summary>
Vim script version
</summary>

``` vim
let g:auto_session_log_level = 'info', " debug | info | error
let g:auto_session_root_dir = stdpath('data') + "/sessions/",
let g:auto_session_auto_session = 1,
let g:auto_session_auto_restore = 0,
let g:auto_session_auto_save = 0,
let g:auto_session_last_session = 0, " experimental
let g:auto_session_suppress_dirs = 0,
let g:auto_session_silent_mode = 0
let g:auto_session_allowed_dirs = []
lua require('auto-session').setup({})
```

</details>

### Description

| Config            | Description                                                     |
|-------------------|-----------------------------------------------------------------|
| **log_level**     | Set the log level of the plugin.                                |
| **root_dir**      | Change the root dir for sessions.                               |
| **auto_session**  | Enable the plugin’s auto save *and* restore features.           |
| **auto_restore**  | Enable auto restoring.                                          |
| **auto_save**     | Enable auto saving.                                             |
| **last_session**  | Load the last loaded session if session for cwd does not exist. |
| **suppress_dirs** | Suppress session create/restore if in one of the list of dirs.  |
| **allowed_dirs**  | Allow session create/restore if in one of the list of dirs.     |

## :electric_plug: Usage

### :loudspeaker: Commands

Auto Session exposes two commands that can be used or mapped to any
keybindings for manually saving and restoring sessions. And one to
delete sessions.

``` vim
:SaveSession " saves or creates a session in the currently set `auto_session_root_dir`.
:SaveSession ~/my/custom/path " saves or creates a session in the specified directory path.
:RestoreSession " restores a previously saved session based on the `cwd`.
:RestoreSession ~/my/custom/path " restores a previously saved session based on the provided path.
:DeleteSession " deletes a session in the currently set `auto_session_root_dir`.
:DeleteSession ~/my/custom/path " deleetes a session based on the provided path.
```

#### 🪝 Command Hooks

**Command hooks are a list of commands that get executed at different
stages of the session management lifecycle.**

#### Hooks available

| hook_name        | Description                               |
|------------------|-------------------------------------------|
| **pre_save**     | Execute **before** a session is saved.    |
| **post_save**    | Execute **after** a session is saved.     |
| **pre_restore**  | Execute **before** a session is restored. |
| **post_restore** | Execute **after** a session is restored.  |
| **pre_delete**   | Execute **before** a session is deleted.  |
| **post_delete**  | Execute **after** a session is deleted.   |

#### Setting up hooks

Hooks are configured by setting:

``` lua
require('auto-session').setup({
    {hook_name}_cmds = {"{hook_command1}", "{hook_command2}"}
})
```

<details>
<summary>
Vim script version
</summary>

``` vim
let g:auto_session_{hook_name}_cmds = ["{hook_command1}", "{hook_command2}"]
lua require('auto-session').setup({})
```

</details>

#### Examples

##### Closing file managers before saving a session

``` lua
require('auto-session').setup({
    pre_save_cmds = {"tabdo NERDTreeClose", "NvimTreeClose"}
})
```

<details>
<summary>
Vim script version
</summary>

``` vim
let g:auto_session_pre_save_cmds = ["tabdo NERDTreeClose", "NvimTreeClose"]
lua require('auto-session').setup({})
```

</details>

##### Usage of lua functions

``` lua
local function custom_hook()
    -- insert hook here
end

require('auto-session').setup {
    post_restore_cmds = {"echo before hook", custom_hook, "echo after hook"}
}
```

### :computer: Last Session (Experimental)

This optional feature enables the keeping track and loading of the last
session. This loading of a last session happens only when a
`RestoreSession` could not find a session for the current dir. This
feature can come in handy when starting Neovim from a GUI for example.

:warning: This feature is still experimental and as of right now it
interferes with the plugin’s ability to auto create new sessions when
opening Neovim in a new directory.

``` lua
require('auto-session').setup {
    last_session=true,
}
```

<details>
<summary>
Vim script version
</summary>

``` vim
let g:auto_session_last_session = 1
lua require('auto-session').setup({})
```

</details>

:warning: If the directory does not exist, default directory will be
used and an error message will be printed.

## :page_with_curl: Recommendations

### :heavy_check_mark: Vim Settings

For a better experience with this plugin overall,
[sessionoptions](https://neovim.io/doc/user/options.html) should be set
to:

``` lua
vim.o.sessionoptions="blank,buffers,curdir,folds,help,options,tabpages,winsize,resize,winpos,terminal"
```

<details>
<summary>
Vim script version
</summary>

``` vim
set sessionoptions+=options,resize,winpos,terminal
```

</details>

### :loop: Lazy Loading

**Note**: if you use
[packer.nvim](https://github.com/wbthomason/packer.nvim)’s lazy loading
feature, you might want to *not* add the `options` value to
`sessionoptions`. It might lead to weird behaviour with the lazy
loading, especially around key-based lazy loading.

### :mute: Silent Mode

These options will make the plugin completly silent.

``` lua
require('auto-session').setup({
  log_level = 'error',
  silent_mode = true,
})
```

<details>
<summary>
Vim script version
</summary>

``` vim
g:auto_session_log_level = 'error',
g:auto_session_silent_mode = 1
lua require('auto-session').setup({})
```

</details>

### 🔭 Session Lens

[Session Lens](https://github.com/rmagatti/session-lens) is a companion
plugin to auto-session built on top of
[Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for
easy switching between existing sessions.

See installation and usage instructions in the plugin’s page.

![prevgif](https://github.com/rmagatti/readme-assets/blob/main/session-lens.gif)

## :link: Compatibility

- Neovim >= 0.5

- Tested with: NVIM v0.5.0-dev+a1ec36f Build type: Release LuaJIT
  2.1.0-beta3
