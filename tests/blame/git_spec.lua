-- tests/lua/git_spec.lua

local assert = require("luassert")
local stub = require("luassert.stub")
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

			-- Check if git_root contains the .git directory or file
			local check = vim.fn.isdirectory(git.git_root .. "/.git") == 1
				or vim.fn.filereadable(git.git_root .. "/.git") == 1
			assert.is_true(check)

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

	describe("get_commit_message", function()
		local repo
		local git
		local git_env = {
			GIT_CONFIG_GLOBAL = "/dev/null",
			GIT_CONFIG_NOSYSTEM = "1",
			GIT_AUTHOR_NAME = "Test Author",
			GIT_AUTHOR_EMAIL = "author@example.com",
			GIT_AUTHOR_DATE = "2026-01-02T03:04:05+0000",
			GIT_COMMITTER_NAME = "Test Committer",
			GIT_COMMITTER_EMAIL = "committer@example.com",
			GIT_COMMITTER_DATE = "2026-01-02T03:04:05+0000",
		}
		local previous_env = {}

		before_each(function()
			-- The user config must not change the output, e.g. with `log.date`
			for name, value in pairs(git_env) do
				previous_env[name] = vim.env[name]
				vim.env[name] = value
			end
			repo = vim.fn.tempname()
			vim.fn.mkdir(repo, "p")
			vim.system({ "git", "init", "--quiet" }, { cwd = repo }):wait()
			vim.system(
				{ "git", "commit", "--quiet", "--allow-empty", "-m", "Add a subject", "-m", "Explain why." },
				{ cwd = repo }
			):wait()
			local buf_id = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buf_id, repo .. "/file")
			git = Git:new(buf_id)
			vim.api.nvim_buf_delete(buf_id, { force = true })
		end)

		after_each(function()
			for name in pairs(git_env) do
				vim.env[name] = previous_env[name]
			end
			vim.fn.delete(repo, "rf")
		end)

		it("returns the message, hash, author and date of a commit", function()
			assert(git)

			local message = git:get_commit_message("HEAD")

			assert.are.same({
				"commit a91719acddede54654abd65439ae1535ad22819c",
				"Author: Test Author <author@example.com>",
				"Date:   Fri Jan 2 03:04:05 2026 +0000",
				"",
				"    Add a subject",
				"    ",
				"    Explain why.",
			}, message)
		end)

		it("returns plain text even if the user config enables colors", function()
			assert(git)
			vim.env.GIT_CONFIG_COUNT = "1"
			vim.env.GIT_CONFIG_KEY_0 = "color.ui"
			vim.env.GIT_CONFIG_VALUE_0 = "always"

			local message = git:get_commit_message("HEAD")

			vim.env.GIT_CONFIG_COUNT = nil
			vim.env.GIT_CONFIG_KEY_0 = nil
			vim.env.GIT_CONFIG_VALUE_0 = nil
			assert(message)
			assert.are.equal("commit a91719acddede54654abd65439ae1535ad22819c", message[1])
		end)

		it("returns nil and shows a warning if the commit does not exist", function()
			assert(git)
			local notify_stub = stub(vim, "notify")

			assert.is_nil(git:get_commit_message("does-not-exist"))

			assert.stub(notify_stub).was.called(1)
		end)
	end)
end)
