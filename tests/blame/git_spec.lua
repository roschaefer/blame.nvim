-- tests/lua/git_spec.lua

local assert = require("luassert")
local Git = require("blame.git")

describe("blame.git", function()
	local test_file = "README.md"
	local snapshot

	before_each(function()
		snapshot = assert:snapshot()
	end)

	after_each(function()
		snapshot:revert()
	end)

	describe("Git:new", function()
		it("initializes a new Git instance for README.md", function()
			local buf_id = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buf_id, test_file)

			local git = Git:new(buf_id)
			assert.is_not_nil(git)
			---@cast git -nil
			assert.are.equal(vim.fn.fnamemodify(test_file, ":p"), git.original_file)

			-- Check if git_root contains the .git directory
			local check = vim.fn.isdirectory(git.git_root .. "/.git")
			assert.is_true(check == 1)

			vim.api.nvim_buf_delete(buf_id, { force = true })
		end)

		it("returns nil for a non-git directory", function()
			local tmpdir = vim.fn.tempname()
			vim.fn.mkdir(tmpdir, "p")
			local buf_id = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buf_id, tmpdir .. "/anyfile")

			local git = Git:new(buf_id)
			assert.is_nil(git)

			vim.api.nvim_buf_delete(buf_id, { force = true })
			vim.fn.delete(tmpdir, "rf")
		end)
	end)

	describe("get_blame_output", function()
		it("returns porcelain blame output for README.md", function()
			local buf_id = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buf_id, test_file)
			local git = Git:new(buf_id)
			assert.is_not_nil(git)
			---@cast git -nil

			local output = git:get_blame_output()
			assert(output)
			assert.is_true(string.len(output) > 0)
			-- Porcelain output should start with a commit hash
			local match =
				output:match("^%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x")
			assert.is_not_nil(match)

			vim.api.nvim_buf_delete(buf_id, { force = true })
		end)
	end)
end)
