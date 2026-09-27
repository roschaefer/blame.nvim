-- tests/blame/relative_date_spec.lua

local assert = require("luassert")
local relative_date = require("blame.relative_date")

describe("blame.relative_date", function()
	local now = 1790000000
	local minute = 60
	local hour = 60 * minute
	local day = 24 * hour

	local function format_ago(seconds)
		return relative_date.format(now - seconds, now)
	end

	it("formats the current second as now", function()
		assert.are.equal("now", format_ago(0))
	end)

	it("formats timestamps in the future as now, because clocks of committers may be ahead", function()
		assert.are.equal("now", format_ago(-3600))
	end)

	it("formats seconds", function()
		assert.are.equal("1 second ago", format_ago(1))
		assert.are.equal("54 seconds ago", format_ago(54))
	end)

	it("formats minutes, rounded", function()
		assert.are.equal("1 minute ago", format_ago(55))
		assert.are.equal("1 minute ago", format_ago(89))
		assert.are.equal("2 minutes ago", format_ago(90))
		assert.are.equal("54 minutes ago", format_ago(54 * minute))
	end)

	it("formats hours, rounded", function()
		assert.are.equal("1 hour ago", format_ago(55 * minute))
		assert.are.equal("20 hours ago", format_ago(20 * hour))
	end)

	it("formats one day as yesterday", function()
		assert.are.equal("yesterday", format_ago(21 * hour))
		assert.are.equal("yesterday", format_ago(day))
	end)

	it("formats days", function()
		assert.are.equal("2 days ago", format_ago(2 * day))
		assert.are.equal("6 days ago", format_ago(6 * day))
	end)

	it("formats one week as last week", function()
		assert.are.equal("last week", format_ago(7 * day))
		assert.are.equal("last week", format_ago(10 * day))
	end)

	it("formats weeks", function()
		assert.are.equal("2 weeks ago", format_ago(11 * day))
		assert.are.equal("4 weeks ago", format_ago(26 * day))
	end)

	it("formats one month as last month", function()
		assert.are.equal("last month", format_ago(27 * day))
		assert.are.equal("last month", format_ago(45 * day))
	end)

	it("formats months", function()
		assert.are.equal("2 months ago", format_ago(46 * day))
		assert.are.equal("11 months ago", format_ago(334 * day))
	end)

	it("formats one year as last year", function()
		assert.are.equal("last year", format_ago(360 * day))
		assert.are.equal("last year", format_ago(547 * day))
	end)

	it("formats years", function()
		assert.are.equal("2 years ago", format_ago(548 * day))
		assert.are.equal("52 years ago", format_ago(52 * 365 * day))
	end)
end)
