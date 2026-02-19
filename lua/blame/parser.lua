-- lua/blame/parser.lua
-- This module will contain parsing logic for git blame output.

local M = {}

---@class Header
---@field commit string
---@field source_line number
---@field result_line number
---@field num_lines number|nil

---@class Previous
---@field commit string
---@field filename string

---@class Porcelain
---@field header Header
---@field author string
---@field author_mail string
---@field author_time number
---@field author_tz string
---@field committer string
---@field committer_mail string
---@field committer_time number
---@field committer_tz string
---@field summary string
---@field boundary boolean|nil
---@field previous Previous|nil
---@field filename string
---@field line_content string
---@field date string (computed from author_time)

--- Parses the git blame --line-porcelain output.
--- @param blame_result_stdout string The stdout of the git blame command.
--- @return table A table with a 'lines' field containing a list of Porcelain objects.
function M.parse_blame_output(blame_result_stdout)
	local result = {
		lines = {},
	}

	if not blame_result_stdout or blame_result_stdout == "" then
		return result
	end

	local current_porcelain = {}

	for _, line in ipairs(vim.split(blame_result_stdout, "\n")) do
		if line:sub(1, 1) == "\t" then
			-- This is the actual file content line, which signifies the end of a blame hunk for this line.
			current_porcelain.line_content = line:sub(2)
			table.insert(result.lines, current_porcelain)
			current_porcelain = {}
		else
			-- Try to match the header line
			local commit, source_line, result_line, num_lines = line:match("^(%x+) (%d+) (%d+) ?(%d*)")
			if commit and source_line and result_line then
				current_porcelain.header = {
					commit = commit,
					source_line = tonumber(source_line),
					result_line = tonumber(result_line),
				}
				if num_lines ~= "" then
					current_porcelain.header.num_lines = tonumber(num_lines)
				end
			elseif line:sub(1, 7) == "author " then
				current_porcelain.author = line:sub(8)
			elseif line:sub(1, 12) == "author-mail " then
				current_porcelain.author_mail = line:sub(13)
			elseif line:sub(1, 12) == "author-time " then
				current_porcelain.author_time = tonumber(line:sub(13))
				if current_porcelain.author_time then
					current_porcelain.date = os.date("%Y-%m-%d", current_porcelain.author_time)
				end
			elseif line:sub(1, 10) == "author-tz " then
				current_porcelain.author_tz = line:sub(11)
			elseif line:sub(1, 10) == "committer " then
				current_porcelain.committer = line:sub(11)
			elseif line:sub(1, 15) == "committer-mail " then
				current_porcelain.committer_mail = line:sub(16)
			elseif line:sub(1, 15) == "committer-time " then
				current_porcelain.committer_time = tonumber(line:sub(16))
			elseif line:sub(1, 13) == "committer-tz " then
				current_porcelain.committer_tz = line:sub(14)
			elseif line:sub(1, 7) == "summary" then
				current_porcelain.summary = line:sub(9)
			elseif line == "boundary" then
				current_porcelain.boundary = true
			elseif line:sub(1, 9) == "previous " then
				local prev_commit, prev_filename = line:match("^previous (%x+) (.+)$")
				if prev_commit and prev_filename then
					current_porcelain.previous = {
						commit = prev_commit,
						filename = prev_filename,
					}
				end
			elseif line:sub(1, 9) == "filename " then
				current_porcelain.filename = line:sub(10)
			end
		end
	end
	return result
end

return M
