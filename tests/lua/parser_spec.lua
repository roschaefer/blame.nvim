local blame = require("blame.parser")

describe("blame.parser", function()
	it("correctly parses git blame --porcelain output", function()
		local blame_result_stdout = [[
061d471a00000000000000000000000000000000 1 1 2
author Author Name
author-mail <author@example.com>
author-time 1672567200
author-tz +0000
summary Summary 1
filename file.txt
	Line 1 content
061d471a00000000000000000000000000000000 1 2 2
author Author Name
author-mail <author@example.com>
author-time 1672567200
author-tz +0000
summary Summary 1
filename file.txt
	Line 2 content
4a8e23b100000000000000000000000000000000 3 3 1
author Another Author
author-mail <another@example.com>
author-time 1676457000
author-tz +0000
summary Summary 2
filename file.txt
	Different line content
]]
		local expected_blame_lines = {
			{
				commit = "061d471a00000000000000000000000000000000",
				author = "Author Name",
				date = "2023-01-01",
			},
			{
				commit = "061d471a00000000000000000000000000000000",
				author = "Author Name",
				date = "2023-01-01",
			},
			{
				commit = "4a8e23b100000000000000000000000000000000",
				author = "Another Author",
				date = "2023-02-15",
			},
		}

		local actual_blame_lines = blame.parse_blame_output(blame_result_stdout)

		assert.are.same(expected_blame_lines, actual_blame_lines)
	end)

	it("handles blame output for uncommitted changes", function()
		local blame_result_stdout = [[
0000000000000000000000000000000000000000 1 1 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1704110400
author-tz +0000
summary
filename newfile.txt
	New line content
0000000000000000000000000000000000000000 1 2 1
author Not Committed Yet
author-mail <not.committed.yet>
author-time 1704110400
author-tz +0000
summary
filename newfile.txt
	Another new line
]]
		local expected_blame_lines = {
			{
				commit = "0000000000000000000000000000000000000000",
				author = "Not Committed Yet",
				date = "2024-01-01",
			},
			{
				commit = "0000000000000000000000000000000000000000",
				author = "Not Committed Yet",
				date = "2024-01-01",
			},
		}

		local actual_blame_lines = blame.parse_blame_output(blame_result_stdout)

		assert.are.same(expected_blame_lines, actual_blame_lines)
	end)

	it("returns empty results for empty blame output", function()
		local blame_result_stdout = ""
		local expected_blame_lines = {}

		local actual_blame_lines = blame.parse_blame_output(blame_result_stdout)

		assert.are.same(expected_blame_lines, actual_blame_lines)
	end)

	it("handles author names with special characters or spaces", function()
		local blame_result_stdout = [[
abcdef1200000000000000000000000000000000 1 1 1
author Long Name With (Spaces)
author-time 1709283600
	Some content
]]
		-- 1709283600 is 2024-03-01 10:00:00 +0000
		local expected_blame_lines = {
			{
				commit = "abcdef1200000000000000000000000000000000",
				author = "Long Name With (Spaces)",
				date = "2024-03-01",
			},
		}

		local actual_blame_lines = blame.parse_blame_output(blame_result_stdout)

		assert.are.same(expected_blame_lines, actual_blame_lines)
	end)
end)
