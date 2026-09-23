local BlameView = {}
BlameView.__index = BlameView

local parser = require("blame.parser")
local Breadcrumb = require("blame.breadcrumb")
local utils = require("blame.utils")

--- Creates a read-only scratch buffer that is wiped as soon as it is no longer displayed.
--- @return number bufnr
local function create_scratch_buffer()
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
	vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
	return bufnr
end

--- Sets the title of a window, escaping `%` for 'winbar'.
--- The title is never empty, because windows without a winbar would be misaligned by one row.
--- @param winid number|nil
--- @param title string
local function set_title(winid, title)
	if winid and vim.api.nvim_win_is_valid(winid) then
		local winbar = " " .. title:gsub("%%", "%%%%")
		vim.api.nvim_set_option_value("winbar", winbar, { scope = "local", win = winid })
	end
end

--- Writes lines into a read-only buffer.
--- @param bufnr number
--- @param lines string[]
local function set_lines(bufnr, lines)
	vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
end

function BlameView:new(dependencies)
	local instance = {
		git_instance = dependencies.git_instance,
		blame_bufnr = create_scratch_buffer(),
		file_bufnr = create_scratch_buffer(),
		blame_winid = nil,
		file_winid = nil,
		tabpage = nil,
		augroup = nil,
		ns_id = vim.api.nvim_create_namespace("blame"),
		breadcrumb = Breadcrumb:new(),
		blame_lines = {},
	}

	vim.api.nvim_set_option_value("filetype", "blame", { buf = instance.blame_bufnr })

	setmetatable(instance, BlameView)
	return instance
end

function BlameView:mount()
	local current_file_win = vim.api.nvim_get_current_win()
	local cursor_pos = vim.api.nvim_win_get_cursor(current_file_win)
	self.breadcrumb:push({ commit_info = nil, cursor_pos = cursor_pos })

	-- A new tab page leaves the user's window layout untouched
	vim.cmd("tab sbuffer " .. self.file_bufnr)
	self.tabpage = vim.api.nvim_get_current_tabpage()
	self.file_winid = vim.api.nvim_get_current_win()
	self.blame_winid = vim.api.nvim_open_win(self.blame_bufnr, true, {
		split = "left",
		win = self.file_winid,
		width = math.floor(vim.o.columns * 0.25),
	})

	for _, winid in ipairs({ self.blame_winid, self.file_winid }) do
		local wo = vim.wo[winid][0]
		wo.cursorline = true
		-- Keeps e.g. <C-o> from replacing the blame or file buffer
		wo.winfixbuf = true
	end
	local blame_wo = vim.wo[self.blame_winid][0]
	blame_wo.number = false
	blame_wo.relativenumber = false
	blame_wo.signcolumn = "no"
	blame_wo.foldcolumn = "0"
	blame_wo.list = false
	blame_wo.spell = false
	blame_wo.winfixwidth = true
	vim.wo[self.file_winid][0].number = true

	self:update_view(nil)

	utils.initialize_cursor_position(current_file_win, self.blame_winid)
	utils.initialize_cursor_position(current_file_win, self.file_winid)

	-- Closing one of the two windows (e.g. with `:q`) closes the whole view
	self.augroup = vim.api.nvim_create_augroup("blame_view_" .. self.tabpage, { clear = true })
	vim.api.nvim_create_autocmd("WinClosed", {
		group = self.augroup,
		pattern = { tostring(self.blame_winid), tostring(self.file_winid) },
		once = true,
		callback = function()
			vim.schedule(function()
				self:close()
			end)
		end,
	})
end

function BlameView:update_view(commit_info)
	local blame_result_stdout = self.git_instance:get_blame_output(commit_info)
	self.blame_lines = {}

	if not blame_result_stdout then
		return
	end

	local blame_title = (commit_info and commit_info.previous and commit_info.previous.commit:sub(1, 8)) or "HEAD"
	set_title(self.blame_winid, blame_title)

	local file_title
	if commit_info and commit_info.previous and commit_info.previous.filename then
		file_title = commit_info.previous.filename
	else
		file_title = self.git_instance.original_file:sub(#self.git_instance.git_root + 2)
	end
	set_title(self.file_winid, file_title)

	local blame_result = parser.parse_blame_output(blame_result_stdout)
	self.blame_lines = blame_result.lines

	local blame_content = {}
	local file_content = {}
	local commit_highlights = {}
	local previous_commit = ""
	for i, line in ipairs(self.blame_lines) do
		-- Only the first line of a block of lines from the same commit is annotated
		if line.header.commit ~= previous_commit then
			local highlight_group = "GitBlameCommit_" .. line.header.commit
			vim.api.nvim_set_hl(0, highlight_group, { fg = "#" .. line.header.commit:sub(1, 6) })
			commit_highlights[i] = highlight_group
			blame_content[i] = string.format("%s %s (%s)", line.header.commit:sub(1, 8), line.author, line.date)
			previous_commit = line.header.commit
		else
			blame_content[i] = ""
		end
		file_content[i] = line.line_content
	end

	set_lines(self.blame_bufnr, blame_content)
	set_lines(self.file_bufnr, file_content)

	vim.api.nvim_buf_clear_namespace(self.blame_bufnr, self.ns_id, 0, -1)
	for i, highlight_group in pairs(commit_highlights) do
		vim.api.nvim_buf_set_extmark(self.blame_bufnr, self.ns_id, i - 1, 0, {
			end_col = 8,
			hl_group = highlight_group,
		})
	end

	-- Set filetype for highlighting
	local filetype
	if commit_info and commit_info.previous and commit_info.previous.filename then
		filetype = vim.filetype.match({ filename = commit_info.previous.filename })
	else
		filetype = vim.filetype.match({ filename = self.git_instance.original_file })
	end

	if filetype then
		vim.api.nvim_set_option_value("filetype", filetype, { buf = self.file_bufnr })
	end

	-- Must come after setting the filetype, because ftplugins or the user config may change these options
	self:keep_lines_aligned()
end

--- Makes every buffer line take exactly one screen row, so the lines of both windows stay aligned.
--- 'scrollbind' and 'cursorbind' only sync buffer lines, not screen rows.
function BlameView:keep_lines_aligned()
	for _, winid in ipairs({ self.blame_winid, self.file_winid }) do
		if winid and vim.api.nvim_win_is_valid(winid) then
			vim.wo[winid][0].wrap = false
			vim.wo[winid][0].foldenable = false
		end
	end
end

--- Moves the cursor in both windows to the same line and re-aligns their scroll views.
--- @param line_num number
function BlameView:set_cursor(line_num)
	utils.set_cursor_to_line(self.blame_winid, line_num)
	utils.set_cursor_to_line(self.file_winid, line_num)
	vim.api.nvim_win_call(self.file_winid, function()
		vim.cmd("syncbind")
	end)
end

function BlameView:navigate_forward()
	local line_num = vim.api.nvim_win_get_cursor(0)[1]
	local commit_info = self.blame_lines[line_num]
	if not commit_info then
		return
	end

	if not commit_info.previous then
		vim.notify("blame.nvim: No previous commit for this line (boundary commit).", vim.log.levels.INFO)
		return
	end

	local current = self.breadcrumb:current()
	if current then
		current.cursor_pos = vim.api.nvim_win_get_cursor(0)
	end

	if self.breadcrumb:push({ commit_info = commit_info, cursor_pos = nil }) then
		self:update_view(commit_info)
		if commit_info and commit_info.header and commit_info.header.source_line then
			self:set_cursor(commit_info.header.source_line)
		end
	end
end

function BlameView:navigate_backward()
	if #self.breadcrumb.stack <= 1 then
		vim.notify("blame.nvim: No more history to go back to.", vim.log.levels.INFO)
		return
	end
	self.breadcrumb:pop()
	local current = self.breadcrumb:current()
	self:update_view(current.commit_info)

	if current.cursor_pos then
		self:set_cursor(current.cursor_pos[1])
	end
end

function BlameView:close()
	if self.augroup then
		vim.api.nvim_del_augroup_by_id(self.augroup)
		self.augroup = nil
	end

	if self.tabpage and vim.api.nvim_tabpage_is_valid(self.tabpage) then
		if #vim.api.nvim_list_tabpages() == 1 then
			-- The last tab page cannot be closed, so open an empty one to fall back to
			vim.cmd("tabnew")
		end
		vim.cmd("tabclose " .. vim.api.nvim_tabpage_get_number(self.tabpage))
	end
	self.tabpage = nil
end

return BlameView
