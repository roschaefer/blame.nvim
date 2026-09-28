-- lua/blame/diff.lua
-- Parses the output of `git diff --unified=0`.

local M = {}

--- Returns the line of the old version of a file that corresponds to a line of the new version.
--- A changed line corresponds to the line at the same position in the old lines of its hunk, or to the last of them.
--- An added line corresponds to the line that follows the place it was added at.
--- @param diff_output string The output of `git diff --unified=0` from the old to the new version
--- @param new_line number
--- @return number
function M.old_line(diff_output, new_line)
	local offset = 0
	for line in vim.gsplit(diff_output, "\n") do
		local old_start, old_count, new_start, new_count = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
		if old_start then
			old_count = tonumber(old_count) or 1
			new_count = tonumber(new_count) or 1
			-- The start of an empty side is the line before the hunk
			local old_first = tonumber(old_start) + (old_count == 0 and 1 or 0)
			local new_first = tonumber(new_start) + (new_count == 0 and 1 or 0)
			if new_line < new_first then
				break
			end
			if new_line < new_first + new_count then
				return old_first + math.min(new_line - new_first, math.max(old_count - 1, 0))
			end
			offset = (old_first + old_count) - (new_first + new_count)
		end
	end
	return new_line + offset
end

return M
