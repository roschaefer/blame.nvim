-- tests/blame/blame_view_spec.lua

local assert = require("luassert")
local stub = require("luassert.stub")
local spy = require("luassert.spy")
local BlameView = require("blame.blame_view")

local function blame_output_with_lines(count)
	local lines = {}
	for i = 1, count do
		table.insert(lines, string.format("abcdef1234567890 %d %d 1", i, i))
		table.insert(lines, "author Test")
		table.insert(lines, "author-time 123456789")
		table.insert(lines, "filename file.lua")
		table.insert(lines, "\tline content " .. i)
	end
	return table.concat(lines, "\n")
end

describe("blame.blame_view", function()
	local snapshot
	before_each(function()
		snapshot = assert:snapshot()
	end)

	after_each(function()
		snapshot:revert()
	end)

	it("initializes a new BlameView instance", function()
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
		assert.is_true(vim.api.nvim_buf_is_valid(blame_view.blame_bufnr))
		assert.is_true(vim.api.nvim_buf_is_valid(blame_view.file_bufnr))
		assert.are.equal("nofile", vim.bo[blame_view.file_bufnr].buftype)
		assert.is_false(vim.bo[blame_view.file_bufnr].modifiable)
		assert.is_nil(blame_view.tabpage)
	end)

	it("updates the view with blame and file content", function()
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = stub(
				{},
				"get_blame_output",
				"abcdef1234567890 1 1 1\nauthor Test\nauthor-time 123456789\nfilename file.lua\n\tline content 1\nabcdef1234567890 2 2\n\tline content 2\n"
			),
		}

		local blame_view = BlameView:new({
			git_instance = mock_git,
		})

		local commit_info = { previous = { commit = "abcdef1234567890", filename = "file.lua" } }
		blame_view:update_view(commit_info)

		assert.stub(mock_git.get_blame_output).was.called_with(mock_git, commit_info)

		local file_content = vim.api.nvim_buf_get_lines(blame_view.file_bufnr, 0, -1, false)
		assert.are.same({ "line content 1", "line content 2" }, file_content)

		-- line 2 belongs to the same commit as line 1, so it is not annotated
		local blame_content = vim.api.nvim_buf_get_lines(blame_view.blame_bufnr, 0, -1, false)
		assert.are.same({ "abcdef12 Test (1973-11-29)", "" }, blame_content)

		local extmarks =
			vim.api.nvim_buf_get_extmarks(blame_view.blame_bufnr, blame_view.ns_id, 0, -1, { details = true })
		assert.are.equal(1, #extmarks)
		assert.are.equal("GitBlameCommit_abcdef1234567890", extmarks[1][4].hl_group)
		assert.are.equal(8, extmarks[1][4].end_col)

		assert.is_false(vim.bo[blame_view.blame_bufnr].modifiable)
		assert.is_false(vim.bo[blame_view.file_bufnr].modifiable)
		assert.are.equal("", vim.bo[blame_view.file_bufnr].filetype)
		assert.are.equal("", vim.bo[blame_view.file_bufnr].syntax)
		assert.is_not_nil(vim.treesitter.highlighter.active[blame_view.file_bufnr])
	end)

	it("falls back to regex syntax highlighting without a tree-sitter parser", function()
		local mock_git = {
			original_file = "/path/to/repo/file.cob",
			git_root = "/path/to/repo",
			get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(1)),
		}
		local blame_view = BlameView:new({ git_instance = mock_git })

		blame_view:update_view(nil)

		assert.are.equal("", vim.bo[blame_view.file_bufnr].filetype)
		assert.are.equal("cobol", vim.bo[blame_view.file_bufnr].syntax)
		assert.is_nil(vim.treesitter.highlighter.active[blame_view.file_bufnr])
	end)

	it("removes all remaining lines when updating the view with fewer lines", function()
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(3)),
		}

		local blame_view = BlameView:new({
			git_instance = mock_git,
		})

		blame_view:update_view(nil)
		mock_git.get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(1))
		blame_view:update_view(nil)

		assert.are.same(
			{ "abcdef12 Test (1973-11-29)" },
			vim.api.nvim_buf_get_lines(blame_view.blame_bufnr, 0, -1, false)
		)
		assert.are.same({ "line content 1" }, vim.api.nvim_buf_get_lines(blame_view.file_bufnr, 0, -1, false))
	end)

	it("mounts blame and file content side by side in a new tab page", function()
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = function()
				return blame_output_with_lines(3)
			end,
		}
		local blame_view = BlameView:new({ git_instance = mock_git })
		local original_tabpage = vim.api.nvim_get_current_tabpage()
		local utils = require("blame.utils")
		local utils_initialize_cursor_position_spy = spy.on(utils, "initialize_cursor_position")

		blame_view:mount()

		assert.are_not.equal(original_tabpage, blame_view.tabpage)
		assert.are.equal(blame_view.tabpage, vim.api.nvim_get_current_tabpage())
		assert.are.same(
			{ blame_view.blame_winid, blame_view.file_winid },
			vim.api.nvim_tabpage_list_wins(blame_view.tabpage)
		)
		assert.are.same(
			{ "row", { { "leaf", blame_view.blame_winid }, { "leaf", blame_view.file_winid } } },
			vim.fn.winlayout()
		)
		assert.are.equal(blame_view.blame_bufnr, vim.api.nvim_win_get_buf(blame_view.blame_winid))
		assert.are.equal(blame_view.file_bufnr, vim.api.nvim_win_get_buf(blame_view.file_winid))
		assert.are.equal(" HEAD", vim.wo[blame_view.blame_winid].winbar)
		assert.are.equal(" file.lua", vim.wo[blame_view.file_winid].winbar)
		assert.are.equal("blame", vim.bo[blame_view.blame_bufnr].filetype)
		assert.is_true(vim.wo[blame_view.blame_winid].winfixbuf)
		assert.is_true(vim.wo[blame_view.file_winid].winfixbuf)
		assert.spy(utils_initialize_cursor_position_spy).was.called(2)
		assert.are.equal(1, #blame_view.breadcrumb.stack)
		assert.is_nil(blame_view.breadcrumb:current().commit_info)

		blame_view:close()
	end)

	it("does not run FileType autocmds of the user config for the file content", function()
		local augroup = vim.api.nvim_create_augroup("blame_view_spec_user_config", { clear = true })
		local filetype_autocmd = spy.new(function() end)
		vim.api.nvim_create_autocmd("FileType", {
			group = augroup,
			pattern = "lua",
			callback = function()
				filetype_autocmd()
			end,
		})
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = function()
				return blame_output_with_lines(50)
			end,
		}
		local blame_view = BlameView:new({ git_instance = mock_git })

		blame_view:mount()
		blame_view.blame_lines = {
			{
				header = { commit = "hash1", source_line = 42, result_line = 1 },
				previous = { commit = "prev_hash", filename = "file.lua" },
			},
		}
		vim.api.nvim_win_set_cursor(blame_view.blame_winid, { 1, 0 })
		blame_view:navigate_forward()

		assert.spy(filetype_autocmd).was.called(0)
		assert.is_false(vim.wo[blame_view.file_winid].wrap)
		assert.is_false(vim.wo[blame_view.file_winid].foldenable)

		blame_view:close()
		vim.api.nvim_del_augroup_by_id(augroup)
	end)

	it("lets the user config customize the blame window, except for the options the view depends on", function()
		local augroup = vim.api.nvim_create_augroup("blame_view_spec_user_config", { clear = true })
		vim.api.nvim_create_autocmd("FileType", {
			group = augroup,
			pattern = "blame",
			command = "setlocal number nocursorline wrap foldenable noscrollbind nocursorbind nowinfixbuf",
		})
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = function()
				return blame_output_with_lines(3)
			end,
		}
		local blame_view = BlameView:new({ git_instance = mock_git })

		blame_view:mount()

		local wo = vim.wo[blame_view.blame_winid]
		assert.is_true(wo.number)
		assert.is_false(wo.cursorline)
		assert.is_false(wo.wrap)
		assert.is_false(wo.foldenable)
		assert.is_true(wo.scrollbind)
		assert.is_true(wo.cursorbind)
		assert.is_true(wo.winfixbuf)

		blame_view:close()
		vim.api.nvim_del_augroup_by_id(augroup)
	end)

	it("closes the tab page of the view", function()
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = function()
				return blame_output_with_lines(3)
			end,
		}
		local blame_view = BlameView:new({ git_instance = mock_git })
		local original_tabpage = vim.api.nvim_get_current_tabpage()
		blame_view:mount()
		local tabpage = blame_view.tabpage

		blame_view:close()

		assert.is_false(vim.api.nvim_tabpage_is_valid(tabpage))
		assert.are.equal(original_tabpage, vim.api.nvim_get_current_tabpage())
		assert.is_false(vim.api.nvim_buf_is_valid(blame_view.blame_bufnr))
		assert.is_false(vim.api.nvim_buf_is_valid(blame_view.file_bufnr))
	end)

	it("closes the whole view when one of its windows is closed", function()
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = function()
				return blame_output_with_lines(3)
			end,
		}
		local blame_view = BlameView:new({ git_instance = mock_git })
		blame_view:mount()
		local tabpage = blame_view.tabpage

		vim.api.nvim_win_close(blame_view.blame_winid, true)
		vim.wait(100, function()
			return not vim.api.nvim_tabpage_is_valid(tabpage)
		end)

		assert.is_false(vim.api.nvim_tabpage_is_valid(tabpage))
	end)

	it("sets cursor to source_line when navigating forward", function()
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = function()
				return blame_output_with_lines(50)
			end,
		}

		local blame_view = BlameView:new({
			git_instance = mock_git,
		})

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

		vim.api.nvim_win_set_cursor(blame_view.blame_winid, { 1, 0 })

		blame_view:navigate_forward()

		assert.are.same({ 42, 0 }, vim.api.nvim_win_get_cursor(blame_view.blame_winid))
		assert.are.same({ 42, 0 }, vim.api.nvim_win_get_cursor(blame_view.file_winid))
		assert.are.equal(" prev_has", vim.wo[blame_view.blame_winid].winbar)

		blame_view:close()
	end)

	it("restores cursor position when navigating backward", function()
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = function()
				return blame_output_with_lines(50)
			end,
		}

		local blame_view = BlameView:new({
			git_instance = mock_git,
		})

		blame_view:mount()

		-- Setup breadcrumb with two items
		local item1 = {
			commit_info = {
				header = { commit = "hash1", source_line = 10, result_line = 1 },
				previous = { commit = "prev1", filename = "file.lua" },
			},
			cursor_pos = { 15, 0 }, -- This is what we want to restore to
		}
		local item2 = {
			commit_info = {
				header = { commit = "hash2", source_line = 20, result_line = 1 },
				previous = { commit = "prev2", filename = "file.lua" },
			},
		}
		blame_view.breadcrumb.stack = { item1, item2 }

		-- Execute navigate_backward (pops item2, current becomes item1)
		blame_view:navigate_backward()

		-- Verify actual cursor position is restored from item1.cursor_pos, NOT from source_line
		assert.are.same({ 15, 0 }, vim.api.nvim_win_get_cursor(blame_view.blame_winid))
		assert.are.same({ 15, 0 }, vim.api.nvim_win_get_cursor(blame_view.file_winid))

		blame_view:close()
	end)
end)
