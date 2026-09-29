-- tests/lua/git_spec.lua

local assert = require("luassert")
local stub = require("luassert.stub")
local Git = require("blame.git")
local parser = require("blame.parser")

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

	describe("get_prior_line", function()
		local repo

		local function git_in_repo(args)
			local cmd = { "git", "-c", "user.name=Test", "-c", "user.email=test@example.com" }
			vim.list_extend(cmd, args)
			return vim.system(cmd, { cwd = repo, text = true }):wait()
		end

		before_each(function()
			repo = vim.fn.tempname()
			vim.fn.mkdir(repo, "p")
			git_in_repo({ "init", "--quiet" })
			vim.fn.writefile({ "one", "two", "three", "four", "five" }, repo .. "/old.txt")
			git_in_repo({ "add", "old.txt" })
			git_in_repo({ "commit", "--quiet", "-m", "Add a file" })
			git_in_repo({ "mv", "old.txt", "new.txt" })
			vim.fn.writefile({ "zero", "half", "one", "two", "three", "FOUR", "five" }, repo .. "/new.txt")
			git_in_repo({ "commit", "--quiet", "--all", "-m", "Change a renamed file" })
		end)

		after_each(function()
			vim.fn.delete(repo, "rf")
		end)

		it("returns the line in the version prior to the commit, also if the file was renamed", function()
			local buf_id = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buf_id, repo .. "/new.txt")
			local git = Git:new(buf_id)
			vim.api.nvim_buf_delete(buf_id, { force = true })
			assert(git)
			local blame_lines = parser.parse_blame_output(assert(git:get_blame_output(nil))).lines
			local changed_line = blame_lines[6]
			assert.are.equal("FOUR", changed_line.line_content)
			assert.are.equal("old.txt", changed_line.previous.filename)

			assert.are.equal(4, git:get_prior_line(changed_line))
		end)

		--- Blames `new.txt` after committing it with other lines.
		local function blame_after_commit(lines)
			vim.fn.writefile(lines, repo .. "/new.txt")
			git_in_repo({ "commit", "--quiet", "--all", "-m", "Change the file again" })
			local buf_id = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buf_id, repo .. "/new.txt")
			local git = assert(Git:new(buf_id))
			vim.api.nvim_buf_delete(buf_id, { force = true })
			return git, parser.parse_blame_output(assert(git:get_blame_output(nil))).lines
		end

		it("keeps nearby hunks apart, even if the user config merges them", function()
			git_in_repo({ "config", "diff.interHunkContext", "3" })

			local git, blame_lines =
				blame_after_commit({ "zero", "half", "one", "X", "two", "Y", "three", "FOUR", "five" })

			assert.are.equal("Y", blame_lines[6].line_content)
			assert.are.equal(5, git:get_prior_line(blame_lines[6]))
		end)

		it("compares files as text, even if they are marked as binary", function()
			vim.fn.writefile({ "* -diff" }, repo .. "/.git/info/attributes")

			local git, blame_lines = blame_after_commit({ "one", "two", "X", "FOUR", "five" })

			assert.are.equal("X", blame_lines[3].line_content)
			assert.are.equal(5, git:get_prior_line(blame_lines[3]))
		end)

		it("finds the line in a file renamed to a name that git quotes", function()
			git_in_repo({ "mv", "new.txt", 'café "q".txt' })
			vim.fn.writefile({ "zero", "half", "one", "X", "two", "three", "FOUR", "five" }, repo .. '/café "q".txt')
			git_in_repo({ "commit", "--quiet", "--all", "-m", "Rename the file" })
			local buf_id = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buf_id, repo .. '/café "q".txt')
			local git = assert(Git:new(buf_id))
			vim.api.nvim_buf_delete(buf_id, { force = true })
			local blame_lines = parser.parse_blame_output(assert(git:get_blame_output(nil))).lines

			assert.are.equal("X", blame_lines[4].line_content)
			assert.are.equal('café "q".txt', blame_lines[4].filename)
			assert.are.equal(4, git:get_prior_line(blame_lines[4]))
		end)

		it("returns nil if there is no version prior to the commit", function()
			local buf_id = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buf_id, repo .. "/new.txt")
			local git = Git:new(buf_id)
			vim.api.nvim_buf_delete(buf_id, { force = true })
			assert(git)
			local blame_lines = parser.parse_blame_output(assert(git:get_blame_output(nil))).lines

			assert.is_nil(git:get_prior_line(blame_lines[3]))
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
