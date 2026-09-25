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
end

--- Sets the cursor position in a window to a specific line.
--- @param win number The handle of the window.
--- @param line_num number The line number to set the cursor to.
--- @param col number|nil The column, 0 by default. Neovim moves a column beyond the end of the line to its last character.
function M.set_cursor_to_line(win, line_num, col)
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
	vim.api.nvim_win_set_cursor(win, { line_num, col or 0 })
end

--- Creates a read-only scratch buffer that is wiped as soon as it is no longer displayed.
--- @return number bufnr
function M.create_scratch_buffer()
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
	vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
	return bufnr
end

--- Writes lines into a read-only buffer.
--- @param bufnr number
--- @param lines string[]
function M.set_lines(bufnr, lines)
	vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
end

--- Adds a normal mode keymap for one or many keys to a buffer.
--- @param bufnr number The buffer handle.
--- @param keys string|table The key or list of keys to map.
--- @param handler function The function to execute.
function M.add_keymap(bufnr, keys, handler)
	local key_list = type(keys) == "table" and keys or { keys }
	for _, key in ipairs(key_list) do
		vim.keymap.set("n", key, handler, {
			buffer = bufnr,
			silent = true,
		})
	end
end

return M
