-- lua/blame/git.lua
-- This module will contain Git-related utility functions.

local M = {}

--- Finds the Git root directory for a given file path.
--- @param file_path string The path to the file.
--- @return string|nil The Git root directory, or nil if not found or an error occurred.
function M.find_git_root(file_path)
	local git_root_result = vim.system({
		"git",
		"-C",
		vim.fs.dirname(file_path),
		"rev-parse",
		"--show-toplevel",
	}, { text = true }):wait()

	if git_root_result.code ~= 0 then
		vim.notify(
			"blame.nvim: Not in a git repository. Stderr: " .. (git_root_result.stderr or ""),
			vim.log.levels.WARN
		)
		return nil
	end
	local git_root = vim.trim(git_root_result.stdout)
	if not git_root or git_root == "" then
		vim.notify("blame.nvim: Could not determine git repository root.", vim.log.levels.WARN)
		return nil
	end
	return git_root
end

--- Retrieves the git blame output for a given file.
--- @param git_root string The root directory of the Git repository.
--- @param current_file string The path to the file to blame.
--- @param commit_hash_to_blame string|nil Optional: The commit hash to blame from.
--- @return string|nil The stdout of the git blame command, or nil if an error occurred.
function M.get_blame_output(git_root, current_file, commit_hash_to_blame)
	local blame_cmd
	if commit_hash_to_blame then
		blame_cmd = { "git", "blame", "--line-porcelain", commit_hash_to_blame, "--", current_file }
	else
		blame_cmd = { "git", "blame", "--line-porcelain", current_file }
	end

	local blame_result = vim.system(blame_cmd, { text = true, cwd = git_root }):wait()

	if blame_result.code ~= 0 then
		vim.notify("blame.nvim: Git blame command failed. Stderr: " .. (blame_result.stderr or ""), vim.log.levels.WARN)
		return nil
	end
	return blame_result.stdout
end

--- Retrieves the content of a file at a specific commit.
--- @param git_root string The root directory of the Git repository.
--- @param file_path_relative_to_git_root string The path to the file relative to the git root.
--- @param commit_hash string The commit hash.
--- @return string|nil The content of the file, or nil if an error occurred.
function M.get_file_content_at_commit(git_root, file_path_relative_to_git_root, commit_hash)
	local git_show_result = vim.system({
		"git",
		"show",
		commit_hash .. ":" .. file_path_relative_to_git_root,
	}, { text = true, cwd = git_root }):wait()

	if git_show_result.code ~= 0 then
		vim.notify(
			"blame.nvim: Git show command failed. Stderr: " .. (git_show_result.stderr or ""),
			vim.log.levels.WARN
		)
		return nil
	end
	return git_show_result.stdout
end

--- Retrieves the content of a file, either at a specific commit or the current working tree version.
--- @param git_root string The root directory of the Git repository.
--- @param current_file string The full path to the current file.
--- @param commit_hash string|nil Optional: The commit hash to retrieve the file content from. If nil, the current working tree content is returned.
--- @return table|nil A table of lines representing the file content, or nil if an error occurred.
function M.get_file_content(git_root, current_file, commit_hash)
	local content_str
	if commit_hash then
		local file_path_relative_to_git_root = vim.fs.relpath(git_root, current_file)
		if not file_path_relative_to_git_root then
			return nil
		end
		content_str = M.get_file_content_at_commit(git_root, file_path_relative_to_git_root, commit_hash)
		if not content_str then
			return nil
		end
	else
		-- Read from file if commit_hash is nil
		-- vim.fn.readfile returns a list of lines
		return vim.fn.readfile(current_file)
	end
	return vim.split(content_str, "\n")
end

return M
