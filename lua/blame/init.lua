-- blame.nvim/lua/blame/init.lua

local M = {}
-- Import nui.nvim components
local Popup = require("nui.popup")
local Layout = require("nui.layout")

local utils = require("blame.utils")
local Popups = require("blame.popups")
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
	local current_file_win = vim.api.nvim_get_current_win()
	local current_file_buf = vim.api.nvim_get_current_buf()

	-- Create blame_popup for blame information
	local blame_popup_instance = Popup({
		border = { style = "rounded" },
		focusable = true,
		win_options = {
			winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
			number = false,
			relativenumber = false,
			cursorline = true,
			wrap = false,
			winfixwidth = true,
		},
	})

	-- Create file_popup for file content
	local file_popup_instance = Popup({
		border = {
			style = "rounded",
			text = {
				top = "",
			},
		},
		focusable = true,
		win_options = {
			winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
			number = true,
			relativenumber = true,
			cursorline = true,
			wrap = false,
		},
	})

	local git_instance = Git:new(current_file_buf)
	if not git_instance then
		return
	end

	local popups = Popups:new({
		git_instance = git_instance,
		blame_popup_instance = blame_popup_instance,
		file_popup_instance = file_popup_instance,
	}, current_file_buf)
	if not popups then
		return
	end
	popups:update_buffers(nil)

	-- Define the layout: blame_popup on left, file_popup on right
	local main_layout = Layout(
		{ relative = "editor", position = "50%", size = "90%" }, -- Options for the main layout
		Layout.Box({
			Layout.Box(blame_popup_instance, { size = "25%" }), -- Pass popup directly as component
			Layout.Box(file_popup_instance, { size = "75%" }), -- Pass popup directly as component
		}, { dir = "row" })
	)

	-- Mount the layout
	main_layout:mount()

	-- Set current window to the blame popup for initial blame display
	if blame_popup_instance and blame_popup_instance.winid then
		vim.api.nvim_set_current_win(blame_popup_instance.winid)
	end

	utils.initialize_cursor_position(current_file_win, blame_popup_instance.winid)
	utils.initialize_cursor_position(current_file_win, file_popup_instance.winid)

	-- Keymap for breadcrumb navigation (forward)
	blame_popup_instance:map("n", M.options.keys.navigate_forward, function()
		popups:navigate_forward()
	end, {
		noremap = true,
		silent = true,
	})

	-- Keymap for breadcrumb navigation (backward)
	blame_popup_instance:map("n", M.options.keys.navigate_backward, function()
		popups:navigate_backward()
	end, {
		noremap = true,
		silent = true,
	})

	local popups = {
		blame_popup_instance,
		file_popup_instance,
	}
	for _, popup in pairs(popups) do
		popup:on("BufLeave", function()
			vim.schedule(function()
				local curr_bufnr = vim.api.nvim_get_current_buf()
				for _, p in pairs(popups) do
					if p.bufnr == curr_bufnr then
						return
					end
				end
				main_layout:unmount()
			end)
		end)
	end
end

return M
