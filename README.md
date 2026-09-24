# blame.nvim

`blame.nvim` is a Neovim plugin to interactively explore the `git blame` of the current file similar to Github's [blame button](https://docs.github.com/en/repositories/working-with-files/using-files/viewing-and-understanding-files#viewing-the-line-by-line-revision-history-for-a-file).

## Features

* **Git Blame Integration:** Displays the short commit hash, author, and date next to each block of lines from the same commit.
* **Window Synchronization:** Keeps the blame window synchronized with the original file's cursor position and scroll view.
* **Commit History Navigation:** Stack-based navigation (`<CR>` to go forward, `<C-o>` to go backward) through revisions of a file.
* **Custom Keymaps:** Configurable keybindings for navigation and closing.

## Installation

Requires Neovim >= 0.10 and `git`. Install `blame.nvim` using your favorite plugin manager.

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
-- plugins/blame.lua
return {
  {
    "roschaefer/blame.nvim",
    cmd = "Blame",
  },
}
```

## Usage

1. Open a file in a Git repository.
2. Run the command `:Blame`.
3. A new tab page opens with the blame information on the left and the file content on the right. Both windows scroll together.

Navigate through the commit history:

* Press `<CR>` (or `<C-]>`) on any line to view the file as it was before the commit that last changed this line.
* Press `<C-o>` (or `<C-t>`, `<BS>`) to go back to the previous commit in the history.
* Both work in the blame window and in the file content window, similar to following a tag with `<C-]>` and popping the tag stack with `<C-t>`.
* Switch between the blame window and the file content window with the usual window commands, e.g. `<C-w>h` and `<C-w>l`.
* Press `q` or `<C-c>` to close the blame view. Closing one of its windows (e.g. `:q`) closes the whole view.

Both buffers are read-only, but you can select and yank text as usual, e.g. `yiw` on a commit hash.

## Configuration

You can override the default configuration:

```lua
-- plugins/blame.lua
return {
  {
    "roschaefer/blame.nvim",
    opts = {
      keys = {
        navigate_forward = { "<CR>", "<C-]>" },
        navigate_backward = { "<C-o>", "<C-t>", "<BS>" },
        close = { "q", "<C-c>" },
      },
    },
    cmd = "Blame",
  },
}
```

### Blame window

The blame window has the filetype `blame`. You can customize it in `after/ftplugin/blame.lua`, the same way as any other filetype:

```lua
-- after/ftplugin/blame.lua
vim.opt_local.number = true
vim.opt_local.cursorline = false
```

The view always sets these options in both windows, because it needs them to keep the lines of both windows aligned: `scrollbind`, `cursorbind`, `nowrap`, `nofoldenable`, `nodiff` and `winfixbuf`.

The file content window has no filetype. It is highlighted with tree-sitter, or with regex syntax highlighting if no parser is installed. Your ftplugins, LSP clients and other filetype plugins do not run there.

## Development

To start Neovim with `lazy.nvim` and only this plugin activated:

```bash
./scripts/run [file...]
```

To start your own Neovim configuration with this working copy of the plugin
(requires `lazy.nvim`, your `~/.config/nvim` stays untouched):

```bash
./scripts/run-user-config [file...]
```

This works through the project-local [`.lazy.lua`](.lazy.lua) spec, which
lazy.nvim merges into your configuration whenever Neovim starts inside this
repository. The first time, Neovim asks you to trust `.lazy.lua`: choose
`(v)iew` and run `:trust`.

To run the unit tests:

```bash
./scripts/test
```

To run diagnostics:

```bash
./scripts/llscheck
```

Code formatting is managed using [stylua](https://github.com/JohnnyMorganz/StyLua).
To format the code, or to check the formatting the same way CI does:

```bash
stylua lua
stylua --check lua
```
