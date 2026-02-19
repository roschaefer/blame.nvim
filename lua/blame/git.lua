-- lua/blame/git.lua
-- This module will contain Git-related utility functions.

local Git = {}
Git.__index = Git

--- Finds the Git root directory for a given file path.
--- @param file_path string The path to the file.
--- @return string|nil The Git root directory, or nil if not found or an error occurred.
local function find_git_root(file_path)
	local git_root_result = vim.system({
		"git",
		"-C",
		vim.fs.dirname(file_path),
		"rev-parse",
		"--show-toplevel",
	}, { text = true }):wait()

	if git_root_result.code ~= 0 then
		if git_root_result.stderr:match("not a git repository") then
			vim.notify("blame.nvim: Not in a git repository.", vim.log.levels.WARN)
		else
			vim.notify("blame.nvim: `git` Stderr: " .. (git_root_result.stderr or ""), vim.log.levels.ERROR)
		end
		return nil
	end
	local git_root = vim.trim(git_root_result.stdout)
	if not git_root or git_root == "" then
		vim.notify("blame.nvim: Could not determine git repository root.", vim.log.levels.WARN)
		return nil
	end
	return git_root
end

--- Initializes a new Git instance for a given buffer.
--- @param buf_id number The buffer ID.
--- @return table|nil A new Git instance, or nil if it's not a file buffer or not in a Git repository.
function Git:new(buf_id)
	local original_file = vim.api.nvim_buf_get_name(buf_id)
	if not original_file or original_file == "" then
		vim.notify("blame.nvim: Not a file buffer.", vim.log.levels.WARN)
		return nil
	end

	local git_root = find_git_root(original_file)
	if not git_root then
		return nil
	end

	local instance = {
		original_file = original_file,
		git_root = git_root,
	}
	setmetatable(instance, Git)
	return instance
end

--- Retrieves the git blame output for a given file.
--- @param commit_info table|nil Optional: The commit info to blame from.
--- @return string|nil The stdout of the git blame command, or nil if an error occurred.
function Git:get_blame_output(commit_info)
	local blame_cmd
	if commit_info and commit_info.previous then
		blame_cmd = {
			"git",
			"blame",
			"--line-porcelain",
			commit_info.previous.commit,
			"--",
			commit_info.previous.filename,
		}
	else
		blame_cmd = { "git", "blame", "--line-porcelain", self.original_file }
	end

	local blame_result = vim.system(blame_cmd, { text = true, cwd = self.git_root }):wait()

	if blame_result.code ~= 0 then
		vim.notify("blame.nvim: Git blame command failed. Stderr: " .. (blame_result.stderr or ""), vim.log.levels.WARN)
		return nil
	end
	return blame_result.stdout
end

--- Retrieves the content of a file, either at a specific commit or the current working tree version.
--- @param commit_info table|nil Optional: The commit info to retrieve the file content from. If nil, the current working tree content is returned.
--- @return table|nil A table of lines representing the file content, or nil if an error occurred.
function Git:get_file_content(commit_info)
	local content_str
	if commit_info and commit_info.previous then
		local git_show_result = vim.system({
			"git",
			"show",
			commit_info.previous.commit .. ":" .. commit_info.previous.filename,
		}, { text = true, cwd = self.git_root }):wait()

		if git_show_result.code ~= 0 then
			vim.notify(
				"blame.nvim: Git show command failed. Stderr: " .. (git_show_result.stderr or ""),
				vim.log.levels.WARN
			)
			return nil
		end
		content_str = git_show_result.stdout
	else
		-- Read from file if commit_info is nil or has no previous (working tree)
		return vim.fn.readfile(self.original_file)
	end
	return vim.split(content_str or "", "\n")
end

return Git
