-- tests/lua/popups_spec.lua

local assert = require("luassert")
local Popups = require("blame.popups")
local git = require("blame.git")

describe("blame.popups", function()
	local mock_git = {}
	local original_git_find_root = git.find_git_root
	local original_git_get_file_content = git.get_file_content
	local original_notify = vim.notify

	before_each(function()
		---@diagnostic disable-next-line: duplicate-set-field
		git.find_git_root = function()
			return "/path/to/repo"
		end
		---@diagnostic disable-next-line: duplicate-set-field
		git.get_file_content = function()
			return { "line 1", "line 2" }
		end
		---@diagnostic disable-next-line: duplicate-set-field
		vim.notify = function() end
	end)

	after_each(function()
		---@diagnostic disable-next-line: duplicate-set-field
		git.find_git_root = original_git_find_root
		---@diagnostic disable-next-line: duplicate-set-field
		git.get_file_content = original_git_get_file_content
		---@diagnostic disable-next-line: duplicate-set-field
		vim.notify = original_notify
	end)

	it("initializes a new Popups instance", function()
		local buf_id = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(buf_id, "/path/to/repo/file.lua")

		local blame_popup = { bufnr = 101 }
		local file_popup = { bufnr = 102 }

		local popups = Popups:new(buf_id, blame_popup, file_popup)

		assert.is_not_nil(popups)
		---@cast popups -nil
		assert.are.equal("/path/to/repo/file.lua", popups.current_file)
		assert.are.equal("/path/to/repo", popups.git_root)
		assert.are.equal(blame_popup, popups.blame_popup_instance)
		assert.are.equal(file_popup, popups.file_popup_instance)

		vim.api.nvim_buf_delete(buf_id, { force = true })
	end)

	it("updates file buffer content", function()
		local buf_id = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(buf_id, "/path/to/repo/file.lua")

		local blame_popup = { bufnr = vim.api.nvim_create_buf(false, true) }
		local file_popup = { bufnr = vim.api.nvim_create_buf(false, true) }

		local popups = Popups:new(buf_id, blame_popup, file_popup)
		assert.is_not_nil(popups)
		---@cast popups -nil

		popups:update_file_buffer_content("abc1234")

		local content = vim.api.nvim_buf_get_lines(file_popup.bufnr, 0, -1, false)
		assert.are.same({ "line 1", "line 2" }, content)

		vim.api.nvim_buf_delete(buf_id, { force = true })
		vim.api.nvim_buf_delete(blame_popup.bufnr, { force = true })
		vim.api.nvim_buf_delete(file_popup.bufnr, { force = true })
	end)
end)
