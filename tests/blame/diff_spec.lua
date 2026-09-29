-- tests/blame/diff_spec.lua

local assert = require("luassert")
local diff = require("blame.diff")

describe("blame.diff", function()
	describe("old_line", function()
		it("returns the same line if nothing changed", function()
			assert.are.equal(7, diff.old_line("", 7))
		end)

		it("returns the same line before the first hunk", function()
			assert.are.equal(4, diff.old_line("@@ -10,2 +10,3 @@\n-a\n-b\n+A\n+B\n+C\n", 4))
		end)

		it("returns the line at the same position of a changed hunk", function()
			assert.are.equal(11, diff.old_line("@@ -10,2 +10,3 @@\n-a\n-b\n+A\n+B\n+C\n", 11))
		end)

		it("returns the last old line of a hunk with more new than old lines", function()
			assert.are.equal(11, diff.old_line("@@ -10,2 +10,3 @@\n-a\n-b\n+A\n+B\n+C\n", 12))
		end)

		it("returns the line that follows added lines", function()
			assert.are.equal(6, diff.old_line("@@ -5,0 +6,2 @@\n+A\n+B\n", 7))
		end)

		it("shifts lines after added lines", function()
			assert.are.equal(6, diff.old_line("@@ -5,0 +6,2 @@\n+A\n+B\n", 8))
		end)

		it("shifts lines after deleted lines", function()
			assert.are.equal(7, diff.old_line("@@ -5,2 +4,0 @@\n-a\n-b\n", 5))
		end)

		it("reads hunks of a single line without a count", function()
			assert.are.equal(20, diff.old_line("@@ -3 +3 @@\n-a\n+A\n@@ -20 +21,2 @@\n-b\n+B\n+C\n", 21))
		end)

		it("adds up the shifts of all hunks before the line", function()
			assert.are.equal(25, diff.old_line("@@ -3,0 +4,2 @@\n+A\n+B\n@@ -10,3 +12 @@\n-a\n-b\n-c\n+C\n", 25))
		end)
	end)
end)
