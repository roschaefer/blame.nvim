-- tests/lua/popups_spec.lua

local assert = require("luassert")
local stub = require("luassert.stub")
local Popups = require("blame.popups")

describe("blame.popups", function()
	local snapshot
	before_each(function()
		snapshot = assert:snapshot()
	end)

	after_each(function()
		snapshot:revert()
	end)

	it("initializes a new Popups instance", function()
		local buf_id = vim.api.nvim_create_buf(false, true)
		local mock_git = {
			original_file = "/path/to/repo/file.lua",
			git_root = "/path/to/repo",
		}

		local blame_popup = { bufnr = 101 }
		local file_popup = { bufnr = 102 }

		local popups = Popups:new({
			git_instance = mock_git,
			blame_popup_instance = blame_popup,
			file_popup_instance = file_popup,
		}, buf_id)

		assert.is_not_nil(popups)
		---@cast popups -nil
		assert.are.equal(mock_git, popups.git_instance)
		assert.are.equal(blame_popup, popups.blame_popup_instance)
		assert.are.equal(file_popup, popups.file_popup_instance)

		vim.api.nvim_buf_delete(buf_id, { force = true })
	end)

	it("updates file buffer content", function()
		local buf_id = vim.api.nvim_create_buf(false, true)
		local mock_git = {
			get_file_content = stub({}, "get_file_content", { "line 1", "line 2" }),
		}

		local blame_popup = { bufnr = vim.api.nvim_create_buf(false, true) }
		local file_popup = { bufnr = vim.api.nvim_create_buf(false, true) }

		local popups = Popups:new({
			git_instance = mock_git,
			blame_popup_instance = blame_popup,
			file_popup_instance = file_popup,
		}, buf_id)
		assert.is_not_nil(popups)
		---@cast popups -nil

		popups:update_file_buffer_content("abc1234")

		assert.stub(mock_git.get_file_content).was.called_with(mock_git, "abc1234")

		local content = vim.api.nvim_buf_get_lines(file_popup.bufnr, 0, -1, false)
		assert.are.same({ "line 1", "line 2" }, content)

		vim.api.nvim_buf_delete(buf_id, { force = true })
		vim.api.nvim_buf_delete(blame_popup.bufnr, { force = true })
		vim.api.nvim_buf_delete(file_popup.bufnr, { force = true })
	end)
end)
