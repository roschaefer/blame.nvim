local blame = require("blame.parser")

describe("blame.parser", function()
	it("correctly parses git blame --line-porcelain output", function()
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
		local expected = {
			lines = {
				{
					header = {
						commit = "061d471a00000000000000000000000000000000",
						source_line = 1,
						result_line = 1,
						num_lines = 2,
					},
					author = "Author Name",
					author_mail = "<author@example.com>",
					author_time = 1672567200,
					author_tz = "+0000",
					summary = "Summary 1",
					filename = "file.txt",
					line_content = "Line 1 content",
					date = "2023-01-01",
				},
				{
					header = {
						commit = "061d471a00000000000000000000000000000000",
						source_line = 1,
						result_line = 2,
						num_lines = 2,
					},
					author = "Author Name",
					author_mail = "<author@example.com>",
					author_time = 1672567200,
					author_tz = "+0000",
					summary = "Summary 1",
					filename = "file.txt",
					line_content = "Line 2 content",
					date = "2023-01-01",
				},
				{
					header = {
						commit = "4a8e23b100000000000000000000000000000000",
						source_line = 3,
						result_line = 3,
						num_lines = 1,
					},
					author = "Another Author",
					author_mail = "<another@example.com>",
					author_time = 1676457000,
					author_tz = "+0000",
					summary = "Summary 2",
					filename = "file.txt",
					line_content = "Different line content",
					date = "2023-02-15",
				},
			},
		}

		local actual = blame.parse_blame_output(blame_result_stdout)

		assert.are.same(expected, actual)
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
		local expected = {
			lines = {
				{
					header = {
						commit = "0000000000000000000000000000000000000000",
						source_line = 1,
						result_line = 1,
						num_lines = 1,
					},
					author = "Not Committed Yet",
					author_mail = "<not.committed.yet>",
					author_time = 1704110400,
					author_tz = "+0000",
					summary = "",
					filename = "newfile.txt",
					line_content = "New line content",
					date = "2024-01-01",
				},
				{
					header = {
						commit = "0000000000000000000000000000000000000000",
						source_line = 1,
						result_line = 2,
						num_lines = 1,
					},
					author = "Not Committed Yet",
					author_mail = "<not.committed.yet>",
					author_time = 1704110400,
					author_tz = "+0000",
					summary = "",
					filename = "newfile.txt",
					line_content = "Another new line",
					date = "2024-01-01",
				},
			},
		}

		local actual = blame.parse_blame_output(blame_result_stdout)

		assert.are.same(expected, actual)
	end)

	it("returns empty results for empty blame output", function()
		local blame_result_stdout = ""
		local expected = {
			lines = {},
		}

		local actual = blame.parse_blame_output(blame_result_stdout)

		assert.are.same(expected, actual)
	end)

	it("handles author names with special characters or spaces", function()
		local blame_result_stdout = [[
abcdef1200000000000000000000000000000000 1 1 1
author Long Name With (Spaces)
author-time 1709283600
	Some content
]]
		-- 1709283600 is 2024-03-01 10:00:00 +0000
		local expected = {
			lines = {
				{
					header = {
						commit = "abcdef1200000000000000000000000000000000",
						source_line = 1,
						result_line = 1,
						num_lines = 1,
					},
					author = "Long Name With (Spaces)",
					author_time = 1709283600,
					line_content = "Some content",
					date = "2024-03-01",
				},
			},
		}

		local actual = blame.parse_blame_output(blame_result_stdout)

		assert.are.same(expected, actual)
	end)

	it("handles header lines with only 2 numbers after the commit (absent num_lines)", function()
		local blame_result_stdout = [[
061d471a00000000000000000000000000000000 1 1 2
author Author Name
author-time 1672567200
filename file.txt
	Line 1 content
061d471a00000000000000000000000000000000 1 2
author Author Name
author-time 1672567200
filename file.txt
	Line 2 content
]]
		local expected = {
			lines = {
				{
					header = {
						commit = "061d471a00000000000000000000000000000000",
						source_line = 1,
						result_line = 1,
						num_lines = 2,
					},
					author = "Author Name",
					author_time = 1672567200,
					filename = "file.txt",
					line_content = "Line 1 content",
					date = "2023-01-01",
				},
				{
					header = {
						commit = "061d471a00000000000000000000000000000000",
						source_line = 1,
						result_line = 2,
					},
					author = "Author Name",
					author_time = 1672567200,
					filename = "file.txt",
					line_content = "Line 2 content",
					date = "2023-01-01",
				},
			},
		}

		local actual = blame.parse_blame_output(blame_result_stdout)
		assert.are.same(expected, actual)
	end)

	it("handles 'previous' field with commit and filename", function()
		local blame_result_stdout = [[
061d471a00000000000000000000000000000000 1 1 1
author Author Name
author-time 1672567200
previous 4a8e23b100000000000000000000000000000000 old_file.txt
filename file.txt
	Line 1 content
]]
		local expected = {
			lines = {
				{
					header = {
						commit = "061d471a00000000000000000000000000000000",
						source_line = 1,
						result_line = 1,
						num_lines = 1,
					},
					author = "Author Name",
					author_time = 1672567200,
					previous = {
						commit = "4a8e23b100000000000000000000000000000000",
						filename = "old_file.txt",
					},
					filename = "file.txt",
					line_content = "Line 1 content",
					date = "2023-01-01",
				},
			},
		}

		local actual = blame.parse_blame_output(blame_result_stdout)
		assert.are.same(expected, actual)
	end)
end)
