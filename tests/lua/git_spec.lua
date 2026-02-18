-- tests/lua/git_spec.lua

local assert = require("luassert")
local git = require("blame.git")

describe("blame.git", function()
	local test_file = "README.md"

	describe("find_git_root", function()
		it("returns the current project root for README.md", function()
			local root = git.find_git_root(test_file)
			assert(root)
			-- Check if it contains the .git directory
			local check = vim.fn.isdirectory(root .. "/.git")
			assert.is_true(check == 1)
		end)

		it("returns nil for a non-git directory", function()
			-- /tmp is usually not a git repo, but let's be safer and use a temp dir
			local tmpdir = vim.fn.tempname()
			vim.fn.mkdir(tmpdir, "p")
			local root = git.find_git_root(tmpdir .. "/anyfile")
			assert.is_nil(root)
		end)
	end)

	describe("get_blame_output", function()
		it("returns porcelain blame output for README.md", function()
			local root = git.find_git_root(test_file)
			assert(root)
			local output = git.get_blame_output(root, test_file)
			assert(output)
			assert.is_true(string.len(output) > 0)
			-- Porcelain output should start with a commit hash
			local match =
				output:match("^%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x")
			assert.is_not_nil(match)
		end)
	end)

	describe("get_file_content", function()
		it("reads README.md content from disk when no commit hash is provided", function()
			local root = git.find_git_root(test_file)
			assert(root)
			local content = git.get_file_content(root, test_file)
			assert.is_not_nil(content)
			assert.is_true(#content > 0)

			assert(content)
			assert.are.equal("# blame.nvim", content[1])
		end)

		it("retrieves README.md content from HEAD commit", function()
			local root = git.find_git_root(test_file)
			assert(root)
			-- Get the latest commit hash for README.md
			local hash_result = vim.system({ "git", "rev-parse", "HEAD" }, { text = true, cwd = root }):wait()
			local head_hash = vim.trim(hash_result.stdout)

			local content = git.get_file_content(root, test_file, head_hash)
			assert.is_not_nil(content)
			assert.is_true(#content > 0)

			-- The first line of README.md should match
			assert(content)
			assert.are.equal("# blame.nvim", content[1])
		end)
	end)
end)
