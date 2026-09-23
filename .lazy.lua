-- Project-local lazy.nvim spec, see `local_spec` in the lazy.nvim docs.
--
-- When Neovim is started inside this repository, lazy.nvim appends this spec to
-- your own configuration. blame.nvim is then loaded from this working copy
-- instead of the installed version, without touching `~/.config/nvim`.
-- lazy.nvim asks once whether to trust this file (see `:h vim.secure.read()`).
local root = vim.fs.root(vim.uv.cwd(), ".lazy.lua")

-- lazy.nvim drops plugins with a `dir` from the lockfile whenever it rewrites
-- it, so write the lockfile of this session somewhere else.
require("lazy.core.config").options.lockfile = root .. "/.tests/lazy-lock.json"

return {
	{ "MunifTanjim/nui.nvim", lazy = true },
	{
		"roschaefer/blame.nvim",
		dir = root,
		cmd = "Blame",
	},
}
