-- lua/blame/windows.lua
-- This module will contain window-related utility functions.

local M = {}

--- Synchronizes the cursor position and scroll view between two Neovim windows.
--- @param original_win number The handle of the original window.
--- @param win number The handle of the blame window.
function M.initialize_cursor_position(original_win, win)
	local original_cursor_line = vim.api.nvim_win_get_cursor(original_win)[1]
	local blame_buf = vim.api.nvim_win_get_buf(win)
	local blame_line_count = vim.api.nvim_buf_line_count(blame_buf)

	if original_cursor_line > blame_line_count then
		original_cursor_line = blame_line_count
	end

	vim.api.nvim_win_set_cursor(win, { original_cursor_line, 0 })

	-- Synchronize the view from the original window
	local original_top_line = vim.api.nvim_win_call(original_win, function()
		return vim.fn.line("w0")
	end)
	vim.api.nvim_win_call(win, function()
		vim.fn.winrestview({ topline = original_top_line })
	end)

	vim.api.nvim_set_option_value("scrollbind", true, { scope = "local", win = win })
	vim.api.nvim_set_option_value("cursorbind", true, { scope = "local", win = win })
end

--- Sets the cursor position in a window to a specific line.
--- @param win number The handle of the window.
--- @param line_num number The line number to set the cursor to.
function M.set_cursor_to_line(win, line_num)
	if not win or not vim.api.nvim_win_is_valid(win) then
		return
	end
	local buf = vim.api.nvim_win_get_buf(win)
	local line_count = vim.api.nvim_buf_line_count(buf)
	if line_num > line_count then
		line_num = line_count
	end
	if line_num < 1 then
		line_num = 1
	end
	vim.api.nvim_win_set_cursor(win, { line_num, 0 })
end

--- Adds a keymap for one or many keys to a popup.
--- @param popup table The nui.popup instance.
--- @param keys string|table The key or list of keys to map.
--- @param handler function The function to execute.
function M.add_keymap(popup, keys, handler)
	local key_list = type(keys) == "table" and keys or { keys }
	for _, key in ipairs(key_list) do
		popup:map("n", key, handler, {
			noremap = true,
			silent = true,
		})
	end
end

return M
