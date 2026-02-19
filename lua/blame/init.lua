-- blame.nvim/lua/blame/init.lua

local M = {}

local BlameView = require("blame.blame_view")
local Git = require("blame.git")

-- TODO: Fix potential redundancy: The default `opts` from `lazy.lua` are passed to `M.setup` by lazy.vim.
M.defaults = {
	keys = {
		navigate_forward = "<CR>",
		navigate_backward = "<BS>",
	},
}

-- Function to set up the plugin with user configuration
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
	vim.api.nvim_create_user_command("Blame", M.show_blame_info, {
		desc = "Show git blame information and file content in a popup.",
	})
end

-- Function to show blame info in a nui.popup
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
	blame_view:update_buffers(nil)

	-- Mount the layout
	blame_view:mount()

	-- Keymap for breadcrumb navigation (forward)
	blame_view.blame_popup_instance:map("n", M.options.keys.navigate_forward, function()
		blame_view:navigate_forward()
	end, {
		noremap = true,
		silent = true,
	})

	-- Keymap for breadcrumb navigation (backward)
	blame_view.blame_popup_instance:map("n", M.options.keys.navigate_backward, function()
		blame_view:navigate_backward()
	end, {
		noremap = true,
		silent = true,
	})
end

return M
