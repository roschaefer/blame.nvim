-- tests/lua/git_spec.lua

local assert = require("luassert")
local stub = require("luassert.stub")
local Git = require("blame.git")

describe("blame.git", function()
	local test_file = "README.md"

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

	describe("get_file_content", function()
		it("reads README.md content from disk when no commit hash is provided", function()
			local buf_id = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buf_id, test_file)
			local git = Git:new(buf_id)
			assert.is_not_nil(git)
			---@cast git -nil

			local content = git:get_file_content()
			assert.is_not_nil(content)
			assert.is_true(#content > 0)

			assert(content)
			assert.are.equal("# blame.nvim", content[1])

			vim.api.nvim_buf_delete(buf_id, { force = true })
		end)

		it("retrieves README.md content from HEAD commit", function()
			local buf_id = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buf_id, test_file)
			local git = Git:new(buf_id)
			assert.is_not_nil(git)
			---@cast git -nil

			-- Get the latest commit hash for README.md
			local hash_result = vim.system({ "git", "rev-parse", "HEAD" }, { text = true, cwd = git.git_root }):wait()
			local head_hash = vim.trim(hash_result.stdout)

			local content = git:get_file_content(head_hash)
			assert.is_not_nil(content)
			assert.is_true(#content > 0)

			-- The first line of README.md should match
			assert(content)
			assert.are.equal("# blame.nvim", content[1])

			vim.api.nvim_buf_delete(buf_id, { force = true })
		end)
	end)
end)
