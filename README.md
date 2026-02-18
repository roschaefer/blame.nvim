# blame.nvim

`blame.nvim` is a Neovim plugin to interactively explore the `git blame` of the current file similar to Github's [blame button](https://docs.github.com/en/repositories/working-with-files/using-files/viewing-and-understanding-files#viewing-the-line-by-line-revision-history-for-a-file).

## Features

* **Commit History Navigation:** Navigate line-by-line through revisions of a file.

## Installation

Install `blame.nvim` using your favorite plugin manager.

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
3. A popup window will appear, showing the blame information for the current file.

Navigate through the commit history:

* Press `<CR>` on a blame line to view the file content at that commit.
* Press `<BS>` to go back to the previous commit in the history.

## Configuration

You can override the default configuration:

```lua
-- plugins/blame.lua
return {
  {
    "roschaefer/blame.nvim",
    opts = {
      keys = {
        navigate_forward = "<CR>",
        navigate_backward = "<BS>",
      },
    },
    cmd = "Blame",
  },
}

```

## Development

To run the tests, use the following command:

```bash
./scripts/test
```

## Roadmap

* **Blame Previous Version**: Display blame information for the commit prior to the one at the cursor.
* **Retain Cursor Position**: Preserve the cursor's position when navigating through blame history.
* **Commit Summary View**: Introduce a third panel to show a concise summary of the current commit message.
* **Merge Commit Navigation**: Provide an option for users to select which parent to follow when encountering a merge commit.
