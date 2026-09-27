local BlameView = {}
BlameView.__index = BlameView

local parser = require("blame.parser")
local relative_date = require("blame.relative_date")
local Breadcrumb = require("blame.breadcrumb")
local CommitPanel = require("blame.commit_panel")
local utils = require("blame.utils")

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

--- Highlights the syntax of a buffer without setting its 'filetype'.
--- Setting the filetype would run ftplugins and FileType autocmds, e.g. LSP clients or plugins that
--- add virtual lines, which misalign the file content with the blame information.
--- @param bufnr number
--- @param filetype string|nil
local function highlight_syntax(bufnr, filetype)
	-- Neovim 0.10 fails to stop the highlighter if 'syntax_on' is set without the `syntaxset` autocmd group
	pcall(vim.treesitter.stop, bufnr)
	vim.bo[bufnr].syntax = ""
	if not filetype then
		return
	end

	-- Neovim 0.10 only returns explicitly registered languages, so fall back to the filetype like `vim.treesitter.start()`
	local lang = vim.treesitter.language.get_lang(filetype) or filetype
	if not pcall(vim.treesitter.start, bufnr, lang) then
		-- No tree-sitter parser is installed for this language
		vim.bo[bufnr].syntax = filetype
	end
end

--- Pads a string with spaces to a display width.
--- @param text string
--- @param width number
--- @return string
local function pad(text, width)
	return text .. string.rep(" ", width - vim.fn.strdisplaywidth(text))
end

function BlameView:new(dependencies)
	local instance = {
		git_instance = dependencies.git_instance,
		blame_bufnr = utils.create_scratch_buffer(),
		file_bufnr = utils.create_scratch_buffer(),
		blame_winid = nil,
		file_winid = nil,
		tabpage = nil,
		previous_tabpage = nil,
		augroup = nil,
		ns_id = vim.api.nvim_create_namespace("blame"),
		breadcrumb = Breadcrumb:new(),
		commit_panel = CommitPanel:new({ git_instance = dependencies.git_instance }),
		blame_lines = {},
		closed_in_view = nil,
		check_windows_scheduled = false,
	}

	setmetatable(instance, BlameView)
	return instance
end

--- Opens the view in a new tab page.
--- @return boolean mounted false if git blame failed, then nothing is opened
function BlameView:mount()
	-- Run git blame first, so a failure does not leave an empty tab page behind
	local blame_output = self.git_instance:get_blame_output(nil)
	if not blame_output then
		vim.api.nvim_buf_delete(self.blame_bufnr, { force = true })
		vim.api.nvim_buf_delete(self.file_bufnr, { force = true })
		self.commit_panel:destroy()
		return false
	end

	local current_file_win = vim.api.nvim_get_current_win()
	local cursor_pos = vim.api.nvim_win_get_cursor(current_file_win)
	self.breadcrumb:push({ commit_info = nil, cursor_pos = cursor_pos })

	-- A new tab page leaves the user's window layout untouched
	self.previous_tabpage = vim.api.nvim_get_current_tabpage()
	vim.cmd("tab sbuffer " .. self.file_bufnr)
	self.tabpage = vim.api.nvim_get_current_tabpage()
	self.file_winid = vim.api.nvim_get_current_win()
	self.blame_winid = vim.api.nvim_open_win(self.blame_bufnr, true, {
		split = "left",
		win = self.file_winid,
		width = math.floor(vim.o.columns / 3),
	})

	-- Defaults only: the user config may change them for the blame window via its filetype.
	-- New windows take over the window-local options of the window `:Blame` was run from, so reset the gutter.
	vim.wo[self.blame_winid][0].cursorline = true
	vim.wo[self.file_winid][0].cursorline = true
	local blame_wo = vim.wo[self.blame_winid][0]
	blame_wo.number = false
	blame_wo.relativenumber = false
	blame_wo.statuscolumn = ""
	blame_wo.signcolumn = "no"
	blame_wo.foldcolumn = "0"
	blame_wo.list = false
	blame_wo.spell = false
	blame_wo.colorcolumn = ""
	blame_wo.winfixwidth = true
	vim.wo[self.file_winid][0].number = true
	vim.bo[self.blame_bufnr].filetype = "blame"

	self:update_view(nil, blame_output)

	utils.initialize_cursor_position(current_file_win, self.blame_winid)
	utils.initialize_cursor_position(current_file_win, self.file_winid)

	-- Closing a window of the view or opening another buffer in it, e.g. from a file explorer, leaves the view.
	-- Both only queue a check of the resulting windows, so the order of the events does not matter.
	self.augroup = vim.api.nvim_create_augroup("blame_view_" .. self.tabpage, { clear = true })
	vim.api.nvim_create_autocmd("WinClosed", {
		group = self.augroup,
		pattern = { tostring(self.blame_winid), tostring(self.file_winid) },
		callback = function()
			-- Checked right away, because Neovim switches to another tab page before the scheduled check
			self.closed_in_view = self.closed_in_view or vim.api.nvim_get_current_tabpage() == self.tabpage
			self:schedule_check_windows()
		end,
	})
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = self.augroup,
		callback = function()
			if self:view_windows()[vim.api.nvim_get_current_win()] then
				self:schedule_check_windows()
			end
		end,
	})
	vim.api.nvim_create_autocmd("CursorMoved", {
		group = self.augroup,
		buffer = self.blame_bufnr,
		callback = function()
			self:show_commit_message()
		end,
	})
	vim.api.nvim_create_autocmd("CursorMoved", {
		group = self.augroup,
		buffer = self.file_bufnr,
		callback = function()
			self:show_commit_message()
		end,
	})
	return true
end

--- Shows the blame and file content of a version.
--- @param commit_info table|nil The line whose previous version to show, nil for the current one
--- @param blame_output string|nil The output of git blame, if it has already been run
--- @return boolean updated false if git blame failed, then the view stays unchanged
function BlameView:update_view(commit_info, blame_output)
	local blame_result_stdout = blame_output or self.git_instance:get_blame_output(commit_info)
	if not blame_result_stdout then
		return false
	end

	local blame_title = (commit_info and commit_info.previous and commit_info.previous.commit:sub(1, 8))
		or "Working tree"
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

	local file_content = {}
	for i, line in ipairs(self.blame_lines) do
		file_content[i] = line.line_content
	end
	self:render_blame()
	utils.set_lines(self.file_bufnr, file_content)

	local filename
	if commit_info and commit_info.previous and commit_info.previous.filename then
		filename = commit_info.previous.filename
	else
		filename = self.git_instance.original_file
	end
	-- Passing the buffer also detects filetypes from the content, e.g. from a shebang
	local filetype = vim.filetype.match({ buf = self.file_bufnr, filename = filename })
	highlight_syntax(self.file_bufnr, filetype)

	self:enforce_view_options()
	return true
end

--- Writes the date, author and subject of each block of lines into the blame buffer, like GitHub's blame view.
function BlameView:render_blame()
	local now = os.time()
	local annotations = {}
	local date_width = 0
	local author_width = 0
	local previous_commit = ""
	for i, line in ipairs(self.blame_lines) do
		-- Only the first line of a block of lines from the same commit is annotated
		if line.header.commit ~= previous_commit then
			local annotation = {
				date = line.author_time and relative_date.format(line.author_time, now) or "",
				author = line.author or "",
				subject = line.summary or "",
			}
			date_width = math.max(date_width, vim.fn.strdisplaywidth(annotation.date))
			author_width = math.max(author_width, vim.fn.strdisplaywidth(annotation.author))
			annotations[i] = annotation
			previous_commit = line.header.commit
		end
	end

	local blame_content = {}
	for i = 1, #self.blame_lines do
		local annotation = annotations[i]
		if annotation then
			local date = pad(annotation.date, date_width)
			annotation.author_col = #date + 1
			blame_content[i] = date .. " " .. pad(annotation.author, author_width) .. " " .. annotation.subject
		else
			blame_content[i] = ""
		end
	end
	utils.set_lines(self.blame_bufnr, blame_content)

	-- Alternating colours tell the columns apart: date and subject stand out, the author between them does not
	vim.api.nvim_set_hl(0, "GitBlameDate", { link = "Normal", default = true })
	vim.api.nvim_set_hl(0, "GitBlameAuthor", { link = "Comment", default = true })
	vim.api.nvim_set_hl(0, "GitBlameSubject", { link = "Normal", default = true })
	vim.api.nvim_buf_clear_namespace(self.blame_bufnr, self.ns_id, 0, -1)
	for i, annotation in pairs(annotations) do
		local subject_col = annotation.author_col + #pad(annotation.author, author_width) + 1
		for _, column in ipairs({
			{ 0, #annotation.date, "GitBlameDate" },
			{ annotation.author_col, annotation.author_col + #annotation.author, "GitBlameAuthor" },
			{ subject_col, subject_col + #annotation.subject, "GitBlameSubject" },
		}) do
			vim.api.nvim_buf_set_extmark(self.blame_bufnr, self.ns_id, i - 1, column[1], {
				end_col = column[2],
				hl_group = column[3],
			})
		end
	end
end

--- Sets the window options the view depends on, overriding the user config.
function BlameView:enforce_view_options()
	for _, winid in ipairs({ self.blame_winid, self.file_winid }) do
		if winid and vim.api.nvim_win_is_valid(winid) then
			local wo = vim.wo[winid][0]
			wo.scrollbind = true
			wo.cursorbind = true
			-- 'scrollbind' and 'cursorbind' only sync buffer lines, not screen rows,
			-- so every buffer line has to take exactly one screen row
			wo.wrap = false
			wo.foldenable = false
			-- Diff mode adds filler lines, e.g. when `:Blame` is run from a diff window
			wo.diff = false
		end
	end
end

--- Returns the blame information of the cursor line.
--- @return table|nil
function BlameView:get_cursor_line()
	-- Both windows have the same cursor row, but the current window may be another one, e.g. the commit panel
	local winid = vim.api.nvim_get_current_win()
	if winid ~= self.blame_winid then
		winid = self.file_winid
	end
	return self.blame_lines[vim.api.nvim_win_get_cursor(winid)[1]]
end

--- Opens or closes the panel with the commit message of the cursor line.
function BlameView:toggle_commit_message()
	local line = self:get_cursor_line()
	if line then
		self.commit_panel:toggle(line.header.commit)
	end
end

--- Shows the commit message of the cursor line, if the commit panel is open.
function BlameView:show_commit_message()
	local line = self:get_cursor_line()
	if line then
		self.commit_panel:show(line.header.commit)
	end
end

--- Moves the cursor in both windows to the same position and re-aligns their scroll views.
--- @param cursor_pos table {row, col}
function BlameView:set_cursor(cursor_pos)
	for _, winid in ipairs({ self.blame_winid, self.file_winid }) do
		utils.set_cursor_to_line(winid, cursor_pos[1], cursor_pos[2])
	end
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
		if not self:update_view(commit_info) then
			self.breadcrumb:pop()
			return
		end
		if commit_info and commit_info.header and commit_info.header.source_line then
			self:set_cursor({ commit_info.header.source_line, 0 })
		end
		self:show_commit_message()
	end
end

function BlameView:navigate_backward()
	if #self.breadcrumb.stack <= 1 then
		vim.notify("blame.nvim: No more history to go back to.", vim.log.levels.INFO)
		return
	end
	local popped = self.breadcrumb:pop()
	local current = self.breadcrumb:current()
	if not self:update_view(current.commit_info) then
		self.breadcrumb:push(popped)
		return
	end

	if current.cursor_pos then
		self:set_cursor(current.cursor_pos)
	end
	self:show_commit_message()
end

--- Returns the windows of the view, each with the buffer it shows as long as it is part of the view.
--- @return table<number, number> bufnr by winid
function BlameView:view_windows()
	local windows = {
		[self.blame_winid] = self.blame_bufnr,
		[self.file_winid] = self.file_bufnr,
	}
	if self.commit_panel.winid then
		windows[self.commit_panel.winid] = self.commit_panel.bufnr
	end
	return windows
end

--- @param bufnr number
--- @return boolean
function BlameView:is_view_buffer(bufnr)
	return bufnr == self.blame_bufnr or bufnr == self.file_bufnr or bufnr == self.commit_panel.bufnr
end

--- Checks the windows of the view once the current events are handled. Scheduled, because closing windows
--- while e.g. a file explorer still opens a buffer confuses it, and because a single command can close a window
--- and open a buffer in another one.
function BlameView:schedule_check_windows()
	if self.check_windows_scheduled then
		return
	end
	self.check_windows_scheduled = true
	vim.schedule(function()
		self.check_windows_scheduled = false
		self:check_windows()
	end)
end

--- Leaves the view if its windows no longer show their own buffers. Windows that show other buffers, e.g. a file
--- opened from an explorer, are handed over. Otherwise, a closed window or a buffer of the view in the wrong window,
--- e.g. after `:buffer`, closes the whole view.
function BlameView:check_windows()
	if not self.tabpage then
		return
	end
	local broken = false
	for winid, bufnr in pairs(self:view_windows()) do
		if not vim.api.nvim_win_is_valid(winid) then
			-- The commit panel can be closed on its own
			broken = broken or winid ~= self.commit_panel.winid
		else
			local shown_bufnr = vim.api.nvim_win_get_buf(winid)
			if not self:is_view_buffer(shown_bufnr) then
				self:release()
				return
			end
			broken = broken or shown_bufnr ~= bufnr
		end
	end
	if broken then
		self:close(self.closed_in_view)
	end
end

--- Closes the view, except for its windows that show other buffers now, which become normal windows.
--- The tab page stays, e.g. with the file explorer the buffers were opened from.
function BlameView:release()
	if self.augroup then
		vim.api.nvim_del_augroup_by_id(self.augroup)
		self.augroup = nil
	end
	for winid in pairs(self:view_windows()) do
		if vim.api.nvim_win_is_valid(winid) then
			if self:is_view_buffer(vim.api.nvim_win_get_buf(winid)) then
				vim.api.nvim_win_close(winid, true)
			elseif winid == self.commit_panel.winid then
				self.commit_panel.winid = nil
			end
		end
	end
	self.commit_panel:destroy()
	self.tabpage = nil
end

--- Closes the view and returns to the tab page it was opened from.
--- @param return_to_previous_tabpage boolean|nil Defaults to whether the view is the current tab page,
--- so closing the view from another tab page does not switch tab pages.
function BlameView:close(return_to_previous_tabpage)
	if return_to_previous_tabpage == nil then
		return_to_previous_tabpage = vim.api.nvim_get_current_tabpage() == self.tabpage
	end

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
	self.commit_panel:destroy()

	-- `:tabclose` moves to the tab page on the right, not to the one the view was opened from
	if
		return_to_previous_tabpage
		and self.previous_tabpage
		and vim.api.nvim_tabpage_is_valid(self.previous_tabpage)
	then
		vim.api.nvim_set_current_tabpage(self.previous_tabpage)
	end
end

return BlameView
