-- tests/blame/blame_view_spec.lua

local assert = require("luassert")
local stub = require("luassert.stub")
local spy = require("luassert.spy")
local BlameView = require("blame.blame_view")

describe("blame.blame_view", function()
	local snapshot
	before_each(function()
		snapshot = assert:snapshot()
	end)

	after_each(function()
		snapshot:revert()
	end)

	it("initializes a new BlameView instance", function()
		local buf_id = vim.api.nvim_create_buf(false, true)
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
		}

		local blame_view = BlameView:new({
			git_instance = mock_git,
		})

		assert.is_not_nil(blame_view)
		---@cast blame_view -nil
		assert.are.equal(mock_git, blame_view.git_instance)
		assert.is_not_nil(blame_view.blame_popup_instance)
		assert.is_not_nil(blame_view.file_popup_instance)
		assert.is_not_nil(blame_view.layout)

		vim.api.nvim_buf_delete(buf_id, { force = true })
	end)

	it("updates the view with blame and file content", function()
		local buf_id = vim.api.nvim_create_buf(false, true)
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = stub({}, "get_blame_output", "abcdef1234567890 1 1 1\nauthor Test\nauthor-time 123456789\nfilename file.lua\n\tline content 1\nabcdef1234567890 2 2\n\tline content 2\n"),
		}

		local blame_view = BlameView:new({
			git_instance = mock_git,
		})
		assert.is_not_nil(blame_view)
		---@cast blame_view -nil

		local blame_set_text_stub = stub(blame_view.blame_popup_instance.border, "set_text")
		local file_set_text_stub = stub(blame_view.file_popup_instance.border, "set_text")

		local commit_info = { previous = { commit = "abcdef1234567890", filename = "file.lua" } }
		blame_view:update_view(commit_info)

		assert.stub(mock_git.get_blame_output).was.called_with(mock_git, commit_info)

		-- Verify titles
		assert.stub(blame_set_text_stub).was.called_with(blame_view.blame_popup_instance.border, "top", "abcdef12")
		assert.stub(file_set_text_stub).was.called_with(blame_view.file_popup_instance.border, "top", "file.lua")

		-- Verify file buffer content
		local file_content = vim.api.nvim_buf_get_lines(blame_view.file_popup_instance.bufnr, 0, -1, false)
		assert.are.same({ "line content 1", "line content 2" }, file_content)

		-- Verify blame buffer content (simplified check as NuiLine:render is complex to stub)
		local blame_content = vim.api.nvim_buf_get_lines(blame_view.blame_popup_instance.bufnr, 0, -1, false)
		-- line 1 has blame info, line 2 is same commit so it should be empty (spaces)
		assert.is_true(#blame_content[1] > 0)
		assert.is_true(blame_content[2]:match("^%s+$") ~= nil)

		vim.api.nvim_buf_delete(buf_id, { force = true })
	end)

	it("removes all remaining lines when updating the view with fewer lines", function()
		local buf_id = vim.api.nvim_create_buf(false, true)
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = stub({}, "get_blame_output", "abcdef1234567890 1 1 1\nauthor Test\nauthor-time 123456789\nfilename file.lua\n\tline content 1\n"),
		}

		local blame_view = BlameView:new({
			git_instance = mock_git,
		})

		-- Pre-fill buffers with more lines
		vim.api.nvim_buf_set_lines(blame_view.blame_popup_instance.bufnr, 0, -1, false, { "old line 1", "old line 2", "old line 3" })
		vim.api.nvim_buf_set_lines(blame_view.file_popup_instance.bufnr, 0, -1, false, { "old line 1", "old line 2", "old line 3" })

		blame_view:update_view(nil)

		-- Verify buffers have exactly 1 line (from the mock blame output)
		local blame_content = vim.api.nvim_buf_get_lines(blame_view.blame_popup_instance.bufnr, 0, -1, false)
		local file_content = vim.api.nvim_buf_get_lines(blame_view.file_popup_instance.bufnr, 0, -1, false)

		assert.are.equal(1, #blame_content)
		assert.are.equal(1, #file_content)

		vim.api.nvim_buf_delete(buf_id, { force = true })
	end)

	it("mounts the layout and initializes positions", function()
		local buf_id = vim.api.nvim_create_buf(false, true)
		local mock_git = {}
		local blame_view = BlameView:new({ git_instance = mock_git })

		local blame_view_layout_mount_spy = spy.on(blame_view.layout, "mount")
		local utils = require("blame.utils")
		local utils_initialize_cursor_position_spy = spy.on(utils, "initialize_cursor_position")

		blame_view:mount()

		assert.spy(blame_view_layout_mount_spy).was.called(1)
		assert.spy(utils_initialize_cursor_position_spy).was.called(2)

		vim.api.nvim_buf_delete(buf_id, { force = true })
	end)

	it("closes the view by unmounting the layout", function()
		local buf_id = vim.api.nvim_create_buf(false, true)
		local mock_git = {}
		local blame_view = BlameView:new({ git_instance = mock_git })
		local layout_unmount_spy = spy.on(blame_view.layout, "unmount")

		blame_view:close()

		assert.spy(layout_unmount_spy).was.called(1)

		vim.api.nvim_buf_delete(buf_id, { force = true })
	end)

	it("switches focus between blame and file popups", function()
		local buf_id = vim.api.nvim_create_buf(false, true)
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = function()
				return "abcdef1234567890 1 1 1\nauthor Test\nauthor-time 123456789\nfilename file.lua\n\tline content 1\n"
			end,
		}

		local blame_view = BlameView:new({
			git_instance = mock_git,
		})

		blame_view:update_view(nil)
		blame_view:mount()

		local blame_win = blame_view.blame_popup_instance.winid
		local file_win = blame_view.file_popup_instance.winid

		-- Switch from blame to file
		vim.api.nvim_set_current_win(blame_win)
		blame_view:switch_focus()
		assert.are.equal(file_win, vim.api.nvim_get_current_win())

		-- Switch from file to blame
		vim.api.nvim_set_current_win(file_win)
		blame_view:switch_focus()
		assert.are.equal(blame_win, vim.api.nvim_get_current_win())

		blame_view:close()
		vim.api.nvim_buf_delete(buf_id, { force = true })
	end)

	it("sets cursor to source_line when navigating forward", function()
		local buf_id = vim.api.nvim_create_buf(false, true)
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = function()
				local lines = {}
				for i = 1, 50 do
					table.insert(lines, string.format("abcdef1234567890 %d %d 1", i, i))
					table.insert(lines, "author Test")
					table.insert(lines, "author-time 123456789")
					table.insert(lines, "filename file.lua")
					table.insert(lines, "\tline content " .. i)
				end
				return table.concat(lines, "\n")
			end,
		}

		local blame_view = BlameView:new({
			git_instance = mock_git,
		})

		blame_view:update_view(nil)
		blame_view:mount()

		-- Setup some blame lines with source_line
		blame_view.blame_lines = {
			{
				header = { commit = "hash1", source_line = 42, result_line = 1 },
				previous = { commit = "prev_hash", filename = "file.lua" },
				author = "Test",
				date = "2026-02-24",
			},
		}

		-- Mock current cursor position in blame popup (line 1)
		vim.api.nvim_win_set_cursor(blame_view.blame_popup_instance.winid, { 1, 0 })

		-- Execute navigate_forward
		blame_view:navigate_forward()

		-- Verify actual cursor position
		assert.are.same({ 42, 0 }, vim.api.nvim_win_get_cursor(blame_view.blame_popup_instance.winid))
		assert.are.same({ 42, 0 }, vim.api.nvim_win_get_cursor(blame_view.file_popup_instance.winid))

		blame_view:close()
		vim.api.nvim_buf_delete(buf_id, { force = true })
	end)

	it("sets cursor to source_line when navigating backward", function()
		local buf_id = vim.api.nvim_create_buf(false, true)
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = function()
				local lines = {}
				for i = 1, 50 do
					table.insert(lines, string.format("abcdef1234567890 %d %d 1", i, i))
					table.insert(lines, "author Test")
					table.insert(lines, "author-time 123456789")
					table.insert(lines, "filename file.lua")
					table.insert(lines, "\tline content " .. i)
				end
				return table.concat(lines, "\n")
			end,
		}

		local blame_view = BlameView:new({
			git_instance = mock_git,
		})

		blame_view:update_view(nil)
		blame_view:mount()

		-- Setup breadcrumb with two items
		local item1 = {
			header = { commit = "hash1", source_line = 10, result_line = 1 },
			previous = { commit = "prev1", filename = "file.lua" },
		}
		local item2 = {
			header = { commit = "hash2", source_line = 20, result_line = 1 },
			previous = { commit = "prev2", filename = "file.lua" },
		}
		blame_view.breadcrumb:push(item1)
		blame_view.breadcrumb:push(item2)

		-- Execute navigate_backward (pops item2, current becomes item1)
		blame_view:navigate_backward()

		-- Verify actual cursor position
		assert.are.same({ 10, 0 }, vim.api.nvim_win_get_cursor(blame_view.blame_popup_instance.winid))
		assert.are.same({ 10, 0 }, vim.api.nvim_win_get_cursor(blame_view.file_popup_instance.winid))

		blame_view:close()
		vim.api.nvim_buf_delete(buf_id, { force = true })
	end)
end)
