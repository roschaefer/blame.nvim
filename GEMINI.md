# GEMINI.md

## Project Overview

`blame.nvim` is a Neovim plugin written in Lua that aims to enhance code review and understanding by displaying Git blame information and file content in a popup window with a split layout. Key features include:

*   **Git Blame Integration:** Parses `git blame` output to show commit, author, and date for each line.
*   **Window Synchronization:** Keeps the blame window synchronized with the original file's cursor position and scroll view.
*   **Commit History Navigation (Breadcrumb):** Provides a stack-based navigation system (`<CR>` to go forward, `<BS>` to go backward) through different commit versions of a file. It prevents adding duplicate commits or the special "00000000" (uncommitted changes) revision to the history stack.
*   **Custom Keymaps:** Integrates intuitive keybindings for interaction.
*   **User Command:** Exposes a user-friendly `:Blame` command to activate the plugin.

## Building and Running

As a Neovim plugin, `blame.nvim` does not have a traditional build process. It is typically installed using a Neovim plugin manager.

**Installation (using `lazy.nvim` as an example):**

Add the following to your Neovim configuration (e.g., `init.lua`):

```lua
-- init.lua
{
  'owner/blame.nvim', -- Replace with actual repository owner/name
  dependencies = { 'MunifTanjim/nui.nvim' }, -- Add nui.nvim as a dependency
  config = function()
    require('blame').setup()
  end
},
```

Then, run `:Lazy install` in Neovim to install the plugin.

**Usage:**

1.  Open a file within a Git repository in Neovim.
2.  Execute the user command: `:Blame`
3.  A new vertical split will open displaying the Git blame information.
4.  Navigate through commit history:
    *   Press `<CR>` (Carriage Return) on a blame line to view the file content at that commit.
    *   Press `<BS>` (Backspace) to go back to the previous commit in the history.

## Development Conventions

*   **Language:** The plugin is entirely written in Lua.
*   **Neovim API Usage:** Extensively utilizes `vim.api` for core Neovim interactions (e.g., buffer and window manipulation, keymap settings) and `vim.system` for asynchronous execution of Git commands.
*   **Module Structure:** Code is organized into modules under the `lua/blame/` directory.
*   **Formatting:** All Lua files are formatted using `stylua`.
*   **Diagnostics:** Lua Language Server diagnostics are checked using `scripts/llscheck` (based on [llscheck](https://github.com/jeffzi/llscheck)). All code must be free of diagnostic errors.
*   **UI Library:** Utilizes `nui.nvim` for creating interactive popups and managing layouts.
*   **Object-Oriented Style:** Components like the breadcrumb navigation employ an object-oriented approach in Lua, using metatables (`__index`) for method dispatch on instances.
*   **Dependency Injection:** To make dependency injection in the constructor more obvious, if a class has dependencies (e.g. to-be-mocked modules), they should be passed as the first argument to the constructor (e.g. `new`) and named `dependencies`. It is always a table which can contain the to-be-mocked modules. If there are no such dependencies, do not add a `dependencies` parameter. If a module needs to be mocked in a test, it is a strong signal to refactor the code to use this dependency injection pattern.
*   **Testing Framework:** Unit tests are written using `luassert` and are located in `tests/lua/`.
*   **Development Environment:** The presence of `.luarc.json` suggests configuration for Lua language servers (e.g., sumneko/lua-language-server) to provide features like auto-completion, diagnostics, and workspace-wide library definitions for an improved development experience.
*   **Git Integration:** Relies on standard Git commands (`git blame`, `git show`) for its core functionality.

## Testing

Unit tests are written using `luassert` and are located in `tests/`.
**Test File Convention**: Every Lua file under `lua/` must have a corresponding test file in `tests/`. The path in `tests/` must mirror the path in `lua/`, and the filename must end in `_spec.lua`. For example, `lua/blame/init.lua` should have a corresponding test file at `tests/blame/init_spec.lua`.
**Assertion Style**: Assertion values should be hard-coded for readability and safety (avoiding variables that might change unexpectedly).
**Mocks, Stubs, and Spies**: Prefer using stubs, mocks, and spies from `luassert` (e.g., `stub(table, "key")`) instead of manual function overrides. Use snapshots to revert stubs and spies in `before_each` and `after_each` blocks to ensure test isolation.
```lua
describe("module", function()
  local snapshot
  before_each(function()
    snapshot = assert:snapshot()
  end)
  after_each(function()
    snapshot:revert()
  end)
  it("tests something", function()
    stub(vim, "notify")
    -- ...
    assert.stub(vim.notify).was.called()
  end)
end)
```
**Test Description Style**: Test descriptions (for `describe` and `it` blocks) use simple present, affirmative explanations without the word "should". For example, "It synchronizes windows" instead of "It should synchronize windows".
They can be run headless using Neovim:

```bash
./scripts/test
```

### Diagnostics

Before submitting changes, ensure all Lua files pass diagnostics:

```bash
./scripts/test
./scripts/llscheck
```

## Key Files

*   `lua/blame/init.lua`: The main entry point of the plugin, responsible for setting up the blame view, handling user commands, and orchestrating interactions between different components.
*   `lua/blame/git.lua`: Contains utility functions for interacting with Git (blame, show, find root).
*   `lua/blame/blame_view.lua`: Manages the creation and updates of the UI (blame and file content).
*   `lua/blame/parser.lua`: Responsible for parsing the `git blame --line-porcelain` output.
*   `lua/blame/breadcrumb.lua`: Implements the stack-based commit history navigation logic.
*   `lua/blame/utils.lua`: Provides helper functions for window and cursor synchronization.
*   `tests/lua/`: Directory containing unit tests for all modules (e.g., `breadcrumb_spec.lua`, `git_spec.lua`).
*   `.luarc.json`: Configuration file for Lua language server.
