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
		}, buf_id)

		assert.is_not_nil(blame_view)
		---@cast blame_view -nil
		assert.are.equal(mock_git, blame_view.git_instance)
		assert.is_not_nil(blame_view.blame_popup_instance)
		assert.is_not_nil(blame_view.file_popup_instance)
		assert.is_not_nil(blame_view.layout)

		vim.api.nvim_buf_delete(buf_id, { force = true })
	end)

	it("updates file buffer content", function()
		local buf_id = vim.api.nvim_create_buf(false, true)
		local mock_git = {
			get_file_content = stub({}, "get_file_content", { "line 1", "line 2" }),
		}

		local blame_view = BlameView:new({
			git_instance = mock_git,
		}, buf_id)
		assert.is_not_nil(blame_view)
		---@cast blame_view -nil

		local commit_info = { previous = { commit = "abc1234", filename = "file.lua" } }
		blame_view:update_file_buffer_content(commit_info)

		assert.stub(mock_git.get_file_content).was.called_with(mock_git, commit_info)

		local content = vim.api.nvim_buf_get_lines(blame_view.file_popup_instance.bufnr, 0, -1, false)
		assert.are.same({ "line 1", "line 2" }, content)

		vim.api.nvim_buf_delete(buf_id, { force = true })
	end)

	it("mounts the layout and initializes positions", function()
		local buf_id = vim.api.nvim_create_buf(false, true)
		local mock_git = {}
		local blame_view = BlameView:new({ git_instance = mock_git }, buf_id)

		local blame_view_layout_mount_spy = spy.on(blame_view.layout, "mount")
		local utils = require("blame.utils")
		local utils_initialize_cursor_position_spy = spy.on(utils, "initialize_cursor_position")

		blame_view:mount()

		assert.spy(blame_view_layout_mount_spy).was.called(1)
		assert.spy(utils_initialize_cursor_position_spy).was.called(2)

		vim.api.nvim_buf_delete(buf_id, { force = true })
	end)
end)
