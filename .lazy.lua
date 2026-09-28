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

-- `scripts/run-user-config` starts Neovim in the repository root so lazy.nvim
-- finds this file. Change back right away, before Neovim reads relative paths
-- like `-q {errorfile}`, and only once, so a later spec reload keeps `:cd`.
if vim.env.BLAME_NVIM_CWD then
	vim.fn.chdir(vim.env.BLAME_NVIM_CWD)
	vim.env.BLAME_NVIM_CWD = nil
end

return {
	{
		"roschaefer/blame.nvim",
		dir = root,
		-- lazy.nvim ignores the packspec (`lazy.lua`) of local plugins, so
		-- `setup()`, which creates the `:Blame` command, needs to be triggered here.
		opts = {
			-- Demo of `on_attach`, see "Custom keymaps" in the README
			on_attach = function(view)
				view.keymap.set("n", "yc", function()
					local commit = view:commit()
					if not commit then
						vim.notify("Not committed yet")
						return
					end
					vim.fn.setreg(vim.v.register, commit.hash)
					vim.notify("Yanked " .. commit.hash .. " " .. (commit.summary or ""))
				end, { desc = "Yank the commit of the cursor line" })
				view.keymap.set("n", "gd", function()
					local revision = view:revision()
					if not revision then
						vim.notify("The working tree is shown, not a commit")
						return
					end
					vim.cmd("Gitsigns show_commit " .. revision)
				end, { desc = "Show the diff of the shown version" })
			end,
		},
		-- Installed only if missing from your own configuration
		dependencies = { "lewis6991/gitsigns.nvim" },
		cmd = "Blame",
	},
}
