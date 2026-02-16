local blame = require("blame.parser")
local assert = require("luassert")

describe("blame.parser", function()
	it("correctly parses standard git blame output", function()
		local blame_result_stdout = [[
^061d471a (Author Name 2023-01-01 10:00:00 +0000 1) Line 1 content
^061d471a (Author Name 2023-01-01 10:00:00 +0000 2) Line 2 content
4a8e23b1 (Another Author 2023-02-15 11:30:00 +0000 3) Different line content
]]
		local expected_blame_lines = {
			{ info = "^061d471a Author Name (2023-01-01)", commit = "^061d471a" },
			{ info = "^061d471a Author Name (2023-01-01)", commit = "^061d471a" },
			{ info = "4a8e23b1 Another Author (2023-02-15)", commit = "4a8e23b1" },
		}

		local actual_blame_lines = blame.parse_blame_output(blame_result_stdout)

		assert.are.same(expected_blame_lines, actual_blame_lines)
	end)

	it("handles blame output with no author/date information (e.g., deleted files in history)", function()
		local blame_result_stdout = [[
^00000000 (Not Committed Yet 2024-01-01 12:00:00 +0000 1) New line content
00000000 (Not Committed Yet 2024-01-01 12:00:00 +0000 2) Another new line
]]
		local expected_blame_lines = {
			{ info = "^00000000 Not Committed Yet (2024-01-01)", commit = "^00000000" },
			{ info = "00000000 Not Committed Yet (2024-01-01)", commit = "00000000" },
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

	it("handles multiline author names correctly", function()
		local blame_result_stdout = [[
^abcdef12 (Long Name With Spaces 2024-03-01 10:00:00 +0000 1) Some content
    ]]
		local expected_blame_lines = {
			{ info = "^abcdef12 Long Name With Spaces (2024-03-01)", commit = "^abcdef12" },
		}

		local actual_blame_lines = blame.parse_blame_output(blame_result_stdout)

		assert.are.same(expected_blame_lines, actual_blame_lines)
	end)

	it("parses author name with parentheses", function()
		local blame_result_stdout = [[
44e1c83c84 (Min Idzelis             2025-08-24 14:09:45 -0400 101)       - sveltekit:/usr/src/app/web/.svelte-kit
44e1c83c84 (Min Idzelis             2025-08-24 14:09:45 -0400 102)       - coverage:/usr/src/app/web/coverage
383f11019a (Alessandro (Ale) Segala 2023-10-20 11:26:28 -0700 103)     ulimits:
383f11019a (Alessandro (Ale) Segala 2023-10-20 11:26:28 -0700 104)       nofile:
383f11019a (Alessandro (Ale) Segala 2023-10-20 11:26:28 -0700 105)         soft: 1048576
383f11019a (Alessandro (Ale) Segala 2023-10-20 11:26:28 -0700 106)         hard: 1048576
814030be77 (Rohitt Vashishtha       2023-07-06 01:53:23 +0530 107)     restart: unless-stopped
83cbf51704 (Alex                    2022-07-26 12:28:07 -0500 108)     depends_on:
    ]]
		local actual_blame_lines = blame.parse_blame_output(blame_result_stdout)

		local expected_blame_lines = {
			{ info = "44e1c83c84 Min Idzelis (2025-08-24)", commit = "44e1c83c84" },
			{ info = "44e1c83c84 Min Idzelis (2025-08-24)", commit = "44e1c83c84" },
			{ info = "383f11019a Alessandro (Ale) Segala (2023-10-20)", commit = "383f11019a" },
			{ info = "383f11019a Alessandro (Ale) Segala (2023-10-20)", commit = "383f11019a" },
			{ info = "383f11019a Alessandro (Ale) Segala (2023-10-20)", commit = "383f11019a" },
			{ info = "383f11019a Alessandro (Ale) Segala (2023-10-20)", commit = "383f11019a" },
			{ info = "814030be77 Rohitt Vashishtha (2023-07-06)", commit = "814030be77" },
			{ info = "83cbf51704 Alex (2022-07-26)", commit = "83cbf51704" },
		}

		assert.are.same(expected_blame_lines, actual_blame_lines)
	end)
end)
