-- blame.nvim/lua/blame/init.lua

local M = {}

local BlameView = require("blame.blame_view")
local Git = require("blame.git")
local utils = require("blame.utils")

-- TODO: Fix potential redundancy: The default `opts` from `lazy.lua` are passed to `M.setup` by lazy.vim.
M.defaults = {
	keys = {
		navigate_forward = { "<CR>", "<C-]>" },
		navigate_backward = { "<C-o>", "<C-t>", "<BS>" },
		close = { "q", "<C-c>" },
	},
}

-- Function to set up the plugin with user configuration
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
	vim.api.nvim_create_user_command("Blame", M.show_blame_info, {
		desc = "Show git blame information and file content side by side.",
	})
end

-- Function to show blame info next to the file content in a new tab page
function M.show_blame_info()
	local current_file_buf = vim.api.nvim_get_current_buf()

	local git_instance = Git:new(current_file_buf)
	if not git_instance then
		return
	end

	local blame_view = BlameView:new({
		git_instance = git_instance,
	})
	if not blame_view then
		return
	end

	if not blame_view:mount() then
		return
	end

	-- The cursor rows of both windows are in sync, so every keymap works in both of them
	for _, bufnr in ipairs({ blame_view.blame_bufnr, blame_view.file_bufnr }) do
		utils.add_keymap(bufnr, M.options.keys.navigate_forward, function()
			blame_view:navigate_forward()
		end)
		utils.add_keymap(bufnr, M.options.keys.navigate_backward, function()
			blame_view:navigate_backward()
		end)
		utils.add_keymap(bufnr, M.options.keys.close, function()
			blame_view:close()
		end)
	end
end

return M
