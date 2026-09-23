# blame.nvim

`blame.nvim` is a Neovim plugin to interactively explore the `git blame` of the current file similar to Github's [blame button](https://docs.github.com/en/repositories/working-with-files/using-files/viewing-and-understanding-files#viewing-the-line-by-line-revision-history-for-a-file).

## Features

* **Git Blame Integration:** Displays commit hash, author, date, and commit message for each line in a split popup.
* **Window Synchronization:** Keeps the blame window synchronized with the original file's cursor position and scroll view.
* **Commit History Navigation:** Stack-based navigation (`<CR>` to go forward, `<BS>` to go backward) through revisions of a file.
* **Custom Keymaps:** Configurable keybindings for navigation, switching focus, and closing.

## Installation

Install `blame.nvim` using your favorite plugin manager.

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
-- plugins/blame.lua
return {
  {
    "roschaefer/blame.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    cmd = "Blame",
  },
}
```

## Usage

1. Open a file in a Git repository.
2. Run the command `:Blame`.
3. A popup window will appear, showing the blame information for the current file.

Navigate through the commit history:

* Press `<CR>` on a blame line to view the file content at that commit.
* Press `<BS>` to go back to the previous commit in the history.
* Press `<TAB>` to switch focus between the blame window and the file content window.
* Press `<ESC>`, `<C-c>`, or `q` to close the blame view.

## Configuration

You can override the default configuration:

```lua
-- plugins/blame.lua
return {
  {
    "roschaefer/blame.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      keys = {
        navigate_forward = "<CR>",
        navigate_backward = "<BS>",
        switch_focus = "<TAB>",
        close = { "<ESC>", "<C-c>", "q" },
      },
    },
    cmd = "Blame",
  },
}
```

## Development

To start Neovim with `lazy.nvim` and only this plugin activated:

```bash
./scripts/run [file...]
```

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
