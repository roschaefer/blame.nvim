-- tests/blame/blame_view_spec.lua

local assert = require("luassert")
local stub = require("luassert.stub")
local spy = require("luassert.spy")
local BlameView = require("blame.blame_view")

local three_days_ago = os.time() - 3 * 24 * 60 * 60

--- Returns the text of the winbar as it is drawn, without the padding on the right.
local function winbar_text(winid)
	local winbar = vim.api.nvim_eval_statusline(vim.wo[winid].winbar, { winid = winid, use_winbar = true })
	return (winbar.str:gsub("%s+$", ""))
end

local function blame_output_with_lines(count)
	local lines = {}
	for i = 1, count do
		table.insert(lines, string.format("abcdef1234567890 %d %d 1", i, i))
		table.insert(lines, "author Test")
		table.insert(lines, "author-time " .. three_days_ago)
		table.insert(lines, "summary Subject")
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
				"abcdef1234567890 1 1 1\nauthor Test\nauthor-time "
					.. three_days_ago
					.. "\nsummary Subject\nfilename file.lua\n\tline content 1\nabcdef1234567890 2 2\n\tline content 2\n"
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
		assert.are.same({ "3 days ago Test Subject", "" }, blame_content)

		assert.is_false(vim.bo[blame_view.blame_bufnr].modifiable)
		assert.is_false(vim.bo[blame_view.file_bufnr].modifiable)
		assert.are.equal("", vim.bo[blame_view.file_bufnr].filetype)
		assert.are.equal("", vim.bo[blame_view.file_bufnr].syntax)
		assert.is_not_nil(vim.treesitter.highlighter.active[blame_view.file_bufnr])
	end)

	describe("blame lines", function()
		local day = 24 * 60 * 60
		local two_authors = table.concat({
			"1111111111111111111111111111111111111111 1 1 1",
			"author Robert Schäfer",
			"author-time " .. (os.time() - 400 * day),
			"summary feat(view): show the commit subject in the blame window",
			"filename file.lua",
			"\tline content 1",
			"2222222222222222222222222222222222222222 2 2 1",
			"author Bot",
			"author-time " .. (os.time() - 3 * day),
			"summary fix: typo",
			"filename file.lua",
			"\tline content 2",
		}, "\n")

		local function mock_git()
			return {
				original_file = "/path/to/repo/file.lua",
				git_root = "/path/to/repo",
				get_blame_output = stub({}, "get_blame_output", two_authors),
			}
		end

		it("shows the relative date, the author and the subject in aligned columns", function()
			local blame_view = BlameView:new({ git_instance = mock_git() })

			blame_view:update_view(nil)

			assert.are.same({
				"last year  Robert Schäfer feat(view): show the commit subject in the blame window",
				"3 days ago Bot            fix: typo",
			}, vim.api.nvim_buf_get_lines(blame_view.blame_bufnr, 0, -1, false))
		end)

		it("tells the columns apart with alternating colours, the date and the subject standing out", function()
			local blame_view = BlameView:new({ git_instance = mock_git() })

			blame_view:update_view(nil)

			local highlights = vim.tbl_map(function(extmark)
				return { extmark[2], extmark[3], extmark[4].end_col, extmark[4].hl_group }
			end, vim.api.nvim_buf_get_extmarks(blame_view.blame_bufnr, blame_view.ns_id, 0, -1, { details = true }))
			assert.are.same({
				{ 0, 0, 9, "GitBlameDate" },
				{ 0, 11, 26, "GitBlameAuthor" },
				{ 0, 27, 82, "GitBlameSubject" },
				{ 1, 0, 10, "GitBlameDate" },
				{ 1, 11, 14, "GitBlameAuthor" },
				{ 1, 26, 35, "GitBlameSubject" },
			}, highlights)
			assert.are.same({ link = "Normal", default = true }, vim.api.nvim_get_hl(0, { name = "GitBlameDate" }))
			assert.are.same({ link = "Comment", default = true }, vim.api.nvim_get_hl(0, { name = "GitBlameAuthor" }))
			assert.are.same({ link = "Normal", default = true }, vim.api.nvim_get_hl(0, { name = "GitBlameSubject" }))
		end)

		it("takes a third of the page, like GitHub's blame view", function()
			local blame_view = BlameView:new({ git_instance = mock_git() })

			blame_view:mount()

			assert.are.equal(math.floor(vim.o.columns / 3), vim.api.nvim_win_get_width(blame_view.blame_winid))

			blame_view:close()
		end)
	end)

	describe("commit of the cursor line", function()
		local commit_twice = table.concat({
			"1111111111111111111111111111111111111111 1 1 1",
			"author First",
			"summary first",
			"filename file.lua",
			"\tline content 1",
			"2222222222222222222222222222222222222222 1 2 1",
			"author Second",
			"summary second",
			"filename file.lua",
			"\tline content 2",
			"1111111111111111111111111111111111111111 2 3 1",
			"filename file.lua",
			"\tline content 3",
		}, "\n")

		local function highlighted_rows(blame_view)
			return vim.tbl_map(
				function(extmark)
					assert.are.equal("▎", vim.trim(extmark[4].sign_text))
					assert.are.equal("GitBlameCursorCommit", extmark[4].sign_hl_group)
					return extmark[2]
				end,
				vim.api.nvim_buf_get_extmarks(
					blame_view.file_bufnr,
					blame_view.cursor_commit_ns_id,
					0,
					-1,
					{ details = true }
				)
			)
		end

		it(
			"marks all lines of the commit of the cursor line with a bar in the sign column of the file content window",
			function()
				local mock_git = {
					original_file = "/path/to/repo/file.lua",
					git_root = "/path/to/repo",
					get_blame_output = stub({}, "get_blame_output", commit_twice),
				}
				local blame_view = BlameView:new({ git_instance = mock_git })
				blame_view:mount()

				vim.api.nvim_set_current_win(blame_view.file_winid)
				vim.api.nvim_win_set_cursor(blame_view.file_winid, { 3, 0 })
				vim.api.nvim_exec_autocmds("CursorMoved", { buffer = blame_view.file_bufnr })

				assert.are.same({ 0, 2 }, highlighted_rows(blame_view))
				assert.are.same(
					{ link = "Special", default = true },
					vim.api.nvim_get_hl(0, { name = "GitBlameCursorCommit" })
				)

				vim.api.nvim_win_set_cursor(blame_view.file_winid, { 2, 0 })
				vim.api.nvim_exec_autocmds("CursorMoved", { buffer = blame_view.file_bufnr })

				assert.are.same({ 1 }, highlighted_rows(blame_view))

				blame_view:close()
			end
		)

		it("does not redraw the bar while the cursor stays within the same commit", function()
			local mock_git = {
				original_file = "/path/to/repo/file.lua",
				git_root = "/path/to/repo",
				get_blame_output = stub({}, "get_blame_output", commit_twice),
			}
			local blame_view = BlameView:new({ git_instance = mock_git })
			blame_view:mount()
			vim.api.nvim_set_current_win(blame_view.file_winid)
			local set_extmark = spy.on(vim.api, "nvim_buf_set_extmark")

			vim.api.nvim_win_set_cursor(blame_view.file_winid, { 3, 0 })
			blame_view:follow_cursor()

			assert.spy(set_extmark).was.called(0)

			vim.api.nvim_win_set_cursor(blame_view.file_winid, { 2, 0 })
			blame_view:follow_cursor()

			assert.spy(set_extmark).was.called(1)
			assert.are.same({ 1 }, highlighted_rows(blame_view))

			blame_view:close()
		end)

		it("marks the commit of the cursor line right after opening and navigating", function()
			local mock_git = {
				original_file = "/path/to/repo/file.lua",
				git_root = "/path/to/repo",
				get_blame_output = stub({}, "get_blame_output", commit_twice),
			}
			local blame_view = BlameView:new({ git_instance = mock_git })

			blame_view:mount()

			assert.are.same({ 0, 2 }, highlighted_rows(blame_view))

			blame_view.blame_lines[1].previous = { commit = "prev_hash", filename = "file.lua" }
			mock_git.get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(3))
			vim.api.nvim_win_set_cursor(blame_view.blame_winid, { 1, 0 })
			blame_view:navigate_forward()

			assert.are.same({ 0, 1, 2 }, highlighted_rows(blame_view))

			blame_view:close()
		end)
	end)

	describe("age stripe", function()
		local day = 24 * 60 * 60
		local two_authors = table.concat({
			"1111111111111111111111111111111111111111 1 1 1",
			"author Robert Schäfer",
			"author-time " .. (os.time() - 400 * day),
			"summary feat(view): show the commit subject in the blame window",
			"filename file.lua",
			"\tline content 1",
			"2222222222222222222222222222222222222222 2 2 1",
			"author Bot",
			"author-time " .. (os.time() - 3 * day),
			"summary fix: typo",
			"filename file.lua",
			"\tline content 2",
		}, "\n")

		local function mock_git()
			return {
				original_file = "/path/to/repo/file.lua",
				git_root = "/path/to/repo",
				get_blame_output = stub({}, "get_blame_output", two_authors),
			}
		end

		it(
			"draws a stripe next to every line, coloured by the age of its commit, with uncommitted lines as the newest",
			function()
				local older_block = table.concat({
					"1111111111111111111111111111111111111111 1 1 2",
					"author Old",
					"author-time " .. (os.time() - 400 * day),
					"filename file.lua",
					"\tline content 1",
					"1111111111111111111111111111111111111111 2 2",
					"\tline content 2",
					"2222222222222222222222222222222222222222 1 3 1",
					"author New",
					"author-time " .. (os.time() - 3 * day),
					"filename file.lua",
					"\tline content 3",
					"0000000000000000000000000000000000000000 4 4 1",
					"author Not Committed Yet",
					"author-time " .. os.time(),
					"filename file.lua",
					"\tline content 4",
				}, "\n")
				local blame_view = BlameView:new({
					git_instance = {
						original_file = "/path/to/repo/file.lua",
						git_root = "/path/to/repo",
						get_blame_output = stub({}, "get_blame_output", older_block),
					},
				})

				blame_view:update_view(nil)

				local stripe = vim.tbl_map(
					function(extmark)
						return { extmark[2], vim.trim(extmark[4].sign_text), extmark[4].sign_hl_group }
					end,
					vim.api.nvim_buf_get_extmarks(
						blame_view.blame_bufnr,
						blame_view.age_ns_id,
						0,
						-1,
						{ details = true }
					)
				)
				assert.are.same({
					{ 0, "▎", "GitBlameAge1" },
					{ 1, "▎", "GitBlameAge1" },
					{ 2, "▎", "GitBlameAge10" },
					{ 3, "▎", "GitBlameAge10" },
				}, stripe)
			end
		)

		it("shows the legend of the age stripe in the title, if it fits", function()
			local blame_view = BlameView:new({ git_instance = mock_git() })
			blame_view:mount()

			vim.api.nvim_win_set_width(blame_view.blame_winid, 37)
			assert.are.equal(
				" Working tree Older ▎▎▎▎▎▎▎▎▎▎ Newer",
				winbar_text(blame_view.blame_winid)
			)

			vim.api.nvim_win_set_width(blame_view.blame_winid, 36)
			assert.are.equal(" Working tree", winbar_text(blame_view.blame_winid))

			blame_view:close()
		end)
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

	it("detects the language from the file content if the file name is not enough", function()
		local mock_git = {
			original_file = "/path/to/repo/script",
			git_root = "/path/to/repo",
			get_blame_output = stub(
				{},
				"get_blame_output",
				"abcdef1234567890 1 1 1\nauthor Test\nauthor-time 123456789\nfilename script\n\t#!/usr/bin/env python3\n"
			),
		}
		local blame_view = BlameView:new({ git_instance = mock_git })

		blame_view:update_view(nil)

		-- Highlighted with tree-sitter or regex syntax, depending on the installed parsers
		local highlighter = vim.treesitter.highlighter.active[blame_view.file_bufnr]
		local language = highlighter and highlighter.tree:lang() or vim.bo[blame_view.file_bufnr].syntax
		assert.are.equal("python", language)
		assert.are.equal("", vim.bo[blame_view.file_bufnr].filetype)
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

		assert.are.same({ "3 days ago Test Subject" }, vim.api.nvim_buf_get_lines(blame_view.blame_bufnr, 0, -1, false))
		assert.are.same({ "line content 1" }, vim.api.nvim_buf_get_lines(blame_view.file_bufnr, 0, -1, false))
	end)

	it("mounts blame and file content side by side in a new tab page", function()
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(3)),
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
		assert.are.equal(" Working tree", winbar_text(blame_view.blame_winid))
		assert.are.equal(" file.lua", vim.wo[blame_view.file_winid].winbar)
		assert.are.equal("blame", vim.bo[blame_view.blame_bufnr].filetype)
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
			get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(50)),
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

	it("does not take over diff mode or the gutter of the window it was opened from", function()
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(3)),
		}
		local blame_view = BlameView:new({ git_instance = mock_git })
		vim.cmd("vsplit")
		local source_winid = vim.api.nvim_get_current_win()
		vim.wo[source_winid].diff = true
		vim.wo[source_winid].statuscolumn = "%l "
		vim.wo[source_winid].colorcolumn = "80"
		vim.wo[source_winid].signcolumn = "auto"

		blame_view:mount()

		assert.is_false(vim.wo[blame_view.blame_winid].diff)
		assert.is_false(vim.wo[blame_view.file_winid].diff)
		assert.are.equal("", vim.wo[blame_view.blame_winid].statuscolumn)
		assert.are.equal("", vim.wo[blame_view.blame_winid].colorcolumn)
		assert.are.equal("yes:1", vim.wo[blame_view.blame_winid].signcolumn)
		assert.are.equal("yes:1", vim.wo[blame_view.file_winid].signcolumn)
		-- The inherited "%l " would hide the bar in the sign column
		assert.are.equal("", vim.wo[blame_view.file_winid].statuscolumn)

		blame_view:close()
		vim.api.nvim_win_close(source_winid, true)
	end)

	it("lets the user config customize the blame window, except for the options the view depends on", function()
		local augroup = vim.api.nvim_create_augroup("blame_view_spec_user_config", { clear = true })
		vim.api.nvim_create_autocmd("FileType", {
			group = augroup,
			pattern = "blame",
			command = "setlocal number nocursorline wrap foldenable noscrollbind nocursorbind",
		})
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(3)),
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

		blame_view:close()
		vim.api.nvim_del_augroup_by_id(augroup)
	end)

	it("closes the tab page of the view", function()
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(3)),
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
		assert.is_false(vim.api.nvim_buf_is_valid(blame_view.commit_panel.bufnr))
	end)

	it("returns to the tab page it was opened from when there are more tab pages", function()
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(3)),
		}
		local original_tabpage = vim.api.nvim_get_current_tabpage()
		vim.cmd("tabnew")
		local other_tabpage = vim.api.nvim_get_current_tabpage()
		vim.api.nvim_set_current_tabpage(original_tabpage)
		local blame_view = BlameView:new({ git_instance = mock_git })
		blame_view:mount()

		blame_view:close()

		assert.are.equal(original_tabpage, vim.api.nvim_get_current_tabpage())
		assert.are.same({ original_tabpage, other_tabpage }, vim.api.nvim_list_tabpages())

		vim.cmd("tabclose " .. vim.api.nvim_tabpage_get_number(other_tabpage))
	end)

	it("returns to the tab page it was opened from when the user closes the tab page of the view", function()
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(3)),
		}
		local original_tabpage = vim.api.nvim_get_current_tabpage()
		vim.cmd("tabnew")
		local other_tabpage = vim.api.nvim_get_current_tabpage()
		vim.api.nvim_set_current_tabpage(original_tabpage)
		local blame_view = BlameView:new({ git_instance = mock_git })
		blame_view:mount()

		vim.cmd("tabclose")
		vim.wait(100, function()
			return vim.api.nvim_get_current_tabpage() == original_tabpage
		end)

		assert.are.equal(original_tabpage, vim.api.nvim_get_current_tabpage())

		vim.cmd("tabclose " .. vim.api.nvim_tabpage_get_number(other_tabpage))
	end)

	it("stays on the current tab page when the tab page of the view is closed from another one", function()
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(3)),
		}
		local blame_view = BlameView:new({ git_instance = mock_git })
		blame_view:mount()
		local tabpage = blame_view.tabpage
		vim.cmd("tabnew")
		local other_tabpage = vim.api.nvim_get_current_tabpage()

		vim.cmd("tabclose " .. vim.api.nvim_tabpage_get_number(tabpage))
		vim.wait(100, function()
			return false
		end)

		assert.are.equal(other_tabpage, vim.api.nvim_get_current_tabpage())

		vim.cmd("tabclose")
	end)

	describe("another buffer opened in one of its windows, e.g. from a file explorer", function()
		local blame_view
		local other_bufnr
		local view_tabpage

		before_each(function()
			blame_view = BlameView:new({
				git_instance = {
					original_file = "/path/to/repo/file.lua",
					git_root = "/path/to/repo",
					get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(3)),
					get_commit_message = stub({}, "get_commit_message", { "commit message" }),
				},
			})
			blame_view:mount()
			view_tabpage = blame_view.tabpage
			other_bufnr = vim.api.nvim_create_buf(true, false)
		end)

		after_each(function()
			blame_view:close()
			-- The tab page stays after the view is released
			if vim.api.nvim_tabpage_is_valid(view_tabpage) then
				vim.cmd("tabclose! " .. vim.api.nvim_tabpage_get_number(view_tabpage))
			end
			if vim.api.nvim_buf_is_valid(other_bufnr) then
				vim.api.nvim_buf_delete(other_bufnr, { force = true })
			end
		end)

		local function open_in(winid, bufnr)
			vim.api.nvim_set_current_win(winid)
			vim.api.nvim_win_set_buf(winid, bufnr or other_bufnr)
		end

		local function wait_for_release()
			vim.wait(100, function()
				return blame_view.tabpage == nil
			end)
		end

		it("closes the rest of the view and keeps the window with the buffer in the tab page", function()
			local tabpage = blame_view.tabpage
			local file_winid = blame_view.file_winid

			open_in(file_winid)
			wait_for_release()

			assert.are.same({ file_winid }, vim.api.nvim_tabpage_list_wins(tabpage))
			assert.are.equal(other_bufnr, vim.api.nvim_win_get_buf(file_winid))
			assert.are.equal(tabpage, vim.api.nvim_get_current_tabpage())
			assert.is_false(vim.api.nvim_buf_is_valid(blame_view.blame_bufnr))
			assert.is_false(vim.api.nvim_buf_is_valid(blame_view.file_bufnr))
		end)

		it("does not take over the options of the view for the buffer", function()
			local blame_winid = blame_view.blame_winid

			open_in(blame_winid)
			wait_for_release()

			local wo = vim.wo[blame_winid]
			assert.is_false(wo.scrollbind)
			assert.is_false(wo.cursorbind)
			assert.are.equal("", wo.winbar)
		end)

		it("keeps every window that shows another buffer, e.g. when a plugin opens buffers in two of them", function()
			local second_bufnr = vim.api.nvim_create_buf(true, false)
			local blame_winid = blame_view.blame_winid
			local file_winid = blame_view.file_winid

			open_in(blame_winid)
			open_in(file_winid, second_bufnr)
			wait_for_release()

			assert.are.same({ blame_winid, file_winid }, vim.api.nvim_tabpage_list_wins(0))
			assert.are.equal(other_bufnr, vim.api.nvim_win_get_buf(blame_winid))
			assert.are.equal(second_bufnr, vim.api.nvim_win_get_buf(file_winid))
			vim.api.nvim_buf_delete(second_bufnr, { force = true })
		end)

		it("closes the whole view when one of its windows shows the buffer of another one", function()
			local original_tabpage = blame_view.previous_tabpage

			vim.api.nvim_set_current_win(blame_view.blame_winid)
			vim.cmd("buffer " .. blame_view.file_bufnr)
			wait_for_release()

			assert.is_false(vim.api.nvim_tabpage_is_valid(view_tabpage))
			assert.are.equal(original_tabpage, vim.api.nvim_get_current_tabpage())
			assert.is_false(vim.api.nvim_buf_is_valid(blame_view.file_bufnr))
		end)

		it("stays in the tab page when a buffer is opened right after a window of the view was closed", function()
			local blame_winid = blame_view.blame_winid

			vim.api.nvim_win_close(blame_view.file_winid, true)
			open_in(blame_winid)
			wait_for_release()
			vim.wait(50, function()
				return false
			end)

			assert.are.equal(view_tabpage, vim.api.nvim_get_current_tabpage())
			assert.are.same({ blame_winid }, vim.api.nvim_tabpage_list_wins(0))
			assert.are.equal(other_bufnr, vim.api.nvim_win_get_buf(blame_winid))
		end)

		it("stays in the tab page when a window of the view is closed right after a buffer was opened", function()
			local blame_winid = blame_view.blame_winid

			open_in(blame_winid)
			vim.api.nvim_win_close(blame_view.file_winid, true)
			wait_for_release()
			vim.wait(50, function()
				return false
			end)

			assert.are.equal(view_tabpage, vim.api.nvim_get_current_tabpage())
			assert.are.same({ blame_winid }, vim.api.nvim_tabpage_list_wins(0))
			assert.are.equal(other_bufnr, vim.api.nvim_win_get_buf(blame_winid))
		end)

		it("closes the commit panel, too", function()
			blame_view:toggle_commit_message()
			local panel_bufnr = blame_view.commit_panel.bufnr

			open_in(blame_view.blame_winid)
			wait_for_release()

			assert.are.equal(1, #vim.api.nvim_tabpage_list_wins(0))
			assert.is_false(vim.api.nvim_buf_is_valid(panel_bufnr))
		end)

		it("keeps the commit panel window if the buffer is opened there", function()
			blame_view:toggle_commit_message()
			local panel_winid = blame_view.commit_panel.winid

			open_in(panel_winid)
			wait_for_release()

			assert.are.same({ panel_winid }, vim.api.nvim_tabpage_list_wins(0))
			assert.are.equal(other_bufnr, vim.api.nvim_win_get_buf(panel_winid))
		end)
	end)

	it("closes the whole view when one of its windows is closed", function()
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(3)),
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
			get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(50)),
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
			},
		}

		vim.api.nvim_win_set_cursor(blame_view.blame_winid, { 1, 0 })

		blame_view:navigate_forward()

		assert.are.same({ 42, 0 }, vim.api.nvim_win_get_cursor(blame_view.blame_winid))
		assert.are.same({ 42, 0 }, vim.api.nvim_win_get_cursor(blame_view.file_winid))
		assert.are.equal(" prev_has", winbar_text(blame_view.blame_winid))

		blame_view:close()
	end)

	it("restores cursor position when navigating backward", function()
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(50)),
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

	it("restores the cursor column when navigating back", function()
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(50)),
		}
		local blame_view = BlameView:new({ git_instance = mock_git })
		blame_view:mount()
		blame_view.blame_lines[30] = {
			header = { commit = "hash1", source_line = 42, result_line = 30 },
			previous = { commit = "prev_hash", filename = "file.lua" },
		}
		vim.api.nvim_set_current_win(blame_view.file_winid)
		vim.api.nvim_win_set_cursor(blame_view.file_winid, { 30, 5 })

		blame_view:navigate_forward()
		blame_view:navigate_backward()

		assert.are.same({ 30, 5 }, vim.api.nvim_win_get_cursor(blame_view.file_winid))
		-- The blame line is empty, because line 30 belongs to the same commit as line 1
		assert.are.same({ 30, 0 }, vim.api.nvim_win_get_cursor(blame_view.blame_winid))

		blame_view:close()
	end)

	it("does not open the view when git blame fails", function()
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = stub({}, "get_blame_output", nil),
		}
		local blame_view = BlameView:new({ git_instance = mock_git })
		local original_tabpage = vim.api.nvim_get_current_tabpage()

		assert.is_false(blame_view:mount())

		assert.are.same({ original_tabpage }, vim.api.nvim_list_tabpages())
		assert.is_false(vim.api.nvim_buf_is_valid(blame_view.blame_bufnr))
		assert.is_false(vim.api.nvim_buf_is_valid(blame_view.file_bufnr))
	end)

	it("stays at the current version when git blame fails for the previous one", function()
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(3)),
		}
		local blame_view = BlameView:new({ git_instance = mock_git })
		assert.is_true(blame_view:mount())
		blame_view.blame_lines[1].previous = { commit = "prev_hash", filename = "file.lua" }
		vim.api.nvim_win_set_cursor(blame_view.blame_winid, { 1, 0 })
		mock_git.get_blame_output = stub({}, "get_blame_output", nil)

		blame_view:navigate_forward()

		assert.are.equal(1, #blame_view.breadcrumb.stack)
		assert.are.equal(3, #blame_view.blame_lines)
		assert.are.same(
			{ "line content 1", "line content 2", "line content 3" },
			vim.api.nvim_buf_get_lines(blame_view.file_bufnr, 0, -1, false)
		)
		assert.are.equal(" Working tree", winbar_text(blame_view.blame_winid))

		blame_view:close()
	end)

	it("stays at the current version when git blame fails for the one to go back to", function()
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
			get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(3)),
		}
		local blame_view = BlameView:new({ git_instance = mock_git })
		assert.is_true(blame_view:mount())
		blame_view.blame_lines[1].previous = { commit = "prev_hash", filename = "file.lua" }
		vim.api.nvim_win_set_cursor(blame_view.blame_winid, { 1, 0 })
		blame_view:navigate_forward()
		mock_git.get_blame_output = stub({}, "get_blame_output", nil)

		blame_view:navigate_backward()

		assert.are.equal(2, #blame_view.breadcrumb.stack)
		assert.are.equal(" prev_has", winbar_text(blame_view.blame_winid))

		blame_view:close()
	end)

	describe("commit panel", function()
		local two_commits = table.concat({
			"1111111111111111111111111111111111111111 1 1 1",
			"author First",
			"author-time 123456789",
			"previous 3333333333333333333333333333333333333333 file.lua",
			"filename file.lua",
			"\tline content 1",
			"2222222222222222222222222222222222222222 5 2 1",
			"author Second",
			"author-time 123456789",
			"filename file.lua",
			"\tline content 2",
		}, "\n")
		local mock_git

		before_each(function()
			mock_git = {
				original_file = "/path/to/repo/file.lua",
				git_root = "/path/to/repo",
				get_blame_output = stub({}, "get_blame_output", two_commits),
				get_commit_message = stub({}, "get_commit_message", function(_, commit)
					return { "commit " .. commit }
				end),
			}
		end)

		it("toggles the commit message of the cursor line in a panel below both windows", function()
			local blame_view = BlameView:new({ git_instance = mock_git })
			blame_view:mount()
			vim.api.nvim_win_set_cursor(blame_view.blame_winid, { 1, 0 })

			blame_view:toggle_commit_message()

			local panel = blame_view.commit_panel
			assert.are.same({
				"col",
				{
					{ "row", { { "leaf", blame_view.blame_winid }, { "leaf", blame_view.file_winid } } },
					{ "leaf", panel.winid },
				},
			}, vim.fn.winlayout())
			assert.are.same(
				{ "commit 1111111111111111111111111111111111111111" },
				vim.api.nvim_buf_get_lines(panel.bufnr, 0, -1, false)
			)
			assert.are.equal(blame_view.blame_winid, vim.api.nvim_get_current_win())

			blame_view:toggle_commit_message()

			assert.is_false(panel:is_open())
			assert.are.same(
				{ blame_view.blame_winid, blame_view.file_winid },
				vim.api.nvim_tabpage_list_wins(blame_view.tabpage)
			)

			blame_view:close()
		end)

		it("follows the cursor to the commit of another line", function()
			local blame_view = BlameView:new({ git_instance = mock_git })
			blame_view:mount()
			vim.api.nvim_set_current_win(blame_view.file_winid)
			vim.api.nvim_win_set_cursor(blame_view.file_winid, { 1, 0 })
			blame_view:toggle_commit_message()

			vim.api.nvim_win_set_cursor(blame_view.file_winid, { 2, 0 })
			vim.api.nvim_exec_autocmds("CursorMoved", { buffer = blame_view.file_bufnr })

			assert.are.same(
				{ "commit 2222222222222222222222222222222222222222" },
				vim.api.nvim_buf_get_lines(blame_view.commit_panel.bufnr, 0, -1, false)
			)

			blame_view:close()
		end)

		it("shows the commit message of the cursor line after navigating", function()
			local blame_view = BlameView:new({ git_instance = mock_git })
			blame_view:mount()
			vim.api.nvim_win_set_cursor(blame_view.blame_winid, { 1, 0 })
			blame_view:toggle_commit_message()
			mock_git.get_blame_output = stub({}, "get_blame_output", function(_, commit_info)
				return commit_info and blame_output_with_lines(1) or two_commits
			end)

			blame_view:navigate_forward()

			assert.are.same(
				{ "commit abcdef1234567890" },
				vim.api.nvim_buf_get_lines(blame_view.commit_panel.bufnr, 0, -1, false)
			)

			blame_view:navigate_backward()

			assert.are.same(
				{ "commit 1111111111111111111111111111111111111111" },
				vim.api.nvim_buf_get_lines(blame_view.commit_panel.bufnr, 0, -1, false)
			)

			blame_view:close()
		end)

		it("keeps the view open when the commit panel is closed", function()
			local blame_view = BlameView:new({ git_instance = mock_git })
			blame_view:mount()
			blame_view:toggle_commit_message()

			vim.api.nvim_set_current_win(blame_view.commit_panel.winid)
			vim.cmd("quit")
			vim.wait(100, function()
				return false
			end)

			assert.is_true(vim.api.nvim_tabpage_is_valid(blame_view.tabpage))
			assert.are.same(
				{ blame_view.blame_winid, blame_view.file_winid },
				vim.api.nvim_tabpage_list_wins(blame_view.tabpage)
			)

			blame_view:close()
		end)
	end)

	describe("block motions", function()
		-- Blocks start at lines 1, 2, 5 and 6, lines 3, 4 and 7 are empty in the blame window
		local blocks = table.concat({
			"1111111111111111111111111111111111111111 1 1 1",
			"filename file.lua",
			"\tline 1",
			"2222222222222222222222222222222222222222 1 2 3",
			"filename file.lua",
			"\tline 2",
			"2222222222222222222222222222222222222222 2 3",
			"\tline 3",
			"2222222222222222222222222222222222222222 3 4",
			"\tline 4",
			"1111111111111111111111111111111111111111 2 5 1",
			"\tline 5",
			"3333333333333333333333333333333333333333 1 6 2",
			"filename file.lua",
			"\tline 6",
			"3333333333333333333333333333333333333333 2 7",
			"\tline 7",
		}, "\n")
		local blame_view

		before_each(function()
			blame_view = BlameView:new({
				git_instance = {
					original_file = "/path/to/repo/file.lua",
					git_root = "/path/to/repo",
					get_blame_output = stub({}, "get_blame_output", blocks),
				},
			})
			blame_view:mount()
		end)

		after_each(function()
			blame_view:close()
		end)

		local function move(from_row, count)
			vim.api.nvim_win_set_cursor(blame_view.blame_winid, { from_row, 0 })
			blame_view:move_to_block(count)
			return vim.api.nvim_win_get_cursor(blame_view.blame_winid)[1]
		end

		it("moves down to the first line of the next block, skipping empty lines", function()
			assert.are.equal(5, move(2, 1))
			assert.are.equal(5, move(3, 1))
		end)

		it("moves up to the first line of the previous block, skipping empty lines", function()
			assert.are.equal(2, move(5, -1))
			assert.are.equal(5, move(6, -1))
		end)

		it("moves up to the first line of the current block when the cursor is inside it", function()
			assert.are.equal(2, move(4, -1))
			assert.are.equal(6, move(7, -1))
		end)

		it("moves by as many blocks as the count", function()
			assert.are.equal(6, move(1, 3))
			assert.are.equal(1, move(6, -3))
			assert.are.equal(1, move(4, -2))
		end)

		it("stops at the first and the last block", function()
			assert.are.equal(6, move(5, 10))
			assert.are.equal(1, move(2, -10))
		end)

		it("stays inside the last block when moving down, instead of moving up to its first line", function()
			assert.are.equal(7, move(7, 1))
		end)

		it("keeps the cursor column across shorter lines, like plain j and k", function()
			local subjects = { "a long subject line for the first block", "short", "another long subject line" }
			local output = {}
			for i, subject in ipairs(subjects) do
				table.insert(output, string.format("%d%s %d %d 1", i, string.rep("0", 39), i, i))
				table.insert(output, "summary " .. subject)
				table.insert(output, "filename file.lua")
				table.insert(output, "\tline " .. i)
			end
			local view = BlameView:new({
				git_instance = {
					original_file = "/path/to/repo/file.lua",
					git_root = "/path/to/repo",
					get_blame_output = stub({}, "get_blame_output", table.concat(output, "\n")),
				},
			})
			view:mount()
			vim.api.nvim_win_set_cursor(view.blame_winid, { 1, 20 })

			view:move_to_block(1)
			assert.are.same({ 2, 6 }, vim.api.nvim_win_get_cursor(view.blame_winid))

			view:move_to_block(1)
			assert.are.same({ 3, 20 }, vim.api.nvim_win_get_cursor(view.blame_winid))

			view:close()
		end)
	end)

	describe("api for on_attach", function()
		local older_and_uncommitted = table.concat({
			"1111111111111111111111111111111111111111 1 1 2",
			"author First",
			"author-time 123456789",
			"summary first commit",
			"previous 3333333333333333333333333333333333333333 file.lua",
			"filename file.lua",
			"\tline content 1",
			-- `git blame --line-porcelain` repeats the commit information on every line
			"1111111111111111111111111111111111111111 2 2",
			"author First",
			"author-time 123456789",
			"summary first commit",
			"previous 3333333333333333333333333333333333333333 file.lua",
			"filename file.lua",
			"\tline content 2",
			"0000000000000000000000000000000000000000 3 3 1",
			"author Not Committed Yet",
			"filename file.lua",
			"\tline content 3",
		}, "\n")
		local blame_view

		before_each(function()
			blame_view = BlameView:new({
				git_instance = {
					original_file = "/path/to/repo/file.lua",
					git_root = "/path/to/repo",
					get_blame_output = stub({}, "get_blame_output", older_and_uncommitted),
				},
			})
			blame_view:mount()
		end)

		after_each(function()
			blame_view:close()
		end)

		it("describes the view", function()
			local view = blame_view:api()

			assert.are.same({ blame_view.blame_bufnr, blame_view.file_bufnr }, view.buffers)
			assert.are.equal("/path/to/repo/file.lua", view.file)
			assert.are.equal("/path/to/repo", view.git_root)
		end)

		it("sets keymaps like vim.keymap.set, but only in the buffers of the view", function()
			local view = blame_view:api()

			view.keymap.set("n", "yc", "<Cmd>echo 'commit'<CR>", { desc = "Yank commit" })

			local function keymap_in(bufnr)
				return vim.api.nvim_buf_call(bufnr, function()
					return vim.fn.maparg("yc", "n", false, true)
				end)
			end
			for _, bufnr in ipairs({ blame_view.blame_bufnr, blame_view.file_bufnr }) do
				assert.are.equal(1, keymap_in(bufnr).buffer)
				assert.are.equal("Yank commit", keymap_in(bufnr).desc)
			end
			local other_bufnr = vim.api.nvim_create_buf(false, true)
			assert.are.same({}, keymap_in(other_bufnr))
			vim.api.nvim_buf_delete(other_bufnr, { force = true })
		end)

		it("returns the commit of the cursor line, also on the lines without annotation", function()
			local view = blame_view:api()
			vim.api.nvim_win_set_cursor(blame_view.blame_winid, { 2, 0 })

			assert.are.same({
				hash = "1111111111111111111111111111111111111111",
				author = "First",
				time = 123456789,
				summary = "first commit",
			}, view:commit())
		end)

		it("returns no commit for a line that is not committed yet", function()
			local view = blame_view:api()
			vim.api.nvim_win_set_cursor(blame_view.blame_winid, { 3, 0 })

			assert.is_nil(view:commit())
		end)

		it("returns the commit whose version of the file is shown, none for the working tree", function()
			local view = blame_view:api()
			assert.is_nil(view:revision())

			vim.api.nvim_set_current_win(blame_view.blame_winid)
			vim.api.nvim_win_set_cursor(blame_view.blame_winid, { 1, 0 })
			blame_view:navigate_forward()

			assert.are.equal("3333333333333333333333333333333333333333", view:revision())
		end)

		it("closes the view", function()
			local tabpage = blame_view.tabpage

			blame_view:api():close()

			assert.is_false(vim.api.nvim_tabpage_is_valid(tabpage))
		end)
	end)

	describe("local directory", function()
		local git_root, blame_view, other_bufnr, cwd

		before_each(function()
			cwd = vim.fn.getcwd(-1, -1)
			git_root = vim.fn.resolve(vim.fn.tempname())
			vim.fn.mkdir(git_root, "p")
			blame_view = BlameView:new({
				git_instance = {
					original_file = git_root .. "/file.lua",
					git_root = git_root,
					get_blame_output = stub({}, "get_blame_output", blame_output_with_lines(3)),
				},
			})
			other_bufnr = vim.api.nvim_create_buf(true, false)
		end)

		after_each(function()
			local tabpage = blame_view.tabpage
			blame_view:close()
			if tabpage == nil then
				-- The tab page stays after the view is handed over
				vim.cmd("tabclose!")
			end
			vim.api.nvim_buf_delete(other_bufnr, { force = true })
			-- Also clears a local directory of the test
			vim.cmd.cd(vim.fn.fnameescape(cwd))
			vim.fn.delete(git_root, "rf")
		end)

		local function hand_over_file_window()
			local file_winid = blame_view.file_winid
			vim.api.nvim_set_current_win(file_winid)
			vim.api.nvim_win_set_buf(file_winid, other_bufnr)
			vim.wait(100, function()
				return blame_view.tabpage == nil
			end)
			return file_winid
		end

		it("uses the root of the repository in the windows of the view only", function()
			local cwd = vim.fn.getcwd()

			blame_view:mount()

			assert.are.equal(git_root, vim.fn.getcwd(blame_view.blame_winid))
			assert.are.equal(git_root, vim.fn.getcwd(blame_view.file_winid))
			assert.are.equal(cwd, vim.fn.getcwd(-1))
		end)

		it("clears the local directory of a window that is handed over", function()
			blame_view:mount()

			local winid = hand_over_file_window()

			assert.are.equal(0, vim.fn.haslocaldir(winid))
			assert.are.equal(vim.fn.getcwd(-1), vim.fn.getcwd(winid))
		end)

		it("restores the local directory of the window the view was opened from", function()
			local local_dir = git_root .. "/local"
			vim.fn.mkdir(local_dir, "p")
			vim.cmd.lcd(vim.fn.fnameescape(local_dir))
			blame_view:mount()

			local winid = hand_over_file_window()

			assert.are.equal(local_dir, vim.fn.getcwd(winid))
		end)
	end)
end)
