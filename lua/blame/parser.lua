-- lua/blame/parser.lua
-- This module will contain parsing logic for git blame output.

local M = {}

function M.parse_blame_output(blame_result_stdout)
	local parsed_blame_lines = {}

	for _, line in ipairs(vim.split(blame_result_stdout, "\n")) do
		local commit = line:match("^%S+")
		local rest = line:match("^%S+%s+(.*)")
		if rest then
			local author_date, content = rest:match("%((.*)%) (.*)")
			if author_date and content then
				local author = author_date:match("^(.*)%s+%d%d%d%d%-%d%d%-%d%d")
				local date = author_date:match("%d%d%d%d%-%d%d%-%d%d")
				author = author:gsub("^%s*", ""):gsub("%s*$", "")
				local blame_info = string.format("%s %s (%s)", commit, author, date)
				table.insert(parsed_blame_lines, { info = blame_info, commit = commit })
			end
		end
	end
	return parsed_blame_lines
end

return M
