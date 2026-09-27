-- lua/blame/relative_date.lua
-- Formats timestamps relative to now, like GitHub does, e.g. "3 days ago" or "last year".

local M = {}

local MINUTE = 60
local HOUR = 60 * MINUTE
local DAY = 24 * HOUR
local MONTH = 30.4375 * DAY
local YEAR = 365.25 * DAY

local function round(number)
	return math.floor(number + 0.5)
end

--- @param count number
--- @param unit string
--- @param last string|nil The word for a count of one, e.g. "yesterday"
local function ago(count, unit, last)
	if count == 1 then
		return last or ("1 " .. unit .. " ago")
	end
	return string.format("%d %ss ago", count, unit)
end

--- Formats a timestamp relative to now, rounded to a single unit.
--- @param timestamp number Seconds since the epoch
--- @param now number Seconds since the epoch
--- @return string
function M.format(timestamp, now)
	-- Clocks of other committers may be ahead
	local seconds = math.max(now - timestamp, 0)

	if seconds == 0 then
		return "now"
	elseif seconds < 55 then
		return ago(seconds, "second")
	elseif round(seconds / MINUTE) < 55 then
		return ago(round(seconds / MINUTE), "minute")
	elseif round(seconds / HOUR) < 21 then
		return ago(round(seconds / HOUR), "hour")
	end

	local days = round(seconds / DAY)
	if days < 7 then
		return ago(days, "day", "yesterday")
	elseif days < 27 then
		return ago(round(days / 7), "week", "last week")
	elseif round(seconds / MONTH) < 12 then
		return ago(round(seconds / MONTH), "month", "last month")
	end
	return ago(math.max(round(seconds / YEAR), 1), "year", "last year")
end

return M
