-- blame.nvim/lua/blame/init.lua

local M = {}

local BlameView = require("blame.blame_view")
local Git = require("blame.git")
local utils = require("blame.utils")

-- TODO: Fix potential redundancy: The default `opts` from `lazy.lua` are passed to `M.setup` by lazy.vim.
M.defaults = {
	keys = {
		navigate_forward = "<CR>",
		navigate_backward = "<BS>",
		switch_focus = "<TAB>",
		close = { "<ESC>", "<C-c>", "q" },
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
	blame_view:update_view(nil)

	-- Mount the layout
	blame_view:mount()

	-- Keymap for breadcrumb navigation (forward)
	utils.add_keymap(blame_view.blame_popup_instance, M.options.keys.navigate_forward, function()
		blame_view:navigate_forward()
	end)

	-- Keymap for breadcrumb navigation (backward)
	utils.add_keymap(blame_view.blame_popup_instance, M.options.keys.navigate_backward, function()
		blame_view:navigate_backward()
	end)

	-- Keymap for switching focus
	local popups_list = {
		blame_view.blame_popup_instance,
		blame_view.file_popup_instance,
	}
	for _, popup in pairs(popups_list) do
		utils.add_keymap(popup, M.options.keys.switch_focus, function()
			blame_view:switch_focus()
		end)
	end

	-- Keymap for closing the blame view
	for _, popup in pairs(popups_list) do
		utils.add_keymap(popup, M.options.keys.close, function()
			blame_view:close()
		end)
	end
end

return M
