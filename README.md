# blame.nvim

`blame.nvim` is a Neovim plugin to interactively explore the `git blame` of the current file similar to Github's [blame button](https://docs.github.com/en/repositories/working-with-files/using-files/viewing-and-understanding-files#viewing-the-line-by-line-revision-history-for-a-file).

## Features

* **Git Blame Integration:** Displays the date (relative to today), author and commit subject next to each block of lines from the same commit, like GitHub's blame view.
* **Commit Grouping:** A bar in the sign column of the file content window marks all lines of the commit under the cursor, to show which lines belong together.
* **Commit Age:** A coloured stripe in the blame window shows the age of each commit relative to the other commits of the file, faint for older and strong for newer, like GitHub's blame view. A legend in the title of the blame window explains the colours, if there is room for it (Neovim 0.12 or newer).
* **Window Synchronization:** Keeps the blame window synchronized with the original file's cursor position and scroll view.
* **Commit Message Panel:** Shows the full commit message of the cursor line on demand (`K`), to answer why a line is there.
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
* Press `K` to open or close a panel at the bottom with the full commit message, author and date of the cursor line. It follows the cursor while it is open. Pressing `K` inside the panel closes it and returns to the window you came from, `q` closes the whole view. `:q` inside the panel closes only the panel.
* Press `q` or `<C-c>` to close the blame view. Closing the blame or the file content window (e.g. `:q`) closes the whole view.
* Opening another file in one of the windows of the view, e.g. from a file explorer, closes the rest of the view. The file stays open in that window.

Both buffers are read-only, but you can select and yank text as usual, e.g. the commit hash in the commit message panel (`K`).

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
        toggle_commit_message = "K",
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

Buffer-local keymaps defined there take precedence over the keymaps of `blame.nvim`.

The age stripe is drawn in the sign column of the blame window. Its colours are blended from the background of the sign column towards `GitBlameAge` (linked to `DiagnosticWarn`), so they follow your colour scheme; this needs `termguicolors`, otherwise all commits get the colour of `GitBlameAge`.

The bar next to the lines of the commit under the cursor is drawn in the sign column of the file content window and highlighted with `GitBlameCursorCommit` (linked to `Special`).

The columns of the blame window are highlighted with `GitBlameDate` (linked to `Normal`), `GitBlameAuthor` (linked to `Comment`) and `GitBlameSubject` (linked to `Normal`).

The view always sets these options in both windows, because it needs them to keep the lines of both windows aligned: `scrollbind`, `cursorbind`, `nowrap`, `nofoldenable` and `nodiff`.

The commit message panel has the filetype `git`.

The file content window has no filetype. It is highlighted with tree-sitter, or with regex syntax highlighting if no parser is installed. Your ftplugins, LSP clients and other filetype plugins do not run there.

## Development

The development tools (Neovim, git, stylua, lua-language-server and llscheck) are provided by a [Nix](https://nixos.org) dev shell:

```bash
nix develop
```

`nix develop` starts bash. To keep your shell, run e.g. `nix develop --command fish`, or use [direnv](https://direnv.net) with `use flake`.
The scripts below work the same with tools installed in any other way, as long as they are on your `PATH`.

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
