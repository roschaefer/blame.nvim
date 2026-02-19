-- tests/lua/windows_spec.lua

local assert = require("luassert")
local utils = require("blame.utils")

describe("blame.utils: integrates with real Neovim windows", function()
	local original_win_id
	local blame_win_id
	local original_buf_id
	local blame_buf_id

	-- Store original window/buffer before tests
	local old_current_win
	local old_current_buf

	before_each(function()
		old_current_win = vim.api.nvim_get_current_win()
		old_current_buf = vim.api.nvim_get_current_buf()

		-- Create a temporary buffer for the original window
		original_buf_id = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(original_buf_id, 0, -1, false, {
			"line 1",
			"line 2",
			"line 3",
			"line 4",
			"line 5",
			"line 6",
			"line 7",
			"line 8",
			"line 9",
			"line 10",
			"line 11",
			"line 12",
			"line 13",
			"line 14",
			"line 15",
		})

		-- Open a new window for the original buffer
		vim.cmd("vsplit")
		original_win_id = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(original_win_id, original_buf_id)
		vim.api.nvim_set_current_win(original_win_id)

		-- Create a temporary buffer for the blame window
		blame_buf_id = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(blame_buf_id, 0, -1, false, {
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
		}) -- 15 empty lines

		-- Open another new window for the blame buffer
		vim.cmd("vsplit")
		blame_win_id = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(blame_win_id, blame_buf_id)
	end)

	after_each(function()
		-- Close the created windows
		if vim.api.nvim_win_is_valid(original_win_id) then
			vim.api.nvim_win_close(original_win_id, true)
		end
		if vim.api.nvim_win_is_valid(blame_win_id) then
			vim.api.nvim_win_close(blame_win_id, true)
		end

		-- Delete temporary buffers
		if vim.api.nvim_buf_is_valid(original_buf_id) then
			vim.api.nvim_buf_delete(original_buf_id, {})
		end
		if vim.api.nvim_buf_is_valid(blame_buf_id) then
			vim.api.nvim_buf_delete(blame_buf_id, {})
		end

		-- Restore original window and buffer
		vim.api.nvim_set_current_win(old_current_win)
		vim.api.nvim_set_current_buf(old_current_buf)
	end)

	it("sets cursor position and scroll view", function()
		local expected_cursor_line = 7 -- 1-indexed
		local expected_top_line = 3 -- 1-indexed (vim.fn.line('w0') is 1-indexed)

		-- Set up the original window's state
		vim.api.nvim_set_current_win(original_win_id) -- Ensure current window is original
		vim.api.nvim_win_set_cursor(original_win_id, { expected_cursor_line, 0 }) -- Set cursor
		-- Now set the topline
		vim.api.nvim_win_call(original_win_id, function()
			vim.fn.winrestview({ topline = expected_top_line })
		end)

		-- Call the function under test
		utils.initialize_cursor_position(original_win_id, blame_win_id)

		-- Assert cursor synchronization in the blame window
		local blame_cursor_pos = vim.api.nvim_win_get_cursor(blame_win_id)
		assert.are.same({ expected_cursor_line, 0 }, blame_cursor_pos)

		-- Assert scroll view synchronization in the blame window
		local blame_top_line = vim.api.nvim_win_call(blame_win_id, function()
			return vim.fn.line("w0")
		end)
		assert.are.same(expected_top_line, blame_top_line)

		-- Assert scrollbind and cursorbind options were set for both windows
		assert.is_true(vim.api.nvim_get_option_value("scrollbind", { win = blame_win_id }))
		assert.is_true(vim.api.nvim_get_option_value("cursorbind", { win = blame_win_id }))
	end)

	it("handles cursor position exceeding line count", function()
		-- Set blame window to have fewer lines
		vim.api.nvim_buf_set_lines(blame_buf_id, 0, -1, false, { "", "", "" }) -- 3 lines

		-- Set cursor in original window to a line that is out of bounds for the blame window
		local original_cursor_line = 10
		vim.api.nvim_win_set_cursor(original_win_id, { original_cursor_line, 0 })

		-- Call the function under test
		utils.initialize_cursor_position(original_win_id, blame_win_id)

		-- Assert that the cursor in the blame window is on the last line
		local blame_line_count = vim.api.nvim_buf_line_count(blame_buf_id)
		local blame_cursor_pos = vim.api.nvim_win_get_cursor(blame_win_id)
		assert.are.same({ blame_line_count, 0 }, blame_cursor_pos)
	end)
end)
