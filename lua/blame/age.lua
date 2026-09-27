-- lua/blame/age.lua
-- Colours for the age of a commit, like the stripe of GitHub's blame view: faint for older, strong for newer.

local M = {}

M.BUCKETS = 10

--- The share of the accent colour in the oldest bucket, so even the oldest commits stay visible.
local OLDEST_MIX = 0.25

--- Sorts an age into a bucket, relative to the ages of all commits of the file.
--- The scale is logarithmic, because files usually have a few recent commits and a long tail of old ones.
--- @param age number Seconds
--- @param newest_age number Seconds
--- @param oldest_age number Seconds
--- @return number bucket From 1 (oldest) to M.BUCKETS (newest)
function M.bucket(age, newest_age, oldest_age)
	local function log(seconds)
		return math.log(math.max(seconds, 1))
	end
	local range = log(oldest_age) - log(newest_age)
	if range <= 0 then
		return M.BUCKETS
	end
	local recency = (log(oldest_age) - log(age)) / range
	return math.max(1, math.min(M.BUCKETS, math.floor(recency * M.BUCKETS) + 1))
end

--- Mixes two RGB colours.
--- @param from number RGB colour
--- @param to number RGB colour
--- @param ratio number Share of `to`, from 0 to 1
--- @return number RGB colour
function M.blend(from, to, ratio)
	local color = 0
	for _, shift in ipairs({ 16, 8, 0 }) do
		local a = math.floor(from / 2 ^ shift) % 256
		local b = math.floor(to / 2 ^ shift) % 256
		color = color + math.floor(a + (b - a) * ratio + 0.5) * 2 ^ shift
	end
	return color
end

--- Returns the highlight group of a bucket.
--- @param bucket number
--- @return string
function M.highlight_group(bucket)
	return "GitBlameAge" .. bucket
end

--- Returns the highlight group of a bucket in the legend, which keeps the background of the winbar.
--- @param bucket number
--- @return string
function M.legend_highlight_group(bucket)
	return "GitBlameAgeLegend" .. bucket
end

local OLDER = "Older "
local NEWER = " Newer "

--- Returns a legend of the colours for 'winbar', like "Older ▎▎▎▎▎ Newer" in GitHub's blame view.
--- @return string
function M.legend()
	local bars = {}
	for bucket = 1, M.BUCKETS do
		table.insert(bars, "%#" .. M.legend_highlight_group(bucket) .. "#▎")
	end
	return OLDER .. table.concat(bars) .. "%*" .. NEWER
end

--- Returns the legend if it fits into the 'winbar' of the window being drawn, next to its title, otherwise nothing.
--- @param title_width number
--- @return string
function M.legend_if_fits(title_width)
	-- `%{}` in 'winbar' is evaluated with the window being drawn as the current window
	local width = vim.api.nvim_win_get_width(0)
	local legend_width = vim.fn.strdisplaywidth(OLDER .. NEWER) + M.BUCKETS
	-- At least one space between the title and the legend
	if title_width + 1 + legend_width > width then
		return ""
	end
	return M.legend()
end

--- Returns 'winbar' items for the legend, evaluated whenever the window is redrawn, so it appears and disappears
--- when the window is resized.
--- @param title_width number
--- @return string
function M.winbar_legend(title_width)
	return string.format("%%{%%v:lua.require'blame.age'.legend_if_fits(%d)%%}", title_width)
end

--- Defines one highlight group per bucket, blended from the background towards `GitBlameAge`,
--- so the colours follow the colour scheme in light and dark themes.
function M.define_highlights()
	vim.api.nvim_set_hl(0, "GitBlameAge", { link = "DiagnosticWarn", default = true })
	local accent = vim.api.nvim_get_hl(0, { name = "GitBlameAge", link = false }).fg
	if not (vim.o.termguicolors and accent) then
		-- Blending needs RGB colours, so all buckets look the same
		for bucket = 1, M.BUCKETS do
			vim.api.nvim_set_hl(0, M.highlight_group(bucket), { link = "GitBlameAge" })
			vim.api.nvim_set_hl(0, M.legend_highlight_group(bucket), { link = "GitBlameAge" })
		end
		return
	end

	-- Transparent terminals have no background colour
	local background = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg
		or (vim.o.background == "light" and 0xffffff or 0x000000)
	-- `%#Group#` in 'winbar' does not inherit its background, and `%$Group$`, which does, needs Neovim 0.12
	local winbar_background = vim.api.nvim_get_hl(0, { name = "WinBar", link = false }).bg
	for bucket = 1, M.BUCKETS do
		local ratio = OLDEST_MIX + (1 - OLDEST_MIX) * (bucket - 1) / (M.BUCKETS - 1)
		local color = M.blend(background, accent, ratio)
		vim.api.nvim_set_hl(0, M.highlight_group(bucket), { fg = color })
		vim.api.nvim_set_hl(0, M.legend_highlight_group(bucket), { fg = color, bg = winbar_background })
	end
end

return M
