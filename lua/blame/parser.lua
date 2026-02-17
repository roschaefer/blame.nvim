-- lua/blame/parser.lua
-- This module will contain parsing logic for git blame output.

local M = {}

function M.parse_blame_output(blame_result_stdout)
	local parsed_blame_lines = {}
	local blame_info = {}

	for _, line in ipairs(vim.split(blame_result_stdout, "\n")) do
		-- Silly lua has no regex quantifiers: https://stackoverflow.com/a/32885308
		local commit = line:match("^%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x")
		if commit then
			-- This is the header line for a blame hunk.
			blame_info.commit = commit
		elseif line:sub(1, 7) == "author " then
			blame_info.author = line:sub(8)
		elseif line:sub(1, 12) == "author-time " then
			local timestamp = tonumber(line:sub(13))
			if timestamp then
				blame_info.date = os.date("%Y-%m-%d", timestamp)
			end
		elseif line:sub(1, 1) == "\t" then
			-- This is the actual file content line, which signifies the end of a blame hunk.
			table.insert(parsed_blame_lines, blame_info)
			blame_info = {}
		end
	end
	return parsed_blame_lines
end

return M
